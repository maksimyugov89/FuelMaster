import 'package:flutter/material.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';

/// Кнопки расчёта, сохранения и блок результатов.
class FuelCalculatorActionsSection extends StatelessWidget {
  final String result;
  final VoidCallback onCalculate;
  final VoidCallback onSaveAndBack;
  final VoidCallback onContinue;

  const FuelCalculatorActionsSection({
    super.key,
    required this.result,
    required this.onCalculate,
    required this.onSaveAndBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientButton(
          text: l10n.calculate,
          gradient: primaryActionGradient,
          iconData: Icons.calculate,
          onPressed: onCalculate,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GradientButton(
                text: l10n.save_and_back,
                gradient: primaryActionGradient,
                iconData: Icons.save,
                onPressed: onSaveAndBack,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GradientButton(
                text: l10n.continue_calculations,
                gradient: secondaryActionGradient,
                iconData: Icons.replay,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.current_calculations,
          style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'Roboto'),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        if (result.isNotEmpty)
          SelectableText(result, style: theme.textTheme.bodyMedium)
        else
          Center(
            child: Text(
              l10n.no_calculations,
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
