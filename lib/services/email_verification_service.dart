import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fuelmaster/utils/logger.dart';

/// Итог отправки письма подтверждения e-mail.
enum VerificationSendResult {
  /// Письмо отправлено.
  sent,

  /// Отправлять пока нельзя: не истёк интервал между письмами.
  cooldown,

  /// Пользователь не авторизован.
  noUser,

  /// Ошибка отправки.
  error,
}

/// Подтверждение e-mail (F-2).
///
/// Проверка адреса нужна для восстановления доступа к аккаунту и для
/// синхронизации истории между устройствами. Работу приложения подтверждение
/// НЕ блокирует: данные учёта хранятся локально, поэтому неподтверждённый
/// пользователь продолжает считать расход — ему лишь напоминают о письме.
class EmailVerificationService {
  const EmailVerificationService._();

  /// Метка последней отправки (для интервала между письмами).
  static const String _lastSentKey = 'email_verification_sent_at';

  /// Метка «письмо уже отправляли на этом устройстве» (одно письмо на установку).
  static const String _initialSentKey = 'email_verification_initial_sent';

  /// Интервал между отправками: без него кнопка «отправить ещё раз»
  /// превращается в поток писем, а Firebase отвечает too-many-requests.
  static const Duration cooldown = Duration(seconds: 60);

  static User? get user => FirebaseAuth.instance.currentUser;

  static String? get email => user?.email;

  static bool get isVerified => user?.emailVerified ?? false;

  /// Есть пользователь и адрес ещё не подтверждён.
  static bool get needsVerification => user != null && !isVerified;

  /// Сколько секунд осталось до следующей возможной отправки (0 — можно).
  static Future<int> secondsUntilResend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? sentAt = prefs.getInt(_lastSentKey);
      if (sentAt == null) return 0;
      final int elapsed = DateTime.now().millisecondsSinceEpoch - sentAt;
      final int left = cooldown.inMilliseconds - elapsed;
      return left > 0 ? (left / 1000).ceil() : 0;
    } catch (e) {
      logger.e('Не удалось прочитать метку отправки письма: $e');
      return 0;
    }
  }

  /// Отправляет письмо подтверждения.
  ///
  /// [respectCooldown] false — для письма сразу после регистрации: пользователя
  /// о нём предупредили, и ждать минуту до повторной попытки незачем.
  static Future<VerificationSendResult> send({
    bool respectCooldown = true,
  }) async {
    final User? current = user;
    if (current == null) return VerificationSendResult.noUser;

    try {
      if (respectCooldown && await secondsUntilResend() > 0) {
        return VerificationSendResult.cooldown;
      }
      await current.sendEmailVerification();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastSentKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool(_initialSentKey, true);
      logger.d('Письмо подтверждения e-mail отправлено');
      return VerificationSendResult.sent;
    } on FirebaseAuthException catch (e) {
      logger.e('Письмо подтверждения не отправлено: ${e.code}');
      return e.code == 'too-many-requests'
          ? VerificationSendResult.cooldown
          : VerificationSendResult.error;
    } catch (e) {
      logger.e('Письмо подтверждения не отправлено: $e');
      return VerificationSendResult.error;
    }
  }

  /// Одно письмо на установку: закрывает аккаунты, созданные до появления
  /// подтверждения. Дальше письмо уходит только по кнопке пользователя.
  static Future<VerificationSendResult> sendInitial() async {
    if (!needsVerification) return VerificationSendResult.noUser;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_initialSentKey) ?? false) {
        return VerificationSendResult.cooldown;
      }
    } catch (e) {
      logger.e('Не удалось прочитать флаг первичного письма: $e');
    }
    return send(respectCooldown: false);
  }

  /// Перечитывает пользователя с сервера и возвращает актуальный статус.
  ///
  /// Без сети остаётся прежнее значение: подтверждение — не повод показывать
  /// ошибку или терять статус.
  static Future<bool> refresh() async {
    final User? current = user;
    if (current == null) return false;
    try {
      await current.reload();
      final bool verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (verified) logger.d('E-mail подтверждён');
      return verified;
    } catch (e) {
      logger.e('Не удалось обновить статус подтверждения e-mail: $e');
      return isVerified;
    }
  }
}
