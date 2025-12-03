import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sensors_plus/sensors_plus.dart'; // TAMBAH INI

import 'home_page.dart';
import 'lari_start_page.dart';
import 'akun_page.dart'; 

class LariPage extends StatefulWidget {
  const LariPage({super.key});

  @override
  State<LariPage> createState() => _LariPageState();
}

class _LariPageState extends State<LariPage> {
  // Existing variables
  String? _currentAddress;
  String _targetType = 'Target Jarak';
  double _targetJarakValue = 2.0;
  int _targetWaktuValue = 15;
  latlong.LatLng? _currentLocation;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStreamSubscription;

  // === TAMBAH: VARIABEL UNTUK PREVIEW AKTIVITAS ===
  StreamSubscription? _accelSubscription;
  final List<double> _accelBuffer = [];
  String _previewActivity = 'IDLE';
  double _previewConfidence = 0.0;
  
  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM', 'id_ID').format(now);
  }

  Future<void> _updateAddressFromLocation() async {
    if (_currentLocation == null) return;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _currentAddress = [
            if (p.name != null && p.name!.isNotEmpty) p.name,
            if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality,
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
          ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      // ignore error
    }
  }

  // === TAMBAH: FUNGSI DETEKSI AKTIVITAS PREVIEW ===
  void _startActivityPreview() {
    _accelSubscription = accelerometerEventStream().listen((event) {
      double magnitude = sqrt(
        event.x * event.x + 
        event.y * event.y + 
        event.z * event.z
      );
      
      _accelBuffer.add(magnitude);
      if (_accelBuffer.length > 30) {
        _accelBuffer.removeAt(0);
      }
      
      // Klasifikasi setiap 30 samples
      if (_accelBuffer.length == 30) {
        _classifyPreviewActivity();
      }
    });
  }
  
  void _classifyPreviewActivity() {
    double mean = _accelBuffer.reduce((a, b) => a + b) / _accelBuffer.length;
    double variance = _accelBuffer.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / _accelBuffer.length;
    double stdDev = sqrt(variance);
    
    String activity;
    double confidence;
    
    if (stdDev < 1.5) {
      activity = 'IDLE';
      confidence = 0.95;
    } else if (stdDev < 3.5) {
      activity = 'WALKING';
      confidence = 0.85;
    } else {
      activity = 'RUNNING';
      confidence = 0.90;
    }
    
    if (activity != _previewActivity) {
      setState(() {
        _previewActivity = activity;
        _previewConfidence = confidence;
      });
    }
  }

  void _startPositionStream() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _currentLocation = latlong.LatLng(position.latitude, position.longitude);
      });
      _updateAddressFromLocation();
    });
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _startPositionStream();
    _startActivityPreview(); // TAMBAH INI
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAddressFromLocation());
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _accelSubscription?.cancel(); // TAMBAH INI
    super.dispose();
  }

  Future<void> _determinePosition() async {
    Timer(const Duration(seconds: 15), () {
      if (_isLoading && mounted) {
        setState(() {
          _isLoading = false;
          _currentLocation ??= const latlong.LatLng(-7.2820, 112.7944);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal mendapatkan lokasi. Menampilkan lokasi default.'),
          backgroundColor: Colors.red,
        ));
      }
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Layanan lokasi tidak aktif. Mohon aktifkan GPS.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return; 
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Izin lokasi ditolak permanen, kami tidak dapat meminta izin.')));
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = latlong.LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (_currentLocation == null) {
      _currentLocation = const latlong.LatLng(-7.2820, 112.7944);
    }
  }

  @override
  Widget build(BuildContext context) {
    // === TAMBAH: TENTUKAN WARNA BADGE BERDASARKAN AKTIVITAS ===
    Color badgeColor;
    IconData badgeIcon;
    
    switch (_previewActivity) {
      case 'RUNNING':
        badgeColor = Colors.red;
        badgeIcon = Icons.directions_run;
        break;
      case 'WALKING':
        badgeColor = Colors.green;
        badgeIcon = Icons.directions_walk;
        break;
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.accessibility_new;
    }

    return Scaffold(
      body: Stack(
        children: [
          // PETA
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: _currentLocation != null
                  ? gmaps.LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
                  : const gmaps.LatLng(-7.2820, 112.7944),
              zoom: 17.0,
            ),
            markers: {
              if (_currentLocation != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('currentLocation'),
                  position: gmaps.LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
                ),
            },
          ),
          
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
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
            ),
            
          if (!_isLoading) ...[
            Positioned(
              top: 50,
              left: 24,
              right: 24,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LARI',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        shadows: [
                          Shadow(
                              blurRadius: 10.0,
                              color: Colors.white,
                              offset: Offset(0, 0))
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFormattedDate(),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                              blurRadius: 10.0,
                              color: Colors.white,
                              offset: Offset(0, 0))
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _currentAddress ?? 'Mencari lokasi...',
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.white,
                                    offset: Offset(0, 0))
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // === TAMBAH: BADGE PREVIEW AKTIVITAS ===
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$_previewActivity (${(_previewConfidence * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Target selector (existing code)
            Positioned(
              top: 300,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE440),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE54721),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 36,
                              constraints: const BoxConstraints(minWidth: 100, maxWidth: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE54721),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isDense: true,
                                  value: _targetType,
                                  dropdownColor: const Color(0xFFE54721),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  items: <String>['Target Jarak', 'Target Waktu', 'Tanpa Target']
                                      .map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Center(child: Text(value)),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _targetType = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.black, size: 32),
                            onPressed: () {
                              setState(() {
                                if (_targetType == 'Target Jarak') {
                                  if (_targetJarakValue > 0.5) {
                                    _targetJarakValue -= 0.5;
                                  }
                                } else {
                                  if (_targetWaktuValue > 1) {
                                    _targetWaktuValue -= 1;
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _targetType == 'Tanpa Target'
                              ? const SizedBox(height: 40)
                              : Text(
                                  _targetType == 'Target Jarak'
                                      ? '${_targetJarakValue.toStringAsFixed(2)} Km'
                                      : '${_targetWaktuValue} Menit',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color.fromARGB(255, 16, 15, 15), size: 32),
                            onPressed: () {
                              setState(() {
                                if (_targetType == 'Target Jarak') {
                                  _targetJarakValue += 0.5;
                                } else {
                                  _targetWaktuValue += 1;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // GO Button
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => LariStartPage(
                          isTargetJarak: _targetType == 'Target Jarak',
                          targetJarak: _targetJarakValue,
                          targetWaktu: _targetWaktuValue,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE54721),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE54721).withValues(alpha: 0.5),
                          spreadRadius: 10,
                          blurRadius: 20,
                        ),
                        BoxShadow(
                          color: const Color(0xFFE54721).withValues(alpha: 0.2),
                          spreadRadius: 20,
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'GO!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

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
      } 
    );
  }
}