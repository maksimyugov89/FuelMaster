import 'package:flutter_test/flutter_test.dart';
import 'package:fuelmaster/main.dart';
import 'package:flutter/material.dart';
import 'package:fuelmaster/onboarding_page.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:fuelmaster/main_menu_page.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/widgets.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {
  @override
  Future<bool> setBool(String key, bool value) async => true;
  @override
  bool getBool(String key, [bool defValue = false]) => key == 'isFirstLaunch' ? true : key == 'isDarkMode' ? true : defValue;
  @override
  Future<bool> setStringList(String key, List<String> value) async => true;
  @override
  List<String>? getStringList(String key) => key == 'cars' ? ['{"brand": "Test", "licensePlate": "ABC123", "cityNorm": "8.0", "highwayNorm": "6.0"}'] : null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'isFirstLaunch': true,
      'isDarkMode': true,
      'cars': ['{"brand": "Test", "licensePlate": "ABC123", "cityNorm": "8.0", "highwayNorm": "6.0"}'],
    });
  });

  testWidgets('FuelMaster smoke test', (WidgetTester tester) async {
    final mockPrefs = MockSharedPreferences();
    await tester.pumpWidget(
      const MyApp(),
    );

    await tester.pumpAndSettle(const Duration(seconds: 3));
    final l10n = AppLocalizations.of(tester.element(find.byType(OnboardingPage)))!;
    final startButton = find.widgetWithText(ElevatedButton, l10n.start_app);
    expect(startButton, findsOneWidget);

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(MainMenuPage), findsOneWidget);

    final themeData = Theme.of(tester.element(find.byType(MainMenuPage)));
    expect(themeData.brightness, Brightness.dark);

    final menuL10n = AppLocalizations.of(tester.element(find.byType(MainMenuPage)))!;
    expect(find.text(menuL10n.app_title), findsOneWidget);
    expect(find.byType(DropdownButton<CarData>), findsOneWidget);
    expect(find.widgetWithText(AnimatedButton, menuL10n.settings), findsOneWidget);
    expect(find.widgetWithText(AnimatedButton, menuL10n.history), findsOneWidget);
  });
}