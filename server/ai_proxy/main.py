"""AI-прокси для FuelMaster.

Зачем: ключ AI-провайдера не должен попадать в APK. Приложение в release
обращается сюда, а ключ хранится только на сервере (переменные окружения).

Что делает:
  * проверяет Firebase ID token пользователя (firebase-admin);
  * ограничивает частоту запросов на пользователя;
  * фиксирует модель и лимит токенов на стороне сервера (клиент их не выбирает);
  * ходит к провайдеру и возвращает только текст совета.

Запуск (см. README.md рядом):
    uvicorn main:app --host 127.0.0.1 --port 8095
"""

from __future__ import annotations

import logging
import os
import time
from collections import defaultdict, deque
from typing import Any, Deque, Dict

import firebase_admin
import httpx
from fastapi import FastAPI, Header, HTTPException, Request
from firebase_admin import auth as fb_auth
from firebase_admin import credentials
from pydantic import BaseModel, Field

import entitlements

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("fuelmaster.ai")

# ---------------------------------------------------------------- конфигурация

PROVIDER_URL = os.environ.get(
    "AI_PROVIDER_URL", "https://openrouter.ai/api/v1/chat/completions"
)
PROVIDER_KEY = os.environ.get("AI_PROVIDER_KEY", "")
PROVIDER_MODEL = os.environ.get("AI_PROVIDER_MODEL", "deepseek/deepseek-r1-0528:free")
PROVIDER_MAX_TOKENS = int(os.environ.get("AI_PROVIDER_MAX_TOKENS", "1700"))
REQUEST_TIMEOUT = float(os.environ.get("AI_REQUEST_TIMEOUT", "55"))

RATE_LIMIT_PER_HOUR = int(os.environ.get("AI_RATE_LIMIT_PER_HOUR", "20"))
MAX_PROMPT_CHARS = int(os.environ.get("AI_MAX_PROMPT_CHARS", "4000"))
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "")
FIREBASE_SERVICE_ACCOUNT = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "")

if not PROVIDER_KEY:
    log.warning("AI_PROVIDER_KEY не задан — запросы к провайдеру будут падать с 503")

AUTH_READY = False

if FIREBASE_SERVICE_ACCOUNT and os.path.exists(FIREBASE_SERVICE_ACCOUNT):
    firebase_admin.initialize_app(
        credentials.Certificate(FIREBASE_SERVICE_ACCOUNT),
        {"projectId": FIREBASE_PROJECT_ID} if FIREBASE_PROJECT_ID else None,
    )
    AUTH_READY = True
    log.info("firebase-admin инициализирован")
else:
    log.warning(
        "FIREBASE_SERVICE_ACCOUNT не найден — проверка пользователей отключена, "
        "эндпоинт /v1/advice отвечает 503"
    )

app = FastAPI(title="FuelMaster AI proxy", docs_url=None, redoc_url=None)

_hits: Dict[str, Deque[float]] = defaultdict(deque)


# --------------------------------------------------------------------- модели


class AdviceRequest(BaseModel):
    """Запрос совета. Метрики расчёта идут в details и попадают в промпт."""

    car_model: str = Field(default="автомобиль", max_length=200)
    details: Dict[str, Any] | None = None
    prompt: str = Field(default="", max_length=8000)


class EntitlementRequest(BaseModel):
    """Чек Google Play для серверной проверки премиума (A-7 аудита)."""

    purchase_token: str = Field(min_length=8, max_length=4096)
    product_id: str = Field(min_length=1, max_length=200)


# ------------------------------------------------------------------- служебное


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _check_rate_limit(uid: str) -> None:
    now = time.time()
    window: Deque[float] = _hits[uid]
    while window and now - window[0] > 3600:
        window.popleft()
    if len(window) >= RATE_LIMIT_PER_HOUR:
        retry_in = int(3600 - (now - window[0])) + 1
        raise HTTPException(
            status_code=429,
            detail=f"Слишком много запросов. Повторите через {retry_in} с.",
        )
    window.append(now)


def _verify_user(authorization: str | None) -> str:
    if not AUTH_READY:
        raise HTTPException(status_code=503, detail="Проверка пользователей не настроена")
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Нужен Firebase ID token")

    token = authorization.split(" ", 1)[1].strip()
    try:
        decoded = fb_auth.verify_id_token(token, check_revoked=False)
    except Exception as exc:  # noqa: BLE001 — наружу отдаём только 401
        log.info("Отклонён токен: %s", type(exc).__name__)
        raise HTTPException(status_code=401, detail="Недействительный токен") from exc

    uid = decoded.get("uid") or decoded.get("sub")
    if not uid:
        raise HTTPException(status_code=401, detail="В токене нет uid")
    return str(uid)


