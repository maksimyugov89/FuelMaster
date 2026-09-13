import 'dart:async';

import 'package:flutter/foundation.dart';

/// Откладывает вызов [action] до истечения [duration] после последнего срабатывания.
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({required this.duration});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
