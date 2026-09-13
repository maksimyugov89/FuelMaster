import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/onboarding_page.dart';

void main() {
  testWidgets('Onboarding shows start button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingPage(onFinish: () {}),
      ),
    );

    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(OnboardingPage)))!;
    expect(find.text(l10n.onboarding_button), findsOneWidget);
  });
}
