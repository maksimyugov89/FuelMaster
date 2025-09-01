import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class TextUtils {
  static double roundToTwoDecimals(double value) {
    final intValue = (value * 1000).round();
    if (intValue % 10 >= 5) {
      return (intValue ~/ 10 + 1) / 100.0;
    }
    return (intValue ~/ 10) / 100.0;
  }

  static String formatJsonRecord(Map<String, dynamic> record, AppLocalizations l10n) {
    final List<String> formatted = [];
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    if (record['license_plate'] != null) {
      formatted.add('${l10n.license_plate}: ${record['license_plate']}');
    }

    if (record['date'] != null) {
      try {
        final date = dateFormat.parse(record['date'].toString());
        formatted.add('${l10n.date}: ${dateFormat.format(date)}');
      } catch (e) {
        formatted.add('${l10n.date}: ${record['date']}');
      }
    }

    if (record['brand'] != null) {
      formatted.add('${l10n.brand}: ${record['brand']}');
    }

    if (record['model'] != null) {
      formatted.add('${l10n.model}: ${record['model']}');
    }

    if (record['initial_mileage'] != null) {
      final value = double.tryParse(record['initial_mileage'].toString()) ?? 0.0;
      formatted.add('${l10n.initial_mileage}: ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}');
    }

    if (record['final_mileage'] != null) {
      final value = double.tryParse(record['final_mileage'].toString()) ?? 0.0;
      formatted.add('${l10n.final_mileage}: ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}');
    }

    if (record['total_mileage'] != null) {
      final value = double.tryParse(record['total_mileage'].toString()) ?? 0.0;
      formatted.add('${l10n.total_mileage}: ${value.toStringAsFixed(value.truncateToDouble() == value ? 1 : 2)}');
    }

    if (record['city_mileage'] != null) {
      final value = double.tryParse(record['city_mileage'].toString()) ?? 0.0;
      formatted.add('${l10n.city_mileage}: ${value.toStringAsFixed(value.truncateToDouble() == value ? 1 : 2)}');
    }

    if (record['highway_mileage'] != null) {
      final value = double.tryParse(record['highway_mileage'].toString()) ?? 0.0;
      formatted.add('${l10n.highway_mileage}: ${value.toStringAsFixed(value.truncateToDouble() == value ? 1 : 2)}');
    }

    if (record['initial_fuel'] != null) {
      final value = double.tryParse(record['initial_fuel'].toString()) ?? 0.0;
      final roundedValue = roundToTwoDecimals(value);
      formatted.add('${l10n.initial_fuel_short}: ${roundedValue.toStringAsFixed(roundedValue.truncateToDouble() == roundedValue ? 1 : 2)}');
    }

    if (record['refuel'] != null) {
      final value = double.tryParse(record['refuel'].toString()) ?? 0.0;
      final roundedValue = roundToTwoDecimals(value);
      formatted.add('${l10n.refuel_short}: ${roundedValue.toStringAsFixed(roundedValue.truncateToDouble() == roundedValue ? 1 : 2)}');
    }

    if (record['fuel_used'] != null) {
      final value = double.tryParse(record['fuel_used'].toString()) ?? 0.0;
      final roundedValue = roundToTwoDecimals(value);
      formatted.add('${l10n.fuel_used}: ${roundedValue.toStringAsFixed(2)}');
    }

    if (record['final_fuel'] != null) {
      final value = double.tryParse(record['final_fuel'].toString()) ?? 0.0;
      final roundedValue = roundToTwoDecimals(value);
      formatted.add('${l10n.final_fuel}: ${roundedValue.toStringAsFixed(2)}');
    }

    if (record['conditions'] != null && record['conditions'] is Map && (record['conditions'] as Map)['winter'] != null && (record['conditions'] as Map)['winter'] > 1.0) {
      if (record['weather_multiplier'] != null) {
        final value = double.tryParse(record['weather_multiplier'].toString()) ?? 0.0;
        final roundedValue = roundToTwoDecimals(value);
        formatted.add('${l10n.weather_multiplier}: ${roundedValue.toStringAsFixed(2)}');
      }
    }

    return formatted.join('\n');
  }
}