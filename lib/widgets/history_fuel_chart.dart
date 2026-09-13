import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/utils/history_display_service.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';

/// График расхода топлива на экране истории.
class HistoryFuelChart extends StatelessWidget {
  final HistoryDisplayService displayService;

  const HistoryFuelChart({super.key, required this.displayService});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final spots = displayService.getChartSpots();

    if (spots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          l10n.no_chart_data,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 4.0,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientText(
                l10n.fuel_usage_chart,
                gradient: primaryActionGradient,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 24 * 3600 * 1000 * 7,
                          getTitlesWidget: (value, meta) {
                            final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                            final dateText = DateFormat('dd.MM').format(date);
                            return Transform.rotate(
                              angle: -45 * (3.1415926535 / 180),
                              child: Text(
                                dateText,
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                    minY: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
