import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:collection/collection.dart';
import 'fuel_calculator_page.dart';
import 'car_info_page.dart';
import 'car_list_page.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/providers/app_settings_provider.dart';
import 'package:fuelmaster/providers/history_provider.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/license_plate_widget.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';
import 'package:fuelmaster/widgets/weather_display_widget.dart';
import 'package:fuelmaster/services/location_service.dart';

class MainMenuPage extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  const MainMenuPage({
    super.key,
    required this.history,
  });

  @override
  _MainMenuPageState createState() => _MainMenuPageState();
}

// --- ШАГ 1: ДОБАВЛЯЕМ WidgetsBindingObserver ---
// Это позволит нашему виджету отслеживать состояние приложения (свернуто/развернуто)
class _MainMenuPageState extends State<MainMenuPage> with WidgetsBindingObserver {
  CarData? _selectedCar;
  final ListEquality _listEquality = ListEquality();
  
  // --- ШАГ 2: ДОБАВЛЯЕМ КЛЮЧ ДЛЯ ВИДЖЕТА ПОГОДЫ ---
  // Изменение этого ключа заставит виджет погоды полностью перестроиться и запросить новые данные
  Key _weatherWidgetKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // --- ШАГ 3: ПОДПИСЫВАЕМСЯ НА СОБЫТИЯ ЖИЗНЕННОГО ЦИКЛА ---
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }
  
  @override
  void dispose() {
    // --- ШАГ 4: ОТПИСЫВАЕМСЯ ОТ СОБЫТИЙ ПРИ УНИЧТОЖЕНИИ ВИДЖЕТА ---
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- ШАГ 5: РЕАГИРУЕМ НА ИЗМЕНЕНИЕ СОСТОЯНИЯ ПРИЛОЖЕНИЯ ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Если пользователь вернулся в приложение
    if (state == AppLifecycleState.resumed) {
      logger.d('Приложение возобновлено. Проверка местоположения...');
      _updateLocationAndWeatherIfNeeded();
    }
  }

  // --- ШАГ 6: НОВЫЙ МЕТОД ДЛЯ ПРОВЕРКИ И ОБНОВЛЕНИЯ ГОРОДА ---
  Future<void> _updateLocationAndWeatherIfNeeded() async {
    try {
      final locationService = LocationService();
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(AppConstants.userCityKey);

      // Получаем текущий город
      final currentCity = await locationService.getCurrentCity();

      // Сравниваем новый город с сохраненным
      if (currentCity != null && currentCity != savedCity) {
        logger.i('Обнаружен новый город: $currentCity. Обновление погоды.');
        // Сохраняем новый город
        await prefs.setString(AppConstants.userCityKey, currentCity);
        // Обновляем ключ, чтобы пересоздать виджет погоды
        if (mounted) {
          setState(() {
            _weatherWidgetKey = UniqueKey();
          });
        }
      } else {
        logger.d('Местоположение не изменилось. Текущий город: $savedCity');
      }
    } catch (e) {
      logger.e('Ошибка при обновлении местоположения: $e');
    }
  }

void _refreshCarListAndSetSelection() {
    final carProvider = Provider.of<CarProvider>(context, listen: false);
    
    // Принудительно загружаем актуальный список автомобилей из БД
    carProvider.loadCars().then((_) {
      if (!mounted) return;

      final userCars = carProvider.cars.where((c) => c.isPreset == 0).toList();
      
      setState(() {
        if (userCars.isNotEmpty) {
           // После создания новой машины, она будет последней в списке.
           // Устанавливаем ее как выбранную.
          _selectedCar = userCars.last;
        } else {
          // Если пользовательских машин нет, сбрасываем выбор
          _selectedCar = null;
        }
      });
    });
  }

  void _initialize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadHistory();
      _refreshCarListAndSetSelection(); // Теперь используем наш новый надежный метод
    });
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

  void _goToCalculator() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);

    if (_selectedCar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.select_car)),
      );
      return;
    }
    
    logger.d('Navigating to FuelCalculatorPage for car: ${_selectedCar!.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FuelCalculatorPage(
          car: _selectedCar!,
          cars: Provider.of<CarProvider>(context, listen: false).cars,
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
    
    // Ждем результат со страницы создания/редактирования
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarInfoPage(
          cars: carProvider.cars,
          locale: appSettings.locale,
        ),
      ),
    );

    // Если результат равен true (т.е. мы вернулись после успешного сохранения)
    if (result == true && mounted) {
      logger.i('Возврат с CarInfoPage после сохранения. Обновление списка...');
      _refreshCarListAndSetSelection(); // Вызываем новый метод для обновления (создадим его далее)
    }
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

    // После возврата со списка авто, также обновляем данные
    if(mounted) {
      _refreshCarListAndSetSelection();
    }
  }
  
  Widget _buildMyCarsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final carProvider = context.watch<CarProvider>();

    return Card(
      elevation: 4.0,
      shadowColor: theme.colorScheme.primary.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.your_cars,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CarData>(
              value: _selectedCar,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.selected_car,
              ),
              items: carProvider.cars
                  .where((car) => car.isPreset == 0)
                  .map((car) => DropdownMenuItem(
                        value: car,
                        child: Text('${car.brand} ${car.model}', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() {
                    _selectedCar = value;
                    logger.d('Selected car id: ${_selectedCar?.id}');
                  });
                }
              },
            ),
            const SizedBox(height: 20),
           if (_selectedCar != null && _selectedCar!.licensePlate != null && _selectedCar!.licensePlate!.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (AppConstants.brandIcons.containsKey(_selectedCar!.brand))
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark 
                            ? Colors.white.withOpacity(0.9)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        AppConstants.brandIcons[_selectedCar!.brand]!,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.directions_car, size: 28);
                        },
                      ),
                    ),
                  
                  const SizedBox(width: 16),
                  LicensePlateWidget(
                    plateNumber: _selectedCar!.licensePlate!,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            GradientButton(
              text: l10n.go_to_calculator,
              gradient: primaryActionGradient,
              iconData: Icons.calculate,
              onPressed: _goToCalculator,
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GradientButton(
                  text: l10n.create_new_car,
                  iconData: Icons.add_circle_outline,
                  gradient: darkerBlueGradient,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  onPressed: _createNewCar,
                ),
                const SizedBox(height: 8),
                GradientButton(
                  text: l10n.configure_cars,
                  iconData: Icons.settings_outlined,
                  gradient: secondaryActionGradient,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  onPressed: _goToCarList,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = Provider.of<AppSettingsProvider>(context);
    final carProvider = context.watch<CarProvider>();

    final pageContent = carProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMyCarsCard(context),
                if (!appSettings.isPremium) ...[
                  const SizedBox(height: 24),
                  AdManager.buildNativeAdView(adUnitId: "R-M-16174255-2"),
                ],
              ],
            ),
          );

    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        toolbarHeight: 120,
        backgroundColor: Colors.transparent, 
        elevation: 0,
        flexibleSpace: Stack( // Используем Stack для наложения виджетов
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'appLogo',
              child: Image.asset(
                'assets/fuelmaster_logo.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 8,
              right: 16,
              // --- ШАГ 7: ПЕРЕДАЕМ КЛЮЧ В ВИДЖЕТ ПОГОДЫ ---
              child: WeatherDisplayWidget(key: _weatherWidgetKey),
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: GradientBackground(child: pageContent),
    );
  }
}