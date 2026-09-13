# D-4: офлайн-первый синк — план и состояние

Закрывает класс B-1 (два устройства присваивали один и тот же локальный `id`
разным сущностям, и записи схлопывались). Основной транспорт — Firestore
(`users/{uid}/cars/...`, `users/{uid}/history/...`), идентичность меняем с
локального `AUTOINCREMENT` на постоянный `uuid`.

## Что уже сделано (фаза 1, коммит d312fdc)

| Элемент | Где | Проверено |
|---|---|---|
| Генератор UUID v4 без зависимостей, `ensureUuid` | `lib/utils/uuid_v4.dart` | `test/sync_outbox_test.dart` |
| Журнал операций: `enqueue/pending/markDone/markFailed/backoffFor/clear` | `lib/services/sync_outbox.dart` | те же |
| БД версии 13: `uuid` в `cars` и `fuel_logs`, бэкфилл для существующих строк, таблица `sync_outbox` + индексы | `lib/utils/database_helper.dart` (`_createDB`, `_upgradeDB`, `_backfillEntityUuids`, `_createSyncOutboxTable`) | `test/sync_outbox_integration_test.dart` |
| `insertCar`/`updateCar`/`deleteCar` пишут данные и операцию **одной транзакцией** | `lib/utils/database_helper.dart` | там же |
| `saveHistoryEntry`/`saveHistoryToDatabase`/`deleteHistoryRecord` так же; облачный синк истории не валит локальное сохранение | `lib/utils/history_manager.dart` (`_syncHistoryRecordToCloud`, `_deleteHistoryRecordFromCloud`) | там же |
| Формат проверки uuid (`isUuidV4`) | `lib/utils/uuid_v4.dart` | — |

Проверки фазы 1: `flutter analyze` — 0 замечаний, `flutter test` — 55/55 (после фазы 2 — 65/65)
(три мок-теста CRUD заменены интеграционными на реальной SQLite).

## Фаза 2 — закрыта (коммиты `93eb4f5`, `2ce22e8`)

| Элемент | Где |
|---|---|
| Воркер `drain()`: `pending()` → отправка → `markDone`/`markFailed`, единичный прогон | `lib/services/sync_worker.dart` |
| Запуск: вход в аккаунт, возврат из фона, таймер 5 мин, сразу после правки | `lib/main.dart`, `lib/providers/car_provider.dart`, `lib/utils/history_manager.dart` |
| Сеть выведена из UI: пути записи только пишут в БД и очередь | `database_helper.dart`, `history_manager.dart` |
| Ключ документа — `uuid`; чтение и по `uuid`, и по старому `id`; чужие локальные id не переносятся | `syncCarsWithFirestore`, `_performFirestoreSync` |
| Индикатор «Ждёт отправки: N» и кнопка «Отправить сейчас» в настройках | `settings_page.dart` |
| Снят премиум-гейт с синхронизации (монетизация отложена, F-1) | `database_helper.dart`, `history_manager.dart` |
| Тесты воркера с подменённым отправителем | `test/sync_worker_test.dart` (5) |

## Что НЕ сделано (это фазы 3–4)

### Фаза 3 — слияние (LWW + надгробия)

1. Поля `updated_at` и `device_id` в документах; сравнение `updated_at`, при
   равенстве — детерминированный тай-брейк по `device_id` (иначе конфликты
   разрешаются по-разному на разных устройствах).
2. Удаления — надгробия (`deleted_at`), а не физическое удаление: иначе удаление
   на одном устройстве «оживает» после синка второго (сейчас `deleteCar` чистит
   `fuel_logs` локально, но не отправляет их удаление — см. фазу 4).
3. Часы: клиентское время может врать — при первом синке брать `TimeStamp` сервера
   (`@serverTimestamp`/`FieldValue.serverTimestamp()`) как точку отсчёта, а
   клиентское смещение хранить в настройках.

### Фаза 4 — хвосты

- Хранить в очереди id объекта из Firestore и не отправлять одно и то же дважды при
  параллельных прогонах воркера (нужен флаг «в работе» либо единичный воркер).
- Удаление машины: отправлять удаление и для её заправок.
- Ограничение объёма: `sync_outbox` расти не должна — после N попыток (например 10)
  помечать операцию как «требует вмешательства» и показывать в настройках.
- Тесты слияния: две «устройства»-сессии на разных in-memory БД, одинаковый uuid,
  разные `updated_at` → проверка результата.
- Нагрузочная проверка миграции 12 → 13 на реальной базе пользователя (несколько
  тысяч строк в `fuel_logs`).

## Риски

| Риск | Как снижаем |
|---|---|
| Миграция 13 на живой базе у друзей | Бэкфилл идёт построчно в одной транзакции открытия БД; сначала прогон на копии базы с телефона |
| Старые документы в Firestore без `uuid` | Читаем оба ключа (id и uuid), uuid прописываем при следующей правке записи |
| Премиум-гейт на историю (бесплатные пользователи не синкаются) | В очереди операции копятся — после подписки уедут; поведение нужно подтвердить с владельцем |
| Двойная отправка операции | Единичный воркер + флаг «в работе» (фаза 4) |

## Как проверять

```bash
cd /c/Users/Despa/fuelmaster
flutter analyze                     # должно быть 0
flutter test                        # 55+, включая sync_outbox*
flutter build apk --release --dart-define-from-file=env.defines.json
```
