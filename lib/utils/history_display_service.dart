import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/utils.dart';
import 'package:collection/collection.dart';

class HistoryDisplayService {
  final List<Map<String, dynamic>> history;
  final List<CarData> cars;
  final String? selectedModel;
  final DateTime? startDate;
  final DateTime? endDate;
  final AppLocalizations l10n;

  HistoryDisplayService({
    required this.history,
    required this.cars,
    required this.selectedModel,
    required this.startDate,
    required this.endDate,
    required this.l10n,
  });

  String formatCarDisplayNameForCar(CarData car) {
    final brand = car.brand;
    final licensePlate = car.licensePlate ?? '';
    final model = car.model;
    final modelParts = RegExp(r'[^\d\s]+').allMatches(model);
    final modelDisplay = modelParts.isNotEmpty
        ? modelParts.map((match) => match.group(0)).join(' ')
        : model;
    return '$brand $licensePlate $modelDisplay'.trim();
  }

  List<String> formatHistoryRecord(Map<String, dynamic> record) {
    final car = cars.firstWhereOrNull((c) => c.id == record['car_id']);

    final List<String> formatted = [
      '${l10n.history_label_date}: ${record['date'] ?? ''}',
      '${l10n.brand}: ${car?.brand ?? ''}',
      '${l10n.model}: ${car?.model ?? ''}',
      '${l10n.license_plate}: ${car?.licensePlate ?? l10n.no}',
      '${l10n.history_label_initial_mileage}: ${record['initial_mileage']?.toString() ?? '0'} ${l10n.kilometers}',
      '${l10n.history_label_final_mileage}: ${record['final_mileage']?.toString() ?? '0'} ${l10n.kilometers}',
      '${l10n.history_label_total_mileage}: ${record['total_mileage']?.toStringAsFixed(1) ?? '0.0'} ${l10n.kilometers}',
      '${l10n.history_label_city_mileage}: ${record['city_mileage']?.toStringAsFixed(1) ?? '0.0'} ${l10n.kilometers}',
      '${l10n.history_label_highway_mileage}: ${record['highway_mileage']?.toStringAsFixed(1) ?? '0.0'} ${l10n.kilometers}',
    ];

    // ✨ FIX: Отображаем все нормы расхода для всех типов ТС.
    final cityNorm = record['base_city_norm'] as num? ?? car?.baseCityNorm ?? 0.0;
    final highwayNorm = record['base_highway_norm'] as num? ?? car?.baseHighwayNorm ?? 0.0;
    final combinedNorm = (cityNorm + highwayNorm) / 2;

    if (cityNorm > 0) {
      formatted.add('${l10n.history_label_city_norm}: ${cityNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}');
    }
    if (highwayNorm > 0) {
      formatted.add('${l10n.history_label_highway_norm}: ${highwayNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}');
    }
    if (combinedNorm > 0) {
        formatted.add('${l10n.combined_norm}: ${combinedNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}');
    }

    formatted.addAll([
      '${l10n.history_label_initial_fuel}: ${record['initial_fuel']?.toStringAsFixed(2) ?? '0.00'} ${l10n.liters}',
      '${l10n.history_label_refuel}: ${record['refuel']?.toStringAsFixed(2) ?? '0.00'} ${l10n.liters}',
      '${l10n.history_label_fuel_used}: ${record['fuel_used']?.toStringAsFixed(2) ?? '0.00'} ${l10n.liters}',
      '${l10n.history_label_final_fuel}: ${record['final_fuel']?.toStringAsFixed(2) ?? '0.00'} ${l10n.liters}',
    ]);
    final correctionFactor = record['correction_factor'];
    if (correctionFactor != null && correctionFactor > 0) {
        formatted.add('${l10n.correction_factor}: ${correctionFactor.toStringAsFixed(2)} %');
    }
    final heaterTime = record['heater_operating_time'];
    if (heaterTime != null && heaterTime > 0) {
        formatted.add('${l10n.heater_operating_time}: ${heaterTime.toStringAsFixed(2)} ч');
    }
    final heaterFuel = record['heater_fuel_used'];
    if (heaterFuel != null && heaterFuel > 0) {
        String heaterLabel = l10n.localeName == 'ru' ? 'Расход отопителем' : 'Heater Fuel';
        formatted.add('$heaterLabel: ${heaterFuel.toStringAsFixed(2)} ${l10n.liters}');
    }
    final conditions = record['conditions'] as Map<String, dynamic>?;
    if (conditions != null) {
      List<String> appliedConditions = [];
      if (conditions['winter'] != null && conditions['winter'] > 1.0) {
        appliedConditions.add(l10n.condition_winter);
      }
      if (conditions['ac'] != null && conditions['ac'] > 1.0) {
        appliedConditions.add(l10n.condition_ac);
      }
      if (conditions['mountain'] != null && conditions['mountain'] > 1.0) {
        appliedConditions.add(l10n.condition_mountain);
      }
      if(appliedConditions.isNotEmpty) {
        formatted.add('${l10n.adjustments}: ${appliedConditions.join(', ')}');
      }
    }

    return formatted;
  }

