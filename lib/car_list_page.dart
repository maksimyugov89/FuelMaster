import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'car_info_page.dart';
import 'package:fuelmaster/providers/car_provider.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';

class CarListPage extends StatefulWidget {
  final List<CarData> cars;
  final Locale locale;

  const CarListPage({
    super.key,
    required this.cars,
    required this.locale,
  });

  @override
  _CarListPageState createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  List<CarData> filteredCars = [];
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Инициализируем список только пользовательскими авто
    filteredCars = List.from(widget.cars.where((car) => car.isPreset == 0));
    searchController.addListener(_filterCars);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterCars() {
    final carProvider = context.read<CarProvider>();
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredCars = carProvider.cars.where((car) {
        if (car.isPreset == 1) return false; // Всегда исключаем предустановленные
        final licensePlate = car.licensePlate?.toLowerCase() ?? '';
        final model = car.model.toLowerCase();
        final brand = car.brand.toLowerCase();
        return brand.contains(query) || model.contains(query) || licensePlate.contains(query);
      }).toList();
    });
  }

  void _editCar(CarData car, int index) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarInfoPage(
          cars: context.read<CarProvider>().cars,
          locale: widget.locale,
          carToEdit: car,
        ),
      ),
    );
    // После возвращения обновляем список, т.к. данные могли измениться
    context.read<CarProvider>().loadCars();
  }

  void _deleteCar(int carId) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete_car),
        content: Text(l10n.delete_car_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              if (mounted) {
                try {
                  await context.read<CarProvider>().deleteCar(carId);
                  Navigator.pop(context); // Закрываем диалог
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.car_deleted)),
                  );
                } catch (e) {
                  logger.e('Ошибка удаления автомобиля: $e');
                  if (mounted) {
                    Navigator.pop(context); // Закрываем диалог
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.error)),
                    );
                  }
                }
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
  
  // Вспомогательный метод для отображения имени в заголовке карточки
  Widget _formatCarDisplayName(CarData car) {
    final theme = Theme.of(context);
    final brand = car.brand.trim();
    final licensePlate = car.licensePlate?.trim() ?? '';
    final model = car.model.trim();

    return RichText(
      text: TextSpan(
        style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18),
        children: [
          TextSpan(text: '$brand '),
          TextSpan(
            text: model,
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
           if(licensePlate.isNotEmpty)
            TextSpan(
              text: ' ($licensePlate)',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  // Новый метод для отрисовки строки "ключ-значение"
  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7))),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // Новый метод для отрисовки карточки автомобиля
  Widget _buildCarCard(CarData car, int index) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      shadowColor: theme.colorScheme.primary.withOpacity(0.1),
      child: ExpansionTile(
        title: _formatCarDisplayName(car),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            car.brand.isNotEmpty ? car.brand[0] : '?',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                _buildInfoRow(l10n.base_city_norm, '${car.baseCityNorm} ${l10n.liters_per_100km}'),
                _buildInfoRow(l10n.base_highway_norm, '${car.baseHighwayNorm} ${l10n.liters_per_100km}'),
                if (car.modification != null)
                  _buildInfoRow(l10n.modification, car.modification!),
                if (car.fuelType != null)
                   _buildInfoRow(l10n.fuel_type, car.fuelType!),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                  tooltip: l10n.edit_car,
                  onPressed: () => _editCar(car, index),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: theme.colorScheme.error),
                  tooltip: l10n.delete,
                  onPressed: () => _deleteCar(car.id!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark; // Проверяем тему
    final carProvider = context.watch<CarProvider>();
    // Обновляем список при каждой перерисовке
    _filterCars();

    // --- ШАГ 1: Выносим всё содержимое страницы в отдельный виджет ---
    final pageContent = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: l10n.search_car,
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
            ),
          ),
        ),
        Expanded(
          child: carProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredCars.isEmpty
                  ? Center(
                      child: Text(
                        searchController.text.isEmpty ? l10n.no_cars : l10n.no_data_found,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: filteredCars.length,
                      itemBuilder: (context, index) {
                        final car = filteredCars[index];
                        return _buildCarCard(car, index);
                      },
                    ),
        ),
      ],
    );

    // --- ШАГ 2: Собираем финальный экран с фоном ---
    return Scaffold(
      backgroundColor: Colors.transparent, // <--- ИЗМЕНЕНИЕ
      appBar: AppBar(
        toolbarHeight: 120.0,
        backgroundColor: Colors.transparent, // <--- ИЗМЕНЕНИЕ
        elevation: 0, // <--- ИЗМЕНЕНИЕ
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
      body: GradientBackground(child: pageContent), // Для светлой - применяем наш новый фон
    );
  }
}