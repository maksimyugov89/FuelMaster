import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/utils.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:fuelmaster/utils/deepseek_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fuelmaster/widgets.dart';
import 'package:fuelmaster/utils/fuel_calculation_service.dart';
import 'package:fuelmaster/utils/weather_service.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';
import 'package:fuelmaster/widgets/license_plate_widget.dart';

class FuelCalculatorPage extends StatefulWidget {
  final CarData car;
  final List<CarData> cars;
  final Locale locale;

  const FuelCalculatorPage({
    super.key,
    required this.car,
    required this.cars,
    required this.locale,
  });

  @override
  FuelCalculatorPageState createState() => FuelCalculatorPageState();
}

class FuelCalculatorPageState extends State<FuelCalculatorPage> {
  late FuelCalculationService _fuelCalculationService;
  final TextEditingController initialMileageController = TextEditingController();
  final TextEditingController finalMileageController = TextEditingController();
  final TextEditingController highwayKmController = TextEditingController();
  final TextEditingController initialFuelController = TextEditingController();
  final TextEditingController refuelController = TextEditingController();
  final TextEditingController correctionFactorController = TextEditingController();
  final TextEditingController heaterOperatingTimeController = TextEditingController();
  final FocusNode initialMileageFocus = FocusNode();
  final FocusNode finalMileageFocus = FocusNode();
  final FocusNode highwayKmFocus = FocusNode();
  final FocusNode initialFuelFocus = FocusNode();
  final FocusNode refuelFocus = FocusNode();
  final FocusNode correctionFactorFocus = FocusNode();
  final FocusNode heaterOperatingTimeFocus = FocusNode();
  String result = '';
  List<Map<String, dynamic>> localHistory = [];
  double totalMileage = 0;
  bool isWinter = false;
  bool isAC = false;
  bool isMountain = false;
  bool _calculationDone = false;
  bool _isPremium = false;
  bool _isLoading = false;
  bool _useAutoCorrectionFactor = false;
  bool _bannerShown = false; // ✅ новый флаг
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _fuelCalculationService = FuelCalculationService(
      context: context,
      car: widget.car,
      localHistory: localHistory,
      initialMileageController: initialMileageController,
      finalMileageController: finalMileageController,
      highwayKmController: highwayKmController,
      initialFuelController: initialFuelController,
      refuelController: refuelController,
      correctionFactorController: correctionFactorController,
      heaterOperatingTimeController: heaterOperatingTimeController,
      onCalculationComplete: (resRecord, done) => setState(() {
        if (resRecord != null) {
          result = _formatHistoryRecord(resRecord, AppLocalizations.of(context)!).join('\n');
          final existingIndex = localHistory.indexWhere((rec) => rec['date'] == resRecord['date']);
          if (existingIndex == -1) {
            localHistory.insert(0, resRecord);
          }
        }
        _calculationDone = done;
        if (done && resRecord != null) {
          _showCalculationResult(resRecord);
        }
      }),
    );

    _loadHistoryForCar().then((_) {
      if (localHistory.isNotEmpty) {
        final lastRecord = localHistory.first;
        final finalFuel = double.tryParse(lastRecord['final_fuel'].toString()) ?? 0.0;
        if (finalFuel >= 0) {
          final finalMileage = double.tryParse(lastRecord['final_mileage'].toString())?.toInt() ?? 0;
          final roundedFinalFuel = TextUtils.roundToTwoDecimals(finalFuel);
          initialMileageController.text = finalMileage.toString();
          initialFuelController.text = roundedFinalFuel.toStringAsFixed(2);
          if (widget.car.vehicleType == 'Bus') {
            correctionFactorController.text = lastRecord['correction_factor']?.toString() ?? '0';
            heaterOperatingTimeController.text = lastRecord['heater_operating_time']?.toString() ?? '0';
          }
          logger.d('Автозаполнение: initial_mileage = ${initialMileageController.text}, initial_fuel = ${initialFuelController.text}');
        } else {
          logger.w('Остаток топлива отрицательный, автозаполнение пропущено');
        }
      }
    });
    _checkPremiumStatus();

