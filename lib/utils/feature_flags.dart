/// Выключатели функций, отложенных на будущие версии (F-1, 13.09.2026).
///
/// Монетизация, реклама и AI-советы сознательно выведены из текущего релиза:
/// приоритет — стабильность работы приложения. Логика функций не удалена и не
/// переписана — она включается обратно одним ключом сборки:
///
///   flutter build apk --release --dart-define=FEATURE_ADS=true \
///     --dart-define=FEATURE_PREMIUM=true --dart-define=FEATURE_AI_ADVICE=true
///
/// Пока флаг выключен: рекламные блоки не запрашиваются, Billing не
/// поднимается, платные запросы к AI не уходят, а экраны показывают, что
/// функция появится в новых версиях.
class FeatureFlags {
  const FeatureFlags._();

  /// Реклама (Яндекс Мобильная Реклама).
  static const bool ads = bool.fromEnvironment('FEATURE_ADS');

  /// Подписка и проверка чека через сервер.
  static const bool premium = bool.fromEnvironment('FEATURE_PREMIUM');

  /// AI-советы по экономии топлива (DeepSeek).
  static const bool aiAdvice = bool.fromEnvironment('FEATURE_AI_ADVICE');
}
