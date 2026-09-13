import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:fuelmaster/services/sync_outbox.dart';
import 'package:fuelmaster/utils/logger.dart';

/// Одна операция синхронизации, разобранная из строки очереди.
@immutable
class SyncOperation {
  const SyncOperation({
    required this.entity,
    required this.entityUuid,
    required this.op,
    this.entityId,
    this.payload,
  });

  /// `SyncOutbox.entityCar` или `SyncOutbox.entityHistory`.
  final String entity;

  /// Постоянный идентификатор сущности (D-4): именно он — ключ документа.
  final String entityUuid;

  /// `SyncOutbox.opUpsert` или `SyncOutbox.opDelete`.
  final String op;

  /// Локальный autoincrement id — только для диагностики и переходного периода.
  final int? entityId;

  /// Снимок строки БД на момент правки.
  final Map<String, dynamic>? payload;

  bool get isDelete => op == SyncOutbox.opDelete;

  /// Разбирает строку очереди. Возвращает null, если строка повреждена:
  /// вызывающий уберёт её из очереди, а не будет пытаться отправить вечно.
  static SyncOperation? fromRow(Map<String, Object?> row) {
    final String? entity = row['entity'] as String?;
    final String? uuid = row['entity_uuid'] as String?;
    final String? op = row['op'] as String?;
    if (entity == null || op == null || uuid == null || uuid.isEmpty) {
      return null;
    }

    Map<String, dynamic>? payload;
    final String? raw = row['payload'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        payload = jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        logger.w('Повреждён payload операции ${row['id']}: $e');
        payload = null;
      }
    }

    return SyncOperation(
      entity: entity,
      entityUuid: uuid,
      op: op,
      entityId: row['entity_id'] as int?,
      payload: payload,
    );
  }
}

/// Отправляет одну операцию. Бросает исключение, если отправить не удалось.
typedef SyncSender = Future<void> Function(SyncOperation operation);

/// Воркер синхронизации (D-4, фаза 2).
///
/// UI никогда не ждёт сети: изменения пишутся в SQLite и в журнал операций
/// одной транзакцией, а воркер разбирает журнал — при старте, при возврате
/// приложения из фона, по таймеру и сразу после правки. Единичный прогон
/// (`_draining`) исключает двойную отправку одной операции.
///
/// Отправитель инъектируется: тесты проверяют поведение очереди без Firebase,
/// а приложение использует [SyncWorker._sendToFirestore].
class SyncWorker {
  SyncWorker({SyncSender? sender, bool Function()? canSend, this.interval = const Duration(minutes: 5)})
      : _sender = sender ?? _sendToFirestore,
        _canSend = canSend ?? _hasAuthenticatedUser;

  /// Воркер приложения.
  static final SyncWorker instance = SyncWorker();

  final SyncSender _sender;
  final bool Function() _canSend;

  /// Как часто разбирать очередь, пока приложение на переднем плане.
  final Duration interval;

  /// Сколько операций ждёт отправки — для индикатора в настройках.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  /// Когда очередь разбиралась в последний раз.
  final ValueNotifier<DateTime?> lastDrainAt = ValueNotifier<DateTime?>(null);

  Timer? _timer;
  Timer? _debounce;
  bool _draining = false;

  bool get isRunning => _timer != null;

  /// Запускает периодический разбор и сразу делает первую попытку.
  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(drain()));
    unawaited(refreshPendingCount());
    unawaited(drain());
  }

  /// Останавливает таймер (выход из аккаунта, уход в фон).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
  }

  /// Разбор очереди «скоро» — после правки, не дожидаясь таймера.
  void scheduleDrain({Duration delay = const Duration(seconds: 3)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(drain()));
  }

  Future<int> refreshPendingCount() async {
    try {
      final int count = await SyncOutbox.countPending();
      pendingCount.value = count;
      return count;
    } catch (e) {
      logger.w('Не удалось посчитать очередь синка: $e');
      return pendingCount.value;
    }
  }

  /// Разбирает очередь и возвращает число успешно отправленных операций.
  ///
  /// При первой же ошибке отправка прекращается: если упала сеть, долбить
  /// остальные операции бессмысленно — они уйдут со следующей попытки, а
  /// очередь уже помнит, что операция не доставлена.
  Future<int> drain({int limit = 50}) async {
    if (_draining || !_canSend()) return 0;

    _draining = true;
    int sent = 0;
    try {
      final List<Map<String, Object?>> rows =
          await SyncOutbox.pending(limit: limit);
      for (final Map<String, Object?> row in rows) {
        final int? id = row['id'] as int?;
        if (id == null) continue;

        final SyncOperation? operation = SyncOperation.fromRow(row);
        if (operation == null) {
          // Строку не разобрать — из очереди убираем, иначе она застрянет навсегда.
          await SyncOutbox.markDone(id);
          continue;
        }

        try {
          await _sender(operation);
          await SyncOutbox.markDone(id);
          sent++;
        } catch (e) {
          await SyncOutbox.markFailed(id, e);
          break;
        }
      }
    } catch (e) {
      logger.e('Разбор очереди синка не удался: $e');
    } finally {
      _draining = false;
      lastDrainAt.value = DateTime.now();
      await refreshPendingCount();
    }

    if (sent > 0) logger.d('Синк: отправлено операций — $sent');
    return sent;
  }

  static bool _hasAuthenticatedUser() =>
      Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;

  /// Отправка в Firestore: `users/{uid}/cars|history/{uuid}`.
  ///
  /// Ключ — uuid, а не локальный id (D-4): иначе два устройства с одинаковым
  /// локальным id перезаписывали одну и ту же запись друг друга.
  static Future<void> _sendToFirestore(SyncOperation operation) async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase не инициализирован');
    }
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Нет вошедшего пользователя');
    }

    final String collection = operation.entity == SyncOutbox.entityCar
        ? 'cars'
        : 'history';
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(operation.entityUuid);

    if (operation.isDelete) {
      await ref.delete();
      return;
    }

    final Map<String, dynamic> data = <String, dynamic>{
      ...?operation.payload,
      'uuid': operation.entityUuid,
      // Фаза 3: серверная метка времени — точка отсчёта для LWW, чтобы
      // подкрученные часы телефона не выигрывали конфликт.
      'updated_at': FieldValue.serverTimestamp(),
    };
    await ref.set(data, SetOptions(merge: true));
  }
}
