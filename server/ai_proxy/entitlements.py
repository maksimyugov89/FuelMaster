"""Серверная проверка премиум-статуса (хвост A-7 аудита).

Единственный источник правды о премиуме — чек Google Play, проверенный здесь.
Клиент присылает `purchase_token`, сервер отвечает вердиктом и пишет
entitlement в Firestore (`users/{uid}/entitlements/premium`), куда клиент
писать не может.

Переменные окружения (см. README.md рядом):
  PLAY_PACKAGE_NAME          — applicationId приложения (обязателен);
  PLAY_SERVICE_ACCOUNT_FILE  — путь к json сервисного аккаунта Play;
  PLAY_SERVICE_ACCOUNT_JSON  — тот же json строкой (альтернатива файлу);
  PLAY_SUBSCRIPTION_PRODUCTS — product_id подписок через запятую.

Если Play API не настроен, наружу уходит `verification_unavailable` (503),
и клиент НЕ меняет локальный статус: сеть, ошибки и отсутствие настройки
никогда не «отменяют» премиум у платящего пользователя.
"""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Dict, Optional

log = logging.getLogger("fuelmaster.entitlements")

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
REQUEST_TIMEOUT = float(os.environ.get("PLAY_REQUEST_TIMEOUT", "20"))

# Состояния подписки, при которых доступ сохраняется.
ACTIVE_SUBSCRIPTION_STATES = frozenset(
    {
        "SUBSCRIPTION_STATE_ACTIVE",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    }
)

PURCHASE_STATE_NAMES = {0: "purchased", 1: "canceled", 2: "pending"}


class VerifyUnavailable(RuntimeError):
    """Проверить чек сейчас нельзя (нет настройки, сеть, 5xx Play)."""


@dataclass(frozen=True)
class Verdict:
    """Вердикт по чеку."""

    premium: bool
    reason: str
    expires_at: Optional[int] = None
    source: str = "google_play"


def evaluate_one_time(payload: Dict[str, Any]) -> Verdict:
    """Разбор ответа `purchases.products.get` (разовая покупка)."""
    state = payload.get("purchaseState")
    if state == 0:
        return Verdict(premium=True, reason="purchased")
    return Verdict(
        premium=False,
        reason=PURCHASE_STATE_NAMES.get(state, f"purchase_state_{state}"),
    )


def evaluate_subscription(payload: Dict[str, Any]) -> Verdict:
    """Разбор ответа `purchases.subscriptionsv2.get` (подписка)."""
    state = str(payload.get("subscriptionState") or "").strip()
    expires: Optional[int] = None
    for item in payload.get("lineItems") or []:
        ms = _millis_from_rfc3339(item.get("expiryTime"))
        if ms and (expires is None or ms > expires):
            expires = ms

    if state in ACTIVE_SUBSCRIPTION_STATES:
        return Verdict(premium=True, reason=state.lower(), expires_at=expires)
    return Verdict(
        premium=False,
        reason=state.lower() or "unknown_subscription_state",
        expires_at=expires,
    )


def evaluate(payload: Dict[str, Any]) -> Verdict:
    """Определяет тип покупки по форме ответа Play API."""
    if "subscriptionState" in payload:
        return evaluate_subscription(payload)
    return evaluate_one_time(payload)


def _millis_from_rfc3339(value: Optional[str]) -> Optional[int]:
    """`2026-09-13T15:00:00Z` → миллисекунды эпохи (только stdlib)."""
    if not value:
        return None
    try:
        from datetime import datetime, timezone

        text = str(value).strip().replace("Z", "+00:00")
        moment = datetime.fromisoformat(text)
        if moment.tzinfo is None:
            moment = moment.replace(tzinfo=timezone.utc)
        return int(moment.timestamp() * 1000)
    except Exception:  # noqa: BLE001 — некорректная дата не должна ломать вердикт
        return None


def _subscription_products() -> set:
    raw = os.environ.get("PLAY_SUBSCRIPTION_PRODUCTS", "")
    return {item.strip() for item in raw.split(",") if item.strip()}


