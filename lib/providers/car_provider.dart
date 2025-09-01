import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';

class CarProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<CarData> _cars = [];
  bool _isLoading = false;

  List<CarData> get cars => _cars;
  bool get isLoading => _isLoading;

  CarProvider({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance {
    loadCars();
  }

  Future<void> loadCars() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _cars = await _dbHelper.getCars(); // Используем getCars() для всех автомобилей
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _dbHelper.syncCarsWithFirestore(user.uid);
        _cars = await _dbHelper.getCars(); // Refresh after sync
      }
      logger.d('Loaded ${_cars.length} cars in CarProvider');
    } catch (e) {
      logger.e('Error loading cars in CarProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> getPresetBrands(String vehicleType) async {
    try {
      final brands = await _dbHelper.getPresetBrandsByVehicleType(vehicleType); // Убрано приведение типов
      logger.d('Loaded ${brands.length} preset brands for vehicle type $vehicleType: $brands');
      return brands; // Возвращаем List<String> напрямую
    } catch (e) {
      logger.e('Error getting preset brands for $vehicleType: $e');
      return [];
    }
  }

  Future<bool> addCar(CarData car) async {
    try {
      // Валидация для автобусов
      if (car.vehicleType == 'Bus') {
        if (car.baseCombinedNorm == null || car.baseCombinedNorm! <= 0) {
          logger.w('Invalid baseCombinedNorm for bus: ${car.baseCombinedNorm}');
          return false;
        }
        if (car.passengerCapacity == null || car.passengerCapacity! <= 0) {
          logger.w('Invalid passengerCapacity for bus: ${car.passengerCapacity}');
          return false;
        }
      } else {
        if (car.baseCityNorm <= 0 || car.baseHighwayNorm <= 0) {
          logger.w('Invalid baseCityNorm or baseHighwayNorm: ${car.baseCityNorm}, ${car.baseHighwayNorm}');
          return false;
        }
      }

      // ✨ FIX: Убрана логика, которая приравнивала baseHighwayNorm к baseCityNorm.
      // Теперь данные сохраняются как есть.
      await _dbHelper.insertCar(car);
      await loadCars();
      logger.d('Car added successfully: ${car.toJson()}');
      return true;
    } catch (e) {
      logger.e('Error adding car in CarProvider: $e');
      return false;
    }
  }

  Future<bool> updateCar(CarData car) async {
    try {
      // Валидация для автобусов
      if (car.vehicleType == 'Bus') {
        if (car.baseCombinedNorm == null || car.baseCombinedNorm! <= 0) {
          logger.w('Invalid baseCombinedNorm for bus: ${car.baseCombinedNorm}');
          return false;
        }
        if (car.passengerCapacity == null || car.passengerCapacity! <= 0) {
          logger.w('Invalid passengerCapacity for bus: ${car.passengerCapacity}');
          return false;
        }
      } else {
        if (car.baseCityNorm <= 0 || car.baseHighwayNorm <= 0) {
          logger.w('Invalid baseCityNorm or baseHighwayNorm: ${car.baseCityNorm}, ${car.baseHighwayNorm}');
          return false;
        }
      }
      
      // ✨ FIX: Убрана логика, которая приравнивала baseHighwayNorm к baseCityNorm.
      // Теперь данные обновляются как есть.
      await _dbHelper.updateCar(car);
      await loadCars();
      logger.d('Car updated successfully: ${car.toJson()}');
      return true;
    } catch (e) {
      logger.e('Error updating car in CarProvider: $e');
      return false;
    }
  }


  Future<bool> deleteCar(int id) async {
    try {
      await _dbHelper.deleteCar(id);
      await loadCars();
      logger.d('Car deleted successfully: ID $id');
      return true;
    } catch (e) {
      logger.e('Error deleting car in CarProvider: $e');
      return false;
    }
  }
}