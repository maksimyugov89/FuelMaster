import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

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

  static Future<bool> _isPremiumUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isPremiumKey) ?? false;
  }

  static Map<String, Object?> _fuelLogRow(Map<String, dynamic> record) {
    final recordWithTimestamp = {
      ...record,
      'last_modified': record['last_modified'] ?? DateTime.now().millisecondsSinceEpoch,
    };
    return {
      if (recordWithTimestamp['id'] != null) 'id': recordWithTimestamp['id'],
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
        logger.d('Запись истории — дубликат, пропускаем: $entry');
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final id = await db.insert(
        'fuel_logs',
        _fuelLogRow(entry),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final saved = {...entry, 'id': id};
      logger.d('Запись истории сохранена в SQLite: $saved');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && await _isPremiumUser()) {
        await _syncHistoryRecordToFirestore(user.uid, saved);
      }
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
      final batch = db.batch();
      var inserted = 0;

      for (final record in history) {
        if (_isDuplicateRecord(record, existing)) continue;
        batch.insert(
          'fuel_logs',
          _fuelLogRow(record),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        inserted++;
      }

      if (inserted > 0) {
        await batch.commit(noResult: true);
        logger.d('Сохранено записей истории в SQLite: $inserted');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && await _isPremiumUser()) {
        for (final record in history) {
          await _syncHistoryRecordToFirestore(user.uid, record);
        }
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
    if (!await _isPremiumUser()) {
      logger.d('Синхронизация истории пропущена: нет premium');
      return;
    }

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

  static Future<void> _performFirestoreSync(String uid) async {
    final firestore = FirebaseFirestore.instance;
    final localHistory = await loadHistoryFromDatabase();
    final remoteSnapshot =
        await firestore.collection('users').doc(uid).collection('history').get();

    final remoteHistory = remoteSnapshot.docs.map((doc) {
      return {...doc.data(), 'id': int.tryParse(doc.id) ?? 0};
    }).toList();

    final db = await DatabaseHelper.instance.database;

    for (final localRecord in localHistory) {
      final remoteRecord = remoteHistory.firstWhere(
        (rr) => rr['id'] == localRecord['id'],
        orElse: () => <String, dynamic>{},
      );
      if (remoteRecord.isEmpty ||
          (localRecord['last_modified'] ?? 0) > (remoteRecord['last_modified'] ?? 0)) {
        await _syncHistoryRecordToFirestore(uid, localRecord);
      } else if ((remoteRecord['last_modified'] ?? 0) > (localRecord['last_modified'] ?? 0)) {
        await db.update(
          'fuel_logs',
          _fuelLogRow(remoteRecord),
          where: 'id = ?',
          whereArgs: [remoteRecord['id']],
        );
      }
    }

    for (final remoteRecord in remoteHistory) {
      if (!localHistory.any((lr) => lr['id'] == remoteRecord['id'])) {
        await db.insert('fuel_logs', _fuelLogRow(remoteRecord));
      }
    }

    logger.d('Синхронизация истории с Firestore завершена');
  }

  static Future<void> _syncHistoryRecordToFirestore(
    String uid,
    Map<String, dynamic> record,
  ) async {
    final id = record['id'];
    if (id == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .doc(id.toString())
          .set(record);
    } catch (e) {
      logger.e('Ошибка синхронизации записи с Firestore: $e');
      rethrow;
    }
  }

  static Future<void> deleteHistoryRecord(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && await _isPremiumUser()) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .doc(id.toString())
            .delete();
      }
    } catch (e) {
      logger.e('Ошибка удаления записи истории: $e');
      rethrow;
    }
  }
}
