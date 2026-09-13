import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/vehicle_type_labels.dart';
import 'package:fuelmaster/widgets.dart';
import 'package:fuelmaster/widgets/license_plate_widget.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

/// Шаг 1: тип ТС и госномер.
class CarInfoStep1Card extends StatelessWidget {
  final String? vehicleType;
  final TextEditingController licensePlateController;
  final FocusNode licensePlateFocus;
  final MaskTextInputFormatter licensePlateMask;
  final ValueChanged<String?> onVehicleTypeChanged;

  const CarInfoStep1Card({
    super.key,
    required this.vehicleType,
    required this.licensePlateController,
    required this.licensePlateFocus,
    required this.licensePlateMask,
    required this.onVehicleTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.car_form_step1_title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: vehicleType,
              decoration: InputDecoration(
                labelText: l10n.vehicle_type,
                prefixIcon: Icon(Icons.commute, color: theme.colorScheme.primary),
              ),
              items: kVehicleTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          localizedVehicleType(l10n, type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: onVehicleTypeChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: licensePlateController,
              focusNode: licensePlateFocus,
              inputFormatters: [licensePlateMask],
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.license_plate,
                prefixIcon: Icon(Icons.confirmation_number, color: theme.colorScheme.primary),
                hintText: 'А 123 ВС 78',
              ),
            ),
            if (licensePlateController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: LicensePlateWidget(plateNumber: licensePlateController.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Шаг 2: марка, модель, модификация (пресеты).
class CarInfoStep2Card extends StatelessWidget {
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController modificationController;
  final FocusNode brandFocus;
  final FocusNode modelFocus;
  final FocusNode modificationFocus;
  final VoidCallback onBrandTap;
  final VoidCallback onModelTap;
  final VoidCallback onModificationTap;

  const CarInfoStep2Card({
    super.key,
    required this.brandController,
    required this.modelController,
    required this.modificationController,
    required this.brandFocus,
    required this.modelFocus,
    required this.modificationFocus,
    required this.onBrandTap,
    required this.onModelTap,
    required this.onModificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.car_form_step2_title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            CustomTextField(
              controller: brandController,
              focusNode: brandFocus,
              labelKey: 'brand',
              icon: Icons.directions_car,
              readOnly: true,
              onTap: onBrandTap,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: modelController,
              focusNode: modelFocus,
              labelKey: 'model',
              icon: Icons.directions_car,
              enabled: brandController.text.isNotEmpty,
              readOnly: true,
              onTap: onModelTap,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: modificationController,
              focusNode: modificationFocus,
              labelKey: 'modification',
              icon: Icons.car_repair,
              enabled: modelController.text.isNotEmpty,
              readOnly: true,
              onTap: onModificationTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Шаг 3: тип топлива и нормы расхода.
class CarInfoStep3Card extends StatelessWidget {
  final String? vehicleType;
  final String? fuelType;
  final TextEditingController baseCityNormController;
  final TextEditingController baseHighwayNormController;
  final TextEditingController baseCombinedNormController;
  final TextEditingController heaterFuelConsumptionController;
  final TextEditingController passengerCapacityController;
  final FocusNode baseCityNormFocus;
  final FocusNode baseHighwayNormFocus;
  final FocusNode baseCombinedNormFocus;
  final FocusNode heaterFuelConsumptionFocus;
  final FocusNode passengerCapacityFocus;
  final ValueChanged<String?> onFuelTypeChanged;

  const CarInfoStep3Card({
    super.key,
    required this.vehicleType,
    required this.fuelType,
    required this.baseCityNormController,
    required this.baseHighwayNormController,
    required this.baseCombinedNormController,
    required this.heaterFuelConsumptionController,
    required this.passengerCapacityController,
    required this.baseCityNormFocus,
    required this.baseHighwayNormFocus,
    required this.baseCombinedNormFocus,
    required this.heaterFuelConsumptionFocus,
    required this.passengerCapacityFocus,
    required this.onFuelTypeChanged,
  });

  static const List<String> _fuelTypes = ['Б', 'Д', 'СУГ', 'КПГ', 'Электро', 'Газодизель'];

  String _localizedFuelType(AppLocalizations l10n, String type) {
    switch (type) {
      case 'Б':
        return l10n.petrol;
      case 'Д':
        return l10n.diesel;
      case 'СУГ':
        return l10n.lpg;
      case 'КПГ':
        return l10n.cng;
      case 'Электро':
        return l10n.electric;
      default:
        return l10n.gas_diesel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isBus = vehicleType == 'Bus';

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.car_form_step3_title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: fuelType,
              decoration: InputDecoration(
                labelText: l10n.fuel_type,
                prefixIcon: Icon(Icons.local_gas_station, color: theme.colorScheme.primary),
              ),
              items: _fuelTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          _localizedFuelType(l10n, type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: onFuelTypeChanged,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: baseCityNormController,
              focusNode: baseCityNormFocus,
              labelKey: 'base_city_norm',
              isNumber: true,
              icon: Icons.location_city,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: baseHighwayNormController,
              focusNode: baseHighwayNormFocus,
              labelKey: 'base_highway_norm',
              isNumber: true,
              icon: Icons.add_road,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: baseCombinedNormController,
              focusNode: baseCombinedNormFocus,
              labelKey: 'base_combined_norm',
              isNumber: true,
              icon: Icons.blender,
            ),
            if (isBus) ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: heaterFuelConsumptionController,
                focusNode: heaterFuelConsumptionFocus,
                labelKey: 'heater_fuel_consumption',
                isNumber: true,
                icon: Icons.thermostat,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: passengerCapacityController,
                focusNode: passengerCapacityFocus,
                labelKey: 'passenger_capacity',
                isNumber: true,
                icon: Icons.people,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
