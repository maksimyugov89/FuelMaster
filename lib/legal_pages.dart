import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';

/// Политика конфиденциальности и условия использования (B-12 аудита).
///
/// Текст продублирован в приложении, потому что Play требует доступную из
/// интерфейса ссылку, а `url_launcher` в проекте нет (новые зависимости не
/// добавляем). Публичный URL для карточки в Play задаётся владельцем аккаунта.
class LegalTexts {
  const LegalTexts._();

  static const String privacy = '''
Политика конфиденциальности FuelMaster

Какие данные обрабатываются:
• e-mail и пароль — для входа в аккаунт (Firebase Authentication);
• город и страна — для расчёта норм расхода и прогноза погоды;
• местоположение — только по вашему запросу, для подстановки города;
• автомобили, заправки и расход — ваша история учёта топлива;
• технические данные об ошибках — для диагностики.

Где хранятся данные:
• на устройстве — в локальной базе данных приложения;
• в облаке — в Firebase Firestore (Google) и только для вашего аккаунта;
• правила доступа разрешают чтение и запись лишь владельцу документа.

Передача третьим сторонам (только необходимый минимум):
• Geoapify — координаты для определения города;
• WeatherAPI — город для прогноза погоды;
• сервис AI-советов — модель авто и параметры расхода без ваших контактов.

Что вы можете сделать:
• удалить аккаунт вместе с данными — в настройках приложения;
• выйти из аккаунта — локальные данные пользователя при этом удаляются;
• запретить доступ к геолокации — приложение продолжит работать.

Реклама: используется Яндекс Мобильная Реклама; при активной подписке
реклама не показывается.
''';

  static const String terms = '''
Условия использования FuelMaster

1. Приложение помогает учитывать расход топлива и носит справочный характер.
   Расчёты не заменяют данные производителя автомобиля.
2. Аккаунт нужен для синхронизации истории между устройствами и AI-советов.
   Вы отвечаете за сохранность пароля.
3. Подписка оформляется через Google Play; управление и отмена — в Play.
4. Приложение предоставляется «как есть». Мы стремимся к точности расчётов,
   но не гарантируем отсутствие ошибок.
5. Мы можем обновлять приложение и эти условия; актуальная версия — здесь.
''';
}

/// Экран политики конфиденциальности.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: AppLocalizations.of(context)!.privacy_policy,
      body: LegalTexts.privacy,
    );
  }
}

/// Экран условий использования.
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalScaffold(
      title: AppLocalizations.of(context)!.terms_of_use,
      body: LegalTexts.terms,
    );
  }
}

class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          body,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
