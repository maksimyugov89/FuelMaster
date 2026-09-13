import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';

/// D-4: журнал операций (outbox) для офлайн-первого синка.
///
/// Идея: ни одно действие пользователя не ждёт сети. Локальная запись в SQLite и
/// постановка операции в эту очередь происходят **в одной транзакции**, а сеть
/// догоняет потом — очередь разбирает воркер синхронизации (см.
/// docs/D4_OFFLINE_SYNC_PLAN.md). Если приложение упало или сети не было,
/// операция всё равно не потеряется: она лежит на диске до успешной отправки.
///
/// Строка очереди — «что сказать серверу», а не «что мы думаем о сервере»:
/// payload — снимок сущности на момент правки, поэтому конфликт двух устройств
/// разрешается сравнением снимков и времени правки (LWW).
class SyncOutbox {
  const SyncOutbox._();

  static const String table = 'sync_outbox';

  /// Сущности, которые синхронизируются.
  static const String entityCar = 'car';
  static const String entityHistory = 'history';

  /// Операции.
  static const String opUpsert = 'upsert';
  static const String opDelete = 'delete';

  static const Duration baseBackoff = Duration(seconds: 30);
  static const Duration maxBackoff = Duration(hours: 1);

  static const int _maxErrorLength = 500;

  /// Кладёт операцию в очередь.
  ///
  /// [executor] — транзакция вызывающего кода. Передавайте её всегда, когда
  /// запись данных и постановка в очередь должны быть атомарны: иначе сбой между
  /// двумя записями оставит правку локально, но не отправит её на сервер.
  static Future<int> enqueue({
    required String entity,
    required String entityUuid,
    required String op,
    int? entityId,
    Map<String, dynamic>? payload,
    DatabaseExecutor? executor,
    int? now,
  }) async {
    if (entityUuid.isEmpty) {
      throw ArgumentError('Пустой uuid сущности: синхронизация без него невозможна');
    }
    final DatabaseExecutor db =
        executor ?? await DatabaseHelper.instance.database;
    final int timestamp = now ?? DateTime.now().millisecondsSinceEpoch;

    final int id = await db.insert(table, <String, Object?>{
      'entity': entity,
      'entity_uuid': entityUuid,
      'entity_id': entityId,
      'op': op,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': timestamp,
      'attempts': 0,
      'next_attempt_at': timestamp,
      'last_error': null,
    });

    logger.d('В очередь синка: $op $entity (uuid=$entityUuid, id=$id)');
    return id;
  }

  /// Операции, готовые к отправке, в порядке постановки.
  static Future<List<Map<String, Object?>>> pending({
    int limit = 50,
    int? now,
    DatabaseExecutor? executor,
    String? entity,
  }) async {
    final DatabaseExecutor db =
        executor ?? await DatabaseHelper.instance.database;
    final int timestamp = now ?? DateTime.now().millisecondsSinceEpoch;

    return db.query(
      table,
      where: entity == null
          ? 'next_attempt_at <= ?'
          : 'next_attempt_at <= ? AND entity = ?',
      whereArgs: <Object?>[timestamp, if (entity != null) entity],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
  }

  /// Сколько операций ждёт отправки (для индикатора в UI и диагностики).
  static Future<int> countPending({DatabaseExecutor? executor}) async {
    final DatabaseExecutor db =
        executor ?? await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows =
        await db.rawQuery('SELECT COUNT(*) AS cnt FROM $table');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  /// Операция доставлена — строку из очереди убираем (это очередь, а не история).
  static Future<void> markDone(int id, {DatabaseExecutor? executor}) async {
    final DatabaseExecutor db =
        executor ?? await DatabaseHelper.instance.database;
    await db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Операция не прошла: увеличиваем счётчик попыток и откладываем следующую
  /// по экспоненте (30 с, 1 мин, 2 мин, … не больше часа).
  static Future<Duration> markFailed(
    int id,
    Object error, {
    DatabaseExecutor? executor,
    int? now,
  }) async {
    final DatabaseExecutor db =
        executor ?? await DatabaseHelper.instance.database;
    final int timestamp = now ?? DateTime.now().millisecondsSinceEpoch;

    final List<Map<String, Object?>> rows = await db.query(
      table,
      columns: <String>['attempts'],
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    final int attempts = ((rows.isEmpty ? 0 : rows.first['attempts']) as int? ?? 0) + 1;
    final Duration delay = backoffFor(attempts);

    await db.update(
      table,
      <String, Object?>{
        'attempts': attempts,
        'next_attempt_at': timestamp + delay.inMilliseconds,
        'last_error': error.toString().length > _maxErrorLength
            ? error.toString().substring(0, _maxErrorLength)
            : error.toString(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );

    logger.w('Синк не прошёл (попытка $attempts), повтор через ${delay.inSeconds} с');
    return delay;
  }

  /// Пауза перед следующей попыткой для номера попытки [attempts] (начиная с 1).
  static Duration backoffFor(int attempts) {
    if (attempts <= 1) return baseBackoff;
    final int seconds =
        baseBackoff.inSeconds * (1 << (attempts - 1).clamp(0, 20));
    return seconds >= maxBackoff.inSeconds ? maxBackoff : Duration(seconds: seconds);
  }

  /// Очистка очереди — например, при выходе из аккаунта.
  static Future<void> clear({DatabaseExecutor? executor}) async {
    final DatabaseExecutor db =
        executor ?? await DatabaseHelper.instance.database;
    await db.delete(table);
  }
}
