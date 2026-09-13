# AI-прокси FuelMaster

Ключ AI-провайдера не должен лежать в APK: приложение распаковывается за минуту,
а ключ биллинга утекает вместе с ним. Схема после внедрения:

```
Flutter (release)  ──Firebase ID token──►  /fuelmaster/ai/v1/advice  ──ключ──►  OpenRouter
        AI_PROXY_URL в --dart-define                (этот сервис)
```

Клиент подписывает запрос Firebase ID token, сервер проверяет его,
ограничивает частоту (по умолчанию 20 запросов в час на пользователя),
сам выбирает модель и лимит токенов и только потом обращается к провайдеру.

## Ротация ключей (обязательно, один раз)

1. OpenRouter → **отозвать прежний ключ** и создать новый (он был в APK и в git-истории).
2. Yandex Maps API-key — тоже был зашит в `AndroidManifest.xml` до правок:
   перевыпустить и указать в `android/local.properties` (`yandex.maps.apikey`).
3. Geoapify / WeatherAPI — ключи лежали в `.env` внутри APK: перевыпустить.
4. Проверить расходы на OpenRouter и в кабинетах внешних сервисов за последние месяцы.

## Установка на сервер

```bash
# 1. Пользователь и каталог
sudo useradd -r -s /usr/sbin/nologin fuelmaster-ai
sudo mkdir -p /opt/fuelmaster-ai
sudo cp main.py requirements.txt /opt/fuelmaster-ai/
sudo chown -R fuelmaster-ai:fuelmaster-ai /opt/fuelmaster-ai

# 2. Виртуальное окружение
sudo -u fuelmaster-ai python3 -m venv /opt/fuelmaster-ai/venv
sudo -u fuelmaster-ai /opt/fuelmaster-ai/venv/bin/pip install -r /opt/fuelmaster-ai/requirements.txt

# 3. Секреты
sudo cp env.example /etc/fuelmaster-ai.env      # заполнить значения
sudo cp service-account.json /etc/fuelmaster-ai-service-account.json
sudo chown root:fuelmaster-ai /etc/fuelmaster-ai.env /etc/fuelmaster-ai-service-account.json
sudo chmod 640 /etc/fuelmaster-ai.env /etc/fuelmaster-ai-service-account.json

# 4. systemd
sudo cp ai_proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now ai_proxy
systemctl status ai_proxy --no-pager
curl -s http://127.0.0.1:8095/health
# ожидаем: {"status":"ok","provider_configured":true,"auth_configured":true}

# 5. nginx (вставка из nginx.conf.example в нужный server-блок)
sudo nginx -t && sudo systemctl reload nginx
```

Service account для `firebase-admin`: Firebase Console → Project settings →
Service accounts → *Generate new private key* (файл JSON никому не передавать).

Проверка снаружи (должен ответить 401 — токена нет):

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://ВАШ_ДОМЕН/fuelmaster/ai/v1/advice -X POST
```

## Подключение клиента

`env.defines.json` (файл в `.gitignore`):

```json
{
  "AI_PROXY_URL": "https://ВАШ_ДОМЕН/fuelmaster/ai"
}
```

Дальше — сборка релиза как обычно:

```bash
flutter build apk --release --dart-define-from-file=env.defines.json
```

`DEEPSEEK_API_KEY` **не добавляйте** в `env.defines.json`: в release-сборке
`EnvConfig` его не отдаёт, а прокси-режим включается одним `AI_PROXY_URL`.

## Поведение клиента

| Режим | `AI_PROXY_URL` задан | Результат |
|---|---|---|
| debug | да | запрос через прокси |
| debug | нет | прямой запрос OpenRouter с ключом из `.env` |
| release | да | запрос через прокси (ключей в APK нет) |
| release | нет | AI-совет недоступен, в лог пишется пояснение |

## Премиум: проверка чека (`/v1/entitlement`)

Клиентский флаг премиума в prefs — только офлайн-кэш. Правду о покупке знает
сервер: `POST /v1/entitlement` с телом `{"purchase_token": ..., "product_id": ...}`
проверяет чек в Google Play Developer API и пишет вердикт в Firestore
(`users/{uid}/entitlements/premium`). Подколлекция `entitlements` закрыта
правилами для клиента — подделать статус из приложения нельзя.

`GET /v1/entitlement` отдаёт сохранённый вердикт для сверки при старте;
`404 no_record` означает «записи ещё нет» — клиент оставляет локальный статус.

Главное правило: **вердиктом считается только HTTP 200**. `503
verification_unavailable` (не настроен сервисный аккаунт, Play недоступен) и
сетевые ошибки статус НЕ меняют, иначе платящий пользователь терял бы премиум
из-за обрыва связи.

| Переменная | Назначение |
|---|---|
| `PLAY_PACKAGE_NAME` | `applicationId` приложения, например `com.example.fuelmaster` |
| `PLAY_SERVICE_ACCOUNT_FILE` | путь к json сервисного аккаунта Play Console |
| `PLAY_SERVICE_ACCOUNT_JSON` | тот же json строкой (альтернатива файлу) |
| `PLAY_SUBSCRIPTION_PRODUCTS` | `product_id` подписок через запятую (иначе — разовая покупка) |

Самопроверка логики без сети и без Play: `python selfcheck_entitlements.py`.
Сервисному аккаунту в Play Console нужно выдать доступ к заказам и подпискам
приложения (Users and permissions).

## Эксплуатация

* Логи: `journalctl -u ai_proxy -f` — пишутся только uid (8 символов), модель,
  длина ответа и время; промпты и ответы не логируются.
* Ограничения по нагрузке: `AI_RATE_LIMIT_PER_HOUR`, `AI_MAX_PROMPT_CHARS`,
  `AI_PROVIDER_MAX_TOKENS` — задаются в `/etc/fuelmaster-ai.env`.
* Лимит частоты хранится в памяти процесса: при рестарте счётчики сбрасываются.
  Если понадобится строгий лимит — вынести в Redis.
* Данные, которые уходят провайдеру: модель автомобиля и метрики расчёта
  (пробег, нормы расхода). Email, uid и город не передаются.
