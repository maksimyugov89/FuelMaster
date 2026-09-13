import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fuelmaster/services/sync_outbox.dart';
import 'package:fuelmaster/utils/uuid_v4.dart';
import 'package:fuelmaster/services/sync_worker.dart';

/// Управление историей расчётов. Единственный источник правды — SQLite.
class HistoryManager {
  static const String _legacyHistoryKey = 'history';

  static bool _isDuplicateRecord(
    Map<String, dynamic> newRecord,
    List<Map<String, dynamic>> history,
  ) {
    return history.any((record) =>
        record['model'] == newRecord['model'] &&
        record['license_plate'] == newRecord['license_plate'] &&
        record['initial_mileage'] == newRecord['initial_mileage'] &&
        record['final_mileage'] == newRecord['final_mileage'] &&
        record['highway_mileage'] == newRecord['highway_mileage'] &&
        record['initial_fuel'] == newRecord['initial_fuel'] &&
        record['refuel'] == newRecord['refuel']);
  }

  static Map<String, Object?> _fuelLogRow(Map<String, dynamic> record) {
    final recordWithTimestamp = {
      ...record,
      'last_modified': record['last_modified'] ?? DateTime.now().millisecondsSinceEpoch,
    };
    return {
      if (recordWithTimestamp['id'] != null) 'id': recordWithTimestamp['id'],
      // D-4: ключ синхронизации. Строки без него (созданные до версии 13)
      // получают uuid здесь же — в той же транзакции, что и запись.
      'uuid': ensureUuid(recordWithTimestamp['uuid'] as String?),
      'car_id': recordWithTimestamp['car_id'] ?? 0,
      'date': recordWithTimestamp['date'],
      'license_plate': recordWithTimestamp['license_plate'],
      'initial_mileage': recordWithTimestamp['initial_mileage'],
      'final_mileage': recordWithTimestamp['final_mileage'],
      'total_mileage': recordWithTimestamp['total_mileage'],
      'highway_mileage': recordWithTimestamp['highway_mileage'],
      'city_mileage': recordWithTimestamp['city_mileage'],
      'initial_fuel': recordWithTimestamp['initial_fuel'],
      'refuel': recordWithTimestamp['refuel'],
      'fuel_used': double.tryParse(recordWithTimestamp['fuel_used'].toString()) ?? 0.0,
      'final_fuel': double.tryParse(recordWithTimestamp['final_fuel'].toString()) ?? 0.0,
      'conditions_applied': jsonEncode(recordWithTimestamp['conditions'] ?? {}),
      'correction_factor': recordWithTimestamp['correction_factor'],
      'heater_operating_time': recordWithTimestamp['heater_operating_time'],
      'last_modified': recordWithTimestamp['last_modified'],
      'base_city_norm': recordWithTimestamp['base_city_norm'],
      'base_highway_norm': recordWithTimestamp['base_highway_norm'],
    };
  }