@lru_cache(maxsize=1)
def _credentials():
    """Сервисный аккаунт Play Developer API или None.

    `google-auth` приходит транзитивной зависимостью firebase-admin.
    """
    try:
        from google.oauth2 import service_account
    except ImportError:  # pragma: no cover — окружение без google-auth
        log.warning("google-auth недоступен: проверка чеков выключена")
        return None

    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "")
    if raw:
        try:
            info = json.loads(raw)
        except ValueError:
            log.error("PLAY_SERVICE_ACCOUNT_JSON не является JSON")
            return None
        return service_account.Credentials.from_service_account_info(
            info, scopes=[SCOPE]
        )

    path = os.environ.get("PLAY_SERVICE_ACCOUNT_FILE", "")
    if path and os.path.exists(path):
        return service_account.Credentials.from_service_account_file(
            path, scopes=[SCOPE]
        )

    log.info("Сервисный аккаунт Play не задан: проверка чеков выключена")
    return None


def is_configured() -> bool:
    """Настроена ли проверка (пакет + сервисный аккаунт)."""
    return bool(os.environ.get("PLAY_PACKAGE_NAME", "").strip()) and (
        _credentials() is not None
    )


def _endpoint(package: str, product_id: str, purchase_token: str) -> str:
    """URL проверки: подписки и разовые покупки живут на разных путях."""
    if product_id in _subscription_products():
        return f"{API}/{package}/purchases/subscriptionsv2/tokens/{purchase_token}"
    return f"{API}/{package}/purchases/products/{product_id}/tokens/{purchase_token}"


def verify_purchase(purchase_token: str, product_id: str) -> Verdict:
    """Проверяет чек у Google Play.

    Бросает [VerifyUnavailable], если проверить нельзя: вызывающий код обязан
    отдать 503, а не «премиума нет».
    """
    package = os.environ.get("PLAY_PACKAGE_NAME", "").strip()
    credentials = _credentials()
    if not package or credentials is None:
        raise VerifyUnavailable("Play API не настроен")

    try:
        from google.auth.transport.requests import Request
    except ImportError as exc:  # pragma: no cover
        raise VerifyUnavailable("google-auth без requests-транспорта") from exc

    import httpx

    try:
        credentials.refresh(Request())
    except Exception as exc:  # noqa: BLE001
        raise VerifyUnavailable(f"не удалось получить токен: {type(exc).__name__}") from exc

    url = _endpoint(package, product_id, purchase_token)
    try:
        response = httpx.get(
            url,
            headers={"Authorization": f"Bearer {credentials.token}"},
            timeout=REQUEST_TIMEOUT,
        )
    except Exception as exc:  # noqa: BLE001
        raise VerifyUnavailable(f"Play API недоступен: {type(exc).__name__}") from exc

    if response.status_code == 200:
        try:
            return evaluate(response.json())
        except ValueError as exc:
            raise VerifyUnavailable("Play API вернул не-JSON") from exc

    if response.status_code in (400, 403, 404, 410):
        # Чек не найден/отозван/чужой — это вердикт «премиума нет».
        return Verdict(premium=False, reason=f"not_found_{response.status_code}")

    raise VerifyUnavailable(f"Play API вернул {response.status_code}")


def entitlement_document(uid: str):
    """Ссылка на документ entitlement в Firestore."""
    from firebase_admin import firestore

    return (
        firestore.client()
        .collection("users")
        .document(uid)
        .collection("entitlements")
        .document("premium")
    )


def store_entitlement(uid: str, verdict: Verdict) -> None:
    """Записывает вердикт в Firestore (клиент такого писать не может)."""
    from firebase_admin import firestore

    entitlement_document(uid).set(
        {
            "premium": verdict.premium,
            "reason": verdict.reason,
            "source": verdict.source,
            "expires_at": verdict.expires_at,
            "updated_at": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def read_entitlement(uid: str) -> Optional[Dict[str, Any]]:
    """Читает сохранённый вердикт. None — записи ещё нет."""
    snapshot = entitlement_document(uid).get()
    if not snapshot.exists:
        return None
    return snapshot.to_dict() or {}
