import 'dart:convert';

class CarData {
  final int? id;
  final String brand;
  final String model;
  final String? licensePlate;
  final String? generation;
  final String? modification;
  final int? yearFrom;
  final int? yearTo;
  final double? engineVolume;
  final double? powerHp;
  final double? powerKw;
  final String? fuelType;
  final String? transmissionType;
  final int? transmissionSpeeds;
  final double baseCityNorm;
  final double baseHighwayNorm;
  final double? baseCombinedNorm;
  final String? vehicleType;
  final String? cylinders;
  final int? isPreset;
  final int? passengerCapacity;
  final double? heaterFuelConsumption;
  final double? fuelConsumptionPerTonKm;
  final double? trailerWeight;
  final double? fuelConsumptionPerLoad;
  final double? loadCapacity;
  final double? batteryCapacityKwh;
  final int? lastModified;

  CarData({
    this.id,
    required this.brand,
    required this.model,
    this.licensePlate,
    this.generation,
    this.modification,
    this.yearFrom,
    this.yearTo,
    this.engineVolume,
    this.powerHp,
    this.powerKw,
    this.fuelType,
    this.transmissionType,
    this.transmissionSpeeds,
    required this.baseCityNorm,
    required this.baseHighwayNorm,
    this.baseCombinedNorm,
    this.vehicleType,
    this.cylinders,
    this.isPreset = 0,
    this.passengerCapacity,
    this.heaterFuelConsumption,
    this.fuelConsumptionPerTonKm,
    this.trailerWeight,
    this.fuelConsumptionPerLoad,
    this.loadCapacity,
    this.batteryCapacityKwh,
    this.lastModified,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'license_plate': licensePlate,
        'generation': generation,
        'modification': modification,
        'year_from': yearFrom,
        'year_to': yearTo,
        'engine_volume': engineVolume,
        'power_hp': powerHp,
        'power_kw': powerKw,
        'fuel_type': fuelType,
        'transmission_type': transmissionType,
        'transmission_speeds': transmissionSpeeds,
        'base_rate_city': baseCityNorm,
        'base_rate_highway': baseHighwayNorm,
        'base_rate_combined': baseCombinedNorm,
        'vehicle_type': vehicleType ?? 'Passenger Car',
        'cylinders': cylinders,
        'is_preset': isPreset,
        'passenger_capacity': passengerCapacity,
        'heater_fuel_consumption': heaterFuelConsumption,
        'fuel_consumption_per_ton_km': fuelConsumptionPerTonKm,
        'trailer_weight': trailerWeight,
        'fuel_consumption_per_load': fuelConsumptionPerLoad,
        'load_capacity': loadCapacity,
        'battery_capacity_kwh': batteryCapacityKwh,
        'last_modified': lastModified,
      };

  factory CarData.fromJson(Map<String, dynamic> json) => CarData(
        id: json['id'] is int ? json['id'] as int? : int.tryParse(json['id']?.toString() ?? ''),
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        licensePlate: json['license_plate'] as String?,
        generation: json['generation'] as String?,
        modification: json['modification'] as String?,
        yearFrom: json['year_from'] is int ? json['year_from'] as int? : int.tryParse(json['year_from']?.toString() ?? ''),
        yearTo: json['year_to'] is int ? json['year_to'] as int? : int.tryParse(json['year_to']?.toString() ?? ''),
        engineVolume: json['engine_volume'] is num ? (json['engine_volume'] as num).toDouble() : double.tryParse(json['engine_volume']?.toString() ?? '0.0'),
        powerHp: json['power_hp'] is num ? (json['power_hp'] as num).toDouble() : double.tryParse(json['power_hp']?.toString() ?? '0.0'),
        powerKw: json['power_kw'] is num ? (json['power_kw'] as num).toDouble() : double.tryParse(json['power_kw']?.toString() ?? '0.0'),
        fuelType: json['fuel_type'] as String?,
        transmissionType: json['transmission_type'] as String?,
        transmissionSpeeds: json['transmission_speeds'] is int ? json['transmission_speeds'] as int? : int.tryParse(json['transmission_speeds']?.toString() ?? '0'),
        baseCityNorm: (json['base_rate_city'] is num ? json['base_rate_city'] as num : double.tryParse(json['base_rate_city']?.toString() ?? '0.0') ?? 0.0).toDouble(),
        baseHighwayNorm: (json['base_rate_highway'] is num ? json['base_rate_highway'] as num : double.tryParse(json['base_rate_highway']?.toString() ?? '0.0') ?? 0.0).toDouble(),
        baseCombinedNorm: json['base_rate_combined'] is num ? (json['base_rate_combined'] as num).toDouble() : double.tryParse(json['base_rate_combined']?.toString() ?? ''),
        vehicleType: json['vehicle_type'] as String? ?? 'Passenger Car',
        cylinders: json['cylinders'] as String?,
        isPreset: json['is_preset'] is int ? json['is_preset'] as int? ?? 0 : int.tryParse(json['is_preset']?.toString() ?? '0') ?? 0,
        passengerCapacity: json['passenger_capacity'] is int ? json['passenger_capacity'] as int? : int.tryParse(json['passenger_capacity']?.toString() ?? ''),
        heaterFuelConsumption: json['heater_fuel_consumption'] is num ? (json['heater_fuel_consumption'] as num).toDouble() : double.tryParse(json['heater_fuel_consumption']?.toString() ?? ''),
        fuelConsumptionPerTonKm: json['fuel_consumption_per_ton_km'] is num ? (json['fuel_consumption_per_ton_km'] as num).toDouble() : double.tryParse(json['fuel_consumption_per_ton_km']?.toString() ?? ''),
        trailerWeight: json['trailer_weight'] is num ? (json['trailer_weight'] as num).toDouble() : double.tryParse(json['trailer_weight']?.toString() ?? ''),
        fuelConsumptionPerLoad: json['fuel_consumption_per_load'] is num ? (json['fuel_consumption_per_load'] as num).toDouble() : double.tryParse(json['fuel_consumption_per_load']?.toString() ?? ''),
        loadCapacity: json['load_capacity'] is num ? (json['load_capacity'] as num).toDouble() : double.tryParse(json['load_capacity']?.toString() ?? ''),
        batteryCapacityKwh: json['battery_capacity_kwh'] is num ? (json['battery_capacity_kwh'] as num).toDouble() : double.tryParse(json['battery_capacity_kwh']?.toString() ?? ''),
        lastModified: json['last_modified'] is int ? json['last_modified'] as int? : int.tryParse(json['last_modified']?.toString() ?? ''),
      );

  CarData copyWith({
    int? id,
    String? brand,
    String? model,
    String? licensePlate,
    String? generation,
    String? modification,
    int? yearFrom,
    int? yearTo,
    double? engineVolume,
    double? powerHp,
    double? powerKw,
    String? fuelType,
    String? transmissionType,
    int? transmissionSpeeds,
    double? baseCityNorm,
    double? baseHighwayNorm,
    double? baseCombinedNorm,
    String? vehicleType,
    String? cylinders,
    int? isPreset,
    int? passengerCapacity,
    double? heaterFuelConsumption,
    double? fuelConsumptionPerTonKm,
    double? trailerWeight,
    double? fuelConsumptionPerLoad,
    double? loadCapacity,
    double? batteryCapacityKwh,
    int? lastModified,
  }) {
    return CarData(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      generation: generation ?? this.generation,
      modification: modification ?? this.modification,
      yearFrom: yearFrom ?? this.yearFrom,
      yearTo: yearTo ?? this.yearTo,
      engineVolume: engineVolume ?? this.engineVolume,
      powerHp: powerHp ?? this.powerHp,
      powerKw: powerKw ?? this.powerKw,
      fuelType: fuelType ?? this.fuelType,
      transmissionType: transmissionType ?? this.transmissionType,
      transmissionSpeeds: transmissionSpeeds ?? this.transmissionSpeeds,
      baseCityNorm: baseCityNorm ?? this.baseCityNorm,
      baseHighwayNorm: baseHighwayNorm ?? this.baseHighwayNorm,
      baseCombinedNorm: baseCombinedNorm ?? this.baseCombinedNorm,
      vehicleType: vehicleType ?? this.vehicleType,
      cylinders: cylinders ?? this.cylinders,
      isPreset: isPreset ?? this.isPreset,
      passengerCapacity: passengerCapacity ?? this.passengerCapacity,
      heaterFuelConsumption: heaterFuelConsumption ?? this.heaterFuelConsumption,
      fuelConsumptionPerTonKm: fuelConsumptionPerTonKm ?? this.fuelConsumptionPerTonKm,
      trailerWeight: trailerWeight ?? this.trailerWeight,
      fuelConsumptionPerLoad: fuelConsumptionPerLoad ?? this.fuelConsumptionPerLoad,
      loadCapacity: loadCapacity ?? this.loadCapacity,
      batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarData &&
          runtimeType == other.runtimeType &&
          brand == other.brand &&
          model == other.model &&
          modification == other.modification;

  @override
  int get hashCode => brand.hashCode ^ model.hashCode ^ (modification?.hashCode ?? 0);
}