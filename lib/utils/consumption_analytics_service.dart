import 'dart:math' as math;

import 'package:intl/intl.dart';

/// D-2: аналитика расхода топлива.
///
/// Слой сознательно не знает ни о Flutter, ни о базе: на вход приходят строки
/// таблицы `fuel_logs` в том виде, в каком их отдаёт sqflite, на выходе — числа.
/// Поэтому вся математика покрыта обычными unit-тестами, а экран остаётся
/// тонким и занимается только оформлением.
///
/// Термины:
///  * расход — л на 100 км (fuel_used / total_mileage * 100);
///  * норма — паспортная норма из карточки авто (base_city_norm/base_highway_norm),
///    средневзвешенная по фактическому пробегу города и трассы.
class FuelEntry {
  FuelEntry({
    required this.date,
    required this.distance,
    required this.fuelUsed,
    required this.refueled,
    this.cityDistance = 0,
    this.highwayDistance = 0,
    this.cityNorm,
    this.highwayNorm,
  });

  final DateTime date;

  /// Пробег записи (total_mileage), км.
  final double distance;

  /// Израсходовано топлива (fuel_used), л.
  final double fuelUsed;

  /// Залито топлива (refuel), л.
  final double refueled;

  final double cityDistance;
  final double highwayDistance;

  /// Паспортная норма города/трассы, л/100 км.
  final double? cityNorm;
  final double? highwayNorm;

  /// Запись пригодна для расчётов: есть пробег и расход.
  bool get isValid => distance > 0 && fuelUsed > 0;

  /// Фактический расход записи, л/100 км.
  double get consumption => distance > 0 ? fuelUsed / distance * 100 : 0;

  /// Норма, средневзвешенная по пробегу города и трассы, л/100 км.
  double? get normConsumption {
    final double? city = (cityNorm != null && cityNorm! > 0) ? cityNorm : null;
    final double? highway =
        (highwayNorm != null && highwayNorm! > 0) ? highwayNorm : null;
    if (city == null && highway == null) return null;

    final double cityKm = cityDistance;
    final double highwayKm = highwayDistance;
    final double total = cityKm + highwayKm;

    if (total > 0 && city != null && highway != null) {
      return (cityKm / total) * city + (highwayKm / total) * highway;
    }
    // Нет разбивки по типам дорог — берём то, что известно.
    return city ?? highway;
  }

  static final DateFormat _mainFormat = DateFormat('dd.MM.yyyy HH:mm');

  /// Разбирает дату записи. Основной формат приложения —
  /// `dd.MM.yyyy HH:mm`; ISO-строки из синхронизации тоже понимаем.
  static DateTime? parseDate(Object? raw) {
    if (raw == null) return null;
    final String value = raw.toString().trim();
    if (value.isEmpty) return null;
    try {
      return _mainFormat.parseStrict(value);
    } on FormatException {
      // не наш формат — пробуем ISO
    }
    return DateTime.tryParse(value);
  }

  static double _toDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return 0;
    return double.tryParse(raw.toString().replaceAll(',', '.')) ?? 0;
  }

  /// Собирает запись из строки `fuel_logs`. Возвращает null, если дата
  /// нечитаемая — такую строку учитывать нельзя.
  static FuelEntry? fromRecord(Map<String, dynamic> record) {
    final DateTime? date = parseDate(record['date']);
    if (date == null) return null;

    final double? cityNorm = record['base_city_norm'] == null
        ? null
        : _toDouble(record['base_city_norm']);
    final double? highwayNorm = record['base_highway_norm'] == null
        ? null
        : _toDouble(record['base_highway_norm']);

    return FuelEntry(
      date: date,
      distance: _toDouble(record['total_mileage']),
      fuelUsed: _toDouble(record['fuel_used']),
      refueled: _toDouble(record['refuel']),
      cityDistance: _toDouble(record['city_mileage']),
      highwayDistance: _toDouble(record['highway_mileage']),
      cityNorm: cityNorm,
      highwayNorm: highwayNorm,
    );
  }

  /// Все пригодные записи, по возрастанию даты. Если задан [carId],
  /// учитываются только записи этого автомобиля.
  static List<FuelEntry> listFromRecords(
    Iterable<Map<String, dynamic>> records, {
    int? carId,
  }) {
    final List<FuelEntry> entries = <FuelEntry>[];
    for (final Map<String, dynamic> record in records) {
      if (carId != null && record['car_id'] != carId) continue;
      final FuelEntry? entry = fromRecord(record);
      if (entry == null || !entry.isValid) continue;
      entries.add(entry);
    }
    entries.sort((FuelEntry a, FuelEntry b) => a.date.compareTo(b.date));
    return entries;
  }
}

/// Сводка по набору записей за период.
class ConsumptionStats {
  const ConsumptionStats({
    required this.entries,
    required this.distance,
    required this.fuelUsed,
    required this.refueled,
    required this.cityDistance,
    required this.highwayDistance,
    required this.normPer100,
    this.pricePerLiter,
  });

