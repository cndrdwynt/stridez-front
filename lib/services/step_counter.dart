import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepCounterService {
  static final StepCounterService _instance = StepCounterService._internal();
  factory StepCounterService() => _instance;
  StepCounterService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  final _stepController = StreamController<int>.broadcast();
  
  int _todaySteps = 0;
  int _initialSteps = 0;
  String _lastSavedDate = '';
  bool _isInitialized = false;

  Stream<int> get stepStream => _stepController.stream;
  int get todaySteps => _todaySteps;

  // Inisialisasi step counter
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    var status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      print('❌ Permission denied for step counter');
      return false;
    }

    await _loadTodaySteps();
    _startListening();
    _isInitialized = true;
    print('✅ Step counter initialized');
    return true;
  }

  // Load langkah hari ini dari storage
  Future<void> _loadTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    _lastSavedDate = prefs.getString('last_step_date') ?? '';
    
    // Jika hari berbeda, reset langkah
    if (_lastSavedDate != todayKey) {
      _todaySteps = 0;
      _initialSteps = 0;
      await prefs.setString('last_step_date', todayKey);
      await prefs.setInt('steps_$todayKey', 0);
      print('🆕 New day detected, reset steps');
    } else {
      _todaySteps = prefs.getInt('steps_$todayKey') ?? 0;
      print('📥 Loaded today steps: $_todaySteps');
    }
  }

  // Mulai mendengarkan sensor
  void _startListening() {
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        // Set initial steps pada deteksi pertama
        if (_initialSteps == 0) {
          _initialSteps = event.steps;
          print('🔢 Initial steps set: $_initialSteps');
        }
        
        // Cek apakah hari sudah berganti
        final today = DateTime.now();
        final todayKey = '${today.year}-${today.month}-${today.day}';
        
        if (_lastSavedDate != todayKey) {
          await _loadTodaySteps();
          _initialSteps = event.steps; // Reset initial
        }
        
        // Hitung steps untuk hari ini
        final sessionSteps = event.steps - _initialSteps;
        _todaySteps = sessionSteps;
        
        _stepController.add(_todaySteps);
        
        // Simpan setiap 10 langkah
        if (_todaySteps % 10 == 0 && _todaySteps > 0) {
          await _saveTodaySteps();
        }
      },
      onError: (error) {
        print('❌ Step Count Error: $error');
      },
    );
  }

  // Simpan langkah hari ini
  Future<void> _saveTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    await prefs.setInt('steps_$todayKey', _todaySteps);
  }

  // Ambil langkah untuk tanggal tertentu
  Future<int> getStepsForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${date.year}-${date.month}-${date.day}';
    return prefs.getInt('steps_$dateKey') ?? 0;
  }

  // Ambil target langkah harian
  Future<int> getDailyTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('daily_step_target') ?? 6000;
  }

  // Set target langkah harian
  Future<void> setDailyTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_step_target', target);
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _stepController.close();
  }
}