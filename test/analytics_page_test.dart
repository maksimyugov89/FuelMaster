import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fuelmaster/analytics_page.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';

/// D-2: экран аналитики проверяем как пользователь — что видно на экране.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final DateFormat fmt = DateFormat('dd.MM.yyyy HH:mm');

  final CarData car = CarData(
    id: 1,
    brand: 'Toyota',
    model: 'Camry',
    licensePlate: '123ABC01',
    baseCityNorm: 10,
    baseHighwayNorm: 8,
  );

  List<Map<String, dynamic>> history() => <Map<String, dynamic>>[
        <String, dynamic>{
          'car_id': 1,
          'date': fmt.format(DateTime.now().subtract(const Duration(days: 20))),
          'total_mileage': 500,
          'fuel_used': 47,
          'refuel': 47,
          'city_mileage': 300,
          'highway_mileage': 200,
          'base_city_norm': 10.0,
          'base_highway_norm': 8.0,
        },
        <String, dynamic>{
          'car_id': 1,
          'date': fmt.format(DateTime.now().subtract(const Duration(days: 5))),
          'total_mileage': 500,
          'fuel_used': 53,
          'refuel': 53,
          'city_mileage': 250,
          'highway_mileage': 250,
          'base_city_norm': 10.0,
          'base_highway_norm': 8.0,
        },
      ];

  Future<AppLocalizations> pumpPage(
    WidgetTester tester, {
    required List<Map<String, dynamic>> records,
    List<CarData> cars = const <CarData>[],
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Окно побольше: на 800x600 карточки аналитики уезжают за пределы ListView,
    // и часть виджетов просто не строится.
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnalyticsPage(history: records, cars: cars),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(AnalyticsPage)))!;
  }

  testWidgets('показывает средний расход, отклонение от нормы и прогноз',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        await pumpPage(tester, records: history(), cars: <CarData>[car]);

    expect(find.text(l10n.analytics_title), findsOneWidget);
    expect(find.text(l10n.analytics_summary), findsOneWidget);
    expect(find.text(l10n.analytics_forecast), findsOneWidget);
    expect(find.text(l10n.analytics_share_report), findsOneWidget);
    // средний расход 100 л на 1000 км = 10 л/100 км
    expect(find.textContaining('10,0 ${l10n.liters_per_100km}'), findsWidgets);
    // по умолчанию считаются все автомобили
    expect(find.text(l10n.analytics_all_cars), findsOneWidget);

    // выбор конкретного авто в фильтре подставляется в расчёт
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toyota Camry 123ABC01').last);
    await tester.pumpAndSettle();
    expect(find.text('Toyota Camry 123ABC01'), findsOneWidget);
  });

  testWidgets('без цены литра стоимость не показывается, с ценой — показывается',
      (WidgetTester tester) async {
    final AppLocalizations l10n =
        await pumpPage(tester, records: history(), cars: <CarData>[car]);
    expect(find.text(l10n.analytics_cost), findsNothing);

    await tester.enterText(find.byType(TextField), '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(l10n.analytics_cost), findsOneWidget);
    expect(find.text(l10n.analytics_cost_per_km), findsOneWidget);
  });

  testWidgets('без записей объясняет, что данных мало', (WidgetTester tester) async {
    final AppLocalizations l10n = await pumpPage(tester, records: const []);

    expect(find.text(l10n.analytics_no_data), findsOneWidget);
    expect(find.text(l10n.analytics_share_report), findsNothing);
  });
}
