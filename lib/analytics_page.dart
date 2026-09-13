import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/utils/consumption_analytics_service.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';

/// D-2: экран аналитики расхода топлива.
///
/// Вся математика живёт в [ConsumptionAnalyticsService] и покрыта тестами;
/// здесь — выбор периода и автомобиля, оформление и текстовая выгрузка отчёта.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    required this.history,
    required this.cars,
  });

  /// Записи журнала в том виде, в каком их отдаёт база (fuel_logs).
  final List<Map<String, dynamic>> history;

  final List<CarData> cars;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  /// Доступные периоды анализа в днях.
  static const List<int> _periods = <int>[30, 90, 365];

  /// 0 — «все автомобили».
  int _carId = 0;
  int _periodDays = 30;
  double? _pricePerLiter;
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadPrice() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? saved = prefs.getDouble(AppConstants.fuelPricePerLiterKey);
    if (!mounted || saved == null) return;
    setState(() {
      _pricePerLiter = saved;
      _priceController.text = saved.toStringAsFixed(2);
    });
  }

  Future<void> _savePrice(String raw) async {
    final double? value = double.tryParse(raw.trim().replaceAll(',', '.'));
    final double? normalized = (value == null || value <= 0) ? null : value;
    setState(() => _pricePerLiter = normalized);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(AppConstants.fuelPricePerLiterKey);
    } else {
      await prefs.setDouble(AppConstants.fuelPricePerLiterKey, normalized);
    }
  }

  String _periodLabel(AppLocalizations l10n, int days) {
    switch (days) {
      case 30:
        return l10n.analytics_period_30;
      case 90:
        return l10n.analytics_period_90;
      default:
        return l10n.analytics_period_365;
    }
  }

  String _carLabel(AppLocalizations l10n) {
    if (_carId == 0) return l10n.analytics_all_cars;
    final CarData? car = widget.cars.where((CarData c) => c.id == _carId).firstOrNull;
    if (car == null) return l10n.analytics_all_cars;
    return '${car.brand} ${car.model}'.trim();
  }

  String _number(double value, {int decimals = 1}) =>
      value.toStringAsFixed(decimals).replaceAll('.', ',');

  String _money(double? value) {
    if (value == null) return '—';
    return _number(value, decimals: 0);
  }

  String _deviationText(AppLocalizations l10n, double? deviation) {
    if (deviation == null) return '—';
    final String sign = deviation >= 0 ? '+' : '−';
    final String direction = deviation.abs() < 2
        ? l10n.analytics_on_norm
        : (deviation > 0 ? l10n.analytics_above_norm : l10n.analytics_below_norm);
    return '$sign${_number(deviation.abs())} % ($direction)';
  }

  String _trendText(AppLocalizations l10n, ConsumptionTrend trend) {
    if (!trend.isKnown) return l10n.analytics_trend_stable;
    final String direction;
    switch (trend.direction) {
      case TrendDirection.rising:
        direction = l10n.analytics_trend_rising;
      case TrendDirection.falling:
        direction = l10n.analytics_trend_falling;
      case TrendDirection.stable:
        direction = l10n.analytics_trend_stable;
    }
    final String slope = _number(trend.slopePerMonth.abs(), decimals: 2);
    return '$direction ($slope ${l10n.analytics_trend_per_month})';
  }

  String _deltaText(double? percent) {
    if (percent == null) return '—';
    final String sign = percent >= 0 ? '+' : '−';
    return '$sign${_number(percent.abs())} %';
  }

  String _buildReport(
    AppLocalizations l10n,
    ConsumptionStats stats,
    ConsumptionForecast forecast,
    PeriodComparison comparison,
  ) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(l10n.analytics_report_title);
    buffer.writeln(
      '${l10n.analytics_period_label}: ${_periodLabel(l10n, _periodDays)}',
    );
    buffer.writeln('${l10n.analytics_car}: ${_carLabel(l10n)}');
    buffer.writeln(DateFormat('dd.MM.yyyy').format(DateTime.now()));
    buffer.writeln('');
    buffer.writeln('${l10n.analytics_entries}: ${stats.entries}');
    buffer.writeln(
      '${l10n.analytics_distance}: ${_number(stats.distance)} ${l10n.kilometers}',
    );
    buffer.writeln(
      '${l10n.analytics_fuel_used}: ${_number(stats.fuelUsed)} ${l10n.liters}',
    );
    buffer.writeln(
      '${l10n.analytics_avg_consumption}: ${_number(stats.avgConsumption)} ${l10n.liters_per_100km}',
    );
    if (stats.normPer100 != null) {
      buffer.writeln(
        '${l10n.analytics_norm}: ${_number(stats.normPer100!)} ${l10n.liters_per_100km}',
      );
      buffer.writeln(
        '${l10n.analytics_deviation}: ${_deviationText(l10n, stats.deviationPercent)}',
      );
    }
    if (stats.cost != null) {
      buffer.writeln(
        '${l10n.analytics_cost}: ${_money(stats.cost)} ${l10n.analytics_currency}',
      );
      buffer.writeln(
        '${l10n.analytics_cost_per_km}: ${_number(stats.costPerKm ?? 0)} ${l10n.analytics_currency}',
      );
    }
    if (forecast.hasData) {
      buffer.writeln('');
      buffer.writeln('${l10n.analytics_forecast}:');
      buffer.writeln(
        '  ${l10n.analytics_forecast_distance}: ${_number(forecast.monthlyDistance!)} ${l10n.kilometers}',
      );
      buffer.writeln(
        '  ${l10n.analytics_forecast_fuel}: ${_number(forecast.monthlyFuel ?? 0)} ${l10n.liters}',
      );
      if (forecast.monthlyCost != null) {
        buffer.writeln(
          '  ${l10n.analytics_forecast_cost}: ${_money(forecast.monthlyCost)} ${l10n.analytics_currency}',
        );
      }
      buffer.writeln(
        '  ${l10n.analytics_trend}: ${_trendText(l10n, forecast.trend)}',
      );
    }
    buffer.writeln('');
    if (comparison.hasPrevious) {
      buffer.writeln(
        '${l10n.analytics_comparison}: ${_deltaText(comparison.consumptionDeltaPercent)}',
      );
    } else {
      buffer.writeln(l10n.analytics_comparison_empty);
    }
    return buffer.toString();
  }

  Future<void> _shareReport(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();

    final List<FuelEntry> allEntries = FuelEntry.listFromRecords(
      widget.history,
      carId: _carId == 0 ? null : _carId,
    );
    final List<FuelEntry> periodEntries = allEntries
        .where((FuelEntry entry) =>
            entry.date.isAfter(now.subtract(Duration(days: _periodDays))))
        .toList();

    final ConsumptionStats stats = ConsumptionStats.fromEntries(
      periodEntries,
      pricePerLiter: _pricePerLiter,
    );
    final ConsumptionForecast forecast = ConsumptionForecast.build(
      allEntries,
      pricePerLiter: _pricePerLiter,
      now: now,
    );
    final PeriodComparison comparison = PeriodComparison.splitByDays(
      allEntries,
      days: _periodDays,
      now: now,
      pricePerLiter: _pricePerLiter,
    );

    final bool hasData = stats.entries > 0;
    final String report = _buildReport(l10n, stats, forecast, comparison);

    return Scaffold(
      appBar: AppBar(
        title: GradientText(
          l10n.analytics_title,
          gradient: primaryActionGradient,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            _filtersCard(l10n, theme),
            const SizedBox(height: 16),
            if (!hasData)
              _messageCard(l10n.analytics_no_data, theme)
            else ...<Widget>[
              _statsCard(l10n, theme, stats),
              const SizedBox(height: 16),
              _forecastCard(l10n, theme, forecast),
              const SizedBox(height: 16),
              _comparisonCard(l10n, theme, comparison),
              const SizedBox(height: 20),
              GradientButton(
                text: l10n.analytics_share_report,
                iconData: Icons.share,
                gradient: primaryActionGradient,
                onPressed: () => _shareReport(report),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filtersCard(AppLocalizations l10n, ThemeData theme) {
    final List<CarData> carsWithId =
        widget.cars.where((CarData car) => car.id != null).toList();
    final Set<int> knownIds = carsWithId.map((CarData car) => car.id!).toSet();
    final int selectedCarId = knownIds.contains(_carId) ? _carId : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.analytics_period, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: _periods
                  .map(
                    (int days) => ButtonSegment<int>(
                      value: days,
                      label: Text(_periodLabel(l10n, days)),
                    ),
                  )
                  .toList(),
              selected: <int>{_periodDays},
              onSelectionChanged: (Set<int> selection) =>
                  setState(() => _periodDays = selection.first),
            ),
            const SizedBox(height: 16),
            Text(l10n.analytics_car, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            DropdownButton<int>(
              value: selectedCarId,
              isExpanded: true,
              items: <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(
                  value: 0,
                  child: Text(l10n.analytics_all_cars),
                ),
                ...carsWithId.map(
                  (CarData car) => DropdownMenuItem<int>(
                    value: car.id,
                    child: Text(
                      '${car.brand} ${car.model} ${car.licensePlate ?? ''}'.trim(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (int? value) =>
                  setState(() => _carId = value ?? 0),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.analytics_price_per_liter,
                hintText: l10n.analytics_price_hint,
                suffixText: l10n.analytics_currency,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _savePrice,
              onEditingComplete: () => _savePrice(_priceController.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(
    AppLocalizations l10n,
    ThemeData theme,
    ConsumptionStats stats,
  ) {
    final double? deviation = stats.deviationPercent;
    final Color deviationColor = deviation == null
        ? theme.colorScheme.onSurface
        : (deviation > 2
            ? theme.colorScheme.error
            : (deviation < -2 ? Colors.green : theme.colorScheme.onSurface));

    return _card(
      theme,
      title: l10n.analytics_summary,
      rows: <Widget>[
        _row(
          theme,
          l10n.analytics_avg_consumption,
          '${_number(stats.avgConsumption)} ${l10n.liters_per_100km}',
        ),
        if (stats.normPer100 != null)
          _row(
            theme,
            l10n.analytics_norm,
            '${_number(stats.normPer100!)} ${l10n.liters_per_100km}',
          ),
        _row(
          theme,
          l10n.analytics_deviation,
          _deviationText(l10n, deviation),
          color: deviationColor,
        ),
        _row(
          theme,
          l10n.analytics_distance,
          '${_number(stats.distance)} ${l10n.kilometers}',
        ),
        _row(
          theme,
          l10n.analytics_fuel_used,
          '${_number(stats.fuelUsed)} ${l10n.liters}',
        ),
        if (stats.cost != null)
          _row(
            theme,
            l10n.analytics_cost,
            '${_money(stats.cost)} ${l10n.analytics_currency}',
          ),
        if (stats.costPerKm != null)
          _row(
            theme,
            l10n.analytics_cost_per_km,
            '${_number(stats.costPerKm!)} ${l10n.analytics_currency}',
          ),
        _row(theme, l10n.analytics_entries, '${stats.entries}'),
        _row(
          theme,
          l10n.analytics_city_share,
          '${_number(stats.cityShare * 100, decimals: 0)} %',
        ),
      ],
    );
  }

  Widget _forecastCard(
    AppLocalizations l10n,
    ThemeData theme,
    ConsumptionForecast forecast,
  ) {
    return _card(
      theme,
      title: l10n.analytics_forecast,
      rows: <Widget>[
        _row(
          theme,
          l10n.analytics_forecast_distance,
          forecast.monthlyDistance == null
              ? '—'
              : '${_number(forecast.monthlyDistance!)} ${l10n.kilometers}',
        ),
        _row(
          theme,
          l10n.analytics_forecast_fuel,
          forecast.monthlyFuel == null
              ? '—'
              : '${_number(forecast.monthlyFuel!)} ${l10n.liters}',
        ),
        _row(
          theme,
          l10n.analytics_forecast_cost,
          forecast.monthlyCost == null
              ? '—'
              : '${_money(forecast.monthlyCost)} ${l10n.analytics_currency}',
        ),
        _row(
          theme,
          l10n.analytics_daily_distance,
          '${_number(forecast.dailyDistance)} ${l10n.kilometers}',
        ),
        _row(
          theme,
          l10n.analytics_avg_refuel,
          '${_number(forecast.averageRefuelVolume)} ${l10n.liters}',
        ),
        _row(
          theme,
          l10n.analytics_trend,
          _trendText(l10n, forecast.trend),
        ),
      ],
    );
  }

  Widget _comparisonCard(
    AppLocalizations l10n,
    ThemeData theme,
    PeriodComparison comparison,
  ) {
    if (!comparison.hasPrevious) {
      return _messageCard(l10n.analytics_comparison_empty, theme);
    }
    final double? consumptionDelta = comparison.consumptionDeltaPercent;
    final Color color = consumptionDelta == null
        ? theme.colorScheme.onSurface
        : (consumptionDelta > 0 ? theme.colorScheme.error : Colors.green);

    return _card(
      theme,
      title: l10n.analytics_comparison,
      rows: <Widget>[
        _row(
          theme,
          l10n.analytics_avg_consumption,
          _deltaText(consumptionDelta),
          color: color,
        ),
        _row(
          theme,
          l10n.analytics_distance,
          _deltaText(comparison.distanceDeltaPercent),
        ),
        if (comparison.current.cost != null && comparison.previous.cost != null)
          _row(
            theme,
            l10n.analytics_cost,
            _deltaText(comparison.costDeltaPercent),
          ),
      ],
    );
  }

  Widget _card(ThemeData theme, {required String title, required List<Widget> rows}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GradientText(
              title,
              gradient: primaryActionGradient,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(String text, ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}
