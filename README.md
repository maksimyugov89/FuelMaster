# <img width="64" height="74" alt="logo" src="https://github.com/user-attachments/assets/1bceca05-16a6-421e-b3ea-2349624b89a9" /> FuelMaster

**FuelMaster** — это комплексное мобильное приложение на базе Flutter, разработанное для эффективного управления расходом топлива и данными автомобилей. Приложение предоставляет интуитивно понятный интерфейс для добавления и отслеживания транспортных средств, записи истории заправок и расчетов, а также визуализации трендов потребления топлива. Оно поддерживает многоязычность (английский и русский), светлую и темную темы, а также предлагает функции синхронизации данных (для премиум-пользователей) и монетизации через рекламу и подписку.

## Возможности

-   **Управление автомобилями**: Добавление, редактирование и удаление автомобилей. Приложение включает обширную базу предустановленных моделей автомобилей, загружаемых из CSV-файла.
-   **Калькулятор расхода топлива**: Детальный расчет потребления топлива с учетом пробега (город/трасса), уровня топлива, заправок и различных условий (зима, кондиционер, горы).
-   **История расчётов**: Хранение и просмотр всех расчетов. История может быть отфильтрована по автомобилю и дате, а также визуализирована с помощью интерактивных графиков (`fl_chart`).
-   **Система пользователей**: Регистрация и вход в систему через Firebase Authentication (email/пароль).
-   **Синхронизация с облаком (Премиум)**: Для премиум-пользователей данные автомобилей и история расчетов синхронизируются с Google Firestore.
-   **Настройки**: Пользователи могут настраивать тему приложения (светлая/темная/авто), язык (en/ru) и другие параметры.
-   **Интеграция с внешними сервисами**:
    *   **Geoapify**: Используется на экране регистрации для поиска городов и автозаполнения.
    *   **WeatherAPI**: Получает данные о погоде для расчета коэффициента расхода топлива.
    *   **OpenRouter (DeepSeek)**: Подключается к ИИ-сервису для генерации советов по топливной эффективности.
-   **UI/UX**: Приложение следует принципам Material 3 Design, имеет настраиваемые темы (`theme.dart`) и переиспользуемые виджеты (`widgets.dart`). Стандартный поток запуска: `SplashScreen` -> `OnboardingPage` -> `RegistrationPage` -> `MainMenuPage`.
-   **Управление состоянием**: Использует пакет `provider` для эффективного управления состоянием приложения.
-   **Локальная база данных**: Использует SQLite (`sqflite`) для локального хранения данных автомобилей и истории расчетов.

## Монетизация

-   **Реклама**: Интеграция Yandex Mobile Ads для показа баннерной, нативной и межстраничной рекламы.
-   **Покупки в приложении**: Премиум-подписка доступна для покупки через пакет `in_app_purchase`.
-   **Firebase Analytics**: Для отслеживания взаимодействий пользователей и эффективности рекламы.

## Критическое предупреждение о безопасности

**ВНИМАНИЕ:** API-ключи для **WeatherAPI** и **OpenRouter (DeepSeek)** в настоящее время жестко закодированы непосредственно в исходных файлах Dart (`weather_service.dart`, `deepseek_service.dart`). Это представляет собой серьезную уязвимость безопасности и должно быть немедленно устранено путем перемещения этих ключей в файл `.env` или аналогичный безопасный механизм. Также рекомендуется переместить `yandex_mobile_ads_app_id` из `AndroidManifest.xml` в `.env` для единообразия и безопасности.

## Скриншоты
![Screenshot_2025-09-04-02-30-09-10_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/2b646849-1ba2-4b50-b5be-7a50ef011d7e)
![Screenshot_2025-09-04-02-30-23-94_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/acdcca64-7f8d-426c-b49b-0a5c2fae65ea)
![Screenshot_2025-09-04-02-06-47-69_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/4f50cbec-52e2-4df9-82fc-4b6483858d1b)
![Screenshot_2025-09-04-02-06-57-95_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/d5bf34be-5b4f-4886-953a-0c023fa4f412)
![Screenshot_2025-09-04-02-07-41-11_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/48bc266a-abbf-4476-8a8f-f94f5cec8223)
![Screenshot_2025-09-04-02-08-02-21_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/0d7a5bda-ab21-4b1e-afab-ca9409adc2b0)
![Screenshot_2025-09-04-02-08-09-04_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/50f9f920-f008-4040-a438-7350abb975cd)
![Screenshot_2025-09-04-02-08-23-75_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/fb3441f8-c200-4e57-8d5e-1b1290607b8c)
![Screenshot_2025-09-04-02-08-53-96_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/e1217bd5-e956-4e92-93f8-ed67b7abe597)
![Screenshot_2025-09-04-02-09-13-81_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/6eaa8d6a-a97d-4687-b02c-24205a2d2a16)
![Screenshot_2025-09-04-02-09-36-73_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/57b521ed-aad3-43c5-a9be-70e47f4d650b)
![Screenshot_2025-09-04-02-09-46-74_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/68be8383-eca2-42be-8acd-0a5a377cf327)
![Screenshot_2025-09-04-02-10-30-96_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/7eb67611-d216-4dbc-b771-d36136d45459)
![Screenshot_2025-09-04-02-10-41-30_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/a20b3d66-440d-47ed-8d47-237ef5cca0b0)
![Screenshot_2025-09-04-02-11-01-48_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/a2d3395e-bb26-4f0b-891f-03ea30049173)
![Screenshot_2025-09-04-02-11-08-62_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/5a0e5e24-472c-4d37-b00d-3ce4c5085586)
![Screenshot_2025-09-04-02-11-14-97_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/3f5187ea-14bc-4867-9f98-c2153c23b69f)
![Screenshot_2025-09-04-02-12-12-09_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/4d717264-f4ff-4bc7-b497-3edf83afad20)
![Screenshot_2025-09-04-02-14-06-35_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/4ab7338c-2884-4102-818f-d1daf017ee17)
![Screenshot_2025-09-04-02-14-18-68_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/89e8f46c-68dd-45b5-a87d-40d6f4e49613)
![Screenshot_2025-09-04-02-14-22-28_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/0a4a5d3a-001b-4901-bcfb-e314d2aba4ba)
![Screenshot_2025-09-04-02-14-42-18_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/f7ceb6ad-1122-4751-8482-ffb179ddcdea)
![Screenshot_2025-09-04-02-15-02-46_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/1c8946ba-96c7-4697-9055-b6208d507c34)
![Screenshot_2025-09-04-02-15-10-38_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/a71f705e-ef81-4b02-9781-f65c64ac19d6)


