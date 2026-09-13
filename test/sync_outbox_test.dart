import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fuelmaster/services/sync_outbox.dart';
import 'package:fuelmaster/utils/database_helper.dart';

/// D-4: механика очереди операций на настоящей SQLite.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 13,
        onCreate: (Database database, int version) =>
            DatabaseHelper.createSchemaForTesting(database, version),
      ),
    );
  });

  tearDown(() async => db.close());

  test('операция встаёт в очередь и читается из неё', () async {
    await SyncOutbox.enqueue(
      entity: SyncOutbox.entityCar,
      entityUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      entityId: 7,
      op: SyncOutbox.opUpsert,
      payload: <String, dynamic>{'brand': 'Toyota', 'model': 'Camry'},
      executor: db,
    );

    final List<Map<String, Object?>> rows = await SyncOutbox.pending(executor: db);
    expect(rows.length, 1);
    expect(rows.first['entity'], SyncOutbox.entityCar);
    expect(rows.first['op'], SyncOutbox.opUpsert);
    expect(rows.first['entity_id'], 7);
    expect(rows.first['attempts'], 0);
    expect(rows.first['payload'], contains('Camry'));
    expect(await SyncOutbox.countPending(executor: db), 1);
  });

  test('пустой uuid — ошибка: синхронизировать нечего', () async {
    expect(
      () => SyncOutbox.enqueue(
        entity: SyncOutbox.entityCar,
        entityUuid: '',
        op: SyncOutbox.opUpsert,
        executor: db,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('markDone убирает операцию, markFailed откладывает с backoff', () async {
    final int id = await SyncOutbox.enqueue(
      entity: SyncOutbox.entityHistory,
      entityUuid: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      op: SyncOutbox.opUpsert,
      executor: db,
    );
    const int now = 1000000;

    final Duration first = await SyncOutbox.markFailed(id, 'нет сети', executor: db, now: now);
    expect(first, SyncOutbox.backoffFor(1));
    expect(first, const Duration(seconds: 30));

    // Пока пауза не вышла — операция не готова.
    expect(await SyncOutbox.pending(executor: db, now: now), isEmpty);
    final List<Map<String, Object?>> ready = await SyncOutbox.pending(
      executor: db,
      now: now + first.inMilliseconds + 1,
    );
    expect(ready.length, 1);
    expect(ready.first['attempts'], 1);
    expect(ready.first['last_error'], 'нет сети');

    final Duration second = await SyncOutbox.markFailed(id, 'нет сети', executor: db, now: now);
    expect(second, const Duration(minutes: 1));

    await SyncOutbox.markDone(id, executor: db);
    expect(await SyncOutbox.countPending(executor: db), 0);
  });

  test('backoff растёт по экспоненте и упирается в потолок', () {
    expect(SyncOutbox.backoffFor(1), const Duration(seconds: 30));
    expect(SyncOutbox.backoffFor(2), const Duration(seconds: 60));
    expect(SyncOutbox.backoffFor(3), const Duration(seconds: 120));
    expect(SyncOutbox.backoffFor(8), SyncOutbox.maxBackoff);
    expect(SyncOutbox.backoffFor(30), SyncOutbox.maxBackoff);
  });

  test('pending отдаёт операции в порядке постановки и уважает limit', () async {
    for (int i = 0; i < 3; i++) {
      await SyncOutbox.enqueue(
        entity: SyncOutbox.entityCar,
        entityUuid: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc$i',
        entityId: i,
        op: SyncOutbox.opUpsert,
        executor: db,
        now: 5000 + i,
      );
    }
    final List<Map<String, Object?>> rows =
        await SyncOutbox.pending(executor: db, limit: 2, now: 9000);
    expect(rows.map((Map<String, Object?> r) => r['entity_id']), <int>[0, 1]);
    expect(await SyncOutbox.countPending(executor: db), 3);
  });

  test('сбой транзакции откатывает и данные, и очередь', () async {
    await expectLater(
      db.transaction<void>((txn) async {
        await txn.insert('cars', <String, Object?>{
          'uuid': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          'brand': 'Тест',
          'model': 'Сбой',
          'base_rate_city': 8.0,
          'base_rate_highway': 6.0,
        });
        await SyncOutbox.enqueue(
          entity: SyncOutbox.entityCar,
          entityUuid: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          op: SyncOutbox.opUpsert,
          executor: txn,
        );
        throw StateError('сбой после записи');
      }),
      throwsA(isA<StateError>()),
    );

    expect(await db.query('cars'), isEmpty);
    expect(await SyncOutbox.countPending(executor: db), 0);
  });
}
