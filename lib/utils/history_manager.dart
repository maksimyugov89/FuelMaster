import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:intl/intl.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';

class HistoryManager {
  static const String _historyKey = 'history';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static bool _isDuplicateRecord(Map<String, dynamic> newRecord, List<Map<String, dynamic>> history) {
    return history.any((record) =>
        record['model'] == newRecord['model'] &&
        record['license_plate'] == newRecord['license_plate'] &&
        record['initial_mileage'] == newRecord['initial_mileage'] &&
        record['final_mileage'] == newRecord['final_mileage'] &&
        record['highway_mileage'] == newRecord['highway_mileage'] &&
        record['initial_fuel'] == newRecord['initial_fuel'] &&
        record['refuel'] == newRecord['refuel']);
  }

  static Future<void> saveHistoryEntry(Map<String, dynamic> entry) async {
    if (entry.isEmpty) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.w('[$timestamp] Попытка сохранить пустую запись, пропускаем');
      return;
    }

    try {
      // Save to SharedPreferences (for potential legacy use or quick access)
      final prefs = await _getPrefs();
      final historyJson = prefs.getStringList(_historyKey) ?? [];
      final history = historyJson.map((json) {
        try {
          return jsonDecode(json) as Map<String, dynamic>;
        } catch (e) {
          logger.e('Ошибка парсинга JSON истории: $e, JSON: $json');
          return null;
        }
      }).where((item) => item != null).cast<Map<String, dynamic>>().toList();

      if (!_isDuplicateRecord(entry, history)) {
        history.insert(0, entry);
        final historyJsonNew = history.map((record) {
          try {
            return jsonEncode(record);
          } catch (e) {
            logger.e('Ошибка сериализации записи: $record, ошибка: $e');
            return null;
          }
        }).where((item) => item != null).cast<String>().toList();
        await prefs.setStringList(_historyKey, historyJsonNew);
        final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
        logger.d('[$timestamp] Saved history entry to SharedPreferences: $entry');

        // --- ALSO SAVE TO DATABASE ---
        final db = await DatabaseHelper.instance.database;
        final recordWithTimestamp = {
          ...entry,
          'last_modified': DateTime.now().millisecondsSinceEpoch,
        };
        await db.insert('fuel_logs', {
          'car_id': recordWithTimestamp['car_id'] ?? 0,
          'date': recordWithTimestamp['date'],
          'license_plate': recordWithTimestamp['license_plate'],
          'initial_mileage': recordWithTimestamp['initial_mileage'],
          'final_mileage': recordWithTimestamp['final_mileage'],
          // ✨ FIX: Добавлено сохранение общего пробега в базу данных
          'total_mileage': recordWithTimestamp['total_mileage'], 
          'highway_mileage': recordWithTimestamp['highway_mileage'],
          'city_mileage': recordWithTimestamp['city_mileage'],
          'initial_fuel': recordWithTimestamp['initial_fuel'],
          'refuel': recordWithTimestamp['refuel'],
          'fuel_used': double.tryParse(recordWithTimestamp['fuel_used'].toString()) ?? 0.0,
          'final_fuel': double.tryParse(recordWithTimestamp['final_fuel'].toString()) ?? 0.0,
          'conditions_applied': jsonEncode(recordWithTimestamp['conditions']),
          'correction_factor': recordWithTimestamp['correction_factor'],
          'heater_operating_time': recordWithTimestamp['heater_operating_time'],
          'last_modified': recordWithTimestamp['last_modified'],
          'base_city_norm': recordWithTimestamp['base_city_norm'],
          'base_highway_norm': recordWithTimestamp['base_highway_norm'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        logger.d('[$timestamp] Saved history entry to Database: $entry');

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final prefs = await SharedPreferences.getInstance();
          final isPremium = prefs.getBool('isPremium') ?? false;
          if (isPremium) {
            await _syncHistoryRecordToFirestore(user.uid, entry);
          }
        }
      } else {
        final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
        logger.d('[$timestamp] Запись является дубликатом, пропускаем: $entry');
      }
    } catch (e) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.e('[$timestamp] Ошибка сохранения записи: $e');
      rethrow;
    }
  }

  static Future<void> saveHistory(List<Map<String, dynamic>>? history) async {
    if (history == null || history.isEmpty) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.w('[$timestamp] Попытка сохранить пустую историю, пропускаем');
      return;
    }

