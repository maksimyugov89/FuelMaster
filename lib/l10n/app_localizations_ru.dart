// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get app_title => 'FuelMaster';

  @override
  String get welcome_message => 'Добро пожаловать в Fuel Master!';

  @override
  String get go_to_history => 'Перейти к истории';

  @override
  String get history_title => 'История расчетов';

  @override
  String get select_car => 'Выбрать автомобиль';

  @override
  String get all_cars => 'Все автомобили';

  @override
  String get fuel_usage_chart => 'График расхода топлива';

  @override
  String get no_chart_data => 'Нет данных для графика';

  @override
  String get history_calculations => 'История расчетов';

  @override
  String get history_empty => 'История пуста';

  @override
  String get no_history_for_car => 'Нет записей для выбранного автомобиля';

  @override
  String get export_record => 'Экспортировать запись';

  @override
  String get export_email => 'Экспортировать через Email';

  @override
  String get export_telegram => 'Экспортировать через Telegram';

  @override
  String get export_whatsapp => 'Экспортировать через WhatsApp';

  @override
  String get clear_history => 'Очистить историю';

  @override
  String get clear_history_confirm =>
      'Вы уверены, что хотите очистить историю расчетов?';

  @override
  String get cancel => 'Отмена';

  @override
  String get clear => 'Очистить';

  @override
  String get history_cleared => 'История очищена';

  @override
  String get history_empty_export => 'История пуста';

  @override
  String get fuel_history_message => 'История расчетов топлива';

  @override
  String get email_subject => 'История топлива';

  @override
  String get error => 'Произошла ошибка';

  @override
  String get error_email => 'Не удалось открыть почтовый клиент';

  @override
  String get error_telegram => 'Не удалось открыть Telegram';

  @override
  String get error_whatsapp => 'Не удалось открыть WhatsApp';

  @override
  String get other => 'Другое';

  @override
  String get share_history => 'Поделиться историей';

  @override
  String get select_share_method => 'Выберите способ отправки истории';

  @override
  String get invalid_input => 'Неверный формат данных';

  @override
  String get out_of_range => 'Значения вне допустимого диапазона';

  @override
  String get final_mileage_greater =>
      'Конечный пробег должен быть больше начального';

  @override
  String get highway_not_exceed_total =>
      'Пробег по трассе не должен превышать общий';

  @override
  String get date => 'Дата';

  @override
  String get brand => 'Марка';

  @override
  String get model => 'Модель';

  @override
  String get initial_mileage => 'Начальный пробег';

  @override
  String get final_mileage => 'Конечный пробег';

  @override
  String get total_mileage => 'Общий пробег';

  @override
  String get city_mileage => 'Пробег по городу';

  @override
  String get city_norm => 'Городская норма';

  @override
  String get highway_mileage => 'Пробег по трассе';

  @override
  String get highway_norm => 'Трассовая норма';

  @override
  String get refuel => 'Заправка';

  @override
  String get fuel_used => 'Расход';

  @override
  String get final_fuel => 'Остаток';

  @override
  String get liters => 'л';

  @override
  String get kilometers => 'км';

  @override
  String get success => 'Расчет выполнен';

  @override
  String get current_calculations => 'Текущие расчеты';

  @override
  String get no_calculations => 'Нет доступных расчетов';

  @override
  String get record_deleted => 'Запись успешно удалена';

  @override
  String get ok => 'ОК';

  @override
  String get back => 'Назад';

  @override
  String get logo_not_found => 'Логотип не найден';

  @override
  String get initial_mileage_short => 'Нач. км';

  @override
  String get final_mileage_short => 'Кон. км';

  @override
  String get initial_fuel_short => 'Нач. топл.';

  @override
  String get refuel_short => 'Заправка';

  @override
  String get highway_distance_short => 'Трасса км';

  @override
  String get theme => 'Тема';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Темная';

  @override
  String get auto => 'Авто';

  @override
  String get theme_changed => 'Тема изменена на %s';

  @override
  String get language => 'Язык';

  @override
  String get russian => 'Русский';

  @override
  String get english => 'Английский';

  @override
  String get language_changed => 'Язык изменен на %s';

  @override
  String get step1 =>
      'Введите данные автомобиля (марка, модель, нормы расхода).';

  @override
  String get step2 => 'Рассчитайте расход топлива, указав пробег и заправки.';

  @override
  String get step3 => 'Просмотрите историю и экспортируйте данные.';

  @override
  String get step1_title => 'Добавьте свой автомобиль';

  @override
  String get step1_description =>
      'Добавьте данные о своем автомобиле, включая марку, модель и нормы расхода топлива.';

  @override
  String get step2_title => 'Рассчитывайте расход топлива';

  @override
  String get step2_description =>
      'Используйте калькулятор для отслеживания расхода топлива на основе пробега и заправок.';

  @override
  String get step3_title => 'Отслеживайте свою историю';

  @override
  String get step3_description =>
      'Просматривайте историю расхода топлива, экспортируйте данные и получайте статистику.';

  @override
  String get start_app => 'Начать использование';

  @override
  String get enter_car_details => 'Введите данные автомобиля';

  @override
  String get save_and_continue => 'Сохранить и продолжить';

  @override
  String get next => 'Далее';

  @override
  String get previous_cars => 'Ранее введенные автомобили';

  @override
  String get no_cars => 'Нет добавленных автомобилей';

  @override
  String get delete_car => 'Удалить автомобиль';

  @override
  String get delete_car_confirm =>
      'Вы уверены, что хотите удалить этот автомобиль?';

  @override
  String get fill_all_fields => 'Заполните все поля';

  @override
  String get delete => 'Удалить';

  @override
  String get settings => 'Настройки';

  @override
  String get home => 'Главная';

  @override
  String get history => 'История';

  @override
  String get liters_per_100km => 'л/100км';

  @override
  String get calculate => 'Рассчитать';

  @override
  String get save_and_back => 'Сохранить';

  @override
  String get continue_calculations => 'Продолжить';

  @override
  String get your_cars => 'Ваши автомобили';

  @override
  String get car_saved => 'Автомобиль успешно сохранён';

  @override
  String get create_new_car => 'Создать новый автомобиль';

  @override
  String get configure_cars => 'Настройка твоих авто';

  @override
  String get select_period => 'Выбрать период';

  @override
  String get reset_period => 'Сброс периода';

  @override
  String get share_all_history => 'Поделиться всей историей';

  @override
  String get go_to_calculator => 'Перейти к калькулятору';

  @override
  String get calculation_complete => 'Расчёт завершён';

  @override
  String get calculation_options =>
      'Для продолжения вы можете сохранить текущий расчёт и вернуться в главное меню или продолжить расчёты в этом окне.';

  @override
  String get duplicate_model => 'Эта модель уже используется!';

  @override
  String get invalid_norm => 'Неверный формат нормы расхода!';

  @override
  String get positive_norm => 'Норма расхода должна быть положительной!';

  @override
  String get loading => 'Загрузка...';

  @override
  String get ad_not_available => 'Реклама недоступна';

  @override
  String get period => 'Период';

  @override
  String get ad_load_failed => 'Не удалось загрузить рекламу, попробуйте позже';

  @override
  String get ad_show_failed => 'Не удалось показать рекламу, попробуйте снова';

  @override
  String get continue_calculation => 'Продолжить расчёт';

  @override
  String get choose_calculation_option =>
      'Хотите начать новый расчёт или продолжить текущий?';

  @override
  String get start_new_calculation => 'Начать новый расчёт';

  @override
  String get continue_current_calculation => 'Продолжить текущий расчёт';

  @override
  String get new_calculation_started => 'Начался новый расчёт';

  @override
  String get continued_calculation => 'Продолжен текущий расчёт';

  @override
  String get no_previous_calculation => 'Нет предыдущих расчётов';

  @override
  String get negative_final_fuel =>
      'Остаток топлива из предыдущего расчёта отрицательный, начните новый расчёт';

  @override
  String get confirm_save_before_exit =>
      'У вас есть несохранённые расчёты. Сохранить перед выходом?';

  @override
  String get generation => 'Поколение';

  @override
  String get modification => 'Модификация';

  @override
  String get year_from => 'Год начала выпуска';

  @override
  String get year_to => 'Год окончания выпуска';

  @override
  String get engine_volume => 'Объём двигателя';

  @override
  String get power_hp => 'Мощность (л.с.)';

  @override
  String get fuel_type => 'Тип топлива';

  @override
  String get petrol => 'Бензин';

  @override
  String get diesel => 'Дизель';

  @override
  String get lpg => 'Сжиженный газ';

  @override
  String get cng => 'Компрессированный газ';

  @override
  String get transmission_type => 'Тип КПП';

  @override
  String get transmission_speeds => 'Количество передач';

  @override
  String get combined_norm => 'Смешанный расход топлива';

  @override
  String get base_city_norm => 'Базовая норма по городу';

  @override
  String get base_highway_norm => 'Базовая норма по трассе';

  @override
  String get base_combined_norm => 'Базовая смешанная норма';

  @override
  String get city => 'Город';

  @override
  String get weather_multiplier => 'Погодный коэффициент';

  @override
  String get invalid_engine_volume =>
      'Объём двигателя должен быть от 0.5 до 10 литров';

  @override
  String get premium_subscription => 'Премиум-подписка';

  @override
  String get buy => 'Купить';

  @override
  String get premium_active => 'Премиум активирован';

  @override
  String get store_unavailable => 'Магазин недоступен';

  @override
  String get product_not_found => 'Премиум-продукт не найден';

  @override
  String get premium_purchase_in_progress => 'Покупка в процессе';

  @override
  String get premium_activated => 'Премиум активирован';

  @override
  String get purchase_error => 'Ошибка покупки';

  @override
  String get weather_unavailable =>
      'Погодные данные недоступны, используются значения по умолчанию';

  @override
  String get enter_city => 'Введите ваш город';

  @override
  String get register => 'Регистрация';

  @override
  String get email_or_phone => 'Email или телефон';

  @override
  String get password => 'Пароль';

  @override
  String get detect_location => 'Определить местоположение';

  @override
  String get location_service_disabled => 'Службы геолокации отключены';

  @override
  String get location_permission_denied => 'Разрешение на геолокацию отклонено';

  @override
  String get location_permission_denied_forever =>
      'Разрешение на геолокацию отклонено навсегда';

  @override
  String get invalid_email_or_phone =>
      'Неверный формат email или номера телефона';

  @override
  String get api_key_missing => 'Ключ Google API отсутствует';

  @override
  String get edit_car => 'Редактировать автомобиль';

  @override
  String get vehicleType => 'Тип транспортного средства';

  @override
  String get selectVehicleType => 'Выберите тип транспортного средства';

  @override
  String get passengerCar => 'Легковой';

  @override
  String get bus => 'Автобус';

  @override
  String get truck => 'Грузовой бор. автомобиль';

  @override
  String get tractor => 'Тягач';

  @override
  String get dumpTruck => 'Самосвал';

  @override
  String get van => 'Фургон';

  @override
  String get vanWithoutCargo => 'Фургон без учета груза (добавка 10% к норме)';

  @override
  String get trailerMass => 'Масса прицепа (т)';

  @override
  String get payloadCapacity => 'Грузоподъемность (т)';

  @override
  String get tripFuelRate => 'Норма расхода топлива на ездку (л)';

  @override
  String get heaterRate => 'Норма расхода топлива на отопитель (л/ч)';

  @override
  String get heaterTime => 'Время работы отопителя (ч)';

  @override
  String get mileage => 'Пробег (км)';

  @override
  String get cargoMass => 'Масса груза (т)';

  @override
  String get cargoMileage => 'Пробег с грузом (км)';

  @override
  String get trips => 'Количество ездок';

  @override
  String get correctionFactor => 'Поправочный коэффициент (%)';

  @override
  String get autoCorrectionFactor =>
      'Использовать автоматический расчет коэффициента';

  @override
  String get winterConditions => 'Зимние условия (+10%)';

  @override
  String get mountainConditions => 'Горная местность (+15%)';

  @override
  String get airConditioner => 'Кондиционер (+7%)';

  @override
  String get calculatedFuelConsumption => 'Рассчитанный расход топлива';

  @override
  String get electric => 'Электро';

  @override
  String get gas_diesel => 'Газодизель';

  @override
  String get adjustments => 'Корректировки';

  @override
  String get history_exported => 'История экспортирована';

  @override
  String get export => 'Экспорт';

  @override
  String get geocoding_error => 'Не удалось определить местоположение';

  @override
  String get api_key_invalid => 'Недействительный ключ API';

  @override
  String get winter => 'Зима';

  @override
  String get ac => 'Кондиционер';

  @override
  String get mountain => 'Горная местность';

  @override
  String get vehicle_type => 'Тип транспортного средства';

  @override
  String get passenger_car => 'Легковой автомобиль';

  @override
  String get dump_truck => 'Самосвал';

  @override
  String get special_equipment => 'Спецтехника';

  @override
  String get select_preset_car => 'Выберите предустановленный автомобиль';

  @override
  String get custom_input => 'Ручной ввод';

  @override
  String get license_plate => 'ГРЗ';

  @override
  String get fill_license_plate => 'Заполните ГРЗ';

  @override
  String get duplicate_license_plate => 'ГРЗ уже используется';

  @override
  String get search_car => 'Поиск автомобиля';

  @override
  String get car_deleted => 'Автомобиль удалён';

  @override
  String get select_brand => 'Выберите марку';

  @override
  String get select_model => 'Выберите модель';

  @override
  String get select_generation => 'Выберите поколение';

  @override
  String get no_data_found => 'Данные не найдены';

  @override
  String get no_cars_available => 'Нет доступных автомобилей';

  @override
  String get fuel_advice_button => 'AI совет по экономии';

  @override
  String get fuel_advice_title => 'Советы по экономии топлива';

  @override
  String get premium_feature =>
      'Эта функция доступна только для премиум-пользователей';

  @override
  String get share => 'Поделиться';

  @override
  String get insufficient_balance =>
      'Недостаточно баланса для AI-советов. Пополните счёт.';

  @override
  String get error_sharing => 'Ошибка при попытке поделиться советом';

  @override
  String get no_advice_to_share => 'Нет советов для отправки';

  @override
  String get search => 'Поиск';

  @override
  String get correction_factor => 'Поправочный коэффициент (%)';

  @override
  String get heater_operating_time => 'Время работы отопителя (ч)';

  @override
  String get invalid_correction_factor =>
      'Поправочный коэффициент должен быть в диапазоне -50..50%';

  @override
  String get invalid_heater_time =>
      'Время работы отопителя должно быть неотрицательным';

  @override
  String get heater_fuel_consumption => 'Расход топлива на отопитель';

  @override
  String get passenger_capacity => 'Пассажировместимость';

  @override
  String get sync_success => 'Данные успешно синхронизированы';

  @override
  String get sync_error =>
      'Не удалось синхронизировать данные. Попробуйте снова.';

  @override
  String get login => 'Вход';

  @override
  String get email => 'Электронная почта';

  @override
  String get invalid_email => 'Недействительный адрес электронной почты';

  @override
  String get weak_password => 'Пароль должен содержать не менее 6 символов';

  @override
  String get registration_success => 'Регистрация прошла успешно';

  @override
  String get email_already_in_use => 'Электронная почта уже используется';

  @override
  String get login_success => 'Вход выполнен успешно';

  @override
  String get invalid_credentials => 'Недействительный email или пароль';

  @override
  String get register_instead => 'Нет аккаунта? Зарегистрируйтесь';

  @override
  String get login_instead => 'Уже есть аккаунт? Войдите';

  @override
  String get sign_out => 'Выйти из аккаунта';

  @override
  String get sign_out_success => 'Выход выполнен успешно';

  @override
  String get loading_car_database => 'Загрузка базы данных автотранспорта...';

  @override
  String get duplicate_record => 'Расчет уже сохранен.';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get unsaved_changes => 'Несохраненные изменения';

  @override
  String get save => 'Сохранить';

  @override
  String get history_label_date => 'Дата';

  @override
  String get history_label_brand => 'Марка';

  @override
  String get history_label_license_plate => 'Гос. номер';

  @override
  String get history_label_initial_mileage => 'Начальный пробег';

  @override
  String get history_label_final_mileage => 'Конечный пробег';

  @override
  String get history_label_total_mileage => 'Общий пробег';

  @override
  String get history_label_city_mileage => 'Пробег по городу';

  @override
  String get history_label_highway_mileage => 'Пробег по трассе';

  @override
  String get history_label_city_norm => 'Городская норма';

  @override
  String get history_label_highway_norm => 'Трассовая норма';

  @override
  String get history_label_initial_fuel => 'Начальное топливо';

  @override
  String get history_label_refuel => 'Заправка';

  @override
  String get history_label_fuel_used => 'Расход';

  @override
  String get history_label_final_fuel => 'Остаток';

  @override
  String get condition_winter => 'Зима';

  @override
  String get condition_ac => 'Кондиционер';

  @override
  String get condition_mountain => 'Горная местность';

  @override
  String get confirm_delete_record_title => 'Подтвердите удаление';

  @override
  String get confirm_delete_record_content =>
      'Вы уверены, что хотите удалить эту запись?';

  @override
  String get no_modification => 'Нет модификации';

  @override
  String get correction_factor_tooltip =>
      'Этот коэффициент корректирует норму расхода топлива.\n\nАвтоматический режим:\nПри включении этой опции, коэффициент рассчитывается сам на основе актуальных погодных данных (температура, ветер, осадки). Это позволяет точно учесть влияние погоды на расход.\n\nРучной режим:\nКоэффициент вводится вручную в процентах (%) и может быть положительным (увеличивает расход) или отрицательным (уменьшает). Используйте его для учета уникальных условий, не связанных с погодой. Например: плохое состояние дороги, частые пробки, агрессивный стиль вождения или техническое состояние автомобиля.';

  @override
  String get heater_operating_time_tooltip =>
      'Введите общее время работы автономного отопителя салона в часах. Расход топлива отопителем рассчитывается отдельно и суммируется с основным расходом на движение. Норма расхода для отопителя задается в настройках автомобиля.';

  @override
  String get auto_factor_error =>
      'Не удалось получить погодные данные. Включен ручной ввод.';

  @override
  String get onboarding_title => 'Ваш личный топливный ассистент';

  @override
  String get onboarding_step1_title => 'Умный учет автомобилей';

  @override
  String get onboarding_step1_desc =>
      'Добавляйте свои автомобили вручную или выбирайте из обширной базы данных с автозаполнением норм расхода. Все ваши машины — в одном удобном списке.';

  @override
  String get onboarding_step2_title => 'Точные расчеты';

  @override
  String get onboarding_step2_desc =>
      'Используйте калькулятор для точного расчета расхода топлива, учитывая зимние условия, работу кондиционера и поездки в горной местности. Для автобусов доступен учет работы отопителя.';

  @override
  String get onboarding_step3_title => 'Анализ и экспорт';

  @override
  String get onboarding_step3_desc =>
      'Следите за статистикой на наглядных графиках, просматривайте детальную историю расчетов и делитесь данными в удобном формате.';

  @override
  String get onboarding_button => 'Начать работу';

  @override
  String get car_form_step1_title => 'Шаг 1: Идентификация';

  @override
  String get car_form_step2_title => 'Шаг 2: Выбор модели (автозаполнение)';

  @override
  String get car_form_step3_title => 'Шаг 3: Нормы расхода и детали';
}