def _build_prompt(payload: AdviceRequest) -> str:
    if payload.prompt.strip():
        prompt = payload.prompt.strip()
    else:
        details = payload.details or {}
        prompt = (
            f"Дайте детальные и специфические советы на русском языке по оптимизации "
            f"расхода топлива для автомобиля {payload.car_model} для водителя со стажем "
            f"более 5 лет. "
        )
        if details:
            prompt += (
                "Используйте данные: общий пробег %s км, город %s км, трасса %s км, "
                "норма город %s л/100 км, норма трасса %s л/100 км. "
                % (
                    details.get("total_mileage", "—"),
                    details.get("city_mileage", "—"),
                    details.get("highway_mileage", "—"),
                    details.get("base_city_norm", "—"),
                    details.get("base_highway_norm", "—"),
                )
            )
        prompt += (
            "Сфокусируйтесь на техническом обслуживании, маршрутах, настройке двигателя "
            "и шин, избегая общих фраз."
        )
    return prompt[:MAX_PROMPT_CHARS]


# --------------------------------------------------------------------- routes


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "provider_configured": bool(PROVIDER_KEY),
        "auth_configured": AUTH_READY,
    }


@app.post("/v1/entitlement")
async def confirm_entitlement(
    payload: EntitlementRequest,
    authorization: str | None = Header(default=None),
) -> Dict[str, Any]:
    """Проверяет чек Google Play и записывает вердикт в Firestore.

    503 `verification_unavailable` — проверить нельзя (нет сервисного
    аккаунта, Play недоступен): клиент в этом случае статус не меняет.
    """
    uid = _verify_user(authorization)

    if not entitlements.is_configured():
        raise HTTPException(status_code=503, detail="verification_unavailable")

    try:
        verdict = entitlements.verify_purchase(
            payload.purchase_token, payload.product_id
        )
    except entitlements.VerifyUnavailable as exc:
        log.warning("Проверка чека недоступна uid=%s err=%s", uid[:8], exc)
        raise HTTPException(status_code=503, detail="verification_unavailable") from exc

    try:
        entitlements.store_entitlement(uid, verdict)
    except Exception as exc:  # noqa: BLE001 — вердикт важнее записи
        log.error("Не записал entitlement uid=%s err=%s", uid[:8], type(exc).__name__)

    log.info(
        "Премиум uid=%s premium=%s reason=%s",
        uid[:8],
        verdict.premium,
        verdict.reason,
    )
    return {
        "premium": verdict.premium,
        "reason": verdict.reason,
        "expires_at": verdict.expires_at,
    }


@app.get("/v1/entitlement")
async def get_entitlement(
    authorization: str | None = Header(default=None),
) -> Dict[str, Any]:
    """Сохранённый вердикт для сверки при старте приложения.

    Вердиктом считается только 200. Если записи нет — 404 `no_record`:
    клиент оставит локальный статус, пока чек не придёт из магазина.
    """
    uid = _verify_user(authorization)

    try:
        data = entitlements.read_entitlement(uid)
    except Exception as exc:  # noqa: BLE001
        log.error("Не прочитал entitlement uid=%s err=%s", uid[:8], type(exc).__name__)
        raise HTTPException(status_code=503, detail="entitlement_unavailable") from exc

    if data is None:
        raise HTTPException(status_code=404, detail="no_record")

    return {
        "premium": bool(data.get("premium")),
        "reason": data.get("reason", "no_record"),
        "expires_at": data.get("expires_at"),
    }


@app.post("/v1/advice")
async def advice(
    payload: AdviceRequest,
    request: Request,
    authorization: str | None = Header(default=None),
) -> Dict[str, Any]:
    uid = _verify_user(authorization)
    _check_rate_limit(uid)

    if not PROVIDER_KEY:
        raise HTTPException(status_code=503, detail="AI-провайдер не настроен")

    prompt = _build_prompt(payload)
    body = {
        "model": PROVIDER_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": PROVIDER_MAX_TOKENS,
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {PROVIDER_KEY}",
    }

    started = time.monotonic()
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            response = await client.post(PROVIDER_URL, json=body, headers=headers)
    except httpx.HTTPError as exc:
        log.error("Провайдер недоступен uid=%s err=%s", uid[:8], type(exc).__name__)
        raise HTTPException(status_code=502, detail="AI-провайдер недоступен") from exc

    elapsed = round(time.monotonic() - started, 2)

    if response.status_code == 402:
        log.error("Провайдер: нет баланса uid=%s", uid[:8])
        raise HTTPException(status_code=402, detail="Недостаточно средств на балансе AI")

    if response.status_code != 200:
        log.error(
            "Провайдер вернул %s uid=%s ip=%s",
            response.status_code,
            uid[:8],
            _client_ip(request),
        )
        raise HTTPException(status_code=502, detail="Ошибка AI-провайдера")

    try:
        data = response.json()
        advice = data["choices"][0]["message"]["content"]
    except (ValueError, KeyError, IndexError, TypeError):
        log.error("Неожиданный ответ провайдера uid=%s", uid[:8])
        raise HTTPException(status_code=502, detail="Некорректный ответ AI-провайдера")

    log.info(
        "OK uid=%s model=%s chars=%s elapsed=%ss",
        uid[:8],
        PROVIDER_MODEL,
        len(advice or ""),
        elapsed,
    )
    return {"advice": advice}
