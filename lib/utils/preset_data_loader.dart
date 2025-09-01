import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/providers/car_provider.dart';

class PresetDataLoader {
  final BuildContext context;
  final String? vehicleType;
  final Function(bool isLoading) onLoadingChanged;

  // ✨ FIX: Удалены все контроллеры и setStateCallback
  PresetDataLoader({
    required this.context,
    required this.vehicleType,
    required this.onLoadingChanged,
  });

  Future<List<String>> loadPresetBrands() async {
    onLoadingChanged(true);
    try {
      final carProvider = Provider.of<CarProvider>(context, listen: false);
      final brands = await carProvider.getPresetBrands(vehicleType ?? 'Passenger Car');
      onLoadingChanged(false);
      logger.d('Loaded ${brands.length} preset brands for vehicle type ${vehicleType ?? 'Passenger Car'}');
      if (brands.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.no_data_found)),
        );
      }
      return brands;
    } catch (e) {
      logger.e('Ошибка загрузки предустановленных марок: $e');
      onLoadingChanged(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
      return [];
    }
  }

  Future<List<String>> loadPresetModels(String brand) async {
    onLoadingChanged(true);
    try {
      logger.d('Loading preset models for brand: $brand, vehicle type: ${vehicleType?? 'Passenger Car'}');
      final models = await DatabaseHelper.instance.getPresetModelsByBrandAndType(
        brand,
        vehicleType?? 'Passenger Car',
      );
      logger.d('Loaded ${models.length} preset models for brand $brand: $models');
      onLoadingChanged(false);
      if (models.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.no_data_found)),
        );
      }
      return models;
    } catch (e) {
      logger.e('Error loading preset models', error: e);
      onLoadingChanged(false);
      return [];
    }
  }

  Future<List<String>> loadPresetGenerations(String brand, String model) async {
    if (model.isEmpty || brand.isEmpty) return [];
    onLoadingChanged(true);
    try {
      final generations = await DatabaseHelper.instance.getPresetGenerations(
        brand,
        model,
        vehicleType ?? 'Passenger Car',
      );
      onLoadingChanged(false);
      logger.d('Loaded ${generations.length} preset generations for model $model and brand $brand');
      return generations;
    } catch (e) {
      logger.e('Ошибка загрузки предустановленных поколений: $e');
      onLoadingChanged(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
      return [];
    }
  }

  Future<List<String>> loadPresetModifications(String brand, String model, String? generation) async {
    if (model.isEmpty || brand.isEmpty) return [];
    onLoadingChanged(true);
    try {
      final modifications = await DatabaseHelper.instance.getPresetModifications(
        brand,
        model,
        generation,
        vehicleType ?? 'Passenger Car',
      );
      onLoadingChanged(false);
      logger.d('Loaded ${modifications.length} preset modifications for generation $generation and model $model');
      return modifications;
    } catch (e) {
      logger.e('Ошибка загрузки предустановленных модификаций: $e');
      onLoadingChanged(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
      return [];
    }
  }

  Future<CarData?> getFullCarDataFromPreset({
    required String brand,
    required String model,
    String? generation,
    String? modification,
  }) async {
    try {
      final car = await DatabaseHelper.instance.getFullCarData(
        brand,
        model,
        generation,
        modification,
        vehicleType ?? 'Passenger Car',
      );
      if (car != null) {
        // ✨ FIX: Удаляем всю логику обновления контроллеров отсюда
        logger.d('Full car data found: ${car.toJson()}');
        return car;
      } else {
        logger.w('No full car data found for the selection.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.no_data_found)),
        );
        return null;
      }
    } catch (e) {
      logger.e('Ошибка загрузки предустановленных данных автомобиля: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.error)),
      );
      return null;
    }
  }
}