import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

enum ActivityState {
  idle,     // Diam
  walking,  // Jalan
  running   // Lari
}

class ActivityClassifier {
  static final ActivityClassifier _instance = ActivityClassifier._internal();
  factory ActivityClassifier() => _instance;
  ActivityClassifier._internal();

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  
  // Activity stream
  final _activityController = StreamController<ActivityState>.broadcast();
  Stream<ActivityState> get activityStream => _activityController.stream;
  
  // Current state
  ActivityState _currentActivity = ActivityState.idle;
  ActivityState get currentActivity => _currentActivity;
  
  // Sensor data buffers (untuk windowing)
  final List<double> _accelMagnitudes = [];
  final List<double> _gyroMagnitudes = [];
  final int _windowSize = 30; // 30 samples (~1 detik pada 30Hz)
  
  // Confidence score
  double _confidence = 0.0;
  double get confidence => _confidence;
  
  bool _isRunning = false;

  // === THRESHOLDS (SUDAH DITUNING) ===
  // Berdasarkan research dan testing
  static const double IDLE_ACCEL_THRESHOLD = 2.0;      // < 2.0 = diam
  static const double WALKING_ACCEL_THRESHOLD = 5.0;   // 2-5 = jalan
  static const double RUNNING_ACCEL_THRESHOLD = 5.0;   // > 5 = lari
  
  static const double IDLE_GYRO_THRESHOLD = 0.5;       // < 0.5 = diam
  static const double WALKING_GYRO_THRESHOLD = 1.5;    // 0.5-1.5 = jalan
  
  static const double IDLE_VARIANCE_THRESHOLD = 0.5;   // Variasi kecil = diam
  static const double WALKING_VARIANCE_THRESHOLD = 2.0;

  // Mulai monitoring
  void startMonitoring() {
    if (_isRunning) return;
    _isRunning = true;
    
    // Listen accelerometer
    _accelSubscription = accelerometerEventStream().listen((event) {
      _processAccelerometer(event);
    });
    
    // Listen gyroscope
    _gyroSubscription = gyroscopeEventStream().listen((event) {
      _processGyroscope(event);
    });
  }

  // Proses data accelerometer
  void _processAccelerometer(AccelerometerEvent event) {
    // Hitung magnitude (total acceleration)
    double magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    _accelMagnitudes.add(magnitude);
    
    // Jaga ukuran window
    if (_accelMagnitudes.length > _windowSize) {
      _accelMagnitudes.removeAt(0);
    }
    
    // Klasifikasi jika buffer penuh
    if (_accelMagnitudes.length >= _windowSize && 
        _gyroMagnitudes.length >= _windowSize) {
      _classifyActivity();
    }
  }

  // Proses data gyroscope
  void _processGyroscope(GyroscopeEvent event) {
    // Hitung magnitude (total rotation)
    double magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    _gyroMagnitudes.add(magnitude);
    
    // Jaga ukuran window
    if (_gyroMagnitudes.length > _windowSize) {
      _gyroMagnitudes.removeAt(0);
    }
  }

  // === KLASIFIKASI AKTIVITAS (ALGORITMA UTAMA) ===
  void _classifyActivity() {
    // Hitung statistik dari accelerometer
    double accelMean = _calculateMean(_accelMagnitudes);
    double accelVariance = _calculateVariance(_accelMagnitudes, accelMean);
    double accelStdDev = sqrt(accelVariance);
    
    // Hitung statistik dari gyroscope
    double gyroMean = _calculateMean(_gyroMagnitudes);
    double gyroStdDev = sqrt(_calculateVariance(_gyroMagnitudes, gyroMean));
    
    // === DECISION TREE CLASSIFICATION ===
    ActivityState newActivity;
    double newConfidence;
    
    // Rule 1: Cek IDLE (diam)
    if (accelStdDev < IDLE_ACCEL_THRESHOLD && 
        gyroMean < IDLE_GYRO_THRESHOLD &&
        accelVariance < IDLE_VARIANCE_THRESHOLD) {
      newActivity = ActivityState.idle;
      newConfidence = 0.95;
    }
    // Rule 2: Cek RUNNING (lari)
    else if (accelStdDev > RUNNING_ACCEL_THRESHOLD && 
             gyroMean > WALKING_GYRO_THRESHOLD) {
      newActivity = ActivityState.running;
      newConfidence = 0.90;
    }
    // Rule 3: WALKING (jalan)
    else if (accelStdDev >= IDLE_ACCEL_THRESHOLD && 
             accelStdDev <= RUNNING_ACCEL_THRESHOLD) {
      newActivity = ActivityState.walking;
      newConfidence = 0.85;
    }
    // Default: IDLE jika tidak yakin
    else {
      newActivity = ActivityState.idle;
      newConfidence = 0.70;
    }
    
    // Update hanya jika aktivitas berubah
    if (newActivity != _currentActivity) {
      _currentActivity = newActivity;
      _confidence = newConfidence;
      _activityController.add(newActivity);
      
      // Debug log
      print('🏃 Activity: $newActivity (confidence: ${(newConfidence * 100).toStringAsFixed(0)}%)');
      print('   Accel StdDev: ${accelStdDev.toStringAsFixed(2)}, Gyro Mean: ${gyroMean.toStringAsFixed(2)}');
    }
  }

  // === HELPER FUNCTIONS ===
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateVariance(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    return values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
  }

  // Stop monitoring
  void stopMonitoring() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _isRunning = false;
  }

  void dispose() {
    stopMonitoring();
    _activityController.close();
  }
}