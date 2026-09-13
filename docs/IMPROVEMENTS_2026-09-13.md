# Улучшения 13.09.2026: C-8, A-8, C-3, C-1, C-7, D-2

Продолжение аудита [AUDIT_2026-09-13.md](AUDIT_2026-09-13.md). Здесь — только то, что
сделано в этом заходе, с проверками и внешними действиями, которые остаются за пользователем.

| Пункт | Что сделано | Коммит |
|---|---|---|
| A-8 | applicationId `com.example.fuelmaster` → `com.fuelmaster.app`, новое Firebase-приложение, перенос Kotlin-пакетов | `5b50332` |
| C-8 | proguard без `-dontoptimize/-dontshrink/-dontobfuscate`, манифест без конфликта `hardwareAccelerated` | `0ac0a88` |
| C-3 | логи в release с уровня warning, из логов убраны данные пользователя | `75e8a45` |
| C-1 | анализатор: 57 замечаний → 0 | `bd1008c` |
| C-1b | CI на GitHub Actions (analyze + test) | `a87317a` |
| C-7 | Crashlytics + Analytics, сбор только в release | `0ce1cf4` |
| D-2 | аналитика расхода: сервис, экран, отчёты, 24 новых теста | `ca1f92a` |

Проверки на момент отчёта: `flutter analyze` — **0 замечаний**, `flutter test` — **48/48**,
`flutter build apk --release` — **успешно** (R8 + сжатие ресурсов + загрузка mapping-файла Crashlytics);
`package: name='com.fuelmaster.app' versionCode='7' versionName='1.0.1'` — подтверждено `aapt dump badging`.

---

## 1. A-8 — applicationId (закрыто до публикации)

Идентификатор приложения в Play меняется один раз и навсегда, поэтому сделан первым.

- `namespace` и `applicationId` → `com.fuelmaster.app`; Kotlin-пакеты перенесены
  (`MainActivity.kt`, `MainApplication.kt` → `com/fuelmaster/app/`), из манифеста убран
  устаревший атрибут `package=`, канал Yandex Ads переименован синхронно в Kotlin и в Dart
  (`lib/utils/yandex_ads_channel.dart`).
- В Firebase-проекте `fuelmaster-984fb` создано **новое** Android-приложение
  (`1:619524253699:android:9cc3a0bc0074d65eb0c636`), `google-services.json` перегенерирован.
  Старый клиент `com.example.fuelmaster` в проекте **оставлен сознательно**: у друзей уже
  установлены APK со старым пакетом, и их вход, данные и синхронизация продолжают работать.
  Оба клиента живут в одном проекте, а значит в одном Firestore и одной Firebase Auth.

### Что нужно от пользователя (A-8)
1. **Yandex Maps API key**: если ключ ограничен по имени пакета — добавить `com.fuelmaster.app`
   (иначе карта на новых сборках вернёт ошибку авторизации).
2. **Firebase App Check**: добавить SHA-256 релизного ключа в разделе App Check; при
   сборке из Play это делает Play Integrity, для sideload-APK нужен отпечаток вручную.
3. **Play Console**: создать приложение с пакетом `com.fuelmaster.app` (старое приложение
   не публиковалось, переносить нечего) и включить Play App Signing.

---

## 2. C-8 — release-инженерка (и два блокера, которые она вскрыла)

- `android/app/proguard-rules.pro`: удалены `-dontoptimize`, `-dontshrink`, `-dontobfuscate` —
  они полностью отменяли `isMinifyEnabled`/`isShrinkResources`; удалён и мусорный
  `-keep class com.android.tools.r8.**`. Конкретные `-keep` для Yandex Ads, WebView, Firebase,
  MyTracker, Retrofit/Gson сохранены.
- `AndroidManifest.xml`: `hardwareAccelerated="false"` + `tools:replace` на `<application>`
  заменены на `true` — конфликт с активностью убран.

**Блокер №1 (найден при первой же release-сборке):** `Crashlytics Gradle plugin 3.x requires
Google-Services 4.4.1 and above`. В `android/settings.gradle.kts` стояла версия **4.3.15**
(при 4.4.3 в корневом `buildscript`). Подняли до 4.4.3. То есть до сегодняшнего дня релизная
сборка с минификацией либо не проходила, либо шла в обход — именно поэтому кто-то и добавил
`-dontobfuscate`.