  static const ConsumptionStats empty = ConsumptionStats(
    entries: 0,
    distance: 0,
    fuelUsed: 0,
    refueled: 0,
    cityDistance: 0,
    highwayDistance: 0,
    normPer100: null,
  );

  final int entries;
  final double distance;
  final double fuelUsed;
  final double refueled;
  final double cityDistance;
  final double highwayDistance;

  /// Средневзвешенная паспортная норма, л/100 км (null — если норм нет).
  final double? normPer100;

  /// Цена литра, если пользователь её указал.
  final double? pricePerLiter;

  bool get isEmpty => entries == 0;

  /// Фактический расход за период, л/100 км.
  double get avgConsumption => distance > 0 ? fuelUsed / distance * 100 : 0;

  /// Отклонение от нормы, %. Положительное — расход выше нормы (хуже).
  double? get deviationPercent {
    final double? norm = normPer100;
    if (norm == null || norm <= 0 || distance <= 0) return null;
    return (avgConsumption - norm) / norm * 100;
  }

  /// Доля городского пробега, 0..1. Косвенно описывает стиль эксплуатации.
  double get cityShare {
    final double total = cityDistance + highwayDistance;
    return total > 0 ? cityDistance / total : 0;
  }

  /// Средний пробег одной записи, км.
  double get avgDistancePerEntry => entries > 0 ? distance / entries : 0;

  /// Средний объём одной заправки, л.
  double get avgRefuelVolume => entries > 0 ? refueled / entries : 0;

  /// Стоимость израсходованного топлива, если известна цена литра.
  double? get cost =>
      pricePerLiter == null ? null : fuelUsed * pricePerLiter!;

  /// Стоимость километра, если известна цена литра.
  double? get costPerKm =>
      (cost == null || distance <= 0) ? null : cost! / distance;

  /// Расход конкретного среза записей.
  static ConsumptionStats fromEntries(
    Iterable<FuelEntry> source, {
    double? pricePerLiter,
  }) {
    double distance = 0;
    double fuelUsed = 0;
    double refueled = 0;
    double cityDistance = 0;
    double highwayDistance = 0;
    double normSum = 0;
    double normWeight = 0;
    int entries = 0;

    for (final FuelEntry entry in source) {
      entries++;
      distance += entry.distance;
      fuelUsed += entry.fuelUsed;
      refueled += entry.refueled;
      cityDistance += entry.cityDistance;
      highwayDistance += entry.highwayDistance;

      final double? norm = entry.normConsumption;
      if (norm != null) {
        normSum += norm * entry.distance;
        normWeight += entry.distance;
      }
    }

    return ConsumptionStats(
      entries: entries,
      distance: distance,
      fuelUsed: fuelUsed,
      refueled: refueled,
      cityDistance: cityDistance,
      highwayDistance: highwayDistance,
      normPer100: normWeight > 0 ? normSum / normWeight : null,
      pricePerLiter: pricePerLiter,
    );
  }
}

/// Направление изменения расхода.
enum TrendDirection { rising, falling, stable }

/// Тренд расхода: насколько л/100 км меняется за месяц.
class ConsumptionTrend {
  const ConsumptionTrend({
    required this.slopePerMonth,
    required this.direction,
    required this.entries,
  });

  static const ConsumptionTrend unknown =
      ConsumptionTrend(slopePerMonth: 0, direction: TrendDirection.stable, entries: 0);

  /// Изменение расхода, л/100 км в месяц (метод наименьших квадратов).
  final double slopePerMonth;
  final TrendDirection direction;
  final int entries;

  bool get isKnown => entries >= 3;

  /// Считает тренд по записям (нужно минимум 3 записи, иначе он не значим).
  static ConsumptionTrend fromEntries(Iterable<FuelEntry> source) {
    final List<FuelEntry> entries = source.toList()
      ..sort((FuelEntry a, FuelEntry b) => a.date.compareTo(b.date));
    if (entries.length < 3) return unknown;

    final DateTime first = entries.first.date;
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumXX = 0;

    for (final FuelEntry entry in entries) {
      final double x = entry.date.difference(first).inMinutes / (60 * 24);
      final double y = entry.consumption;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final int n = entries.length;
    final double denominator = n * sumXX - sumX * sumX;
    if (denominator == 0) return unknown;

    final double slopePerDay = (n * sumXY - sumX * sumY) / denominator;
    final double slopePerMonth = slopePerDay * 30;

    // Порог значимости: меньше 0.1 л/100 км в месяц считаем «стабильно».
    TrendDirection direction = TrendDirection.stable;
    if (slopePerMonth > 0.1) {
      direction = TrendDirection.rising;
    } else if (slopePerMonth < -0.1) {
      direction = TrendDirection.falling;
    }

    return ConsumptionTrend(
      slopePerMonth: slopePerMonth,
      direction: direction,
      entries: n,
    );
  }
}

/// Прогноз на месяц вперёд по фактическому режиму эксплуатации.
class ConsumptionForecast {
  const ConsumptionForecast({
    required this.monthlyDistance,
    required this.monthlyFuel,
    required this.monthlyCost,
    required this.dailyDistance,
    required this.averageRefuelVolume,
    required this.trend,
  });

