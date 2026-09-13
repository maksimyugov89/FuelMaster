import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/widgets.dart';

/// Поля ввода пробега, топлива и поправочного коэффициента.
class FuelCalculatorInputSection extends StatelessWidget {
  final CarData car;
  final double totalMileage;
  final bool useAutoCorrectionFactor;
  final TextEditingController initialMileageController;
  final TextEditingController finalMileageController;
  final TextEditingController initialFuelController;
  final TextEditingController refuelController;
  final TextEditingController highwayKmController;
  final TextEditingController correctionFactorController;
  final TextEditingController heaterOperatingTimeController;
  final FocusNode initialMileageFocus;
  final FocusNode finalMileageFocus;
  final FocusNode initialFuelFocus;
  final FocusNode refuelFocus;
  final FocusNode highwayKmFocus;
  final FocusNode correctionFactorFocus;
  final FocusNode heaterOperatingTimeFocus;
  final ValueChanged<bool> onAutoCorrectionChanged;
  final void Function(String title, String message) onShowHelp;

  const FuelCalculatorInputSection({
    super.key,
    required this.car,
    required this.totalMileage,
    required this.useAutoCorrectionFactor,
    required this.initialMileageController,
    required this.finalMileageController,
    required this.initialFuelController,
    required this.refuelController,
    required this.highwayKmController,
    required this.correctionFactorController,
    required this.heaterOperatingTimeController,
    required this.initialMileageFocus,
    required this.finalMileageFocus,
    required this.initialFuelFocus,
    required this.refuelFocus,
    required this.highwayKmFocus,
    required this.correctionFactorFocus,
    required this.heaterOperatingTimeFocus,
    required this.onAutoCorrectionChanged,
    required this.onShowHelp,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isBus = car.vehicleType == 'Bus';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: initialMileageController,
                focusNode: initialMileageFocus,
                labelKey: 'initial_mileage',
                isNumber: true,
                icon: Icons.speed,
                onTap: () => FocusScope.of(context).requestFocus(initialMileageFocus),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: finalMileageController,
                focusNode: finalMileageFocus,
                labelKey: 'final_mileage',
                isNumber: true,
                icon: Icons.speed,
                onTap: () => FocusScope.of(context).requestFocus(finalMileageFocus),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: initialFuelController,
                focusNode: initialFuelFocus,
                labelKey: 'initial_fuel',
                isNumber: true,
                icon: Icons.local_gas_station,
                onTap: () => FocusScope.of(context).requestFocus(initialFuelFocus),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: refuelController,
                focusNode: refuelFocus,
                labelKey: 'refuel',
                isNumber: true,
                icon: Icons.local_gas_station,
                onTap: () => FocusScope.of(context).requestFocus(refuelFocus),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: highwayKmController,
          focusNode: highwayKmFocus,
          labelKey: 'highway_distance',
          isNumber: true,
          icon: Icons.directions_car,
          onTap: () => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(l10n.autoCorrectionFactor, overflow: TextOverflow.ellipsis),
          value: useAutoCorrectionFactor,
          onChanged: onAutoCorrectionChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: correctionFactorController,
                focusNode: correctionFactorFocus,
                labelKey: 'correction_factor',
                isNumber: true,
                icon: Icons.percent,
                readOnly: useAutoCorrectionFactor,
                onTap: () => FocusScope.of(context).unfocus(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.help_outline, color: theme.iconTheme.color),
              onPressed: () => onShowHelp(l10n.correction_factor, l10n.correction_factor_tooltip),
              tooltip: l10n.correction_factor,
            ),
          ],
        ),
        if (isBus) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: heaterOperatingTimeController,
                  focusNode: heaterOperatingTimeFocus,
                  labelKey: 'heater_operating_time',
                  isNumber: true,
                  icon: Icons.access_time,
                  onTap: () => FocusScope.of(context).unfocus(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.help_outline, color: theme.iconTheme.color),
                onPressed: () => onShowHelp(
                  l10n.heater_operating_time,
                  l10n.heater_operating_time_tooltip,
                ),
                tooltip: l10n.heater_operating_time,
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.total_mileage,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$totalMileage ${l10n.kilometers}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
