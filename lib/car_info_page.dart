import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fuelmaster/widgets.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/utils/preset_data_loader.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'package:fuelmaster/theme.dart';

class CarInfoPage extends StatefulWidget {
  final List<CarData> cars;
  final Locale locale;
  final CarData? carToEdit;

  const CarInfoPage({
    super.key,
    required this.cars,
    required this.locale,
    this.carToEdit,
  });

  @override
  _CarInfoPageState createState() => _CarInfoPageState();
}

class _CarInfoPageState extends State<CarInfoPage> {
  late PresetDataLoader _presetDataLoader;
  int? selectedIndex;
  final TextEditingController licensePlateController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController modificationController = TextEditingController();
  final TextEditingController baseCityNormController = TextEditingController();
  final TextEditingController baseHighwayNormController = TextEditingController();
  final TextEditingController baseCombinedNormController = TextEditingController();
  final TextEditingController heaterFuelConsumptionController = TextEditingController();
  final TextEditingController passengerCapacityController = TextEditingController();
  String? fuelType;
  String? vehicleType;
  bool isCustom = true;
  List<String> presetBrands = [];
  List<String> presetModels = [];
  List<String> presetModifications = [];
  final FocusNode licensePlateFocus = FocusNode();
  final FocusNode brandFocus = FocusNode();
  final FocusNode modelFocus = FocusNode();
  final FocusNode modificationFocus = FocusNode();
  final FocusNode baseCityNormFocus = FocusNode();
  final FocusNode baseHighwayNormFocus = FocusNode();
  final FocusNode baseCombinedNormFocus = FocusNode();
  final FocusNode heaterFuelConsumptionFocus = FocusNode();
  final FocusNode passengerCapacityFocus = FocusNode();
  final Debouncer debouncer = Debouncer(duration: const Duration(milliseconds: 300));
  bool _isLoading = false;

