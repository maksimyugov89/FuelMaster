import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Количество строк стека вызовов
    errorMethodCount: 8, // Количество строк для ошибок
    lineLength: 120, // Длина строки в логах
    colors: true, // Включить цветной вывод
    printEmojis: true, // Включить эмодзи
    printTime: true, // Включить временные метки
  ),
  level: Level.debug, // Минимальный уровень логов
);