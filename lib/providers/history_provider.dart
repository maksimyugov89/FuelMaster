import 'package:flutter/material.dart';
import 'package:fuelmaster/utils/history_manager.dart';
import 'package:fuelmaster/utils/logger.dart';

class HistoryProvider with ChangeNotifier {
  List<Map<String, dynamic>> _history = [];

  List<Map<String, dynamic>> get history => _history;

  HistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      _history = await HistoryManager.loadHistory();
      notifyListeners();
      logger.d('История загружена в HistoryProvider: $_history');
    } catch (e) {
      logger.e('Ошибка загрузки истории в HistoryProvider: $e');
    }
  }

  void updateHistory(List<Map<String, dynamic>> newHistory) {
    _history = newHistory;
    notifyListeners();
    logger.d('История обновлена в HistoryProvider: $_history');
  }

  Future<void> addHistoryEntry(Map<String, dynamic> entry) async {
    await HistoryManager.saveHistoryEntry(entry);
    await _loadHistory(); // Reload to ensure consistency and sorting
  }

  Future<void> deleteHistoryEntry(int id) async {
    await HistoryManager.deleteHistoryRecord(id);
    await _loadHistory(); // Reload to ensure consistency
  }

  Future<void> updateHistoryEntry(Map<String, dynamic> entry) async {
    await HistoryManager.saveHistoryEntry(entry);
    await _loadHistory(); // Reload to ensure consistency
  }
}