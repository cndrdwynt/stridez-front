import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import 'home_page.dart';
import 'lari_finish_page.dart';
import 'akun_page.dart';

// ============== MODEL DATA SENSOR/WAYPOINT ==============
class SensorWaypoint {
  final double latitude;
  final double longitude;
  final double accelX;
  final double gyroZ;
  final DateTime timestamp;

  

  SensorWaypoint({
    required this.latitude,
    required this.longitude,
    required this.accelX,
    required this.gyroZ,
    required this.timestamp,
    
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'accel_x': accelX,
    'gyro_z': gyroZ,
    'timestamp': timestamp.toIso8601String(),
  };
}

// ============== CUSTOM PAINTER PROGRESS LINGKARAN ==============
class TargetProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  TargetProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * 3.1416,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1416 / 2,
      2 * 3.1416 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============== HALAMAN UTAMA LARI ==============
class LariStartPage extends StatefulWidget {
  final bool isTargetJarak;
  final double targetJarak;
  final int targetWaktu;
  final String? initialStartLocationName;

  const LariStartPage({
    super.key,
    required this.isTargetJarak,
    required this.targetJarak,
    required this.targetWaktu,
    this.initialStartLocationName,
  });

  @override
  State<LariStartPage> createState() => _LariStartPageState();
}

class _LariStartPageState extends State<LariStartPage> {
  // ============== STATE VARIABLES ==============
  
  // Lokasi
  gmaps.LatLng? _currentLocation = const gmaps.LatLng(-7.2820, 112.7944);
  Position? _previousPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Sensor
  final List<SensorWaypoint> _allWaypoints = [];
  double _currentAccelX = 0.0;
  double _currentGyroZ = 0.0;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;

  // Rute
  final List<gmaps.LatLng> _routePoints = [];

  // Tracking
  bool isPaused = false;
  Timer? _timer;
  double currentProgress = 0.0;
  double currentDistance = 0.0;
  double _currentSpeed = 0.0;
  int durationMinutes = 0;
  int durationSeconds = 0;
  int calories = 0;
  String? _currentAddress;
  bool _isLoading = true;

  // ============== GETTERS & HELPERS ==============

  bool get isTanpaTarget => widget.targetJarak == 0 && widget.targetWaktu == 0;

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM', 'id_ID').format(now);
  }

  String _formatDuration(int minutes, int seconds) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  // ============== SENSOR STREAMS ==============

  void _startSensorStreams() {
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((AccelerometerEvent event) {
      if (!isPaused && mounted) {
        _currentAccelX = event.x;
      }
    });

    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((GyroscopeEvent event) {
      if (!isPaused && mounted) {
        _currentGyroZ = event.z;
      }
    });
  }

  // ============== TIMER & LOKASI ==============

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      const double minRunningSpeed = 0.5;

