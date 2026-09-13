import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:fuelmaster/utils/consumption_analytics_service.dart';

/// D-2: расчёты аналитики расхода проверяются на синтетических данных,
/// чтобы UI оставался тонким, а математика — проверяемой.
void main() {
  final DateFormat fmt = DateFormat('dd.MM.yyyy HH:mm');

  Map<String, dynamic> record({
    required DateTime date,
    required double distance,
    required double fuelUsed,
    double refuel = 0,
    double city = 0,
    double highway = 0,
    double? cityNorm,
    double? highwayNorm,
    int carId = 1,
  }) {
    return <String, dynamic>{
      'car_id': carId,
      'date': fmt.format(date),
      'total_mileage': distance,
      'fuel_used': fuelUsed,
      'refuel': refuel,
      'city_mileage': city,
      'highway_mileage': highway,
      if (cityNorm != null) 'base_city_norm': cityNorm,
      if (highwayNorm != null) 'base_highway_norm': highwayNorm,
    };
  }

  group('FuelEntry', () {
    test('читает дату основного формата приложения', () {
      final FuelEntry? entry = FuelEntry.fromRecord(
        record(date: DateTime(2026, 9, 1, 8, 30), distance: 500, fuelUsed: 40),
      );
      expect(entry, isNotNull);
      expect(entry!.date, DateTime(2026, 9, 1, 8, 30));
      expect(entry.consumption, closeTo(8, 0.0001));
    });

    test('понимает ISO-дату из синхронизации', () {
      final FuelEntry? entry = FuelEntry.fromRecord(<String, dynamic>{
        'car_id': 1,
        'date': '2026-09-01T08:30:00.000',
        'total_mileage': 200,
        'fuel_used': 16,
        'refuel': 16,
      });
      expect(entry?.date, DateTime(2026, 9, 1, 8, 30));
    });

    test('отбрасывает нечитаемую дату и нулевой пробег', () {
      expect(
        FuelEntry.fromRecord(
          record(date: DateTime(2026, 9, 1), distance: 100, fuelUsed: 10)
            ..['date'] = 'не дата',
        ),
        isNull,
      );
      final List<FuelEntry> entries = FuelEntry.listFromRecords(<Map<String, dynamic>>[
        record(date: DateTime(2026, 9, 1), distance: 0, fuelUsed: 10),
      ]);
      expect(entries, isEmpty);
    });

    test('фильтрует по автомобилю и сортирует по дате', () {
      final List<FuelEntry> entries = FuelEntry.listFromRecords(
        <Map<String, dynamic>>[
          record(date: DateTime(2026, 9, 3), distance: 100, fuelUsed: 9, carId: 1),
          record(date: DateTime(2026, 9, 1), distance: 100, fuelUsed: 9, carId: 1),
          record(date: DateTime(2026, 9, 2), distance: 100, fuelUsed: 9, carId: 2),
        ],
        carId: 1,
      );
      expect(entries.length, 2);
      expect(entries.first.date, DateTime(2026, 9, 1));
      expect(entries.last.date, DateTime(2026, 9, 3));
    });

    test('норма взвешивается по пробегу города и трассы', () {
      final FuelEntry entry = FuelEntry.fromRecord(
        record(
          date: DateTime(2026, 9, 1),
          distance: 200,
          fuelUsed: 18,
          city: 50,
          highway: 150,
          cityNorm: 10,
          highwayNorm: 8,
        ),
      )!;
      // 50 км по городу (10 л/100) + 150 км по трассе (8 л/100).
      expect(entry.normConsumption, closeTo(10 * 0.25 + 8 * 0.75, 0.0001));
    });
  });

  group('ConsumptionStats', () {
    final List<FuelEntry> entries = <FuelEntry>[
      FuelEntry.fromRecord(
        record(
          date: DateTime(2026, 9, 1),
          distance: 100,
          fuelUsed: 10,
          city: 100,
          cityNorm: 10,
          highwayNorm: 8,
        ),
      )!,
      FuelEntry.fromRecord(
        record(
          date: DateTime(2026, 9, 5),
          distance: 100,
          fuelUsed: 9,
          highway: 100,
          cityNorm: 10,
          highwayNorm: 8,
        ),
      )!,
    ];

    test('средний расход — по топливу и пробегу, а не по среднему записей', () {
      final ConsumptionStats stats = ConsumptionStats.fromEntries(entries);
      expect(stats.entries, 2);
      expect(stats.distance, 200);
      expect(stats.fuelUsed, 19);
      expect(stats.avgConsumption, closeTo(9.5, 0.0001));
    });

    test('норма периода взвешена по пробегу, отклонение считается в процентах', () {
      final ConsumptionStats stats = ConsumptionStats.fromEntries(entries);
      expect(stats.normPer100, closeTo(9, 0.0001));
      expect(stats.deviationPercent, closeTo(5.5556, 0.001));
    });

    test('стоимость и стоимость километра появляются только с ценой литра', () {
      final ConsumptionStats withoutPrice = ConsumptionStats.fromEntries(entries);
      expect(withoutPrice.cost, isNull);
      expect(withoutPrice.costPerKm, isNull);

      final ConsumptionStats withPrice =
          ConsumptionStats.fromEntries(entries, pricePerLiter: 500);
      expect(withPrice.cost, closeTo(9500, 0.0001));
      expect(withPrice.costPerKm, closeTo(47.5, 0.0001));
    });

    test('доля города и средние значения считаются корректно', () {
      final ConsumptionStats stats = ConsumptionStats.fromEntries(entries);
      expect(stats.cityShare, closeTo(0.5, 0.0001));
      expect(stats.avgDistancePerEntry, closeTo(100, 0.0001));
    });

    test('пустой набор не даёт деления на ноль', () {
      final ConsumptionStats stats = ConsumptionStats.fromEntries(<FuelEntry>[]);
      expect(stats.isEmpty, isTrue);
      expect(stats.avgConsumption, 0);
      expect(stats.deviationPercent, isNull);
      expect(stats.cityShare, 0);
    });
  });

  group('ConsumptionTrend', () {
    List<FuelEntry> series(List<double> consumptions) {
      final List<FuelEntry> entries = <FuelEntry>[];
      for (int i = 0; i < consumptions.length; i++) {
        final double fuel = consumptions[i];
        entries.add(
          FuelEntry.fromRecord(
            record(
              date: DateTime(2026, 9, 1).add(Duration(days: i * 7)),
              distance: 100,
              fuelUsed: fuel,
            ),
          )!,
        );
      }
      return entries;
    }

    test('растущий расход даёт положительный наклон', () {
      final ConsumptionTrend trend =
          ConsumptionTrend.fromEntries(series(<double>[10, 11, 12, 13]));
      expect(trend.isKnown, isTrue);
      expect(trend.direction, TrendDirection.rising);
      expect(trend.slopePerMonth, closeTo(4.2857, 0.01));
    });

    test('падающий расход даёт отрицательный наклон', () {
      final ConsumptionTrend trend =
          ConsumptionTrend.fromEntries(series(<double>[13, 12, 11, 10]));
      expect(trend.direction, TrendDirection.falling);
      expect(trend.slopePerMonth, lessThan(0));
    });

    test('ровный расход — стабильно', () {
      final ConsumptionTrend trend =
          ConsumptionTrend.fromEntries(series(<double>[10, 10, 10, 10]));
      expect(trend.direction, TrendDirection.stable);
    });

    test('меньше трёх записей — тренд не считается', () {
      expect(ConsumptionTrend.fromEntries(series(<double>[10, 12])).isKnown, isFalse);
    });
  });

  group('ConsumptionForecast', () {
    test('месячный прогноз — средний дневной пробег на 30 дней', () {
      final List<Map<String, dynamic>> records = <Map<String, dynamic>>[
        record(
          date: DateTime(2026, 8, 1),
          distance: 500,
          fuelUsed: 50,
          refuel: 50,
        ),
        record(
          date: DateTime(2026, 8, 16),
          distance: 500,
          fuelUsed: 50,
          refuel: 50,
        ),
        record(
          date: DateTime(2026, 8, 31),
          distance: 500,
          fuelUsed: 50,
          refuel: 50,
        ),
      ];
      final ConsumptionForecast forecast = ConsumptionForecast.build(
        FuelEntry.listFromRecords(records),
        pricePerLiter: 500,
        now: DateTime(2026, 9, 13),
      );

      expect(forecast.dailyDistance, closeTo(50, 0.001));
      expect(forecast.monthlyDistance, closeTo(1500, 0.001));
      expect(forecast.monthlyFuel, closeTo(150, 0.001));
      expect(forecast.monthlyCost, closeTo(75000, 0.001));
      expect(forecast.averageRefuelVolume, closeTo(50, 0.001));
    });

    test('без записей прогноза нет', () {
      final ConsumptionForecast forecast =
          ConsumptionForecast.build(<FuelEntry>[]);
      expect(forecast.hasData, isFalse);
      expect(forecast.monthlyDistance, isNull);
    });

    test('одна запись: охват берётся от даты записи до «сегодня»', () {
      final ConsumptionForecast forecast = ConsumptionForecast.build(
        FuelEntry.listFromRecords(<Map<String, dynamic>>[
          record(date: DateTime(2026, 9, 1), distance: 300, fuelUsed: 30),
        ]),
        now: DateTime(2026, 9, 11),
      );
      expect(forecast.dailyDistance, closeTo(30, 0.001));
      expect(forecast.monthlyDistance, closeTo(900, 0.001));
    });
  });

  group('PeriodComparison', () {
    final List<FuelEntry> entries = FuelEntry.listFromRecords(<Map<String, dynamic>>[
      // последние 30 дней
      record(date: DateTime(2026, 9, 1), distance: 400, fuelUsed: 40),
      record(date: DateTime(2026, 9, 10), distance: 400, fuelUsed: 44),
      // предыдущие 30 дней
      record(date: DateTime(2026, 8, 1), distance: 500, fuelUsed: 50),
      // старше двух периодов — не учитывается
      record(date: DateTime(2026, 6, 1), distance: 100, fuelUsed: 20),
    ]);

    test('делит записи на текущий и предыдущий периоды', () {
      final PeriodComparison comparison = PeriodComparison.splitByDays(
        entries,
        days: 30,
        now: DateTime(2026, 9, 15),
      );
      expect(comparison.current.entries, 2);
      expect(comparison.previous.entries, 1);
      expect(comparison.hasPrevious, isTrue);
      expect(comparison.current.avgConsumption, closeTo(10.5, 0.0001));
      expect(comparison.previous.avgConsumption, closeTo(10, 0.0001));
      expect(comparison.consumptionDeltaPercent, closeTo(5, 0.0001));
      expect(comparison.distanceDeltaPercent, closeTo(60, 0.0001));
    });

    test('стоимость сравнивается только при известной цене', () {
      final PeriodComparison comparison = PeriodComparison.splitByDays(
        entries,
        days: 30,
        now: DateTime(2026, 9, 15),
      );
      expect(comparison.costDeltaPercent, isNull);

      final PeriodComparison withPrice = PeriodComparison.splitByDays(
        entries,
        days: 30,
        now: DateTime(2026, 9, 15),
        pricePerLiter: 500,
      );
      expect(withPrice.costDeltaPercent, closeTo(68, 0.001));
    });

    test('без предыдущего периода процент не выдумывается', () {
      final PeriodComparison comparison = PeriodComparison.splitByDays(
        FuelEntry.listFromRecords(<Map<String, dynamic>>[
          record(date: DateTime(2026, 9, 10), distance: 100, fuelUsed: 10),
        ]),
        days: 30,
        now: DateTime(2026, 9, 15),
      );
      expect(comparison.hasPrevious, isFalse);
      expect(comparison.consumptionDeltaPercent, isNull);
    });
  });

  test('средний расход последних записей', () {
    final List<FuelEntry> entries = FuelEntry.listFromRecords(<Map<String, dynamic>>[
      record(date: DateTime(2026, 9, 1), distance: 100, fuelUsed: 12),
      record(date: DateTime(2026, 9, 2), distance: 100, fuelUsed: 10),
      record(date: DateTime(2026, 9, 3), distance: 100, fuelUsed: 8),
    ]);
    expect(averageConsumptionOfLast(entries, 2), closeTo(9, 0.0001));
    expect(averageConsumptionOfLast(entries, 10), closeTo(10, 0.0001));
    expect(averageConsumptionOfLast(<FuelEntry>[], 2), isNull);
  });
}