**Блокер №2:** подпись не находилась — `android/fuel_master.jks` в рабочей копии отсутствовал
(`storeFile = rootProject.file(...)`, то есть файл должен лежать в `android/`). Кейстор
восстановлен из вашего же архива `C:\Users\Despa\fuelmaster-backup-20260913.tgz`
(копии положены в `android/` и `android/app/`); пароль — в `android/keystore.properties`
(в git не попадает). Если вы переносили кейстор на другой носитель — сверьте отпечатки,
чтобы не публиковать приложение чужим ключом.

Итог: `app-release.apk` собирается по-настоящему обфусцированным. Размер universal-APK —
**184,3 МБ** (см. C-2: сплэш в четырёх плотностях + все ABI в одном файле).

---

## 3. C-3 — логи и персональные данные

- `lib/utils/logger.dart`: в release уровень `Level.warning`, без цветов, эмодзи, таймстампов
  и стека вызовов; в debug поведение прежнее.
- Из 14 мест убраны дампы данных: `car.toJson()` (в нём номер, пробег, цена), история целиком,
  город, ответы погодного API. Вместо объектов — идентификаторы и количества
  (`Deleted car id=12`, `История загружена: 37 записей`).
- Правило для будущего кода записано в доккомментарии логгера: id и количество — можно,
  номер авто, цену, маршрут, email — нет.

---

## 4. C-1 / C-1b — анализатор и CI

- 57 замечаний → **0**: автофиксы `dart fix` (импорты, мёртвые переменные, `rethrow`,
  `sort_child_properties_last`) плюс ручные правки: явный тип `State<Widget> createState()`
  в 9 файлах, `Share`/`shareXFiles` → `SharePlus.instance.share(ShareParams(...))`,
  `ExpansionTileController` → `ExpansibleController`, `desiredAccuracy` → `locationSettings`,
  `value` → `initialValue` у `DropdownButtonFormField`, `printTime` → `dateTimeFormat`.
- `sqflite_common` объявлен явной dev-зависимостью (его требуют сгенерированные
  mockito-моки), вместо `any` поставлено `^2.5.6`.
- `.github/workflows/ci.yml`: на каждый push в `main` и на PR — `flutter pub get`,
  `flutter analyze --fatal-infos`, `flutter test`. Flutter зафиксирован на 3.38.5
  (версия релизной сборки), включён кэш pub.
- Отдельная job `build-debug` собирает debug APK: анализ и тесты не видят поломок
  Gradle/Kotlin/SDK, а именно такая поломка вскрылась в этом заходе (см. блокер №3 ниже).
- Не сделано осознанно: `dart format` в CI. Сейчас **44 файла** не соответствуют
  `dart format`; массовый переформат смешался бы с текущими правками, поэтому его
  стоит делать отдельным коммитом «только форматирование».

---

## 5. C-7 — Crashlytics и Analytics

- Зависимости: `firebase_crashlytics ^5.3.0`, `firebase_analytics ^12.5.0`.
- Перехватчики ставятся **до** `Firebase.initializeApp`, поэтому падения на старте тоже
  попадают в отчёт: `FlutterError.onError` → `recordFlutterFatalError`,
  `PlatformDispatcher.instance.onError` → `recordError(..., fatal: true)`.
- Сбор отчётов включён **только в release** (`setCrashlyticsCollectionEnabled(kReleaseMode)`),
  чтобы debug-падения и тесты не засоряли панель.
- Premium-статус пишется как свойство пользователя в Analytics — заготовка под воронку
  монетизации (D-6).
- App Check переведён на актуальный API (`providerAndroid/providerApple` с классами
  `AndroidDebugProvider`, `AndroidPlayIntegrityProvider`, `AppleDebugProvider`,
  `AppleDeviceCheckProvider`) — старые enum-параметры помечены deprecated и убраны.

Что увидите после первого релиза: раздел Crashlytics начнёт показывать падения у друзей
(раньше они оставались только в logcat на устройстве), Analytics — активность и долю premium.

---