  // Карта для иконок марок
  static const Map<String, String> brandIcons = {
    'Acura': 'assets/car_brands/acura.png', 'Alfa Romeo': 'assets/car_brands/alfa_romeo.png', 'Aston Martin': 'assets/car_brands/aston_martin.png', 'Audi': 'assets/car_brands/audi.png', 'Bentley': 'assets/car_brands/bentley.png', 'BMW': 'assets/car_brands/bmw.png', 'Богдан': 'assets/car_brands/bogdan.png', 'Bugatti': 'assets/car_brands/bugatti.png', 'Buick': 'assets/car_brands/buick.png', 'Cadillac': 'assets/car_brands/cadillac.png', 'Chery': 'assets/car_brands/chery.png', 'Chevrolet': 'assets/car_brands/chevrolet.png', 'Chrysler': 'assets/car_brands/chrysler.png', 'Citroen': 'assets/car_brands/citroen.png', 'Daewoo': 'assets/car_brands/daewoo.png', 'Dodge': 'assets/car_brands/dodge.png', 'Ferrari': 'assets/car_brands/ferrari.png', 'Fiat': 'assets/car_brands/fiat.png', 'Ford': 'assets/car_brands/ford.png', 'Foton': 'assets/car_brands/Foton.png', 'ГАЗ': 'assets/car_brands/gaz.png', 'Genesis': 'assets/car_brands/genesis.png', 'GMC': 'assets/car_brands/gmc.png', 'Golden Dragon': 'assets/car_brands/Golden_Dragon.png', 'Great Wall': 'assets/car_brands/great_wall.png', 'Higer': 'assets/car_brands/Higer.png', 'Honda': 'assets/car_brands/honda.png', 'Hyundai': 'assets/car_brands/hyundai.png', 'Infiniti': 'assets/car_brands/infiniti.png', 'Iveco': 'assets/car_brands/Iveco.png', 'ИЖ': 'assets/car_brands/izh.png', 'Jaguar': 'assets/car_brands/jaguar.png', 'Jeep': 'assets/car_brands/jeep.png', 'KIA': 'assets/car_brands/kia.png', 'Lada': 'assets/car_brands/lada.png', 'Lamborghini': 'assets/car_brands/lamborghini.png', 'Land Rover': 'assets/car_brands/land_rover.png', 'Lexus': 'assets/car_brands/lexus.png', 'ЛиАЗ': 'assets/car_brands/Liaz.png', 'Lifan': 'assets/car_brands/lifan.png', 'Lincoln': 'assets/car_brands/lincoln.png', 'MAN': 'assets/car_brands/MAN.png', 'Maserati': 'assets/car_brands/maserati.png', 'Mazda': 'assets/car_brands/mazda.png', 'Mercedes-Benz': 'assets/car_brands/mercedes.png', 'MINI': 'assets/car_brands/mini.png', 'Mitsubishi': 'assets/car_brands/mitsubishi.png', 'НефАЗ': 'assets/car_brands/Nefaz.png', 'Nissan': 'assets/car_brands/nissan.png', 'Opel': 'assets/car_brands/opel.png', 'ПАЗ': 'assets/car_brands/PAZ.png', 'Peugeot': 'assets/car_brands/peugeot.png', 'Porsche': 'assets/car_brands/porsche.png', 'Ram': 'assets/car_brands/ram.png', 'Renault': 'assets/car_brands/renault.png', 'Rolls-Royce': 'assets/car_brands/rolls_royce.png', 'Rover': 'assets/car_brands/rover.png', 'Saab': 'assets/car_brands/saab.png', 'Scania': 'assets/car_brands/Scania.png', 'Scion': 'assets/car_brands/scion.png', 'Seat': 'assets/car_brands/seat.png', 'СеАЗ': 'assets/car_brands/seaz.png', 'Shenlong': 'assets/car_brands/Shenlong.png', 'Skoda': 'assets/car_brands/skoda.png', 'smart': 'assets/car_brands/smart.png', 'Ssang Yong': 'assets/car_brands/ssang_yong.png', 'Subaru': 'assets/car_brands/subaru.png', 'Suzuki': 'assets/car_brands/suzuki.png', 'TAGAZ': 'assets/car_brands/tagaz.png', 'Tesla': 'assets/car_brands/tesla.png', 'Toyota': 'assets/car_brands/toyota.png', 'УАЗ': 'assets/car_brands/uaz.png', 'УРАЛ': 'assets/car_brands/URAL.png', 'ВАЗ': 'assets/car_brands/vaz.png', 'Волга': 'assets/car_brands/volga.png', 'Volgabus': 'assets/car_brands/Volgabus.png', 'Volkswagen': 'assets/car_brands/volkswagen.png', 'Volvo': 'assets/car_brands/volvo.png', 'Vortex': 'assets/car_brands/vortex.png', 'Yutong': 'assets/car_brands/Yutong.png', 'ЗАЗ': 'assets/car_brands/zaz.png', 'АТС': 'assets/car_brands/АТС.png', 'ЛУИДОР': 'assets/car_brands/ЛУИДОР.png', 'МАЗ': 'assets/car_brands/МАЗ.png', 'МАРЗ': 'assets/car_brands/МАРЗ.png',
  };

  static const List<String> vehicleTypes = [
    'Passenger Car', 'Bus', 'Truck', 'Tractor', 'Dump Truck', 'Van', 'Special Equipment'
  ];

  @override
    void initState() {
      super.initState();

      // Сначала инициализируем все синхронные переменные и объекты
      _setInitialVehicleType();
      _initPresetDataLoader();
      
      // Затем запускаем единый асинхронный метод для загрузки данных
      _loadInitialDataForPage();

      // Слушатели контроллеров остаются без изменений
      _addListenersToControllers();
    }

