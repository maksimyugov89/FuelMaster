import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fuelmaster/services/premium_service.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';

/// Результат удаления аккаунта (B-12 аудита).
enum AccountDeletionResult {
  success,

  /// Firebase требует свежий вход: ничего не удаляем, просим войти заново.
  requiresRecentLogin,
  noUser,
  error,
}

/// Удаление аккаунта и восстановление профиля (B-10, B-12 аудита).
class AccountService {
  const AccountService._();

  /// Полное удаление: подколлекции Firestore → профиль → Auth → устройство.
  ///
  /// Порядок важен: чистить Firestore можно только пока пользователь
  /// авторизован. При `requires-recent-login` не трогаем ничего.
  static Future<AccountDeletionResult> deleteAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return AccountDeletionResult.noUser;

    try {
      await _purgeFirestore(user.uid);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      logger.e('Удаление аккаунта не удалось: ${e.code}');
      return e.code == 'requires-recent-login'
          ? AccountDeletionResult.requiresRecentLogin
          : AccountDeletionResult.error;
    } catch (e) {
      logger.e('Удаление аккаунта не удалось: $e');
      return AccountDeletionResult.error;
    }

    await DatabaseHelper.instance.clearUserData();
    await PremiumService.instance.setPremium(false);
    return AccountDeletionResult.success;
  }

  /// Создаёт документ профиля, если его нет (аккаунт мог появиться в момент,
  /// когда запись профиля не прошла).
  static Future<void> ensureUserProfile(String uid) async {
    try {
      final DocumentReference<Map<String, dynamic>> ref =
          FirebaseFirestore.instance.collection('users').doc(uid);
      final snapshot = await ref.get();
      if (snapshot.exists) return;

      await ref.set({
        'email': FirebaseAuth.instance.currentUser?.email,
        'city': '',
        'country': null,
        'created_at': FieldValue.serverTimestamp(),
      });
      logger.d('Профиль пользователя создан при входе');
    } catch (e) {
      logger.e('Не удалось создать профиль пользователя: $e');
    }
  }

  /// Чистит документ пользователя и его подколлекции.
  static Future<void> _purgeFirestore(String uid) async {
    final DocumentReference<Map<String, dynamic>> userDoc =
        FirebaseFirestore.instance.collection('users').doc(uid);

    for (final String name in const ['history', 'cars']) {
      try {
        final snapshot = await userDoc.collection(name).get();
        if (snapshot.docs.isEmpty) continue;
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        logger.e('Не удалось очистить $name пользователя: $e');
      }
    }

    try {
      await userDoc.delete();
    } catch (e) {
      logger.e('Не удалось удалить профиль пользователя: $e');
    }
  }
}
