/// Единый источник идентификаторов рекламных блоков (B-9 аудита).
///
/// Раньше ID были захардкожены в трёх экранах, а `env.defines.json` содержал
/// свои значения — источник правды дублировался. Теперь ID берутся отсюда:
/// значение из `--dart-define-from-file`, прежние ID оставлены фолбэком,
/// чтобы сборка без dart-define не потеряла рекламу.
class AdUnitIds {
  const AdUnitIds._();

  static const String banner = String.fromEnvironment(
    'YANDEX_BANNER_AD_UNIT_ID',
    defaultValue: 'R-M-16174255-1',
  );

  static const String nativeAd = String.fromEnvironment(
    'YANDEX_NATIVE_AD_UNIT_ID',
    defaultValue: 'R-M-16174255-2',
  );

  /// Межстраничная реклама: ID приходит только из dart-define (в репозитории
  /// его нет). Пустое значение = реклама отключена, показ не запрашивается.
  static const String interstitial = String.fromEnvironment(
    'YANDEX_INTERSTITIAL_AD_UNIT_ID',
  );

  static bool get hasInterstitial => interstitial.isNotEmpty;
}