    // Новый вспомогательный метод для асинхронной загрузки
    Future<void> _loadInitialDataForPage() async {
    // Показываем индикатор загрузки в самом начале
    setState(() => _isLoading = true);

    try { // Обернем в try-finally для надежности
      if (widget.carToEdit != null) {
        // Если редактируем, просто загружаем данные
        _loadCarDataForEditing(widget.carToEdit!);
      } else {
        // Если создаем новую, нужно загрузить список брендов
        final brands = await _presetDataLoader.loadPresetBrands();
        if (mounted) {
          // Только после загрузки обновляем состояние
          setState(() {
            presetBrands = brands;
          });
        }
      }
    } catch (e) {
      logger.e("Error loading initial data: $e");
    } finally {
      // В самом конце, ВНЕ ЗАВИСИМОСТИ от результата, убираем индикатор загрузки
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setInitialVehicleType() {
    vehicleType = widget.carToEdit?.vehicleType ?? 'Passenger Car';
  }

  void _initPresetDataLoader() {
  _presetDataLoader = PresetDataLoader(
    context: context,
    vehicleType: vehicleType,
    onLoadingChanged: (loading) {},
  );
}

  void _loadCarDataForEditing(CarData car) {
    licensePlateController.text = car.licensePlate ?? '';
    brandController.text = car.brand;
    modelController.text = car.model;
    modificationController.text = car.modification ?? '';
    baseCityNormController.text = car.baseCityNorm.toString();
    baseHighwayNormController.text = car.baseHighwayNorm.toString();
    baseCombinedNormController.text = car.baseCombinedNorm?.toString() ?? '';
    heaterFuelConsumptionController.text = car.heaterFuelConsumption?.toString() ?? '';
    passengerCapacityController.text = car.passengerCapacity?.toString() ?? '';
    fuelType = car.fuelType;
    isCustom = car.isPreset == 0;
    selectedIndex = widget.cars.indexWhere((c) => c.id == car.id);
  }

  void _addListenersToControllers() {
    brandController.addListener(() => debouncer.run(() => setState(() {})));
    licensePlateController.addListener(() => debouncer.run(() => setState(() {})));
    modelController.addListener(() => debouncer.run(() => setState(() {})));
    modificationController.addListener(() => debouncer.run(() => setState(() {})));
    baseCityNormController.addListener(() => debouncer.run(() => setState(() {})));
    baseHighwayNormController.addListener(() => debouncer.run(() => setState(() {})));
    baseCombinedNormController.addListener(() => debouncer.run(() => setState(() {})));
    heaterFuelConsumptionController.addListener(() => debouncer.run(() => setState(() {})));
    passengerCapacityController.addListener(() => debouncer.run(() => setState(() {})));
  }

  void _onVehicleTypeChanged(String? value) {
    if (value == null || value == vehicleType) return;
    
    setState(() {
      vehicleType = value;
      isCustom = true;
      _clearCarDetails();
      _initPresetDataLoader(); 
    });

    _presetDataLoader.loadPresetBrands().then((brands) {
      if (!mounted) return;
      setState(() => presetBrands = brands);
    });
  }

  void _clearCarDetails() {
      brandController.clear();
      modelController.clear();
      modificationController.clear();
      baseCityNormController.clear();
      baseHighwayNormController.clear();
      baseCombinedNormController.clear();
      heaterFuelConsumptionController.clear();
      passengerCapacityController.clear();
      presetModels = [];
      presetModifications = [];
  }

  void _showSearchableDropdown({
    required String title,
    required List<String> items,
    required ValueChanged<String> onItemSelected,
    Widget Function(String item)? itemBuilder,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filteredItems = items
                .where((item) => item.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) => setStateDialog(() => searchQuery = value),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.search,
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final tile = itemBuilder != null
                              ? itemBuilder(item)
                              : ListTile(title: Text(item, overflow: TextOverflow.ellipsis));
                          return InkWell(
                            onTap: () {
                              onItemSelected(item);
                              Navigator.pop(context);
                            },
                            child: tile,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBrandDropdown() async {
    final loadedBrands = await _presetDataLoader.loadPresetBrands();
    if (!mounted) return;
    setState(() => presetBrands = loadedBrands);
    _showSearchableDropdown(
      title: AppLocalizations.of(context)!.select_brand,
      items: presetBrands,
      onItemSelected: _onBrandSelected,
      itemBuilder: (brand) {
        return ListTile(
          leading: brandIcons.containsKey(brand)
              ? Image.asset(brandIcons[brand]!, width: 32, height: 32,
                  errorBuilder: (_, __, ___) => Icon(Icons.directions_car, color: Theme.of(context).colorScheme.primary))
              : Icon(Icons.directions_car, color: Theme.of(context).colorScheme.primary),
          title: Text(brand, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }

  void _onBrandSelected(String brand) async {
    setState(() {
      brandController.text = brand;
      modelController.clear();
      modificationController.clear();
      presetModels = [];
      presetModifications = [];
    });
    final loadedModels = await _presetDataLoader.loadPresetModels(brand);
    if (!mounted) return;
    setState(() => presetModels = loadedModels);
  }
  
  void _showModelDropdown() async {
    if (brandController.text.isEmpty) return;
    _showSearchableDropdown(
      title: AppLocalizations.of(context)!.select_model,
      items: presetModels,
      onItemSelected: _onModelSelected,
    );
  }

  void _onModelSelected(String model) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      modelController.text = model;
      modificationController.clear();
      presetModifications = [];
    });

    final loadedModifications = await _presetDataLoader.loadPresetModifications(
        brandController.text, model, null);

    if (!mounted) return;

    if (loadedModifications.isEmpty) {
      loadedModifications.add(l10n.no_modification);
    }
    
    setState(() => presetModifications = loadedModifications);

    if (loadedModifications.length == 1) {
      _onModificationSelected(loadedModifications.first);
    } else {
      _showModificationDropdown();
    }
  }
  
  void _showModificationDropdown() async {
    if (modelController.text.isEmpty) return;
      _showSearchableDropdown(
      title: AppLocalizations.of(context)!.modification,
      items: presetModifications,
      onItemSelected: _onModificationSelected,
    );
  }

  void _onModificationSelected(String modification) {
    setState(() => modificationController.text = modification);
    _autofillAllData();
  }

  Future<void> _autofillAllData() async {
    if (brandController.text.isEmpty || modelController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    final l10n = AppLocalizations.of(context)!;
    final modificationText = modificationController.text;

    final carData = await _presetDataLoader.getFullCarDataFromPreset(
      brand: brandController.text,
      model: modelController.text,
      generation: null,
      modification: modificationText.isNotEmpty && modificationText != l10n.no_modification 
          ? modificationText 
          : null,
    );

    if (carData != null && mounted) {
      logger.d('CarInfoPage: _autofillAllData received carData: ${carData.toJson()}');
      _updateControllersWithCarData(carData);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _updateControllersWithCarData(CarData carData) {
    var localPassengerCapacity = carData.passengerCapacity;
    var localHeaterConsumption = carData.heaterFuelConsumption;
    final modification = carData.modification?.toLowerCase() ?? '';
    final l10n = AppLocalizations.of(context)!;

    if ((localPassengerCapacity == null || localPassengerCapacity == 0) && modification.contains('мест')) {
      final RegExp capacityRegExp = RegExp(r'(\d+)\s*мест');
      final match = capacityRegExp.firstMatch(modification);
      if (match != null) {
        final capacityString = match.group(1);
        if (capacityString != null) {
          localPassengerCapacity = int.tryParse(capacityString);
        }
      }
    }
    
    // --- ИЗМЕНЕНО: Начало блока ---
    // Безусловно устанавливаем норму 0.6 для автобусов, согласно приказу Минтранса.
    // Предыдущая логика парсинга из модификации заменена.
    if (vehicleType == 'Bus') {
      localHeaterConsumption = 0.6;
    }
    // --- ИЗМЕНЕНО: Конец блока ---
    
    setState(() {
        baseCityNormController.text = carData.baseCityNorm.toString();
        baseHighwayNormController.text = carData.baseHighwayNorm.toString();
        
        if (carData.baseCombinedNorm == null && carData.baseCityNorm > 0 && carData.baseHighwayNorm > 0) {
          baseCombinedNormController.text = ((carData.baseCityNorm + carData.baseHighwayNorm) / 2).toStringAsFixed(2);
        } else {
          baseCombinedNormController.text = carData.baseCombinedNorm?.toString() ?? '';
        }
        
        heaterFuelConsumptionController.text = localHeaterConsumption?.toString() ?? '';
        passengerCapacityController.text = localPassengerCapacity?.toString() ?? '';

        if (carData.modification == null && modificationController.text == l10n.no_modification) {
            // ничего не делаем, оставляем текст "Нет модификации"
        } else {
            modificationController.text = carData.modification ?? l10n.no_modification;
        }

        fuelType = carData.fuelType;
        isCustom = false;
        logger.d('CarInfoPage: _updateControllersWithCarData setting heater: ${heaterFuelConsumptionController.text}, capacity: ${passengerCapacityController.text}');
    });
  }

  @override
  void dispose() {
    licensePlateController.dispose();
    brandController.dispose();
    modelController.dispose();
    modificationController.dispose();
    baseCityNormController.dispose();
    baseHighwayNormController.dispose();
    baseCombinedNormController.dispose();
    heaterFuelConsumptionController.dispose();
    passengerCapacityController.dispose();
    licensePlateFocus.dispose();
    brandFocus.dispose();
    modelFocus.dispose();
    modificationFocus.dispose();
    baseCityNormFocus.dispose();
    baseHighwayNormFocus.dispose();
    baseCombinedNormFocus.dispose();
    heaterFuelConsumptionFocus.dispose();
    passengerCapacityFocus.dispose();
    debouncer.dispose();
    super.dispose();
  }

  void clearFields() {
    licensePlateController.clear();
    _clearCarDetails();
    setState(() {
      selectedIndex = null;
      fuelType = null;
      isCustom = true;
    });
  }

  void saveCar() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final carProvider = context.read<CarProvider>();
    final licensePlate = licensePlateController.text.trim();
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final modification = modificationController.text.trim();
    final baseCityNormText = baseCityNormController.text.trim().replaceAll(',', '.');
    final baseHighwayNormText = baseHighwayNormController.text.trim().replaceAll(',', '.');
    final baseCombinedNormText = baseCombinedNormController.text.trim().replaceAll(',', '.');
    final heaterFuelConsumptionText = heaterFuelConsumptionController.text.trim().replaceAll(',', '.');
    final passengerCapacityText = passengerCapacityController.text.trim();

    if (brand.isEmpty || model.isEmpty || vehicleType == null || modification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fill_all_fields)));
      return;
    }

    final baseCityNorm = double.tryParse(baseCityNormText);
    final baseHighwayNorm = double.tryParse(baseHighwayNormText);
    final baseCombinedNorm = double.tryParse(baseCombinedNormText);
    final heaterFuelConsumption = double.tryParse(heaterFuelConsumptionText);
    final passengerCapacity = int.tryParse(passengerCapacityText);

    if (baseCityNorm == null || baseCityNorm <= 0 || baseHighwayNorm == null || baseHighwayNorm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.positive_norm)));
      return;
    }

    if (vehicleType == 'Bus') {
      if (baseCombinedNorm == null || baseCombinedNorm <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.positive_norm)));
        return;
      }
      if (passengerCapacity == null || passengerCapacity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.passenger_capacity} ${l10n.positive_norm}')));
        return;
      }
    }

    if (licensePlate.isNotEmpty) {
      try {
        final isUnique = await DatabaseHelper.instance.isLicensePlateUnique(licensePlate, widget.carToEdit?.id);
        if (!isUnique) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.duplicate_license_plate)));
          return;
        }
      } catch (e) {
        logger.e('Ошибка проверки уникальности номера: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.error)));
        }
        return;
      }
    }

    final car = CarData(
      id: widget.carToEdit?.id,
      brand: brand,
      model: model,
      licensePlate: licensePlate.isEmpty ? null : licensePlate,
      generation: null,
      modification: modification == l10n.no_modification ? null : modification,
      baseCityNorm: baseCityNorm,
      baseHighwayNorm: baseHighwayNorm,
      baseCombinedNorm: baseCombinedNorm ?? (baseCityNorm + baseHighwayNorm) / 2,
      fuelType: fuelType,
      vehicleType: vehicleType,
      isPreset: 0,
      passengerCapacity: passengerCapacity,
      heaterFuelConsumption: heaterFuelConsumption,
    );

    try {
      bool success;
      if (widget.carToEdit == null) {
        success = await carProvider.addCar(car);
      } else {
        success = await carProvider.updateCar(car);
      }
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.car_saved)),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.error)),
          );
        }
      }
    } catch (e) {
      logger.e('Ошибка сохранения автомобиля: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 120.0,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Убираем автоматическую кнопку назад
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: FlexibleSpaceBar(
          background: Hero(
            tag: 'appLogo',
            child: Image.asset(
              'assets/fuelmaster_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                // ✨ НАЧАЛО НОВОГО СПИСКА CHILDREN
                children: [
                  // --- ЗАГОЛОВОК СТРАНИЦЫ ---
                  GradientText(
                    widget.carToEdit != null ? l10n.edit_car : l10n.enter_car_details,
                    gradient: blueGradient,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  // --- КАРТОЧКА: ШАГ 1 ---
                  Card(
                    elevation: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.car_form_step1_title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 16),
                          // Выбор типа ТС
                          DropdownButtonFormField<String>(
                            value: vehicleType,
                            decoration: InputDecoration(
                              labelText: l10n.vehicle_type,
                              prefixIcon: Icon(Icons.commute, color: theme.colorScheme.primary),
                            ),
                            items: vehicleTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text( // Возвращаем простой Text
                          // Ваша логика для названий
                          type == 'Passenger Car' ? l10n.passenger_car :
                          type == 'Bus' ? l10n.bus :
                          type == 'Truck' ? l10n.truck :
                          type == 'Tractor' ? l10n.tractor :
                          type == 'Dump Truck' ? l10n.dump_truck :
                          type == 'Van' ? l10n.van :
                          l10n.special_equipment,
                          overflow: TextOverflow.ellipsis, // Используем ellipsis для длинных строк
                        ),
                      );
                    }).toList(),
                    onChanged: _onVehicleTypeChanged,
                  ),
                  const SizedBox(height: 16),
                  // Гос. номер
                  CustomTextField(
                    controller: licensePlateController,
                    focusNode: licensePlateFocus,
                    labelKey: 'license_plate',
                    icon: Icons.confirmation_number,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- КАРТОЧКА: ШАГ 2 ---
          Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.car_form_step2_title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  // Марка
                  CustomTextField(
                    controller: brandController,
                    focusNode: brandFocus,
                    labelKey: 'brand',
                    icon: Icons.directions_car,
                    readOnly: true,
                    onTap: _showBrandDropdown,
                  ),
                  const SizedBox(height: 16),
                  // Модель
                  CustomTextField(
                    controller: modelController,
                    focusNode: modelFocus,
                    labelKey: 'model',
                    icon: Icons.directions_car,
                    enabled: brandController.text.isNotEmpty,
                    readOnly: true,
                    onTap: _showModelDropdown,
                  ),
                  const SizedBox(height: 16),
                  // Модификация
                  CustomTextField(
                    controller: modificationController,
                    focusNode: modificationFocus,
                    labelKey: 'modification',
                    icon: Icons.car_repair,
                    enabled: modelController.text.isNotEmpty,
                    readOnly: true,
                    onTap: _showModificationDropdown,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- КАРТОЧКА: ШАГ 3 ---
          Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.car_form_step3_title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  // Тип топлива
                  DropdownButtonFormField<String>(
                    value: fuelType,
                    decoration: InputDecoration(
                      labelText: l10n.fuel_type,
                      prefixIcon: Icon(Icons.local_gas_station, color: theme.colorScheme.primary),
                    ),
                    items: ['Б', 'Д', 'СУГ', 'КПГ', 'Электро', 'Газодизель'].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          // Ваша логика названий
                          type == 'Б' ? l10n.petrol :
                          type == 'Д' ? l10n.diesel :
                          type == 'СУГ' ? l10n.lpg :
                          type == 'КПГ' ? l10n.cng :
                          type == 'Электро' ? l10n.electric :
                          l10n.gas_diesel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (mounted) setState(() => fuelType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Норма Город
                  CustomTextField(
                    controller: baseCityNormController,
                    focusNode: baseCityNormFocus,
                    labelKey: 'base_city_norm',
                    isNumber: true,
                    icon: Icons.location_city,
                  ),
                  const SizedBox(height: 16),
                  // Норма Трасса
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
                    icon: Icons.blender, // Иконка, символизирующая "смешивание"
                  ),
                  // Поля для автобуса (появляются по условию)
                  if (vehicleType == 'Bus') ...[
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
          ),
          const SizedBox(height: 32),
          // --- ФИНАЛЬНЫЕ КНОПКИ ---
          GradientButton(
            text: l10n.save_and_continue,
            gradient: greenGradient,
            iconData: Icons.save,
            onPressed: saveCar,
          ),
          const SizedBox(height: 12),
          GradientButton(
            text: l10n.clear,
            gradient: greyGradient,
            iconData: Icons.clear_all,
            onPressed: clearFields,
          ),
        ],
        // ✨ КОНЕЦ НОВОГО СПИСКА CHILDREN
      ),
            ),
    );
  }
}

class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({required this.duration});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}