import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';

/// Переключатели условий поездки (зима, кондиционер, горы).
class FuelCalculatorConditions extends StatelessWidget {
  final bool isWinter;
  final bool isAC;
  final bool isMountain;
  final ValueChanged<bool> onWinterChanged;
  final ValueChanged<bool> onACChanged;
  final ValueChanged<bool> onMountainChanged;

  const FuelCalculatorConditions({
    super.key,
    required this.isWinter,
    required this.isAC,
    required this.isMountain,
    required this.onWinterChanged,
    required this.onACChanged,
    required this.onMountainChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientText(
          l10n.adjustments,
          gradient: primaryActionGradient,
          style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'Roboto'),
        ),
        SwitchListTile(
          title: Text(l10n.winter, style: theme.textTheme.bodyMedium),
          value: isWinter,
          onChanged: onWinterChanged,
        ),
        SwitchListTile(
          title: Text(l10n.ac, style: theme.textTheme.bodyMedium),
          value: isAC,
          onChanged: onACChanged,
        ),
        SwitchListTile(
          title: Text(l10n.mountain, style: theme.textTheme.bodyMedium),
          value: isMountain,
          onChanged: onMountainChanged,
        ),
      ],
    );
  }
}
