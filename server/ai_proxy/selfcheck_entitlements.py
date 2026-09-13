"""Самопроверка логики премиума (хвост A-7).

Запуск: python selfcheck_entitlements.py
Проверяет чистые функции разбора ответов Play API — без сети и без FastAPI.
"""

import os
import sys

import entitlements as ent

FAILED = []


def check(name: str, condition: bool) -> None:
    print(("  OK   " if condition else "  FAIL ") + name)
    if not condition:
        FAILED.append(name)


print("Разовые покупки (purchases.products.get):")
check("purchaseState=0 → премиум", ent.evaluate_one_time({"purchaseState": 0}).premium)
check(
    "purchaseState=1 (canceled) → нет",
    ent.evaluate_one_time({"purchaseState": 1}).premium is False,
)
check(
    "purchaseState=2 (pending) → нет, reason=pending",
    ent.evaluate_one_time({"purchaseState": 2}).reason == "pending",
)
check(
    "неизвестный purchaseState → нет, но вердикт есть",
    ent.evaluate_one_time({"purchaseState": 7}).reason == "purchase_state_7",
)

print("Подписки (purchases.subscriptionsv2.get):")
expiry = "2026-10-13T15:00:00Z"
active = {"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE", "lineItems": [{"expiryTime": expiry}]}
grace = {"subscriptionState": "SUBSCRIPTION_STATE_IN_GRACE_PERIOD", "lineItems": [{"expiryTime": expiry}]}
expired = {"subscriptionState": "SUBSCRIPTION_STATE_EXPIRED", "lineItems": [{"expiryTime": expiry}]}

active_verdict = ent.evaluate(active)
check("ACTIVE → премиум", active_verdict.premium)
check(
    "срок берётся из lineItems",
    active_verdict.expires_at == ent._millis_from_rfc3339(expiry)
    and active_verdict.expires_at is not None,
)
check("IN_GRACE_PERIOD → премиум (доступ сохраняется)", ent.evaluate(grace).premium)
check("EXPIRED → нет премиума", ent.evaluate(expired).premium is False)
check(
    "берётся самый поздний срок из нескольких позиций",
    ent.evaluate(
        {
            "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
            "lineItems": [
                {"expiryTime": "2026-01-01T00:00:00Z"},
                {"expiryTime": expiry},
            ],
        }
    ).expires_at
    == ent._millis_from_rfc3339(expiry),
)

print("Разбор ответа и адреса:")
check("выбор ветки по форме ответа", ent.evaluate({"purchaseState": 0}).premium)
check("битая дата не ломает вердикт", ent._millis_from_rfc3339("не дата") is None)
check("эпоха считается верно", ent._millis_from_rfc3339("1970-01-01T00:00:00Z") == 0)

os.environ.pop("PLAY_SUBSCRIPTION_PRODUCTS", None)
check(
    "разовый товар → путь /purchases/products/",
    "/purchases/products/" in ent._endpoint("com.example.fuelmaster", "premium", "tok"),
)
os.environ["PLAY_SUBSCRIPTION_PRODUCTS"] = "premium_month,other"
check(
    "подписка → путь /purchases/subscriptionsv2/",
    "/purchases/subscriptionsv2/" in ent._endpoint("com.example.fuelmaster", "premium_month", "tok"),
)
os.environ.pop("PLAY_SUBSCRIPTION_PRODUCTS", None)

print("Конфигурация:")
check("без PLAY_PACKAGE_NAME проверка недоступна", ent.is_configured() is False)
try:
    ent.verify_purchase("token-12345678", "premium")
    check("verify_purchase без настройки бросает VerifyUnavailable", False)
except ent.VerifyUnavailable:
    check("verify_purchase без настройки бросает VerifyUnavailable", True)

print()
if FAILED:
    print(f"ПРОВАЛЕНО: {len(FAILED)} — {', '.join(FAILED)}")
    sys.exit(1)
print("Все проверки пройдены.")
