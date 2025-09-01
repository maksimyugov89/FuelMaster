import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/utils.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/history_manager.dart';

class FuelCalculationService {
  final BuildContext context;
  final CarData car;
  final List<Map<String, dynamic>> localHistory;
  final TextEditingController initialMileageController;
  final TextEditingController finalMileageController;
  final TextEditingController highwayKmController;
  final TextEditingController initialFuelController;
  final TextEditingController refuelController;
  final TextEditingController correctionFactorController;
  final TextEditingController heaterOperatingTimeController;
  final Function(Map<String, dynamic>? record, bool calculationDone) onCalculationComplete;

  FuelCalculationService({
    required this.context,
    required this.car,
    required this.localHistory,
    required this.initialMileageController,
    required this.finalMileageController,
    required this.highwayKmController,
    required this.initialFuelController,
    required this.refuelController,
    required this.correctionFactorController,
    required this.heaterOperatingTimeController,
    required this.onCalculationComplete,
  });

  bool _isDuplicateRecord(Map<String, dynamic> newRecord, List<Map<String, dynamic>> history) {
    return history.any((record) =>
        record['car_id'] == newRecord['car_id'] &&
        record['initial_mileage'] == newRecord['initial_mileage'] &&
        record['final_mileage'] == newRecord['final_mileage'] &&
        record['initial_fuel'] == newRecord['initial_fuel'] &&
        record['refuel'] == newRecord['refuel']);
  }

  Future<Map<String, dynamic>?> prepareCalculationRecord({
    required double totalMileage,
    required bool isWinter,
    required bool isAC,
    required bool isMountain,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    double initialMileage = double.tryParse(initialMileageController.text.trim().replaceAll(',', '.')) ?? 0;
    double finalMileage = double.tryParse(finalMileageController.text.trim().replaceAll(',', '.')) ?? 0;
    double highwayKm = double.tryParse(highwayKmController.text.trim().replaceAll(',', '.')) ?? 0;
    double initialFuel = double.tryParse(initialFuelController.text.trim().replaceAll(',', '.')) ?? 0;
    double refuel = double.tryParse(refuelController.text.trim().replaceAll(',', '.')) ?? 0;
    double correctionFactor = double.tryParse(correctionFactorController.text.trim().replaceAll(',', '.')) ?? 0;
    double heaterOperatingTime = double.tryParse(heaterOperatingTimeController.text.trim().replaceAll(',', '.')) ?? 0;
    
    double baseCityNorm = car.baseCityNorm;
    double baseHighwayNorm = car.baseHighwayNorm;
    double heaterFuelConsumptionRate = (car.vehicleType == 'Bus' && car.heaterFuelConsumption != null) ? car.heaterFuelConsumption! : 0.0;


    if (baseCityNorm <= 0 || baseHighwayNorm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.positive_norm)));
      return null;
    }

    if (finalMileage > 0 && finalMileage <= initialMileage) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.final_mileage_greater)));
      return null;
    }
    
    if (initialMileage == 0 && finalMileage == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.initial_mileage)));
        return null;
    }


    if (totalMileage <= 0) {
      // Это условие может быть ложным, если finalMileage > initialMileage, поэтому добавим проверку
      if(finalMileage > initialMileage) {
        // Все в порядке, totalMileage должен быть положительным
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.total_mileage)));
        return null;
      }
    }

    if (highwayKm > totalMileage) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.highway_not_exceed_total)));
      return null;
    }

    double cityNorm = baseCityNorm;
    double highwayNorm = baseHighwayNorm;
    
    if (isWinter) cityNorm *= 1.15;
    if (isAC) cityNorm *= 1.07;
    if (isMountain) cityNorm *= 1.20;

    if (correctionFactor != 0) { // Сработает и для положительных, и для отрицательных значений
      double factor = 1 + (correctionFactor / 100);
      cityNorm *= factor;
      highwayNorm *= factor;
    }

    double cityKm = totalMileage - highwayKm;
    double drivingFuelUsed = (cityKm / 100) * cityNorm + (highwayKm / 100) * highwayNorm;
    double heaterFuelUsed = heaterOperatingTime * heaterFuelConsumptionRate;
    double fuelUsed = drivingFuelUsed + heaterFuelUsed;

    double finalFuel = initialFuel + refuel - fuelUsed;

    final roundedFuelUsed = TextUtils.roundToTwoDecimals(fuelUsed);
    final roundedFinalFuel = TextUtils.roundToTwoDecimals(finalFuel);
    String date = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    Map<String, dynamic> calculationRecord = {
      'date': date,
      'brand': car.brand,
      'model': car.model,
      'license_plate': car.licensePlate,
      'initial_mileage': initialMileage,
      'final_mileage': finalMileage,
      'total_mileage': totalMileage,
      'city_mileage': cityKm,
      'base_city_norm': baseCityNorm,
      'highway_mileage': highwayKm,
      'base_highway_norm': baseHighwayNorm,
      'initial_fuel': initialFuel,
      'refuel': refuel,
      'fuel_used': roundedFuelUsed,
      'final_fuel': roundedFinalFuel,
      'conditions': {
        'winter': isWinter ? 1.15 : 1.0,
        'ac': isAC ? 1.07 : 1.0,
        'mountain': isMountain ? 1.20 : 1.0,
      },
      'correction_factor': correctionFactor,
      'heater_operating_time': heaterOperatingTime,
      'heater_fuel_used': TextUtils.roundToTwoDecimals(heaterFuelUsed),
      'car_id': car.id
    };

    if (_isDuplicateRecord(calculationRecord, localHistory)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.duplicate_record)));
      return null;
    }

    return calculationRecord;
  }

  Future<void> calculate({
    required double totalMileage,
    required bool isWinter,
    required bool isAC,
    required bool isMountain,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final record = await prepareCalculationRecord(
      totalMileage: totalMileage,
      isWinter: isWinter,
      isAC: isAC,
      isMountain: isMountain,
    );
    if (record != null) {
      if (_isDuplicateRecord(record, localHistory)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.duplicate_record)));
        onCalculationComplete(null, false);
        return;
      }
      await HistoryManager.saveHistoryEntry(record);
      onCalculationComplete(record, true);
    } else {
      onCalculationComplete(null, false);
    }
  }
}