import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static final ValueNotifier<int> todaySteps = ValueNotifier<int>(0);
  static final ValueNotifier<double> todayDistance = ValueNotifier<double>(0.0);
  static final ValueNotifier<int> todayCalories = ValueNotifier<int>(0);
  static final ValueNotifier<int> runCaloriesToday = ValueNotifier<int>(0);

  static final ValueNotifier<int> totalRuns = ValueNotifier<int>(0);
  static final ValueNotifier<int> totalCalories = ValueNotifier<int>(0);
  static final ValueNotifier<int> totalDurationSeconds = ValueNotifier<int>(0);

  /// Refresh all values from SharedPreferences and push into the notifiers.
  static Future<void> refreshFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    todaySteps.value = prefs.getInt('steps_$today') ?? 0;
    todayDistance.value = prefs.getDouble('distance_$today') ?? 0.0;
    runCaloriesToday.value = prefs.getInt('run_calories_$today') ?? 0;

    // Calculate today's total calories if not explicitly available
    todayCalories.value = prefs.getInt('calories_$today') ??
        ((todaySteps.value * 0.04).round() + runCaloriesToday.value);

    // Aggregate run history into totals
    final String? runsJson = prefs.getString('run_history_data');
    if (runsJson != null) {
      List<dynamic> historyList = [];
      try {
        historyList = jsonDecode(runsJson);
      } catch (e) {
        historyList = [];
      }

      int totalCal = 0;
      int totalSeconds = 0;
      for (var item in historyList) {
        totalCal += (item['calories'] ?? 0) as int;

        String durationStr = item['duration'] ?? "00:00";
        List<String> parts = durationStr.split(':');
        int h = 0, m = 0, s = 0;
        if (parts.length == 3) {
          h = int.tryParse(parts[0]) ?? 0;
          m = int.tryParse(parts[1]) ?? 0;
          s = int.tryParse(parts[2]) ?? 0;
        } else if (parts.length == 2) {
          m = int.tryParse(parts[0]) ?? 0;
          s = int.tryParse(parts[1]) ?? 0;
        }
        totalSeconds += (h * 3600) + (m * 60) + s;
      }

      totalRuns.value = historyList.length;
      totalCalories.value = totalCal;
      totalDurationSeconds.value = totalSeconds;
    } else {
      totalRuns.value = 0;
      totalCalories.value = 0;
      totalDurationSeconds.value = 0;
    }
  }
}