**Блокер №3 (после подключения Firebase-пакетов):** release-сборка упала на
`:firebase_auth:compileReleaseKotlin` — «Module was compiled with an incompatible version
of Kotlin. The binary version of its metadata is 2.3.0, expected version is 2.1.0».
`firebase_crashlytics`/`firebase_analytics` подтянули свежие Firebase-модули
(`firebase-auth:24.2.0`), которые собраны Kotlin 2.3.0, а в `android/settings.gradle.kts`
стоял плагин Kotlin **2.1.0**. Плагин поднят до **2.3.21** (совместим с Gradle 8.9 и
AGP 8.7.3). Это ровно тот класс поломки, который CI обязан ловить — поэтому в CI добавлена
сборка debug APK.

## 6. D-2 — аналитика расхода

Ядро вынесено в `lib/utils/consumption_analytics_service.dart` — чистый Dart, без Flutter и
без базы: на вход строки `fuel_logs`, на выходе числа. Поэтому математика покрыта
обычными unit-тестами, а экран остаётся тонким.

Считается:

- **средний расход** за период — по топливу и пробегу (а не как среднее расхода записей);
- **норма** — паспортная из карточки авто, средневзвешенная по фактическому пробегу
  города и трассы; **отклонение от нормы** в процентах;
- **стоимость** топлива и **стоимость километра** — по цене литра, которую пользователь
  задаёт в самом экране (хранится в prefs, ключ `fuel_price_per_liter`);
- **тренд** расхода методом наименьших квадратов — л/100 км в месяц (растёт/падает/стабильно,
  порог значимости 0,1);
- **прогноз на месяц**: пробег, литры, затраты — по среднему дневному пробегу за
  календарный охват записей;
- **сравнение с предыдущим периодом** той же длины: расход, пробег, стоимость;
- доля городского пробега, средняя заправка, средний пробег записи.

Экран `lib/analytics_page.dart` открывается из шапки истории (иконка «insights») — отдельный
раздел в нижнем меню не добавляли. Есть выбор периода (30/90/365 дней) и автомобиля
(«Все автомобили» по умолчанию), карточки показателей, прогноза и сравнения, кнопка
«Поделиться отчётом» (текстовый отчёт через `SharePlus`). Локализация ru/en — 41 новый ключ.
Тесты: **21 unit** на математику и **3 widget** на экран (включая поведение без цены литра
и пустое состояние).

Что из D-2 осталось (осознанно не входило):
- цена **каждой** заправки (нужна миграция схемы `fuel_logs` + синхронизация + поле в
  калькуляторе) — сейчас цена одна на всё;
- графики (fl_chart уже в проекте) и прогноз по каждой поездке;
- выгрузка в PDF/Excel — сейчас только текстовый отчёт в «поделиться».

---

## 7. Найдено попутно (не входило в пункты)

1. **`DatabaseHelper.deleteCarByModel`** — метод удаляет машины по модели, то есть при двух
   авто одной модели снёс бы оба (а логи топлива — только первого). В `lib` он **не
   вызывается** (ссылка есть только в сгенерированном моке), поэтому это не живой баг,
   а ловушка: метод стоит удалить вместе с моком.
2. **Размер APK** (усиление C-2): universal-сборка — 184,3 МБ, из которых ~25 МБ — сплэш
   в четырёх плотностях и `cars.csv` 852 КБ. Для Play нужны ABI-splits и WebP.

---

## 8. Осталось за пользователем

| Что | Почему нужно |
|---|---|
| Yandex Maps key: добавить пакет `com.fuelmaster.app` | иначе карта не заработает в новой сборке |
| App Check: SHA-256 релизного ключа | playIntegrity не пройдёт на APK не из Play |
| Play Console: приложение `com.fuelmaster.app` + Play App Signing | публикация |
| Ротация утёкших ключей (DeepSeek/OpenRouter, Geoapify, Weather, Yandex, клиентский ключ) | из блока A аудита |
| Хост для AI-прокси, публичный URL политики конфиденциальности, запрос в поддержку GitHub | прежние хвосты A/D |
| Решение по данным: остаться на `despad.89@mail.ru` или перенести базу на `uid maksim` | влияет на то, чей аккаунт считается владельцем данных |

## 9. Команды для повторной проверки

```bash
cd C:/Users/Despa/fuelmaster
flutter analyze                      # ожидается: No issues found!
flutter test                         # ожидается: All tests passed! (48)
flutter gen-l10n                     # если правились .arb
flutter build apk --release --dart-define-from-file=env.defines.json
```
