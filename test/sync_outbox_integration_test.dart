import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fuelmaster/services/sync_outbox.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:fuelmaster/utils/models/car_data.dart';

/// D-4: каждая правка данных обязана оставить операцию в очереди синка,
/// а сущность — получить постоянный uuid (вместо локального id).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final RegExp uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  late Database db;

  CarData car() => CarData(
        brand: 'Toyota',
        model: 'Camry',
        licensePlate: '123ABC01',
        baseCityNorm: 8.4,
        baseHighwayNorm: 5.7,
      );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 13,
        onCreate: (Database database, int version) =>
            DatabaseHelper.createSchemaForTesting(database, version),
      ),
    );
    DatabaseHelper.setDatabaseForTesting(db);
  });

  tearDown(() async => db.close());

  test('insertCar: строка получает uuid, а очередь — операцию upsert', () async {
    await DatabaseHelper.instance.insertCar(car());

    final List<Map<String, Object?>> cars = await db.query('cars');
    expect(cars.length, 1);
    final String uuid = cars.first['uuid']! as String;
    expect(uuidV4.hasMatch(uuid), isTrue, reason: 'uuid=$uuid');

    final List<Map<String, Object?>> queue = await SyncOutbox.pending(executor: db);
    expect(queue.length, 1);
    expect(queue.first['entity'], SyncOutbox.entityCar);
    expect(queue.first['op'], SyncOutbox.opUpsert);
    expect(queue.first['entity_uuid'], uuid);
    expect(queue.first['payload'] as String, contains('Camry'));
  });

  test('updateCar: uuid не меняется, правка уходит второй операцией', () async {
    await DatabaseHelper.instance.insertCar(car());
    final Map<String, Object?> inserted = (await db.query('cars')).first;

    await DatabaseHelper.instance.updateCar(
      CarData.fromJson(Map<String, dynamic>.from(inserted)).copyWith(model: 'Camry XV70'),
    );

    final Map<String, Object?> updated = (await db.query('cars')).single;
    expect(updated['uuid'], inserted['uuid']);
    expect(updated['model'], 'Camry XV70');
    expect((await SyncOutbox.pending(executor: db)).length, 2);
  });

  test('deleteCar: авто и его заправки уходят, в очередь идёт delete', () async {
    await DatabaseHelper.instance.insertCar(car());
    final Map<String, Object?> inserted = (await db.query('cars')).single;
    final int id = inserted['id']! as int;

    await DatabaseHelper.instance.deleteCar(id);

    expect(await db.query('cars'), isEmpty);
    final List<Map<String, Object?>> queue = await SyncOutbox.pending(executor: db);
    expect(queue.last['op'], SyncOutbox.opDelete);
    expect(queue.last['entity'], SyncOutbox.entityCar);
    expect(queue.last['entity_uuid'], inserted['uuid']);
  });

  test('saveHistoryEntry: запись получает uuid и попадает в очередь', () async {
    await HistoryManager.saveHistoryEntry(<String, dynamic>{
      'car_id': 1,
      'date': '13.09.2026 10:00',
      'initial_mileage': 1000.0,
      'final_mileage': 1500.0,
      'total_mileage': 500.0,
      'highway_mileage': 200.0,
      'city_mileage': 300.0,
      'initial_fuel': 20.0,
      'refuel': 40.0,
      'fuel_used': 45.0,
      'final_fuel': 15.0,
      'base_city_norm': 8.0,
      'base_highway_norm': 6.0,
      'conditions': <String, dynamic>{},
    });

    final List<Map<String, Object?>> logs = await db.query('fuel_logs');
    expect(logs.length, 1);
    expect(uuidV4.hasMatch(logs.first['uuid']! as String), isTrue);

    final List<Map<String, Object?>> queue = await SyncOutbox.pending(executor: db);
    expect(queue.length, 1);
    expect(queue.first['entity'], SyncOutbox.entityHistory);
    expect(queue.first['op'], SyncOutbox.opUpsert);
    expect(queue.first['entity_uuid'], logs.first['uuid']);
  });
}