    // ❌ Убрал показ баннера из initState()

    initialMileageController.addListener(_updateTotalMileage);
    finalMileageController.addListener(_updateTotalMileage);
    highwayKmController.addListener(() {
      if (mounted) setState(() {});
    });
    initialFuelController.addListener(() {
      if (mounted) setState(() {});
    });
    refuelController.addListener(() {
      if (mounted) setState(() {});
    });
    correctionFactorController.addListener(() {
      if (mounted) setState(() {});
    });
    heaterOperatingTimeController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ теперь баннер безопасно показывается здесь
    if (!_isPremium && !_bannerShown) {
      final screenWidth = MediaQuery.of(context).size.width.toInt();
      AdManager.showBannerAd(
        context: context,
        adUnitId: "R-M-16174255-1",
        width: screenWidth,
      );
      _bannerShown = true;
    }
  }

  Future<void> _loadHistoryForCar() async {
    try {
      final loadedHistory = await HistoryManager.loadHistory();
      final filteredHistory = loadedHistory
          .where((record) => record['car_id'] == widget.car.id)
          .toList();

      filteredHistory.sort((a, b) {
        try {
          final dateA = DateFormat('dd.MM.yyyy HH:mm').parse(a['date']);
          final dateB = DateFormat('dd.MM.yyyy HH:mm').parse(b['date']);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          localHistory = filteredHistory;
        });
        final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
        logger.d('[$timestamp] Загружена история для автомобиля ${widget.car.id}: $localHistory');
      }
    } catch (e) {
      final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
      logger.e('[$timestamp] Ошибка загрузки истории для автомобиля ${widget.car.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  Future<void> _checkPremiumStatus() async {
    final iap = InAppPurchase.instance;
    if (await iap.isAvailable()) {
      _purchaseSubscription = iap.purchaseStream.listen((purchases) {
        setState(() {
          _isPremium = purchases.any((purchase) =>
              purchase.productID == 'supergrok_monthly' &&
              (purchase.status == PurchaseStatus.restored ||
                  purchase.status == PurchaseStatus.purchased));
        });
      }, onDone: () {
        _purchaseSubscription?.cancel();
      }, onError: (e) {
        logger.e('Error in purchase stream: $e');
      });
      await iap.restorePurchases();
    }
  }

  Future<bool> _hasUsedDailyAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastUsed = prefs.getString('last_advice_date') ?? '';
    final count = prefs.getInt('advice_count') ?? 0;
    if (lastUsed == today && count >= 1) return true;
    if (lastUsed != today) await prefs.setInt('advice_count', 0);
    await prefs.setString('last_advice_date', today);
    await prefs.setInt('advice_count', count + 1);
    return false;
  }

  Future<void> _showFuelAdvice() async {
    final l10n = AppLocalizations.of(context)!;
    if (!kDebugMode && !_isPremium && await _hasUsedDailyAdvice()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.premium_feature)),
      );
      return;
    }
    setState(() { _isLoading = true; });
    final carModel = '${widget.car.brand} ${widget.car.model}';
    final cachedAdvice = await DeepSeekService().getCachedAdvice(carModel);
    String? advice;
    if (cachedAdvice != null && cachedAdvice.isNotEmpty) {
      advice = cachedAdvice;
    } else {
      Map<String, dynamic>? lastRecord = localHistory.isNotEmpty ? localHistory.first : null;
      advice = await DeepSeekService().getFuelEfficiencyAdvice(carModel, context, lastRecord);
      if (advice != null && advice.isNotEmpty) {
        await DeepSeekService().cacheAdvice(carModel, advice);
      } else {
        advice = await DeepSeekService().getFuelEfficiencyAdvice(carModel, context, lastRecord);
      }
    }
    if (mounted) {
      setState(() { _isLoading = false; });
      if (advice != null && advice.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.fuel_advice_title),
            content: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(child: SelectableText(advice!)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.ok),
              ),
              TextButton(
                onPressed: () async {
                  if (advice!.isNotEmpty) {
                    try {
                      await Share.share(advice);
                    } catch (e) {
                      logger.e('Ошибка при попытке поделиться советом: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.error_sharing)),
                        );
                      }
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.no_advice_to_share)),
                      );
                    }
                  }
                },
                child: Text(l10n.share),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error)),
        );
      }
    }
  }

  void _updateTotalMileage() {
    final initial = double.tryParse(initialMileageController.text.trim().replaceAll(',', '.')) ?? 0;
    final finalMileage = double.tryParse(finalMileageController.text.trim().replaceAll(',', '.')) ?? 0;
    if (mounted) {
      setState(() {
        totalMileage = (finalMileage >= initial) ? finalMileage - initial : 0;
      });
      logger.d('Обновлён общий пробег: $totalMileage');
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    initialMileageController.removeListener(_updateTotalMileage);
    finalMileageController.removeListener(_updateTotalMileage);
    initialMileageController.dispose();
    finalMileageController.dispose();
    highwayKmController.dispose();
    initialFuelController.dispose();
    refuelController.dispose();
    correctionFactorController.dispose();
    heaterOperatingTimeController.dispose();
    initialMileageFocus.dispose();
    finalMileageFocus.dispose();
    highwayKmFocus.dispose();
    initialFuelFocus.dispose();
    refuelFocus.dispose();
    correctionFactorFocus.dispose();
    heaterOperatingTimeFocus.dispose();
    super.dispose();
  }

  bool _isDirty() {
    if (localHistory.isEmpty) {
      return initialMileageController.text.isNotEmpty ||
          finalMileageController.text.isNotEmpty ||
          initialFuelController.text.isNotEmpty ||
          refuelController.text.isNotEmpty;
    }
    final lastRecord = localHistory.first;
    final lastFinalMileage = double.tryParse(lastRecord['final_mileage'].toString())?.toInt() ?? 0;
    final lastFinalFuel = double.tryParse(lastRecord['final_fuel'].toString()) ?? 0.0;
    final currentInitialMileage = int.tryParse(initialMileageController.text) ?? 0;
    final currentInitialFuel = double.tryParse(initialFuelController.text) ?? 0.0;

    return currentInitialMileage != lastFinalMileage ||
        currentInitialFuel != lastFinalFuel ||
        finalMileageController.text.isNotEmpty ||
        refuelController.text.isNotEmpty;
  }

  bool _isDuplicateRecord(Map<String, dynamic> record, List<Map<String, dynamic>> existingHistory) {
    return existingHistory.any((existing) =>
        existing['car_id'] == record['car_id'] &&
        existing['date'] == record['date'] &&
        existing['initial_mileage'] == record['initial_mileage'] &&
        existing['final_mileage'] == record['final_mileage'] &&
        existing['initial_fuel'] == record['initial_fuel'] &&
        existing['refuel'] == record['refuel']);
  }

  Future<void> _exportHistory() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final csvData = const ListToCsvConverter().convert(localHistory.map((record) {
      final formatted = _formatHistoryRecord(record, l10n).map((line) => line.split(': ').last).toList();
      return formatted;
    }).toList());
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/fuel_history_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.history_exported)),
      );
    }
  }

  Future<void> _saveHistory() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final existingHistory = await HistoryManager.loadHistory();
      for (var record in localHistory) {
        if (!_isDuplicateRecord(record, existingHistory)) {
          existingHistory.insert(0, record);
        }
      }
      await HistoryManager.saveHistory(existingHistory);
      logger.d('История сохранена из FuelCalculatorPage: $existingHistory');
    } catch (e) {
      logger.e('Ошибка сохранения истории в FuelCalculatorPage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error)),
        );
      }
    }
  }

  void _resetFields() {
    if (!mounted) return;
    initialMileageController.clear();
    finalMileageController.clear();
    highwayKmController.clear();
    initialFuelController.clear();
    refuelController.clear();
    correctionFactorController.clear();
    heaterOperatingTimeController.clear();
    setState(() {
      result = '';
      totalMileage = 0;
      isWinter = false;
      isAC = false;
      isMountain = false;
      _calculationDone = false;
    });
  }

  void _handleContinueCalculation() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.continue_calculation),
        content: Text(l10n.choose_calculation_option),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetFields();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.new_calculation_started)),
              );
            },
            child: Text(l10n.start_new_calculation),
          ),
          TextButton(
            onPressed: () {
              if (localHistory.isNotEmpty) {
                final lastRecord = localHistory.first;
                final finalFuel = double.tryParse(lastRecord['final_fuel'].toString());
                if (finalFuel != null && finalFuel < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.negative_final_fuel)),
                  );
                } else {
                  final roundedFinalFuel = TextUtils.roundToTwoDecimals(finalFuel ?? 0.0);
                  setState(() {
                    final finalMileage = double.tryParse(lastRecord['final_mileage'].toString())?.toInt() ?? 0;
                    initialMileageController.text = finalMileage.toString();
                    initialFuelController.text = roundedFinalFuel.toStringAsFixed(2);
                    finalMileageController.clear();
                    highwayKmController.clear();
                    refuelController.clear();
                    correctionFactorController.clear();
                    heaterOperatingTimeController.clear();
                    result = '';
                    totalMileage = 0;
                    isWinter = false;
                    isAC = false;
                    isMountain = false;
                    _calculationDone = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.continued_calculation)),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.no_previous_calculation)),
                );
              }
              Navigator.pop(context);
            },
            child: Text(l10n.continue_current_calculation),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndExit() async {
    final record = await _fuelCalculationService.prepareCalculationRecord(
      totalMileage: totalMileage,
      isWinter: isWinter,
      isAC: isAC,
      isMountain: isMountain,
    );
    if (record != null) {
      await HistoryManager.saveHistoryEntry(record);
      if (mounted) {
        Navigator.pop(context, {
          'cars': List<CarData>.from(widget.cars),
          'history': List<Map<String, dynamic>>.from(localHistory),
        });
      }
    } else {
      if (!_isDirty()) {
        Navigator.pop(context);
      }
    }
  }

  void _showHelpDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _showCalculationResult(Map<String, dynamic> record) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.calculation_complete),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _formatHistoryRecord(record, l10n).map((line) => Text(line)).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: _exportHistory,
            child: Text(l10n.export),
          ),
          if (_calculationDone)
            TextButton(
              onPressed: _showFuelAdvice,
              child: Text(l10n.fuel_advice_button),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleContinueCalculation();
            },
            child: Text(l10n.continue_calculations),
          ),
        ],
      ),
    );
  }

  List<String> _formatHistoryRecord(Map<String, dynamic> record, AppLocalizations l10n) {
    final cityNorm = record['base_city_norm'] as num? ?? 0.0;
    final highwayNorm = record['base_highway_norm'] as num? ?? 0.0;
    final combinedNorm = (cityNorm + highwayNorm) / 2;

    final List<String> formatted = [
      '${l10n.date}: ${record['date'] ?? ''}',
      '${l10n.brand}: ${record['brand'] ?? ''}',
      '${l10n.license_plate}: ${record['license_plate'] ?? 'Нет'}',
      '${l10n.initial_mileage}: ${record['initial_mileage']?.toString() ?? '0'} км',
      '${l10n.final_mileage}: ${record['final_mileage']?.toString() ?? '0'} км',
      '${l10n.total_mileage}: ${record['total_mileage']?.toString() ?? '0'} км',
      '${l10n.city_mileage}: ${record['city_mileage']?.toString() ?? '0'} км',
      '${l10n.highway_mileage}: ${record['highway_mileage']?.toString() ?? '0'} км',
      '${l10n.base_city_norm}: ${cityNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
      '${l10n.base_highway_norm}: ${highwayNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
      '${l10n.combined_norm}: ${combinedNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
      '${l10n.initial_fuel_short}: ${record['initial_fuel']?.toStringAsFixed(2) ?? '0.00'} л',
      '${l10n.refuel_short}: ${record['refuel']?.toStringAsFixed(2) ?? '0.00'} л',
      '${l10n.fuel_used}: ${record['fuel_used']?.toStringAsFixed(2) ?? '0.00'} л',
      '${l10n.final_fuel}: ${record['final_fuel']?.toStringAsFixed(2) ?? '0.00'} л',
    ];

    final correctionFactor = record['correction_factor'];
// Показываем коэффициент, если он существует и не является нулем
if (correctionFactor != null && correctionFactor != 0.0) {
  formatted.add('${l10n.correction_factor}: ${correctionFactor.toStringAsFixed(2)} %');
}

    final heaterTime = record['heater_operating_time'];
    if (heaterTime != null && heaterTime > 0) {
        formatted.add('${l10n.heater_operating_time}: ${heaterTime.toStringAsFixed(2)} ч');
    }
    final heaterFuel = record['heater_fuel_used'];
    if (heaterFuel != null && heaterFuel > 0) {
        String heaterLabel = l10n.localeName == 'ru' ? 'Расход отопителем' : 'Heater Fuel';
        formatted.add('$heaterLabel: ${heaterFuel.toStringAsFixed(2)} л');
    }


    if (record['weather_multiplier'] != null) {
      formatted.add('${l10n.weather_multiplier}: ${record['weather_multiplier'].toStringAsFixed(2)}');
    }

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isBus = widget.car.vehicleType == 'Bus';

    // --- ШАГ 1: Выносим всё содержимое страницы в отдельный виджет ---
    // Это нужно, чтобы мы могли поместить его внутрь нашего нового фона.
    final pageContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             Column(
          crossAxisAlignment: CrossAxisAlignment.start, // <-- Эта строка выравнивает все по левому краю
          children: [
            // 1. Марка
            Text(
              '${l10n.brand}: ${widget.car.brand}',
              style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
            ),
            
            // 2. Гос. номер (виджет)
            // Условие: показываем только если номер существует
            if (widget.car.licensePlate != null && widget.car.licensePlate!.isNotEmpty)
              Padding(
                // Добавляем отступы сверху и снизу для красоты
                padding: const EdgeInsets.symmetric(vertical: 8.0), 
                child: LicensePlateWidget(
                  plateNumber: widget.car.licensePlate!,
                  scale: 0.7, // Можно подобрать масштаб, чтобы выглядело гармонично
                ),
              ),

            // 3. Модель
            Text(
              '${l10n.model}: ${RegExp(r'[^\d\s]+').allMatches(widget.car.model).isNotEmpty ? RegExp(r'[^\d\s]+').allMatches(widget.car.model).map((match) => match.group(0)).join(' ') : widget.car.model}',
              style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
            ),
          ],
        ),
          Text(
            '${l10n.base_city_norm}: ${widget.car.baseCityNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
          Text(
            '${l10n.base_highway_norm}: ${widget.car.baseHighwayNorm.toStringAsFixed(2)} ${l10n.liters_per_100km}',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
          Text(
            '${l10n.base_combined_norm}: ${((widget.car.baseCityNorm + widget.car.baseHighwayNorm) / 2).toStringAsFixed(2)} ${l10n.liters_per_100km}',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14), // <--- Убрали fontWeight: FontWeight.bold
          ),
          const SizedBox(height: 16),
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
            title: Text(l10n.autoCorrectionFactor),
            value: _useAutoCorrectionFactor,
            onChanged: (value) {
              setState(() {
                _useAutoCorrectionFactor = value;
                if (value) {
                  correctionFactorController.text = '0';
                }
              });
            },
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
                  readOnly: _useAutoCorrectionFactor,
                  onTap: () => FocusScope.of(context).unfocus(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.help_outline, color: theme.iconTheme.color),
                onPressed: () => _showHelpDialog(
                  l10n.correction_factor,
                  l10n.correction_factor_tooltip,
                ),
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
                  onPressed: () => _showHelpDialog(
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
            style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalMileage ${l10n.kilometers}',
            style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GradientText(
            l10n.adjustments,
            gradient: primaryActionGradient,
            style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'Roboto'),
          ),
          SwitchListTile(
            title: Text(
              l10n.winter,
              style: theme.textTheme.bodyMedium,
            ),
            value: isWinter,
            onChanged: (value) {
              setState(() => isWinter = value);
            },
          ),
          SwitchListTile(
            title: Text(
              l10n.ac,
              style: theme.textTheme.bodyMedium,
            ),
            value: isAC,
            onChanged: (value) {
              setState(() => isAC = value);
            },
          ),
          SwitchListTile(
            title: Text(
              l10n.mountain,
              style: theme.textTheme.bodyMedium,
            ),
            value: isMountain,
            onChanged: (value) {
              setState(() => isMountain = value);
            },
          ),
          const SizedBox(height: 20),
          GradientButton(
            text: l10n.calculate,
            gradient: primaryActionGradient,
            iconData: Icons.calculate,
            onPressed: () async {
              if (_useAutoCorrectionFactor) {
                setState(() => _isLoading = true);
                try {
                  const String userCity = 'Almaty';
                  final weatherService = WeatherService();
                  final weatherMultiplier = await weatherService.getWeatherMultiplier(userCity);
                  final calculatedFactor = (weatherMultiplier - 1) * 100;
                  correctionFactorController.text = calculatedFactor.toStringAsFixed(2);
                } catch (e) {
                  logger.e('Ошибка получения погоды: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.auto_factor_error)),
                    );
                    setState(() => _useAutoCorrectionFactor = false);
                  }
                  return;
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              }
              await _fuelCalculationService.calculate(
                totalMileage: totalMileage,
                isWinter: isWinter,
                isAC: isAC,
                isMountain: isMountain,
              );
              if (!_isPremium) {
                AdManager.showInterstitialAd();
              }
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: l10n.save_and_back,
                  gradient: primaryActionGradient,
                  iconData: Icons.save,
                  onPressed: () async {
                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        await _saveHistory();
                        logger.d('Возврат с FuelCalculatorPage с сохранением истории: $localHistory');
                        if (mounted) Navigator.pop(context); // close dialog
                        if (mounted) {
                          Navigator.pop(context, {
                            'cars': List<CarData>.from(widget.cars),
                            'history': List<Map<String, dynamic>>.from(localHistory),
                          });
                        }
                      } catch (e) {
                        logger.e('Ошибка при сохранении и возврате: $e');
                        if (mounted) Navigator.pop(context); // close dialog
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.error)),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GradientButton(
                  text: l10n.continue_calculations,
                  gradient: secondaryActionGradient,
                  iconData: Icons.replay,
                  onPressed: _handleContinueCalculation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.current_calculations,
            style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'Roboto'),
          ),
          const SizedBox(height: 8),
          if (result.isNotEmpty)
            Text(
              result,
              style: theme.textTheme.bodyMedium,
            )
          else
            Center(
              child: Text(
                l10n.no_calculations,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );

    // --- ШАГ 2: Собираем финальный экран с фоном ---
    return Scaffold(
      backgroundColor: Colors.transparent, // <--- ИЗМЕНЕНИЕ
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 0,
        title: Hero(
          tag: 'appLogo',
          child: Image.asset(
            'assets/fuelmaster_logo.png',
            height: 80,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // <--- ИЗМЕНЕНИЕ
        elevation: 0, // <--- ИЗМЕНЕНИЕ
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.iconTheme.color,
          ),
          onPressed: () async {
            if (_isDirty()) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.unsaved_changes),
                  content: Text(l10n.confirm_save_before_exit),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _saveAndExit();
              } else {
                Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: GradientBackground(child: pageContent), // Для светлой - применяем наш новый фон
    );
  }
}