    try {
      final prefs = await _getPrefs();
      final uniqueHistory = <Map<String, dynamic>>[];
      for (var record in history) {
        if (!_isDuplicateRecord(record, uniqueHistory)) {
          uniqueHistory.add(record);
        }
      }
      final historyJson = uniqueHistory.map((record) {
        try {
          return jsonEncode(record);
        } catch (e) {
          logger.e('Ошибка сериализации записи: $record, ошибка: $e');
          return null;
        }
      }).where((item) => item != null).cast<String>().toList();
      await prefs.setStringList(_historyKey, historyJson);
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.d('[$timestamp] Saved history: $historyJson');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final isPremium = prefs.getBool('isPremium') ?? false;
        if (isPremium) {
          for (var record in uniqueHistory) {
            await _syncHistoryRecordToFirestore(user.uid, record);
          }
        }
      }
    } catch (e) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.e('[$timestamp] Ошибка сохранения истории: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadHistory() async {
    try {
      // USE DATABASE AS THE SINGLE SOURCE OF TRUTH
      return await loadHistoryFromDatabase();
    } catch (e) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.e('[$timestamp] Ошибка загрузки истории: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> migrateHistory() async {
    final prefs = await _getPrefs();
    final oldHistory = prefs.getStringList(_historyKey) ?? [];
    final newHistory = <Map<String, dynamic>>[];
    for (var record in oldHistory) {
      try {
        final parts = record.split(', ');
        final map = <String, dynamic>{};
        for (var part in parts) {
          final keyValue = part.split(': ');
          if (keyValue.length >= 2) {
            final key = keyValue[0].toLowerCase().replaceAll(' ', '');
            final value = keyValue.sublist(1).join(': ').trim();
            switch (key) {
              case 'date':
              case 'дата':
                map['date'] = value;
                break;
              case 'brand':
              case 'марка':
                map['brand'] = value;
                break;
              case 'licenseplate':
              case 'гос.номер':
                map['license_plate'] = value;
                break;
              case 'initialmileage':
              case 'начальныйпробег':
                map['initial_mileage'] = double.tryParse(value.replaceAll(' km', '').replaceAll(' км', '')) ?? 0.0;
                break;
              case 'finalmileage':
              case 'конечныйпробег':
                map['final_mileage'] = double.tryParse(value.replaceAll(' km', '').replaceAll(' км', '')) ?? 0.0;
                break;
              case 'totalmileage':
              case 'общийпробег':
                map['total_mileage'] = double.tryParse(value.replaceAll(' km', '').replaceAll(' км', '')) ?? 0.0;
                break;
              case 'citykm':
              case 'пробегпогороду':
                map['city_mileage'] = double.tryParse(value.replaceAll(' km', '').replaceAll(' км', '')) ?? 0.0;
                break;
              case 'citynorm':
              case 'городскаянорма':
                map['base_city_norm'] = double.tryParse(value.replaceAll(' L/100km', '').replaceAll(' л/100км', '')) ?? 0.0;
                break;
              case 'highwaykm':
              case 'пробегпотрассе':
                map['highway_mileage'] = double.tryParse(value.replaceAll(' km', '').replaceAll(' км', '')) ?? 0.0;
                break;
              case 'highwaynorm':
              case 'трассоваянорма':
                map['base_highway_norm'] = double.tryParse(value.replaceAll(' L/100km', '').replaceAll(' л/100км', '')) ?? 0.0;
                break;
              case 'refuel':
              case 'заправка':
                map['refuel'] = double.tryParse(value.replaceAll(' liters', '').replaceAll(' л', '')) ?? 0.0;
                break;
              case 'fuelused':
              case 'расход':
                map['fuel_used'] = double.tryParse(value.replaceAll(' liters', '').replaceAll(' л', '')) ?? 0.0;
                break;
              case 'finalfuel':
              case 'остаток':
                map['final_fuel'] = double.tryParse(value.replaceAll(' liters', '').replaceAll(' л', '')) ?? 0.0;
                break;
            }
          }
        }
        if (map.isNotEmpty) newHistory.add(map);
      } catch (e) {
        logger.e('Ошибка миграции записи: $record, ошибка: $e');
      }
    }
    await saveHistory(newHistory);
    return newHistory;
  }

  static Future<void> saveHistoryToDatabase(List<Map<String, dynamic>>? history) async {
    if (history == null || history.isEmpty) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.w('[$timestamp] Попытка сохранить пустую историю в базу данных, пропускаем');
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final batch = db.batch();
      for (var record in history) {
        if (!_isDuplicateRecord(record, await loadHistoryFromDatabase())) {
          final recordWithTimestamp = {
            ...record,
            'last_modified': DateTime.now().millisecondsSinceEpoch,
          };
          batch.insert('fuel_logs', {
            'car_id': recordWithTimestamp['car_id'] ?? 0,
            'date': recordWithTimestamp['date'],
            'license_plate': recordWithTimestamp['license_plate'],
            'initial_mileage': recordWithTimestamp['initial_mileage'],
            'final_mileage': recordWithTimestamp['final_mileage'],
            'highway_mileage': recordWithTimestamp['highway_mileage'],
            'city_mileage': recordWithTimestamp['city_mileage'],
            'initial_fuel': recordWithTimestamp['initial_fuel'],
            'refuel': recordWithTimestamp['refuel'],
            'fuel_used': double.tryParse(recordWithTimestamp['fuel_used'].toString()) ?? 0.0,
            'final_fuel': double.tryParse(recordWithTimestamp['final_fuel'].toString()) ?? 0.0,
            'conditions_applied': jsonEncode(recordWithTimestamp['conditions']),
            'correction_factor': recordWithTimestamp['correction_factor'],
            'heater_operating_time': recordWithTimestamp['heater_operating_time'],
            'last_modified': recordWithTimestamp['last_modified'],
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await batch.commit();
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.d('[$timestamp] Saved history to database: $history');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final isPremium = prefs.getBool('isPremium') ?? false;
        if (isPremium) {
          for (var record in history) {
            await _syncHistoryRecordToFirestore(user.uid, record);
          }
        }
      }
    } catch (e) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.e('[$timestamp] Ошибка сохранения истории в базу данных: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> loadHistoryFromDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('fuel_logs', orderBy: 'date DESC');
      final history = result.map((map) {
        final conditionsJson = map['conditions_applied'] as String?;
        final conditions = conditionsJson != null ? jsonDecode(conditionsJson) as Map<String, dynamic> : <String, dynamic>{};
        return {
          'id': map['id'] as int,
          'date': map['date'] as String,
          'car_id': map['car_id'] as int,
          'license_plate': map['license_plate'] as String?,
          'initial_mileage': map['initial_mileage'] as double,
          'final_mileage': map['final_mileage'] as double,
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
      }).toList();
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.d('[$timestamp] Loaded history from database: $history');
      return history;
    } catch (e) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.e('[$timestamp] Ошибка загрузки истории из базы данных: $e');
      return [];
    }
  }

  static Future<void> syncHistoryWithFirestore(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('isPremium') ?? false;
    if (!isPremium) {
      logger.d('History sync skipped: User is not premium');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final localHistory = await loadHistoryFromDatabase();
      final remoteHistorySnapshot = await firestore.collection('users').doc(uid).collection('history').get();

      final remoteHistory = remoteHistorySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'id': int.parse(doc.id),
        };
      }).toList();

      final db = await DatabaseHelper.instance.database;
      for (var localRecord in localHistory) {
        final remoteRecord = remoteHistory.firstWhere(
          (rr) => rr['id'] == localRecord['id'],
          orElse: () => <String, dynamic>{},
        );
        if (remoteRecord.isEmpty || (localRecord['last_modified'] ?? 0) > (remoteRecord['last_modified'] ?? 0)) {
          await _syncHistoryRecordToFirestore(uid, localRecord);
        } else if ((remoteRecord['last_modified'] ?? 0) > (localRecord['last_modified'] ?? 0)) {
          await db.update(
            'fuel_logs',
            remoteRecord,
            where: 'id = ?',
            whereArgs: [remoteRecord['id']],
          );
          logger.d('Updated local history record from Firestore: $remoteRecord');
        }
      }

      for (var remoteRecord in remoteHistory) {
        if (!localHistory.any((lr) => lr['id'] == remoteRecord['id'])) {
          await db.insert('fuel_logs', remoteRecord);
          logger.d('Inserted remote history record to local: $remoteRecord');
        }
      }

      for (var localRecord in localHistory) {
        if (!remoteHistory.any((rr) => rr['id'] == localRecord['id'])) {
          await db.delete('fuel_logs', where: 'id = ?', whereArgs: [localRecord['id']]);
          logger.d('Deleted local history record not in Firestore: id=${localRecord['id']}');
        }
      }

      logger.d('History sync with Firestore completed');
    } catch (e) {
      logger.e('Sync failed: $e');
      await Future.delayed(Duration(seconds: 5));
      await syncHistoryWithFirestore(uid); // retry once
    }
  }

  static Future<void> _syncHistoryRecordToFirestore(String uid, Map<String, dynamic> record) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).collection('history').doc(record['id'].toString()).set(record);
      logger.d('Synced history record to Firestore: $record');
    } catch (e) {
      logger.e('Error syncing history record to Firestore: $e');
      throw Exception('Failed to sync history record: $e');
    }
  }

  static Future<void> deleteHistoryRecord(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
      logger.d('Deleted history record locally: id=$id');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final isPremium = prefs.getBool('isPremium') ?? false;
        if (isPremium) {
          await _deleteHistoryRecordFromFirestore(user.uid, id);
        }
      }
    } catch (e) {
      logger.e('Error deleting history record: $e');
      rethrow;
    }
  }

  static Future<void> _deleteHistoryRecordFromFirestore(String uid, int id) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(uid).collection('history').doc(id.toString()).delete();
      logger.d('Deleted history record from Firestore: id=$id');
    } catch (e) {
      logger.e('Error deleting history record from Firestore: $e');
      throw Exception('Failed to delete history record: $e');
    }
  }
}