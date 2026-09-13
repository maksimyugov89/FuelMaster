import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fuelmaster/services/sync_outbox.dart';
import 'package:fuelmaster/services/sync_worker.dart';
import 'package:fuelmaster/utils/database_helper.dart';

/// Воркер синхронизации (D-4, фаза 2) проверяется на настоящей SQLite:
/// отправитель подменяется, поэтому Firebase тесту не нужен, а очередь,
/// backoff и порядок операций проверяются по-настоящему.
void main() {
  late SyncWorker worker;
  late List<SyncOperation> sent;
  late bool failNext;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Соединение с базой кэшируется в DatabaseHelper, поэтому «чистая» очередь
    // достигается очисткой таблицы, а не удалением файла БД (на Windows файл
    // открытого соединения удалить нельзя).
    final db = await DatabaseHelper.instance.database;
    await db.delete(SyncOutbox.table);

    sent = <SyncOperation>[];
    failNext = false;
    worker = SyncWorker(
      canSend: () => true,
      sender: (operation) async {
        if (failNext) throw Exception('сеть недоступна');
        sent.add(operation);
      },
    );
  });

  test('разбирает очередь в порядке постановки и очищает её', () async {
    final carRow = <String, dynamic>{'uuid': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'brand': 'Haval', 'model': 'Jolion'};
    await SyncOutbox.enqueue(entity: SyncOutbox.entityCar, entityUuid: carRow['uuid'] as String, op: SyncOutbox.opUpsert, entityId: 1, payload: carRow, now: 1000);
    await SyncOutbox.enqueue(entity: SyncOutbox.entityHistory, entityUuid: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', op: SyncOutbox.opUpsert, entityId: 2, payload: {'fuel_used': 42.0}, now: 2000);
    await SyncOutbox.enqueue(entity: SyncOutbox.entityCar, entityUuid: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', op: SyncOutbox.opDelete, entityId: 3, now: 3000);

    final int count = await worker.drain();

    expect(count, 3);
    expect(sent.map((op) => op.entityUuid).toList(), [
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    ]);
    expect(sent.last.isDelete, isTrue);
    expect(await SyncOutbox.countPending(), 0);
    expect(worker.pendingCount.value, 0);
  });

  test('ошибка отправки не теряет операцию: backoff, затем повтор', () async {
    await SyncOutbox.enqueue(entity: SyncOutbox.entityCar, entityUuid: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', op: SyncOutbox.opUpsert, entityId: 1, payload: {'brand': 'Geely'});

    failNext = true;
    expect(await worker.drain(), 0);
    expect(await SyncOutbox.countPending(), 1, reason: 'операция остаётся в очереди');
    expect(worker.pendingCount.value, 1);

    // Повтор сразу недоступен: backoff отложил попытку.
    expect(await SyncOutbox.pending(), isEmpty);
    final later = DateTime.now().millisecondsSinceEpoch + SyncOutbox.baseBackoff.inMilliseconds + 1000;
    expect(await SyncOutbox.pending(now: later), hasLength(1));
    final row = (await SyncOutbox.pending(now: later)).first;
    expect(row['attempts'], 1);
    expect(row['last_error'].toString(), contains('сеть недоступна'));

    failNext = false;
    expect(await worker.drain(limit: 50), 0, reason: 'срок ещё не наступил');
  });

  test('операцию можно отправить после истечения паузы', () async {
    await SyncOutbox.enqueue(entity: SyncOutbox.entityCar, entityUuid: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', op: SyncOutbox.opUpsert, entityId: 1, payload: {'brand': 'Changan'});
    final int id = (await SyncOutbox.pending()).first['id'] as int;

    failNext = true;
    await worker.drain();
    failNext = false;

    // Сдвигаем срок попытки в прошлое — так выглядит «прошло 30 секунд».
    final db = await DatabaseHelper.instance.database;
    await db.update(SyncOutbox.table, {'next_attempt_at': 0}, where: 'id = ?', whereArgs: [id]);

    expect(await worker.drain(), 1);
    expect(await SyncOutbox.countPending(), 0);
    expect(sent.single.entityUuid, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
  });

  test('без вошедшего пользователя очередь не трогается', () async {
    await SyncOutbox.enqueue(entity: SyncOutbox.entityCar, entityUuid: 'ffffffff-ffff-4fff-8fff-ffffffffffff', op: SyncOutbox.opUpsert, entityId: 1, payload: {'brand': 'Jetour'});

    final offlineWorker = SyncWorker(canSend: () => false, sender: (op) async => sent.add(op));
    expect(await offlineWorker.drain(), 0);
    expect(sent, isEmpty);
    expect(await SyncOutbox.countPending(), 1, reason: 'операция ждёт входа в аккаунт');
  });

  test('повреждённая строка очереди не блокирует остальные', () async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(SyncOutbox.table, {
      'entity': SyncOutbox.entityCar,
      'entity_uuid': '',
      'op': SyncOutbox.opUpsert,
      'payload': '{не json',
      'created_at': 500,
      'attempts': 0,
      'next_attempt_at': 0,
    });
    await SyncOutbox.enqueue(entity: SyncOutbox.entityCar, entityUuid: '99999999-9999-4999-8999-999999999999', op: SyncOutbox.opUpsert, entityId: 5, payload: {'brand': 'Tank'}, now: 600);

    expect(await worker.drain(), 1);
    expect(sent.single.entityUuid, '99999999-9999-4999-8999-999999999999');
    expect(await SyncOutbox.countPending(), 0);
  });
}