  /// Миграция legacy-истории из SharedPreferences в SQLite (однократно).
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_legacyHistoryKey);
    if (historyJson == null || historyJson.isEmpty) {
      return;
    }

    final records = <Map<String, dynamic>>[];
    for (final json in historyJson) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        if (map.isNotEmpty) records.add(map);
      } catch (e) {
        logger.e('Ошибка миграции записи истории: $e, JSON: $json');
      }
    }

    if (records.isNotEmpty) {
      await saveHistoryToDatabase(records);
      logger.d('Мигрировано записей истории из SharedPreferences: ${records.length}');
    }

    await prefs.remove(_legacyHistoryKey);
  }

  static Future<void> saveHistoryEntry(Map<String, dynamic> entry) async {
    if (entry.isEmpty) {
      logger.w('Попытка сохранить пустую запись истории, пропускаем');
      return;
    }

    try {
      final existing = await loadHistoryFromDatabase();
      if (_isDuplicateRecord(entry, existing)) {
        logger.d('Запись истории — дубликат, пропускаем');
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final Map<String, Object?> row = _fuelLogRow(entry);

      // Запись и постановка в очередь — одной транзакцией (D-4): запись не
      // считается сохранённой, пока операция не попала в журнал синхронизации.
      final int id = await db.transaction<int>((txn) async {
        final int insertedId = await txn.insert(
          'fuel_logs',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await SyncOutbox.enqueue(
          entity: SyncOutbox.entityHistory,
          entityUuid: row['uuid']! as String,
          entityId: insertedId,
          op: SyncOutbox.opUpsert,
          // payload — строка таблицы: только примитивы, поэтому jsonEncode
          // гарантированно не упадёт (в отличие от исходного map с вложенностями).
          payload: Map<String, dynamic>.from(row),
          executor: txn,
        );
        return insertedId;
      });

      final saved = {...entry, 'id': id, 'uuid': row['uuid']};
      logger.d('Запись истории сохранена в SQLite');

      await _syncHistoryRecordToCloud(saved);
    } catch (e) {
      logger.e('Ошибка сохранения записи истории: $e');
      rethrow;
    }
  }

  /// Сохраняет полный список записей в SQLite (без SharedPreferences).
  static Future<void> saveHistory(List<Map<String, dynamic>>? history) async {
    if (history == null || history.isEmpty) {
      logger.w('Попытка сохранить пустую историю, пропускаем');
      return;
    }
    await saveHistoryToDatabase(history);
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    try {
      return await loadHistoryFromDatabase();
    } catch (e) {
      logger.e('Ошибка загрузки истории: $e');
      return [];
    }
  }

  static Future<void> saveHistoryToDatabase(List<Map<String, dynamic>> history) async {
    if (history.isEmpty) return;

    try {
      final db = await DatabaseHelper.instance.database;
      final existing = await loadHistoryFromDatabase();
      var inserted = 0;

      // Транзакция вместо batch (D-4): вместе с каждой записью в журнал синка
      // попадает операция. Пакетный insert этого не позволял.
      await db.transaction<void>((txn) async {
        for (final record in history) {
          if (_isDuplicateRecord(record, existing)) continue;
          final Map<String, Object?> row = _fuelLogRow(record);
          final int id = await txn.insert(
            'fuel_logs',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await SyncOutbox.enqueue(
            entity: SyncOutbox.entityHistory,
            entityUuid: row['uuid']! as String,
            entityId: id,
            op: SyncOutbox.opUpsert,
            payload: Map<String, dynamic>.from(row),
            executor: txn,
          );
          inserted++;
        }
      });

      if (inserted > 0) {
        logger.d('Сохранено записей истории в SQLite: $inserted');
      }

      for (final record in history) {
        await _syncHistoryRecordToCloud(record);
      }
    } catch (e) {
      logger.e('Ошибка пакетного сохранения истории: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadHistoryFromDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('fuel_logs', orderBy: 'date DESC');
      return result.map(_mapFuelLogRow).toList();
    } catch (e) {
      logger.e('Ошибка загрузки истории из SQLite: $e');
      return [];
    }
  }

  static Map<String, dynamic> _mapFuelLogRow(Map<String, Object?> map) {
    final conditionsJson = map['conditions_applied'] as String?;
    final conditions = conditionsJson != null
        ? jsonDecode(conditionsJson) as Map<String, dynamic>
        : <String, dynamic>{};

    return {
      'id': map['id'] as int,
      'uuid': map['uuid'] as String?,
      'date': map['date'] as String,
      'car_id': map['car_id'] as int,
      'license_plate': map['license_plate'] as String?,
      'initial_mileage': map['initial_mileage'] as double,
      'final_mileage': map['final_mileage'] as double,
      'total_mileage': map['total_mileage'] as double?,
      'highway_mileage': map['highway_mileage'] as double,
      'city_mileage': map['city_mileage'] as double,
      'initial_fuel': map['initial_fuel'] as double,
      'refuel': map['refuel'] as double,
      'fuel_used': map['fuel_used'] as double,
      'final_fuel': map['final_fuel'] as double,
      'conditions': conditions,
      'correction_factor': map['correction_factor'] as double?,
      'heater_operating_time': map['heater_operating_time'] as double?,
      'last_modified': map['last_modified'] as int?,
      'base_city_norm': map['base_city_norm'] as double?,
      'base_highway_norm': map['base_highway_norm'] as double?,
    };
  }

  static Future<void> syncHistoryWithFirestore(String uid) async {
    // F-1: монетизация отложена — синхронизация истории доступна всем.

    const maxRetries = 2;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await _performFirestoreSync(uid);
        return;
      } catch (e) {
        logger.e('Синхронизация истории (попытка ${attempt + 1}): $e');
        if (attempt == maxRetries) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Слияние истории с Firestore (D-4, фаза 2).
  ///
  /// Тянет облачные записи к себе, а свои **ставит в очередь**: отправляет их
  /// SyncWorker. Ключ — uuid; записи старого формата (ключ — локальный id)
  /// читаются в переходный период.
  static Future<void> _performFirestoreSync(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> localHistory =
        await loadHistoryFromDatabase();
    final remoteSnapshot =
        await firestore.collection('users').doc(uid).collection('history').get();

    final Map<String, Map<String, dynamic>> remoteByUuid = {};
    final Map<int, Map<String, dynamic>> remoteByLegacyId = {};
    for (final doc in remoteSnapshot.docs) {
      final Map<String, dynamic> data = <String, dynamic>{...doc.data()};
      final String? uuid = (data['uuid'] as String?)?.trim();
      if (isUuidV4(uuid)) {
        remoteByUuid[uuid!] = data;
      } else {
        final int? legacyId = int.tryParse(doc.id);
        if (legacyId != null) remoteByLegacyId[legacyId] = data;
      }
    }

    final db = await DatabaseHelper.instance.database;

    for (final Map<String, dynamic> local in localHistory) {
      final String? uuid = local['uuid'] as String?;
      Map<String, dynamic>? remote =
          (uuid != null && isUuidV4(uuid)) ? remoteByUuid[uuid] : null;
      remote ??= remoteByLegacyId[(local['id'] as num?)?.toInt() ?? -1];

      final int localTime = (local['last_modified'] as num?)?.toInt() ?? 0;
      final int remoteTime = (remote?['last_modified'] as num?)?.toInt() ?? 0;

      if (remote == null || localTime > remoteTime) {
        await _enqueueHistoryUpsert(local);
      } else if (remoteTime > localTime) {
        await db.update(
          'fuel_logs',
          _fuelLogRow(<String, dynamic>{
            ...remote,
            'id': local['id'],
            'uuid': uuid,
          }),
          where: 'id = ?',
          whereArgs: <Object?>[local['id']],
        );
      }
    }

    // Облачные записи, которых нет на устройстве. Локальный id не переносим:
    // он принадлежит другой строке (класс ошибок B-1), личность — в uuid.
    for (final MapEntry<String, Map<String, dynamic>> entry
        in remoteByUuid.entries) {
      if (localHistory.any((Map<String, dynamic> lr) => lr['uuid'] == entry.key)) {
        continue;
      }
      final Map<String, Object?> row = _fuelLogRow(<String, dynamic>{
        ...entry.value,
        'uuid': entry.key,
      })..remove('id');
      await db.insert('fuel_logs', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final MapEntry<int, Map<String, dynamic>> entry
        in remoteByLegacyId.entries) {
      if (localHistory.any(
          (Map<String, dynamic> lr) => (lr['id'] as num?)?.toInt() == entry.key)) {
        continue;
      }
      final String? uuid = (entry.value['uuid'] as String?)?.trim();
      if (!isUuidV4(uuid)) continue; // без uuid синхронизировать нечем
      final Map<String, Object?> row = _fuelLogRow(<String, dynamic>{
        ...entry.value,
        'uuid': uuid,
      })..remove('id');
      await db.insert('fuel_logs', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    logger.d('История: облако проверено, свои изменения — в очереди синка');
  }

  /// Кладёт в очередь отправку записи истории (отправляет SyncWorker).
  static Future<void> _enqueueHistoryUpsert(Map<String, dynamic> record) async {
    final Map<String, Object?> row = _fuelLogRow(record);
    await SyncOutbox.enqueue(
      entity: SyncOutbox.entityHistory,
      entityUuid: row['uuid']! as String,
      entityId: row['id'] as int?,
      op: SyncOutbox.opUpsert,
      payload: Map<String, dynamic>.from(row),
    );
  }

  /// Отправка записи в облако — необязательный шаг (D-4).
  ///
  /// Локальная запись уже сделана и операция лежит в очереди синка, поэтому
  /// отсутствие Firebase (тесты, офлайн) или ошибка сети не должны ломать
  /// сохранение: очередь отправит запись позже.
  static Future<void> _syncHistoryRecordToCloud(Map<String, dynamic> record) async {
    // Операция уже лежит в очереди (D-4) — просим воркер разобрать её, но
    // ничего не ждём: сохранение не зависит от сети.
    SyncWorker.instance.scheduleDrain();
  }

  static Future<void> _deleteHistoryRecordFromCloud(int id) async {
    // Удаление уже в очереди (D-4) — отправкой займётся воркер.
    SyncWorker.instance.scheduleDrain();
  }

  static Future<void> deleteHistoryRecord(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, Object?>> found = await db.query(
        'fuel_logs',
        columns: <String>['uuid'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final String? uuid = found.isEmpty ? null : found.first['uuid'] as String?;

      await db.transaction<void>((txn) async {
        await txn.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
        if (uuid != null && uuid.isNotEmpty) {
          await SyncOutbox.enqueue(
            entity: SyncOutbox.entityHistory,
            entityUuid: uuid,
            entityId: id,
            op: SyncOutbox.opDelete,
            executor: txn,
          );
        }
      });

      await _deleteHistoryRecordFromCloud(id);
    } catch (e) {
      logger.e('Ошибка удаления записи истории: $e');
      rethrow;
    }
  }
}