  List<Map<String, dynamic>> getFilteredHistory() {
    logger.d('Фильтрация истории для $selectedModel с датами $startDate - $endDate');
    try {
      return history.where((record) {
        final carId = record['car_id'] as int?;
        final selectedId = selectedModel != null && selectedModel != 'all' ? int.tryParse(selectedModel!) : null;
        final matchCar = selectedId == null || carId == selectedId;
        if (!matchCar) return false;

        return _isWithinDateRange(record);
      }).toList();
    } catch (e) {
      logger.e('Ошибка фильтрации истории: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> getDateFilteredHistory() {
    return history.where((record) => _isWithinDateRange(record)).toList();
  }

  bool _isWithinDateRange(Map<String, dynamic> record) {
    if (startDate == null && endDate == null) return true;
    try {
      final dateStr = record['date']?.toString();
      if (dateStr == null) {
        logger.d('Нет даты в записи: $record');
        return false;
      }
      final date = DateFormat('dd.MM.yyyy HH:mm').parse(dateStr);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startDateOnly = startDate != null ? DateTime(startDate!.year, startDate!.month, startDate!.day) : null;
      final endDateOnly = endDate != null ? DateTime(endDate!.year, endDate!.month, endDate!.day) : null;
      final isWithin = (startDateOnly == null || !dateOnly.isBefore(startDateOnly)) &&
          (endDateOnly == null || !dateOnly.isAfter(endDateOnly));
      logger.d('Дата: $dateOnly, В пределах диапазона: $isWithin');
      return isWithin;
    } catch (e) {
      logger.e('Ошибка парсинга даты: $record, ошибка: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> getChartData() {
    final filteredHistory = getFilteredHistory();
    filteredHistory.sort((a, b) => DateFormat('dd.MM.yyyy HH:mm').parse(a['date']).compareTo(DateFormat('dd.MM.yyyy HH:mm').parse(b['date'])));
    final List<Map<String, dynamic>> chartData = [];
    for (var i = 0; i < filteredHistory.length; i++) {
      final record = filteredHistory[i];
      try {
        final dateStr = record['date']?.toString();
        final fuelUsed = record['fuel_used']?.toString();
        if (dateStr != null && fuelUsed != null) {
          final parsedDate = DateFormat('dd.MM.yyyy HH:mm').parse(dateStr);
          final label = (i > 0 && DateFormat('dd.MM.yyyy').format(parsedDate) == DateFormat('dd.MM.yyyy').format(DateFormat('dd.MM.yyyy HH:mm').parse(filteredHistory[i - 1]['date'])))
              ? DateFormat('HH:mm').format(parsedDate)
              : DateFormat('dd.MM').format(parsedDate);
          final fuelValue = double.tryParse(fuelUsed) ?? 0.0;
          final roundedFuelValue = TextUtils.roundToTwoDecimals(fuelValue);
          chartData.add({
            'index': i.toDouble(),
            'fuelUsed': roundedFuelValue,
            'date': label,
          });
        }
      } catch (e) {
        logger.e('Ошибка парсинга данных графика: $record, ошибка: $e');
      }
    }
    return chartData;
  }

    List<FlSpot> getChartSpots() {
    final filtered = getFilteredHistory();
    if (filtered.isEmpty) {
      return [];
    }

    final recordsForChart = filtered.take(50).toList().reversed.toList(); // Переворачиваем, чтобы даты шли от старых к новым

    return recordsForChart.map((record) {
      try {
        // 1. Превращаем строку с датой в объект DateTime
        final date = DateFormat('dd.MM.yyyy HH:mm').parse(record['date']);
        // 2. Получаем timestamp (миллисекунды с 1970 года) - это будет наша ось X
        final timestamp = date.millisecondsSinceEpoch.toDouble();
        // 3. Расход топлива - это наша ось Y
        final fuelUsed = (record['fuel_used'] as num?)?.toDouble() ?? 0.0;
        
        return FlSpot(timestamp, fuelUsed);
      } catch (e) {
        // Если дата в неверном формате, пропускаем эту точку
        return null;
      }
    }).whereType<FlSpot>().toList(); // Отфильтровываем пропущенные точки
  }
}