  final double? monthlyDistance;
  final double? monthlyFuel;
  final double? monthlyCost;
  final double dailyDistance;
  final double averageRefuelVolume;
  final ConsumptionTrend trend;

  bool get hasData => monthlyDistance != null;

  /// Прогноз по записям за период.
  ///
  /// Средний дневной пробег считается по календарному охвату записей
  /// (от первой до последней), а не по числу записей: так «месяц» получается
  /// сопоставимым для любого ритма заправок.
  static ConsumptionForecast build(
    Iterable<FuelEntry> source, {
    double? pricePerLiter,
    DateTime? now,
  }) {
    final List<FuelEntry> entries = source.toList()
      ..sort((FuelEntry a, FuelEntry b) => a.date.compareTo(b.date));
    if (entries.isEmpty) {
      return const ConsumptionForecast(
        monthlyDistance: null,
        monthlyFuel: null,
        monthlyCost: null,
        dailyDistance: 0,
        averageRefuelVolume: 0,
        trend: ConsumptionTrend.unknown,
      );
    }

    final ConsumptionStats stats = ConsumptionStats.fromEntries(
      entries,
      pricePerLiter: pricePerLiter,
    );

    final DateTime reference = now ?? DateTime.now();
    final DateTime first = entries.first.date;
    final DateTime last = entries.last.date;
    int spanDays = last.difference(first).inDays;
    if (spanDays <= 0) {
      // Все записи одного дня — считаем охватом один день.
      final int byClock = reference.difference(first).inDays;
      spanDays = byClock > 0 ? byClock : 1;
    }

    final double dailyDistance = stats.distance / spanDays;
    final double monthlyDistance = dailyDistance * 30;
    final double consumption = stats.avgConsumption;
    final double monthlyFuel = monthlyDistance * consumption / 100;

    return ConsumptionForecast(
      monthlyDistance: monthlyDistance,
      monthlyFuel: monthlyFuel,
      monthlyCost: pricePerLiter == null ? null : monthlyFuel * pricePerLiter,
      dailyDistance: dailyDistance,
      averageRefuelVolume: stats.avgRefuelVolume,
      trend: ConsumptionTrend.fromEntries(entries),
    );
  }
}

/// Сравнение двух соседних периодов одинаковой длины.
class PeriodComparison {
  const PeriodComparison({
    required this.current,
    required this.previous,
    required this.periodDays,
  });

  final ConsumptionStats current;
  final ConsumptionStats previous;
  final int periodDays;

  bool get hasPrevious => previous.entries > 0;

  /// Изменение среднего расхода, % (положительное — расход вырос).
  double? get consumptionDeltaPercent =>
      _deltaPercent(current.avgConsumption, previous.avgConsumption);

  /// Изменение пробега, %.
  double? get distanceDeltaPercent =>
      _deltaPercent(current.distance, previous.distance);

  /// Изменение стоимости, %.
  double? get costDeltaPercent {
    final double? a = current.cost;
    final double? b = previous.cost;
    if (a == null || b == null) return null;
    return _deltaPercent(a, b);
  }

  static double? _deltaPercent(double current, double previous) {
    if (previous <= 0) return null;
    return (current - previous) / previous * 100;
  }

  /// Делит записи на «последние [days] дней» и «предыдущие [days] дней».
  static PeriodComparison splitByDays(
    Iterable<FuelEntry> source, {
    required int days,
    DateTime? now,
    double? pricePerLiter,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime currentFrom = reference.subtract(Duration(days: days));
    final DateTime previousFrom = currentFrom.subtract(Duration(days: days));

    final List<FuelEntry> all = source.toList();
    final List<FuelEntry> current = <FuelEntry>[];
    final List<FuelEntry> previous = <FuelEntry>[];

    for (final FuelEntry entry in all) {
      if (entry.date.isAfter(currentFrom)) {
        current.add(entry);
      } else if (entry.date.isAfter(previousFrom)) {
        previous.add(entry);
      }
    }

    return PeriodComparison(
      current: ConsumptionStats.fromEntries(current, pricePerLiter: pricePerLiter),
      previous: ConsumptionStats.fromEntries(previous, pricePerLiter: pricePerLiter),
      periodDays: days,
    );
  }
}

/// Средний расход по «последним N записям» — нужен, чтобы показать свежий
/// расход, не привязываясь к календарю.
double? averageConsumptionOfLast(Iterable<FuelEntry> source, int count) {
  final List<FuelEntry> entries = source.toList();
  if (entries.isEmpty) return null;
  final int from = math.max(0, entries.length - count);
  final ConsumptionStats stats =
      ConsumptionStats.fromEntries(entries.sublist(from));
  return stats.entries > 0 ? stats.avgConsumption : null;
}
