import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityType {
  idle,      // Diam
  walking,   // Berjalan
  running,   // Lari
  unknown
}

class ActivityDetector {
  // Thresholds untuk klasifikasi
  static const double WALKING_THRESHOLD = 1.5;
  static const double RUNNING_THRESHOLD = 3.0;
  static const int SAMPLE_WINDOW = 50; // 50 sampel untuk analisis
  
  final List<double> _magnitudeBuffer = [];
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  
  ActivityType _currentActivity = ActivityType.idle;
  final _activityController = StreamController<ActivityType>.broadcast();
  
  Stream<ActivityType> get activityStream => _activityController.stream;
  ActivityType get currentActivity => _currentActivity;
  
  // Mulai monitoring
  void startMonitoring() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _processAccelerometerData(event);
    });
  }
  
  // Proses data accelerometer
  void _processAccelerometerData(AccelerometerEvent event) {
    // Hitung magnitude dari vector acceleration
    double magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    _magnitudeBuffer.add(magnitude);
    
    // Jaga buffer tetap pada ukuran window
    if (_magnitudeBuffer.length > SAMPLE_WINDOW) {
      _magnitudeBuffer.removeAt(0);
    }
    
    // Analisis hanya jika buffer sudah penuh
    if (_magnitudeBuffer.length == SAMPLE_WINDOW) {
      _classifyActivity();
    }
  }
  
  // Klasifikasi aktivitas berdasarkan data sensor
  void _classifyActivity() {
    // Hitung variance untuk deteksi gerakan
    double mean = _magnitudeBuffer.reduce((a, b) => a + b) / _magnitudeBuffer.length;
    double variance = _magnitudeBuffer
        .map((val) => pow(val - mean, 2))
        .reduce((a, b) => a + b) / _magnitudeBuffer.length;
    
    double stdDev = sqrt(variance);
    
    // Klasifikasi berdasarkan standar deviasi
    ActivityType newActivity;
    
    if (stdDev < WALKING_THRESHOLD) {
      newActivity = ActivityType.idle;
    } else if (stdDev < RUNNING_THRESHOLD) {
      newActivity = ActivityType.walking;
    } else {
      newActivity = ActivityType.running;
    }
    
    // Update hanya jika aktivitas berubah
    if (newActivity != _currentActivity) {
      _currentActivity = newActivity;
      _activityController.add(newActivity);
    }
  }
  
  // Hybrid detection: kombinasi sensor + GPS speed
  ActivityType detectWithSpeed(double speedMps) {
    // Speed dalam m/s
    // Walking: 0.5 - 2.0 m/s
    // Running: > 2.0 m/s
    
    if (speedMps < 0.5) {
      return ActivityType.idle;
    } else if (speedMps < 2.0) {
      return ActivityType.walking;
    } else {
      return ActivityType.running;
    }
  }
  
  // Hybrid: gabungkan sensor + GPS untuk akurasi lebih baik
  ActivityType getHybridActivity(double speedMps) {
    ActivityType sensorActivity = _currentActivity;
    ActivityType speedActivity = detectWithSpeed(speedMps);
    
    // Jika keduanya setuju, return hasil
    if (sensorActivity == speedActivity) {
      return sensorActivity;
    }
    
    // Jika berbeda, prioritaskan GPS untuk outdoor running
    if (speedMps > 1.0) {
      return speedActivity;
    }
    
    return sensorActivity;
  }
  
  void dispose() {
    _accelerometerSubscription?.cancel();
    _activityController.close();
  }
}