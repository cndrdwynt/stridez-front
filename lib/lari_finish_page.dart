import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:firebase_auth/firebase_auth.dart'; // Digunakan untuk mendapatkan UID
import 'home_page.dart';
import 'akun_page.dart'; 
import 'backend_service.dart'; // Digunakan untuk mengirim data ke Spring Boot

class LariFinishPage extends StatefulWidget {
  final List<gmaps.LatLng> routePoints; 
  final double distance;
  final int durationMinutes;
  final int durationSeconds;
  final int calories;
  // --- PERBAIKAN: Parameter untuk Data Sensor/Waypoint ---
  final List<Map<String, dynamic>> waypointsData; 
  final String? startLocationName;
  // -------------------------------------------------

  const LariFinishPage({
    super.key,
    required this.routePoints, 
    required this.distance,
    required this.durationMinutes,
    required this.durationSeconds,
    required this.calories,
    // --- PERBAIKAN: Tambahkan ke konstruktor ---
    required this.waypointsData,
    this.startLocationName,
    
    // -------------------------------------
  });

  @override
  State<LariFinishPage> createState() => _LariFinishPageState();
}

class _LariFinishPageState extends State<LariFinishPage> {
  // === VARIABEL STATE BARU UNTUK STATUS SIMPAN ===
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    // Panggil fungsi simpan segera setelah halaman selesai dimuat
    _saveRunData(); 
  }

  // MARK: - LOGIC HELPERS
  
  String _getRunTimeOfDay() {
    final int hour = DateTime.now().hour;
    if (hour >= 5 && hour <= 10) return 'Pagi';
    if (hour >= 11 && hour <= 14) return 'Siang';
    if (hour >= 15 && hour <= 18) return 'Sore';
    return 'Malam';
  }

  gmaps.LatLng? get _startPoint => widget.routePoints.isNotEmpty ? widget.routePoints.first : null;
  gmaps.LatLng? get _endPoint => widget.routePoints.isNotEmpty ? widget.routePoints.last : null;
  static const gmaps.LatLng _defaultLocation = gmaps.LatLng(-7.2820, 112.7944);
  
  String _calculatePace() {
    if (widget.distance <= 0) return '0:00';
    final double totalMinutes = widget.durationMinutes + (widget.durationSeconds / 60);
    final double paceValue = totalMinutes / widget.distance;
    final int paceMinutes = paceValue.floor();
    final int paceSeconds = ((paceValue - paceMinutes) * 60).round();
    return '${paceMinutes.toString()}:${paceSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int minutes, int seconds) {
    return '${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  // MARK: - FUNGSI MENGIRIM DATA LARI KE SPRING BOOT (DIUBAH)
  Future<void> _saveRunData() async {
    if (_isSaved || _isSaving) return;
    
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar("Error: Pengguna belum login. Data tidak disimpan.", Colors.orange);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final int totalSeconds = widget.durationMinutes * 60 + widget.durationSeconds;
    final double totalDistanceKm = widget.distance;
    final double totalDistanceMeters = (totalDistanceKm * 1000);
    final double avgSpeedKph = totalSeconds > 0 ? (totalDistanceKm * 3600.0) / totalSeconds : 0.0;
    final DateTime endTime = DateTime.now();
    final DateTime startTime = endTime.subtract(Duration(seconds: totalSeconds));

    final Map<String, dynamic> runPayload = {
      'avgSpeedKph': avgSpeedKph,
      'caloriesBurned': widget.calories,
      'durationSeconds': totalSeconds,
      'distanceKm': totalDistanceKm,
      'totalDistanceMeters': totalDistanceMeters,
      'endTime': endTime.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'userId': user.uid,
      'startLocation': _startPoint != null ? '${_startPoint!.latitude},${_startPoint!.longitude}' : '',
    };
    
    // PANGGIL BACKEND SERVICE DENGAN DATA RUN DAN DATA WAYPOINT/SENSOR
    try {
      // NOTE: Kita hanya perlu satu panggilan API: sendRun
      final response = await BackendService.sendRun(runPayload, widget.waypointsData);

      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        setState(() {
          _isSaved = true;
          _showSnackBar("Data lari berhasil disimpan!", Colors.green);
        });
      } else {
        String errorMsg = "Gagal menyimpan data (Server Error). Status: ${response?.statusCode}";
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      print("Exception saat menyimpan data lari: $e");
      _showSnackBar("Koneksi gagal. Data tidak dapat disimpan.", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan posisi tengah rute untuk kamera peta
    gmaps.LatLng cameraTarget = widget.routePoints.isNotEmpty
        ? widget.routePoints[(widget.routePoints.length / 2).floor()]
        : _defaultLocation; 

    final String runTimeLabel = _getRunTimeOfDay();

    return Scaffold(
      body: Stack(
        children: [
          // Map with route polyline and markers
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: cameraTarget,
              zoom: 14.0,
            ),
            polylines: {
              gmaps.Polyline(
                polylineId: const gmaps.PolylineId('finishedRoute'),
                points: widget.routePoints, 
                color: const Color(0xFFE54721),
                width: 6,
              ),
            },
            markers: {
              if (_startPoint != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('start'),
                  position: _startPoint!,
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
                ),
              if (_endPoint != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('end'),
                  position: _endPoint!,
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
                ),
            },
            // PETA SEKARANG SEPENUHNYA INTERAKTIF
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true, 
            scrollGesturesEnabled: true, 
            tiltGesturesEnabled: true, 
            rotateGesturesEnabled: true, 
          ),
          
          // Header & summary
          Positioned(
            top: 40,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_run, color: Color(0xFFE54721), size: 35),
                    const SizedBox(width: 8),
                    Text(
                      'Lari $runTimeLabel', 
                      style: const TextStyle(
                        fontSize: 30, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFFE54721)
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  // Format jarak dengan koma sebagai pemisah desimal
                  widget.distance.toStringAsFixed(2).replaceAll('.', ','),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFE54721)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kilometer',
                  style: TextStyle(fontSize: 43, fontWeight: FontWeight.bold, color: Color(0xFFE54721)),
                ),
              ],
            ),
          ),
          
          // Info panel
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durasi
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Color(0xFFE54721), size: 28),
                      const SizedBox(width: 8),
                      const Text('DURASI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(width: 12),
                      Text(
                        _formatDuration(widget.durationMinutes, widget.durationSeconds) + ' min',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Kalori
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Color(0xFFE54721), size: 28),
                      const SizedBox(width: 8),
                      const Text('KALORI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(width: 12),
                      Text(
                        '${widget.calories} Kcal',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Pace
                  Row(
                    children: [
                      const Icon(Icons.speed, color: Color(0xFFE54721), size: 28),
                      const SizedBox(width: 8),
                      const Text('PACE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(width: 12),
                      Text(
                        '${_calculatePace()} min/km',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tombol dan Status Simpan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaved || _isSaving ? null : _saveRunData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaved ? Colors.green.shade500 : Colors.white,
                        foregroundColor: _isSaved ? Colors.white : const Color(0xFFE54721), 
                        side: BorderSide(color: _isSaved ? Colors.green.shade500 : const Color(0xFFE54721), width: 1),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFE54721), strokeWidth: 3))
                          : Icon(_isSaved ? Icons.check : Icons.save),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Text(
                          _isSaving ? 'Menyimpan...' : (_isSaved ? 'TERSİMPAN' : 'SIMPAN ULANG LARI'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        items: const [
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
      ),
    );
  }
}