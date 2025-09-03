import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fuelmaster/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:logger/logger.dart';
import 'package:fuelmaster/utils/models/car_data.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:fuelmaster/utils/logger.dart';
import 'package:fuelmaster/utils/utils.dart';
import 'package:intl/intl.dart';
import 'package:fuelmaster/utils/ad_manager.dart';
import 'package:fuelmaster/utils/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart';
import 'package:fuelmaster/utils/history_display_service.dart';
import 'package:fuelmaster/widgets/gradient_button.dart';
import 'package:fuelmaster/widgets/gradient_text.dart';
import 'package:fuelmaster/theme.dart';
import 'package:fuelmaster/widgets/gradient_background.dart';
import 'package:fuelmaster/widgets/license_plate_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fuelmaster/utils/constants.dart';

class HistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final List<CarData> cars;
  final Locale locale;
  final bool isDarkMode;

  const HistoryPage({
    super.key,
    this.history = const [],
    required this.cars,
    required this.locale,
    required this.isDarkMode,
  });

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<CarData> _cars = [];
  String? selectedModel;
  String? selectedRecord;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPremium = false;
  bool _isLoading = true;
  final DeepCollectionEquality _listEquality = DeepCollectionEquality();

  int? _expandedRecordId;
  final Map<int, GlobalKey> _cardKeys = {};
  final Map<int, ExpansionTileController> _tileControllers = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadCars(), _loadHistory()]);
    if (mounted) setState(() => _isLoading = false);
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isPremium = prefs.getBool('isPremium') ?? false);
  }

  Future<void> _loadCars() async {
    if (!mounted) return;
    try {
      final loadedCars = await DatabaseHelper.instance.getUserCars();
      if (mounted) {
        setState(() {
          _cars = loadedCars.where((car) => car.isPreset == 0).toList();
          if (_cars.isEmpty) {
            selectedModel = null;
          } else if (selectedModel == null || !_cars.any((car) => car.id.toString() == selectedModel)) {
            selectedModel = 'all'; 
          }
        });
      }
    } catch (e) {
      logger.e('Ошибка загрузки автомобилей в HistoryPage: $e');
    }
  }

  @override
  void dispose() {
    AdManager.dispose();
    for (var controller in _tileControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    try {
      final loadedHistory = await HistoryManager.loadHistoryFromDatabase();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _isPremium) {
        await HistoryManager.syncHistoryWithFirestore(user.uid);
        final syncedHistory = await HistoryManager.loadHistoryFromDatabase();
        if (mounted && !_listEquality.equals(widget.history, syncedHistory)) {
          setState(() {
            widget.history.clear();
            widget.history.addAll(syncedHistory);
          });
        }
      } else {
        if (mounted && !_listEquality.equals(widget.history, loadedHistory)) {
          setState(() {
            widget.history.clear();
            widget.history.addAll(loadedHistory);
          });
        }
      }
    } catch (e) {
      logger.e('Ошибка загрузки истории в HistoryPage: $e');
    }
  }

  Future<void> saveData(HistoryDisplayService service) async {
    if (!mounted) return;
    try {
      final filteredHistory = service.getFilteredHistory();
      await HistoryManager.saveHistory(filteredHistory);
    } catch (e) {
      logger.e('Ошибка сохранения истории в HistoryPage: $e');
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirm_delete_record_title),
        content: Text(l10n.confirm_delete_record_content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await HistoryManager.deleteHistoryRecord(record['id']);
        setState(() {
          widget.history.removeWhere((r) => r['id'] == record['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.record_deleted)));
      } catch (e) {
        logger.e('Ошибка при удалении записи: $e');
      }
    }
  }

  Future<void> _clearHistory() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clear_history),
        content: Text(l10n.clear_history_confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.clear)),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('fuel_logs');
        setState(() => widget.history.clear());
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && _isPremium) {
          final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').get();
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.history_cleared)));
      } catch (e) {
        logger.e('Ошибка при очистке истории: $e');
      }
    }
  }

  Future<void> _shareHistory(HistoryDisplayService service) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    List<Map<String, dynamic>> recordsToExport = selectedRecord != null
        ? [jsonDecode(selectedRecord!)]
        : service.getFilteredHistory();

    if (recordsToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.history_empty_export)));
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/fuel_history.txt');
    String content = recordsToExport.map((record) => service.formatHistoryRecord(record).join('\n')).join('\n\n');
    await file.writeAsString(content);

    try {
      await Share.shareXFiles([XFile(file.path)], subject: l10n.fuel_history_message);
    } catch (e) {
      logger.e('Ошибка при экспорте: $e');
    } finally {
      await file.delete();
    }
  }

  Future<void> _selectDateRange() async {
    if (!mounted) return;
    final now = DateTime.now();
    final pickedStart = await showDatePicker(context: context, initialDate: _startDate ?? now, firstDate: DateTime(2000), lastDate: now);
    if (pickedStart == null) return;
    final pickedEnd = await showDatePicker(context: context, initialDate: _endDate ?? now, firstDate: pickedStart, lastDate: now);
    if (pickedEnd == null) return;
    setState(() {
      _startDate = pickedStart;
      _endDate = pickedEnd;
    });
  }

  void _resetDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Widget _formatCarDisplayNameForCar(CarData car) {
    final brand = car.brand.trim();
    final model = car.model.trim();
    final licensePlate = car.licensePlate?.trim();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text('$brand $model', overflow: TextOverflow.ellipsis)),
        if (licensePlate != null && licensePlate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: LicensePlateWidget(plateNumber: licensePlate, scale: 0.6),
          ),
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, HistoryDisplayService service) {
    final theme = Theme.of(context);
    final car = _cars.firstWhereOrNull((c) => c.id == record['car_id']);
    final recordId = record['id'] as int;
    final isExpanded = _expandedRecordId == recordId;

    final cardKey = _cardKeys.putIfAbsent(recordId, () => GlobalKey());
    final tileController = _tileControllers.putIfAbsent(recordId, () => ExpansionTileController());

    return Card(
      key: cardKey,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      shadowColor: theme.colorScheme.primary.withOpacity(0.1),
      child: ExpansionTile(
        controller: tileController,
        title: isExpanded 
          ? _buildExpandedTitle(car, record, theme) 
          : _buildCollapsedTitle(car, theme),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: car != null && AppConstants.brandIcons.containsKey(car.brand)
            ? Container(
                width: 32,  // Уменьшенный размер для leading (чтобы поместился в CircleAvatar)
                height: 32,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark 
                    ? Colors.white.withOpacity(0.9)  // Белый фон для тёмной темы
                    : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  AppConstants.brandIcons[car.brand]!,
                  fit: BoxFit.contain,  // Чтобы логотип не обрезался
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.directions_car, color: theme.colorScheme.primary, size: 24);
                  },
                ),
              )
            : Icon(Icons.directions_car, color: theme.colorScheme.primary, size: 24),  // Fallback на стандартную иконку
        ),
        trailing: isExpanded 
          ? const Icon(Icons.expand_less) 
          : const Icon(Icons.expand_more),
        onExpansionChanged: (bool expanding) {
          setState(() {
            _expandedRecordId = expanding ? recordId : null;
          });

          if (expanding) {
            _tileControllers.forEach((id, controller) {
              if (id != recordId && controller.isExpanded) {
                controller.collapse();
              }
            });
            
            Future.delayed(const Duration(milliseconds: 250), () {
              final cardContext = cardKey.currentContext;
              if (cardContext != null && mounted) {
                Scrollable.ensureVisible(
                  cardContext,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  alignment: 0.0,
                );
              }
            });
          }
        },
        children: [
          _buildRecordDetails(record, service, theme),
        ],
      ),
    );
  }

  Widget _buildCollapsedTitle(CarData? car, ThemeData theme) {
    final brand = car?.brand ?? '';
    final model = car?.model ?? '';
    final licensePlate = car?.licensePlate;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                brand,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              if (model.isNotEmpty)
                Text(
                  model,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (licensePlate != null && licensePlate.isNotEmpty)
          LicensePlateWidget(plateNumber: licensePlate, scale: 0.65),
      ],
    );
  }

  Widget _buildExpandedTitle(CarData? car, Map<String, dynamic> record, ThemeData theme) {
    final brand = car?.brand ?? '';
    final dateString = record['date']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          brand,
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        if (dateString.isNotEmpty)
          Text(
            dateString,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
  
  Widget _buildRecordDetails(Map<String, dynamic> record, HistoryDisplayService service, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final formattedLines = service.formatHistoryRecord(record);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: formattedLines.map((line) {
              final parts = line.split(': ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${parts[0]}:', style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7))),
                    Flexible(child: Text(parts.length > 1 ? parts[1] : '', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.share, color: theme.colorScheme.primary),
                tooltip: l10n.share,
                onPressed: () {
                  setState(() => selectedRecord = jsonEncode(record));
                  _shareHistory(service);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete, color: theme.colorScheme.error),
                tooltip: l10n.delete,
                onPressed: () => _deleteRecord(record),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAdCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        alignment: Alignment.center,
        height: 270,
        padding: const EdgeInsets.all(8.0),
        child: AdManager.buildNativeAdView(adUnitId: "R-M-16174255-2"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final historyDisplayService = HistoryDisplayService(
      history: widget.history,
      cars: _cars,
      selectedModel: selectedModel,
      startDate: _startDate,
      endDate: _endDate,
      l10n: l10n,
    );
    final List<Map<String, dynamic>> chartData = historyDisplayService.getChartData();
    final List<Map<String, dynamic>> filteredHistory = historyDisplayService.getFilteredHistory();

    for (var record in filteredHistory) {
      final recordId = record['id'] as int;
      _cardKeys.putIfAbsent(recordId, () => GlobalKey());
      _tileControllers.putIfAbsent(recordId, () => ExpansionTileController());
    }

    final pageContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                expandedHeight: 120.0,
                backgroundColor: Colors.transparent, 
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'appLogo',
                    child: Image.asset('assets/fuelmaster_logo.png', fit: BoxFit.cover),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.delete_sweep, color: theme.colorScheme.error),
                    onPressed: _clearHistory,
                    tooltip: l10n.clear_history,
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 4.0,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GradientText(
                            l10n.history_title,
                            gradient: primaryActionGradient,
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            decoration: BoxDecoration(
                              color: theme.inputDecorationTheme.fillColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedModel,
                                hint: Text(l10n.select_car),
                                isExpanded: true,
                                dropdownColor: theme.cardTheme.color,
                                style: theme.textTheme.bodyMedium,
                                items: [
                                  DropdownMenuItem(value: 'all', child: Text(l10n.all_cars)),
                                  ..._cars.map((car) => DropdownMenuItem(
                                    value: car.id.toString(),
                                    child: _formatCarDisplayNameForCar(car),
                                  )),
                                ],
                                onChanged: (value) {
                                  if (value != null && mounted) {
                                    setState(() => selectedModel = value);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GradientButton(
                                  text: l10n.select_period,
                                  gradient: secondaryActionGradient,
                                  iconData: Icons.date_range,
                                  onPressed: _selectDateRange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GradientButton(
                                  text: l10n.reset_period,
                                  gradient: secondaryActionGradient,
                                  iconData: Icons.refresh,
                                  onPressed: _resetDateRange,
                                ),
                              ),
                            ],
                          ),
                          if (_startDate != null || _endDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Center(
                                child: Text(
                                  '${_startDate != null ? DateFormat('dd.MM.yy').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('dd.MM.yy').format(_endDate!) : ''}',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, color: theme.colorScheme.primary),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: l10n.share_all_history,
                            gradient: darkerBlueGradient,
                            iconData: Icons.share,
                            onPressed: () => _shareHistory(historyDisplayService),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (chartData.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Card(
                      elevation: 4.0,
                      shadowColor: theme.colorScheme.primary.withOpacity(0.2),
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
                                        getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
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
                                            child: Text(dateText, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: historyDisplayService.getChartSpots(),
                                      isCurved: true,
                                      color: theme.colorScheme.primary,
                                      barWidth: 3,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withOpacity(0.2)),
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
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(l10n.no_chart_data, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                  ),
                ),
              if (filteredHistory.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        selectedModel == null || selectedModel == 'all' ? l10n.history_empty : l10n.no_history_for_car,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _isPremium ? filteredHistory.length : filteredHistory.length * 2,
                  itemBuilder: (context, index) {
                    if (!_isPremium) {
                      if (index.isEven) {
                        return _buildAdCard();
                      }
                      final recordIndex = index ~/ 2;
                      if (recordIndex >= filteredHistory.length) return null;
                      return _buildRecordCard(filteredHistory[recordIndex], historyDisplayService);
                    }
                    return _buildRecordCard(filteredHistory[index], historyDisplayService);
                  },
                ),
            ],
          );
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(child: pageContent),
    );
  }
}

