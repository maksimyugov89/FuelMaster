import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Единый логгер приложения.
///
/// В release-сборке (пункт C-3 аудита):
///  * уровень поднят до [Level.warning] — отладочные дампы с данными пользователя
///    (авто, история заправок, город, ответы API) в лог не попадают;
///  * отключены цвета, эмодзи, метки времени и стек вызовов — их всё равно некуда
///    выводить, а лишний объём в logcat только вредит.
///
/// Правило: данные пользователя не логировать даже в debug. Можно id и
/// количество записей, нельзя номер авто, цену, маршрут, email.
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: kReleaseMode ? 0 : 2,
    errorMethodCount: kReleaseMode ? 0 : 8,
    lineLength: 120,
    colors: !kReleaseMode,
    printEmojis: !kReleaseMode,
    dateTimeFormat: kReleaseMode ? DateTimeFormat.none : DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: kReleaseMode ? Level.warning : Level.debug,
);
