import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/widgets/license_plate_widget.dart';

/// Заголовок калькулятора: марка, модель, госномер, базовые нормы.
class FuelCalculatorCarHeader extends StatelessWidget {
  final CarData car;

  const FuelCalculatorCarHeader({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final modelText = RegExp(r'[^\d\s]+').allMatches(car.model).isNotEmpty
        ? RegExp(r'[^\d\s]+')
            .allMatches(car.model)
            .map((match) => match.group(0))
            .join(' ')
        : car.model;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.brand}: ${car.brand}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (car.licensePlate != null && car.licensePlate!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: LicensePlateWidget(
              plateNumber: car.licensePlate!,
              scale: 0.7,
            ),
          ),
        Text(
          '${l10n.model}: $modelText',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${l10n.base_city_norm}: ${car.baseCityNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${l10n.base_highway_norm}: ${car.baseHighwayNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${l10n.base_combined_norm}: ${((car.baseCityNorm + car.baseHighwayNorm) / 2).toStringAsFixed(2)} ${l10n.liters_per_100km}',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
