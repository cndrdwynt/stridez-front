import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalSettings {
  final double langkah;
  final double jarak;
  final double durasi;
  final double targetWeightKg;
  final String gender;
  final int age;
  final int heightCm;
  final int weightKg;

  GoalSettings({
    required this.langkah,
    required this.jarak,
    required this.durasi,
    required this.targetWeightKg,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() => {
        'langkah': langkah,
        'jarak': jarak,
        'durasi': durasi,
        'target_weight_kg': targetWeightKg,
        'gender': gender,
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
      };

  static GoalSettings fromJson(Map<String, dynamic> j) => GoalSettings(
        langkah: (j['langkah'] ?? 8000).toDouble(),
        jarak: (j['jarak'] ?? 25).toDouble(),
        durasi: (j['durasi'] ?? 60).toDouble(),
        targetWeightKg: (j['target_weight_kg'] ?? 0).toDouble(),
        gender: (j['gender'] ?? 'Pria') as String,
        age: (j['age'] ?? 25) as int,
        heightCm: (j['height_cm'] ?? 170) as int,
        weightKg: (j['weight_kg'] ?? 78) as int,
      );
}

class GoalSettingsNotifier extends ChangeNotifier {
  late GoalSettings _settings;

  GoalSettingsNotifier(this._settings);

  GoalSettings get settings => _settings;

  static Future<GoalSettingsNotifier> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('goal_settings_json');
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return GoalSettingsNotifier(GoalSettings.fromJson(map));
      } catch (_) {}
    }

    return GoalSettingsNotifier(GoalSettings(
      langkah: 8000,
      jarak: 25,
      durasi: 60,
      targetWeightKg: 0,
      gender: 'Pria',
      age: 25,
      heightCm: 170,
      weightKg: 78,
    ));
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goal_settings_json', jsonEncode(_settings.toJson()));
  }

  void updateGoals({double? langkah, double? jarak, double? durasi, double? targetWeightKg}) {
    _settings = GoalSettings(
      langkah: langkah ?? _settings.langkah,
      jarak: jarak ?? _settings.jarak,
      durasi: durasi ?? _settings.durasi,
      targetWeightKg: targetWeightKg ?? _settings.targetWeightKg,
      gender: _settings.gender,
      age: _settings.age,
      heightCm: _settings.heightCm,
      weightKg: _settings.weightKg,
    );
    notifyListeners();
    _saveToPrefs();
  }

  void updateProfile({String? gender, int? age, int? heightCm, int? weightKg, double? targetWeightKg}) {
    _settings = GoalSettings(
      langkah: _settings.langkah,
      jarak: _settings.jarak,
      durasi: _settings.durasi,
      targetWeightKg: targetWeightKg ?? _settings.targetWeightKg,
      gender: gender ?? _settings.gender,
      age: age ?? _settings.age,
      heightCm: heightCm ?? _settings.heightCm,
      weightKg: weightKg ?? _settings.weightKg,
    );
    notifyListeners();
    _saveToPrefs();
  }
}