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
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:fuelmaster/widgets/license_plate_widget.dart';
import 'package:fuelmaster/utils/constants.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';

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
  final TextEditingController heaterFuelConsumptionController =
      TextEditingController();
  final TextEditingController passengerCapacityController =
      TextEditingController();
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
  final licensePlateMask = MaskTextInputFormatter(
      mask: 'A ### AA ###', // A - Буква, # - Цифра
      filter: {
        "#": RegExp(r'[0-9]'),
        "A": RegExp(r'[АВЕКМНОРСТУХABEKMHOPCTYX]', caseSensitive: false)
      },
      type: MaskAutoCompletionType.lazy);
  bool _isLoading = false;

  static const List<String> vehicleTypes = [
    'Passenger Car', 'Bus', 'Truck', 'Tractor', 'Dump Truck', 'Van', 'Special Equipment'
  ];

  @override
  void initState() {
    super.initState();

    _setInitialVehicleType();
    _initPresetDataLoader();
    _loadInitialDataForPage();
    _addListenersToControllers();

    // --- ИСПРАВЛЕНИЕ: Слушатель для авто-конвертации теперь находится ВНУТРИ initState ---
    licensePlateController.addListener(_convertLicensePlateLayout);
  }

  Future<void> _loadInitialDataForPage() async {
    setState(() => _isLoading = true);
    try {
      if (widget.carToEdit != null) {
        _loadCarDataForEditing(widget.carToEdit!);
        await _loadDependentPresetDataForEditing(widget.carToEdit!);
      } else {
        final brands = await _presetDataLoader.loadPresetBrands();
        if (mounted) {
          setState(() {
            presetBrands = brands;
          });
        }
      }
    } catch (e) {
      logger.e("Error loading initial data: $e");
    } finally {
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

  // --- ИСПРАВЛЕНИЕ: Этот метод теперь является частью класса и будет найден ---
  void _convertLicensePlateLayout() {
    const Map<String, String> layoutConverter = {
      'A': 'А', 'B': 'В', 'E': 'Е', 'K': 'К', 'M': 'М', 'H': 'Н',
      'O': 'О', 'P': 'Р', 'C': 'С', 'T': 'Т', 'Y': 'У', 'X': 'Х',
    };

    final originalText = licensePlateController.text;
    String convertedText = '';

    for (int i = 0; i < originalText.length; i++) {
      final char = originalText[i].toUpperCase();
      convertedText += layoutConverter[char] ?? char;
    }

    if (originalText != convertedText) {
      final selection = licensePlateController.selection;
      licensePlateController.value = licensePlateController.value.copyWith(
        text: convertedText,
        selection: selection,
      );
    }
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

  Future<void> _loadDependentPresetDataForEditing(CarData car) async {
    final l10n = AppLocalizations.of(context)!;
    final models = await _presetDataLoader.loadPresetModels(car.brand);
    final modifications = await _presetDataLoader.loadPresetModifications(car.brand, car.model, null);

    if (modifications.isEmpty) {
      modifications.add(l10n.no_modification);
    }

    if (mounted) {
      setState(() {
        presetModels = models;
        presetModifications = modifications;
      });
    }
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
                      onChanged: (value) =>
                          setStateDialog(() => searchQuery = value),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final iconWidget = AppConstants.brandIcons.containsKey(brand)
            ? Image.asset(AppConstants.brandIcons[brand]!, width: 28, height: 28,
                errorBuilder: (_, __, ___) => Icon(Icons.directions_car, size: 28, color: Theme.of(context).colorScheme.primary))
            : Icon(Icons.directions_car, size: 28, color: Theme.of(context).colorScheme.primary);

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: iconWidget,
          ),
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
      modification: modificationText.isNotEmpty &&
              modificationText != l10n.no_modification
          ? modificationText
          : null,
    );

    if (carData != null && mounted) {
      logger.d(
          'CarInfoPage: _autofillAllData received carData: ${carData.toJson()}');
      _updateControllersWithCarData(carData);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _updateControllersWithCarData(CarData carData) {
    var localPassengerCapacity = carData.passengerCapacity;
    var localHeaterConsumption = carData.heaterFuelConsumption;
    final modification = carData.modification?.toLowerCase() ?? '';
    final l10n = AppLocalizations.of(context)!;

    if ((localPassengerCapacity == null || localPassengerCapacity == 0) &&
        modification.contains('мест')) {
      final RegExp capacityRegExp = RegExp(r'(\d+)\s*мест');
      final match = capacityRegExp.firstMatch(modification);
      if (match != null) {
        final capacityString = match.group(1);
        if (capacityString != null) {
          localPassengerCapacity = int.tryParse(capacityString);
        }
      }
    }

    if (vehicleType == 'Bus') {
      localHeaterConsumption = 0.6;
    }

    setState(() {
      baseCityNormController.text = carData.baseCityNorm.toString();
      baseHighwayNormController.text = carData.baseHighwayNorm.toString();

      if (carData.baseCombinedNorm == null &&
          carData.baseCityNorm > 0 &&
          carData.baseHighwayNorm > 0) {
        baseCombinedNormController.text =
            ((carData.baseCityNorm + carData.baseHighwayNorm) / 2)
                .toStringAsFixed(2);
      } else {
        baseCombinedNormController.text =
            carData.baseCombinedNorm?.toString() ?? '';
      }

      heaterFuelConsumptionController.text =
          localHeaterConsumption?.toString() ?? '';
      passengerCapacityController.text =
          localPassengerCapacity?.toString() ?? '';

      if (carData.modification == null &&
          modificationController.text == l10n.no_modification) {
        // ничего не делаем
      } else {
        modificationController.text =
            carData.modification ?? l10n.no_modification;
      }

      fuelType = carData.fuelType;
      isCustom = false;
      logger.d(
          'CarInfoPage: _updateControllersWithCarData setting heater: ${heaterFuelConsumptionController.text}, capacity: ${passengerCapacityController.text}');
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
    final licensePlate = licensePlateController.text.replaceAll(' ', '');
    final brand = brandController.text.trim();
    final model = modelController.text.trim();
    final modification = modificationController.text.trim();
    final baseCityNormText =
        baseCityNormController.text.trim().replaceAll(',', '.');
    final baseHighwayNormText =
        baseHighwayNormController.text.trim().replaceAll(',', '.');
    final baseCombinedNormText =
        baseCombinedNormController.text.trim().replaceAll(',', '.');
    final heaterFuelConsumptionText =
        heaterFuelConsumptionController.text.trim().replaceAll(',', '.');
    final passengerCapacityText = passengerCapacityController.text.trim();

    if (licensePlate.isNotEmpty &&
        (licensePlate.length < 8 || licensePlate.length > 9)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fill_license_plate_fully)));
      return;
    }

    if (brand.isEmpty || model.isEmpty || vehicleType == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fill_all_fields)));
      return;
    }

    final baseCityNorm = double.tryParse(baseCityNormText);
    final baseHighwayNorm = double.tryParse(baseHighwayNormText);
    final baseCombinedNorm = double.tryParse(baseCombinedNormText);
    final heaterFuelConsumption = double.tryParse(heaterFuelConsumptionText);
    final passengerCapacity = int.tryParse(passengerCapacityText);

    if (baseCityNorm == null ||
        baseCityNorm <= 0 ||
        baseHighwayNorm == null ||
        baseHighwayNorm <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.positive_norm)));
      return;
    }

    if (vehicleType == 'Bus') {
      if (baseCombinedNorm == null || baseCombinedNorm <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.positive_norm)));
        return;
      }
      if (passengerCapacity == null || passengerCapacity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${l10n.passenger_capacity} ${l10n.positive_norm}')));
        return;
      }
    }

    if (licensePlate.isNotEmpty) {
      try {
        final isUnique = await DatabaseHelper.instance
            .isLicensePlateUnique(licensePlate, widget.carToEdit?.id);
        if (!isUnique) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.duplicate_license_plate)));
          return;
        }
      } catch (e) {
        logger.e('Ошибка проверки уникальности номера: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.error)));
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
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.error)),
          );
        }
      }
    } catch (e) {
      logger.e('Ошибка сохранения автомобиля: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final pageContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                GradientText(
                  widget.carToEdit != null
                      ? l10n.edit_car
                      : l10n.enter_car_details,
                  gradient: primaryActionGradient,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.car_form_step1_title,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: vehicleType,
                          decoration: InputDecoration(
                            labelText: l10n.vehicle_type,
                            prefixIcon: Icon(Icons.commute,
                                color: theme.colorScheme.primary),
                          ),
                          items: vehicleTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                type == 'Passenger Car'
                                    ? l10n.passenger_car
                                    : type == 'Bus'
                                        ? l10n.bus
                                        : type == 'Truck'
                                            ? l10n.truck
                                            : type == 'Tractor'
                                                ? l10n.tractor
                                                : type == 'Dump Truck'
                                                    ? l10n.dump_truck
                                                    : type == 'Van'
                                                        ? l10n.van
                                                        : l10n.special_equipment,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onVehicleTypeChanged,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: licensePlateController,
                          focusNode: licensePlateFocus,
                          inputFormatters: [licensePlateMask],
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: l10n.license_plate,
                            prefixIcon: Icon(Icons.confirmation_number,
                                color: theme.colorScheme.primary),
                            hintText: 'А 123 ВС 78',
                          ),
                        ),
                        Visibility(
                          visible: licensePlateController.text.isNotEmpty,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Center(
                              child: LicensePlateWidget(
                                plateNumber: licensePlateController.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.car_form_step2_title,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: brandController,
                          focusNode: brandFocus,
                          labelKey: 'brand',
                          icon: Icons.directions_car,
                          readOnly: true,
                          onTap: _showBrandDropdown,
                        ),
                        const SizedBox(height: 16),
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
                Card(
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.car_form_step3_title,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: fuelType,
                          decoration: InputDecoration(
                            labelText: l10n.fuel_type,
                            prefixIcon: Icon(Icons.local_gas_station,
                                color: theme.colorScheme.primary),
                          ),
                          items: [
                            'Б', 'Д', 'СУГ', 'КПГ', 'Электро', 'Газодизель'
                          ].map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                type == 'Б'
                                    ? l10n.petrol
                                    : type == 'Д'
                                        ? l10n.diesel
                                        : type == 'СУГ'
                                            ? l10n.lpg
                                            : type == 'КПГ'
                                                ? l10n.cng
                                                : type == 'Электро'
                                                    ? l10n.electric
                                                    : l10n.gas_diesel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (mounted) setState(() => fuelType = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: baseCityNormController,
                          focusNode: baseCityNormFocus,
                          labelKey: 'base_city_norm',
                          isNumber: true,
                          icon: Icons.location_city,
                        ),
                        const SizedBox(height: 16),
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
                          icon: Icons.blender,
                        ),
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
                GradientButton(
                  text: l10n.save_and_continue,
                  gradient: primaryActionGradient,
                  iconData: Icons.save,
                  onPressed: saveCar,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  text: l10n.clear,
                  gradient: secondaryActionGradient,
                  iconData: Icons.clear_all,
                  onPressed: clearFields,
                ),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 120.0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
      body: GradientBackground(child: pageContent),
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