## Начало работы

### Требования

-   **Flutter SDK**: Версия 3.0.0 или выше (указано в `pubspec.yaml`).
-   **Dart**: Совместим с Flutter SDK (версия >=3.0.0 <4.0.0).
-   **Android Studio** или **VS Code** с плагинами Flutter и Dart.
-   **Аккаунт Firebase**: Для интеграции Firebase Authentication, Firestore и Analytics.
-   **Аккаунт Yandex Mobile Ads**: Для интеграции рекламы.
-   **Keystore**: Для подписи релизной сборки Android.

### Настройка переменных окружения

Для корректной работы приложения необходимо настроить переменные окружения для всех API-ключей и идентификаторов. Эти ключи загружаются из файла `.env` в корне проекта.

1.  **Создайте файл `.env`** в корневой директории проекта.
2.  **Скопируйте содержимое** из файла `.env.example` в ваш новый файл `.env`.
3.  **Замените плейсхолдеры** на ваши реальные API-ключи и идентификаторы, полученные от соответствующих сервисов.

    Пример содержимого файла `.env`:
    ```
      WEATHER_API_KEY=your_weather_api_key_here
      DEEPSEEK_API_KEY=your_deepseek_api_key_here
      GEOAPIFY_API_KEY=your_geoapify_api_key_here
      YANDEX_MOBILE_ADS_APP_ID=your_yandex_mobile_ads_app_id_here"
      Firebase Android Keys"
      FIREBASE_ANDROID_API_KEY=your_android_api_key_here
      FIREBASE_ANDROID_APP_ID=your_android_app_id_here
      FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id_here
      FIREBASE_PROJECT_ID=your_project_id_here
      FIREBASE_STORAGE_BUCKET=your_storage_bucket_here
      # Firebase iOS Keys
      FIREBASE_IOS_API_KEY=your_ios_api_key_here"
      FIREBASE_IOS_APP_ID=your_ios_app_id_here"
      FIREBASE_IOS_BUNDLE_ID=your_ios_bundle_id_here"
    ```
    **Важно:** Файл `.env` содержит конфиденциальную информацию и **не должен** быть добавлен в систему контроля версий (Git). Он уже добавлен в `.gitignore`.

### Установка

1.  **Клонирование репозитория**:
    ```bash
    git clone https://github.com/maksimyugov89/FuelMaster.git
    cd FuelMaster
    ```
2.  **Получение зависимостей Flutter**:
    ```bash
    flutter pub get
    ```
3.  **Настройка Firebase**:
    *   Следуйте инструкциям на [Firebase Console](https://console.firebase.google.com/) для добавления вашего Android-приложения.
    *   Загрузите файл `google-services.json` в директорию `android/app/`.
    *   Убедитесь, что в Firebase Console включены Firebase Authentication, Firestore и Play Integrity API.
    *   Добавьте SHA-ключи вашего приложения в настройки проекта Firebase.
4.  **Настройка Yandex Mobile Ads**:
    *   Получите `yandex_mobile_ads_app_id` из вашего аккаунта Yandex Mobile Ads.
    *   **Переместите этот ID в файл `.env`**, как указано выше.
    *   Удалите или закомментируйте соответствующую `meta-data` запись в `android/app/src/main/AndroidManifest.xml` после перемещения ID в `.env`.
5.  **Генерация файлов локализации**:
    ```bash
    flutter gen-l10n
    ```
6.  **Запуск приложения**:
    ```bash
    flutter run
    ```
    Или для запуска на конкретном устройстве (например, `RMX3853`):
    ```bash
    flutter run -d RMX3853 --verbose
    ```

## Тестирование

Для запуска всех тестов:

```bash
flutter test
```

## Вклад

Мы приветствуем вклад в развитие FuelMaster! Пожалуйста, ознакомьтесь с нашими рекомендациями по внесению вклада.

## Лицензия

Этот проект распространяется под лицензией MIT.
