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

![Screenshot_2025-09-04-02-15-10-38_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/00e1b5ff-5737-4d74-9811-d1f1cf851064)
![Screenshot_2025-09-04-02-15-02-46_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/67d1a6d6-b2a4-4af4-bc0e-b3edcab5fc0c)
![Screenshot_2025-09-04-02-14-42-18_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/a4ee5642-b4b6-4426-82e6-daaab634e6ce)
![Screenshot_2025-09-04-02-14-22-28_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/741799d2-a22d-47f3-bea2-f1cb760c63c2)
![Screenshot_2025-09-04-02-14-18-68_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/89c806c5-2574-4d8d-bc7f-b201403ab802)
![Screenshot_2025-09-04-02-14-06-35_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/46aa552b-24e9-476f-a034-b8695fa8706c)
![Screenshot_2025-09-04-02-12-12-09_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/5b18f9e3-931e-41fd-b04f-876d7ab3c821)
![Screenshot_2025-09-04-02-11-14-97_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/183b3918-eddc-4596-9884-da5f23d4555c)
![Screenshot_2025-09-04-02-11-08-62_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/22dafd2f-bed3-4af6-9967-813b193a737f)
![Screenshot_2025-09-04-02-11-01-48_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/3345f88d-b4b6-4eba-8225-d2e1c1fa1b68)
![Screenshot_2025-09-04-02-10-41-30_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/bfe40389-e755-436c-96b9-e873523b1efb)
![Screenshot_2025-09-04-02-10-30-96_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/c2a8fad4-3a41-493d-8018-889718f8e1df)
![Screenshot_2025-09-04-02-09-46-74_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/780df240-b84e-4ae7-ad10-ce5cdaa711a4)
![Screenshot_2025-09-04-02-09-36-73_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/722b9d5a-53f5-4156-a9c1-59d08b75f2a7)
![Screenshot_2025-09-04-02-09-13-81_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/e73cbe0e-d609-47b5-a06a-687126d7d07f)
![Screenshot_2025-09-04-02-08-53-96_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/b78089a2-0708-443e-9ad2-d927a1c294ba)
![Screenshot_2025-09-04-02-08-23-75_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/8fd29ba1-31ef-43f2-a9c2-6748f0368e78)
![Screenshot_2025-09-04-02-08-09-04_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/92f05483-18f3-43e5-ad3a-fee1b908888d)
![Screenshot_2025-09-04-02-08-02-21_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/ae9535de-0f2e-4454-8d1d-c39039e8e767)
![Screenshot_2025-09-04-02-07-41-11_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/00b1732c-7016-4157-936d-2e771ab78ad6)
![Screenshot_2025-09-04-02-06-57-95_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/7fb3beaf-4e3b-463a-8952-f959dbcdc7bf)
![Screenshot_2025-09-04-02-06-47-69_00ed68a25f49ddc81dfbde00b62141e1](https://github.com/user-attachments/assets/52a77466-91a2-44be-bc7d-069329abac8c)


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
    WEATHER_API_KEY=ваш_погодный_api_ключ
    DEEPSEEK_API_KEY=ваш_deepseek_api_ключ
    GEOAPIFY_API_KEY=ваш_geoapify_api_ключ
    YANDEX_MOBILE_ADS_APP_ID=ваш_yandex_mobile_ads_app_id
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
