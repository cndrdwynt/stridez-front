import 'dart:math';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'lari_page.dart';
import 'akun_page.dart';
import 'state_sync.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _displayName = 'User';

  // === DATA HARIAN ===
  int _todaySteps = 0;
  int _targetSteps = 10000;
  double _todayDistance = 0.0;
  int _todayCalories = 0; 
  int _todayPassiveSteps = 0; 
  Map<String, int> _weeklySteps = {}; 

  // === VARIABEL SENSOR ===
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _lastAccMagnitude = 0.0;
  bool _isPeakDetected = false;
  int _stepCooldown = 0;

  static const double STEP_THRESHOLD_MIN = 10.5;
  static const double STEP_THRESHOLD_MAX = 30.0;
  static const int STEP_COOLDOWN_SAMPLES = 8;
  static const double PASSIVE_CALORIES_PER_STEP = 0.04; 

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if(mounted) setState((){}); 
    });

    _loadDisplayName();
    _loadDailyData();
    _loadTargetSteps();
    _startPassiveStepTracking();
    
    AppState.refreshFromPrefs();
    AppState.todaySteps.addListener(_onTodayStepsChanged);
    AppState.todayDistance.addListener(_onTodayDistanceChanged);
    AppState.todayCalories.addListener(_onTodayCaloriesChanged);
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 19) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDailyData();
    _loadTargetSteps();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    AppState.todaySteps.removeListener(_onTodayStepsChanged);
    AppState.todayDistance.removeListener(_onTodayDistanceChanged);
    AppState.todayCalories.removeListener(_onTodayCaloriesChanged);
    super.dispose();
  }

  void _onTodayStepsChanged() { if (mounted) setState(() { _todaySteps = AppState.todaySteps.value; }); }
  void _onTodayDistanceChanged() { if (mounted) setState(() { _todayDistance = AppState.todayDistance.value; }); }
  void _onTodayCaloriesChanged() { if (mounted) setState(() { _todayCalories = AppState.todayCalories.value; }); }

  // === SENSOR TRACKING ===
  void _startPassiveStepTracking() {
    _accelSubscription = accelerometerEventStream().listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (_stepCooldown > 0) {
        _stepCooldown--;
      } else {
        if (magnitude > STEP_THRESHOLD_MIN && magnitude < STEP_THRESHOLD_MAX && magnitude > _lastAccMagnitude) {
          _isPeakDetected = true;
        }
        if (_isPeakDetected && magnitude < _lastAccMagnitude) {
          _updateStepsAndCalories(); 
          _stepCooldown = STEP_COOLDOWN_SAMPLES;
          _isPeakDetected = false;
        }
      }
      _lastAccMagnitude = magnitude;
    });
  }

  Future<void> _updateStepsAndCalories() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int savedRunCalories = prefs.getInt('run_calories_$today') ?? 0;

    if (mounted) {
      setState(() {
        _todaySteps++;         
        _todayPassiveSteps++;  
        _todayDistance += 0.0007; 
        int passiveCalories = (_todayPassiveSteps * PASSIVE_CALORIES_PER_STEP).round();
        _todayCalories = passiveCalories + savedRunCalories;
        _weeklySteps[today] = _todaySteps; 
      });
    }
    await _saveOneStep(today);
  }

  Future<void> _saveOneStep(String today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps_$today', _todaySteps);
    await prefs.setInt('passive_steps_$today', _todayPassiveSteps);
    await prefs.setDouble('distance_$today', _todayDistance);
    await prefs.setInt('calories_$today', _todayCalories); 
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_display_name');
    if (savedName != null && savedName.isNotEmpty) {
      setState(() => _displayName = savedName);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _displayName = (user.displayName != null && user.displayName!.isNotEmpty) ? user.displayName! : (user.email ?? 'User');
        });
      }
    }
  }

  Future<void> _loadTargetSteps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _targetSteps = (prefs.getDouble('target_langkah') ?? 10000.0).toInt();
    });
  }

  Future<void> _loadDailyData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    setState(() {
      _todaySteps = prefs.getInt('steps_$today') ?? 0;
      _todayPassiveSteps = prefs.getInt('passive_steps_$today') ?? 0;
      _todayDistance = prefs.getDouble('distance_$today') ?? 0.0;
      int savedRunCalories = prefs.getInt('run_calories_$today') ?? 0;
      int passiveCalories = (_todayPassiveSteps * PASSIVE_CALORIES_PER_STEP).round();
      _todayCalories = passiveCalories + savedRunCalories;

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        _weeklySteps[dateStr] = prefs.getInt('steps_$dateStr') ?? 0;
      }
    });
    AppState.todaySteps.value = _todaySteps;
    AppState.todayDistance.value = _todayDistance;
    AppState.todayCalories.value = _todayCalories;
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      _loadDailyData();
      _loadTargetSteps();
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LariPage()));
    } else if (index == 2) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AccountPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildHomePageContent(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.run_circle), label: 'Lari'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Akun'),
        ],
        currentIndex: 0,
        selectedItemColor: const Color(0xFFE54721),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHomePageContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFE54721),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
            ),
            padding: const EdgeInsets.only(top: 75, left: 24, right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}, $_displayName!',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ayo jalan! Langkahmu otomatis terhitung.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              children: [
                // WIDGET STEPS CARD (GAYA LINEAR BARU SESUAI GAMBAR)
                _buildStepsCard(), 
                
                const SizedBox(height: 30),

                Row(
                  children: [
                    Image.asset(
                      'assets/icons/lari.png',
                      height: 150,
                      errorBuilder: (c, e, s) => const Icon(Icons.directions_run, size: 100, color: Colors.orange),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TARGET\nLARI\nKAMU\nHARI INI!',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE54721), height: 1.2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${NumberFormat('#,###', 'id_ID').format(_targetSteps)} langkah',
                            style: const TextStyle(fontSize: 15, color: Color(0xFFE54721)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // WIDGET PROGRESS MINGGUAN (LINGKARAN)
                _buildWeeklyProgress(),

                const SizedBox(height: 30),

                _buildStatsContainer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === WIDGET STEPS CARD (GAYA LINEAR BARU SESUAI GAMBAR) ===
  Widget _buildStepsCard() {
    double progress = 0.0;
    if (_targetSteps > 0) {
      progress = (_todaySteps / _targetSteps).clamp(0.0, 1.0);
    }

    return Card(
      color: const Color(0xFFE54721), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "LANGKAH HARI INI", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0)
                ),
                 SizedBox(
                  height: 40, width: 40,
                  child: Image.asset(
                    'assets/icons/langkah_kecil.png', 
                    color: Colors.white,
                    errorBuilder: (ctx, err, trace) => const Icon(Icons.directions_walk, color: Colors.white, size: 35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress, 
                backgroundColor: Colors.white.withOpacity(0.3), 
                color: Colors.white, 
                minHeight: 12, 
              ),
            ),
            
            const SizedBox(height: 15),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Saat Ini", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat('#,###', 'id_ID').format(_todaySteps), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Target", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat('#,###', 'id_ID').format(_targetSteps), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // === WIDGET PROGRESS MINGGUAN (VERSI CIRCULAR / CINCIN) ===
  Widget _buildWeeklyProgress() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progress Mingguan',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        
        // Kotak Putih Pembungkus
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = weekDates[index];
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final steps = _weeklySteps[dateStr] ?? 0;
              
              // Target harian 10.000 langkah
              double progress = (steps / 10000).clamp(0.0, 1.0);
              
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
              
              final ringColor = isToday ? const Color(0xFFE54721) : Colors.orange.shade300;
              final bgColor = Colors.grey.shade100;

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Lingkaran Progress
                      SizedBox(
                        width: 40, 
                        height: 40,
                        child: CircularProgressIndicator(
                          value: progress, 
                          backgroundColor: bgColor,
                          color: ringColor,
                          strokeWidth: 4, 
                          strokeCap: StrokeCap.round, 
                        ),
                      ),
                      
                      // 2. Inisial Hari di Tengah (S/S/R...)
                      Text(
                        DateFormat.E('id_ID').format(date)[0], 
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isToday ? const Color(0xFFE54721) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Tanggal di Bawah (misal: 12)
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsContainer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE54721),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.directions_walk, NumberFormat('#,###', 'id_ID').format(_todaySteps), 'Langkah'),
          _buildStatItem(Icons.location_on, _todayDistance.toStringAsFixed(2), 'Km'),
          _buildStatItem(Icons.local_fire_department, _todayCalories.toString(), 'Kalori'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}