      if (_currentSpeed > minRunningSpeed && !isPaused) {
        setState(() {
          if (durationSeconds < 59) {
            durationSeconds++;
          } else {
            durationSeconds = 0;
            durationMinutes++;
          }

          if (widget.isTargetJarak) {
            currentProgress = widget.targetJarak == 0
                ? 0
                : (currentDistance / widget.targetJarak);
          } else {
            currentProgress = widget.targetWaktu == 0
                ? 0
                : ((durationMinutes * 60 + durationSeconds) / (widget.targetWaktu * 60));
          }

          currentProgress = currentProgress.clamp(0.0, 1.0);
        });
      }
    });
  }

  void _startPositionStream() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        gmaps.LatLng newPoint = gmaps.LatLng(
          position.latitude,
          position.longitude,
        );

        _currentLocation = newPoint;
        _isLoading = false;

        if (!isPaused) {
          _routePoints.add(newPoint);
          _allWaypoints.add(SensorWaypoint(
            latitude: position.latitude,
            longitude: position.longitude,
            accelX: _currentAccelX,
            gyroZ: _currentGyroZ,
            timestamp: position.timestamp,
          ));
        }

        _currentSpeed = position.speed;

        if (_previousPosition != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            _previousPosition!.latitude,
            _previousPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distanceInMeters > 0) {
            currentDistance += distanceInMeters / 1000;
          }
        }

        _previousPosition = position;
      });

      _updateAddressFromLocation();
    });
  }

  Future<void> _updateAddressFromLocation() async {
    if (_currentLocation == null ||
        (_currentLocation!.latitude == -7.2820 &&
            _currentLocation!.longitude == 112.7944)) {
      if (_currentAddress == null || _currentAddress!.isEmpty) {
        setState(() {
          _currentAddress = "Mencari lokasi...";
        });
      }
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          final parts = <String>[];
          if (p.name != null && p.name!.isNotEmpty) parts.add(p.name!);
          if (p.subLocality != null && p.subLocality!.isNotEmpty) {
            parts.add(p.subLocality!);
          }
          if (p.locality != null && p.locality!.isNotEmpty) {
            parts.add(p.locality!);
          }
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            parts.add(p.administrativeArea!);
          }

          _currentAddress = parts.isNotEmpty
              ? parts.join(', ')
              : '${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}';
        });
      } else {
        setState(() {
          _currentAddress =
              '${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = _currentLocation != null
            ? '${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}'
            : 'Gagal memuat alamat';
      });
    }
  }

  // ============== LIFECYCLE ==============

  @override
  void initState() {
    super.initState();
    _updateAddressFromLocation();
    _startPositionStream();
    _startTimer();
    _startSensorStreams();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    super.dispose();
  }

  // ============== NAVIGASI ==============

  void _onPauseResume() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  void _onFinish() {
    _timer?.cancel();

    final List<Map<String, dynamic>> waypointsJson =
        _allWaypoints.map((wp) => wp.toJson()).toList();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LariFinishPage(
          routePoints: _routePoints,
          distance: currentDistance,
          durationMinutes: durationMinutes,
          durationSeconds: durationSeconds,
          calories: calories,
          waypointsData: waypointsJson,
        ),
      ),
    );
  }

  // ============== WIDGETS ==============

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
        BottomNavigationBarItem(icon: Icon(Icons.run_circle), label: 'Lari'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Akun'),
      ],
      currentIndex: 1,
      selectedItemColor: const Color(0xFFE54721),
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AccountPage()),
          );
        }
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Mencari lokasi Anda..."),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 40,
      left: 24,
      right: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LARI',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getFormattedDate(),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.black87, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _currentAddress ?? 'Lokasi tidak terdeteksi',
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle() {
    return Positioned(
      top: 180,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(220, 220),
                painter: TargetProgressPainter(
                  progress: currentProgress,
                  color: const Color(0xFFE54721),
                  strokeWidth: 18,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (widget.isTargetJarak || isTanpaTarget)
                        ? '${currentDistance.toStringAsFixed(1)} Km'
                        : _formatDuration(durationMinutes, durationSeconds),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (!isTanpaTarget) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.isTargetJarak
                          ? '${widget.targetJarak.toStringAsFixed(1)} Km'
                          : '${widget.targetWaktu} Min',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Target Harian',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Positioned(
      bottom: 140,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withOpacity(0.25),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatColumn(
              icon: widget.isTargetJarak ? Icons.timer : Icons.directions_run,
              label: widget.isTargetJarak ? 'DURASI' : 'JARAK',
              value: widget.isTargetJarak
                  ? _formatDuration(durationMinutes, durationSeconds)
                  : '${currentDistance.toStringAsFixed(2)} Km',
            ),
            _buildStatColumn(
              icon: Icons.local_fire_department,
              label: 'KALORI',
              value: '$calories Kcal',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.deepOrange, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCircleButton(
            onTap: _onPauseResume,
            label: isPaused ? 'LANJUT' : 'JEDA',
            isFilled: false,
          ),
          const SizedBox(width: 32),
          _buildCircleButton(
            onTap: _onFinish,
            label: 'FINISH',
            isFilled: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required VoidCallback onTap,
    required String label,
    required bool isFilled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFilled ? const Color(0xFFE54721) : Colors.white,
          border: isFilled
              ? null
              : Border.all(color: const Color(0xFFE54721), width: 7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isFilled ? Colors.white : const Color(0xFFE54721),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ============== BUILD ==============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Peta
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: _currentLocation!,
              zoom: 17.0,
            ),
            markers: {
              if (_currentLocation != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('currentLocation'),
                  position: _currentLocation!,
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                    gmaps.BitmapDescriptor.hueBlue,
                  ),
                ),
            },
            polylines: {
              gmaps.Polyline(
                polylineId: const gmaps.PolylineId('runRoute'),
                points: _routePoints,
                color: const Color(0xFFE54721),
                width: 5,
              ),
            },
          ),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // UI Components
          _buildHeader(),
          _buildProgressCircle(),
          _buildStatsCard(),
          _buildControlButtons(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}