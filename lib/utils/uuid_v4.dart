import 'dart:math';

/// Минимальный генератор UUID v4 (RFC 4122) — без внешних зависимостей.
///
/// Нужен для D-4: сущности синхронизируются по глобально уникальному ключу,
/// а не по локальному autoincrement `id`. Именно из-за локальных id две машины
/// могли получить одинаковый номер на разных устройствах, и Firestore
/// перезаписывал чужую запись (класс ошибок B-1).
String generateUuidV4([Random? random]) {
  final Random rnd = random ?? _secureRandom;
  final List<int> bytes = List<int>.generate(16, (_) => rnd.nextInt(256));

  // version 4 (0100) и variant 10xx
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final String hex =
      bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final Random _secureRandom = Random.secure();

/// Возвращает существующий корректный uuid или выдаёт новый.
///
/// Используется на всех путях записи: и для новых сущностей, и для строк,
/// созданных до версии 13, и для значений, пришедших из Firestore.
String ensureUuid(String? value) => isUuidV4(value) ? value! : generateUuidV4();

/// Проверка формата — используется в тестах и при чтении данных из Firestore,
/// куда uuid мог попасть от старой версии клиента.
final RegExp uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

bool isUuidV4(String? value) => value != null && uuidV4Pattern.hasMatch(value);
