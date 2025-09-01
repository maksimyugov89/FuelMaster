import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import 'fuel_calculator_page.dart';
import 'car_info_page.dart';
import 'car_list_page.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/providers/app_settings_provider.dart';
import 'package:fuelmaster/providers/history_provider.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart'; // Нам понадобится наш градиентный текст
import 'package:fuelmaster/theme.dart';

class MainMenuPage extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  const MainMenuPage({
    super.key,
    required this.history,
  });

  @override
  _MainMenuPageState createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  String? selectedCarId;
  final ListEquality _listEquality = ListEquality();

  Widget _formatCarDisplayName(CarData car) {
    final brand = car.brand.trim();
    final licensePlate = car.licensePlate?.trim() ?? '';
    final model = car.model.trim();
    final modelParts = RegExp(r'[^\d\s]+').allMatches(model);
    final modelDisplay = modelParts.isNotEmpty
        ? modelParts.map((match) => match.group(0)).join(' ')
        : model;

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(text: '$brand '),
          TextSpan(
            text: licensePlate.isNotEmpty ? '($licensePlate) ' : '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: modelDisplay),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    try {
      final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
      final loadedHistory = await HistoryManager.loadHistory();
      if (mounted) {
        if (!_listEquality.equals(historyProvider.history, loadedHistory)) {
          historyProvider.updateHistory(loadedHistory);
        }
        logger.d('История загружена в MainMenuPage: ${historyProvider.history}');
      }
    } catch (e) {
      logger.e('Ошибка загрузки истории в MainMenuPage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  void _selectCar(CarProvider carProvider) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.select_car)),
      );
      return;
    }
    final car = carProvider.cars.firstWhere((car) => car.id.toString() == selectedCarId);
    logger.d('Navigating to FuelCalculatorPage for car: ${car.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FuelCalculatorPage(
          car: car,
          cars: carProvider.cars,
          locale: appSettings.locale,
        ),
      ),
    ).then((result) {
      if (result != null && mounted && result is Map && result.containsKey('history')) {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        final newHistory = List<Map<String, dynamic>>.from(result['history']);
        historyProvider.updateHistory(newHistory);
      }
    });
  }

  void _createNewCar() async {
    if (!mounted) return;
    logger.d('Navigating to CarInfoPage to create new car');
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarInfoPage(
          cars: carProvider.cars,
          locale: appSettings.locale,
        ),
      ),
    );
    carProvider.loadCars(); // Reload cars after adding a new one
  }

  void _goToCarList() async {
    if (!mounted) return;
    logger.d('Navigating to CarListPage');
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarListPage(
          cars: carProvider.cars,
          locale: appSettings.locale,
        ),
      ),
    );
    carProvider.loadCars(); // Reload cars after editing/deleting
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final carProvider = context.watch<CarProvider>();
    final appSettings = Provider.of<AppSettingsProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 120,
        titleSpacing: 0,
        title: null,
        flexibleSpace: FlexibleSpaceBar(
          background: Hero(
            tag: 'appLogo',
            child: Image.asset(
              'assets/fuelmaster_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.background,
        elevation: isDark ? 0 : 4,
        automaticallyImplyLeading: false,
        leading: ModalRoute.of(context)?.canPop == true
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
                onPressed: () {
                  logger.d('Navigating back from MainMenuPage');
                  Navigator.pop(context);
                },
              )
            : null,
      ),
      body: carProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- БЛОК 1: Главное действие ---
                  Card(
                    elevation: 4.0,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GradientText(
                            l10n.select_car,
                            gradient: orangeGradient, // Используем оранжевый градиент для акцента
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Стилизованный контейнер для выпадающего списка
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: theme.inputDecorationTheme.fillColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCarId,
                                hint: Text(l10n.select_car),
                                isExpanded: true,
                                dropdownColor: theme.cardTheme.color,
                                style: theme.textTheme.bodyMedium,
                                items: carProvider.cars
                                    .where((car) => car.isPreset == 0)
                                    .map((car) => DropdownMenuItem(
                                          value: car.id.toString(),
                                          child: _formatCarDisplayName(car),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      selectedCarId = value;
                                      logger.d('Selected car id: $selectedCarId');
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: l10n.go_to_calculator,
                            gradient: greenGradient, // Зеленая кнопка для основного действия
                            iconData: Icons.directions_car,
                            onPressed: () => _selectCar(carProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- БЛОК 2: Управление автомобилями ---
                  Card(
                    elevation: 4.0,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GradientText(
                            l10n.your_cars, // "Ваши автомобили"
                            gradient: blueGradient,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: l10n.create_new_car,
                            gradient: blueGradient, // Синие кнопки для управления
                            iconData: Icons.add_circle_outline,
                            onPressed: _createNewCar,
                          ),
                          const SizedBox(height: 12),
                          GradientButton(
                            text: l10n.configure_cars,
                            gradient: greyGradient, // Серая для второстепенного действия
                            iconData: Icons.settings,
                            onPressed: _goToCarList,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // --- БЛОК 3: Реклама (если нужна) ---
                  if (!appSettings.isPremium) ...[
                    const SizedBox(height: 24),
                    AdManager.buildNativeAdView(),
                  ],
                ],
              ),
            ),
    );
  }
}