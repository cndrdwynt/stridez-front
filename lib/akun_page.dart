import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Wajib untuk tanggal
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'home_page.dart';
import 'lari_page.dart';
import 'akun_setgoals_page.dart';
import 'akun_riwayatlari_page.dart';
import 'akun_profile.dart';
import 'login_page.dart';
import 'akun_achivement.dart';
import 'backend_service.dart';
import 'goal_settings_notifier.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _selectedIndex = 2;
  bool _isLoading = true;

  String _userName = 'Pengguna';
  String _userEmail = 'user@email.com';
  String _userPhone = '-';
  String? _profileImagePath;

  // Stats Hari Ini
  int _todayCalories = 0; 
  String _todayDurationStr = "0j 0m";
  int _todayRunCount = 0;

  // === BERAT BADAN (YANG AKAN KITA SINKRONKAN) ===
  double _weightSaatIni = 60.0; // Default jika kosong
  double _weightTarget = 60.0;  // Default jika kosong

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllUserData();
    });
  }

  Future<void> _loadAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (!mounted) return;

      // A. Load Profil Dasar
      final name = prefs.getString('user_display_name') ?? firebaseUser?.displayName ?? 'Pengguna';
      final email = prefs.getString('user_email') ?? firebaseUser?.email ?? 'user@email.com';
      final phone = prefs.getString('user_phone') ?? '-';
      final imagePath = prefs.getString('user_profile_path');

      // B. Load Berat Badan & Target
      double loadedCurrentWeight = (prefs.getDouble('user_weight') ?? prefs.getInt('user_weight')?.toDouble() ?? 60.0);
      
      // 'target_weight_kg' = Target BMI yang dihitung otomatis di Set Goals
      double loadedTargetWeight = (prefs.getDouble('target_weight_kg') ?? prefs.getDouble('target_weight') ?? 0.0);

      // Fallback jika target 0
      if (loadedTargetWeight == 0.0) {
         double height = (prefs.getDouble('user_height') ?? 170.0) / 100.0;
         loadedTargetWeight = 22.0 * height * height; // Rumus BMI 22
      }

      // C. Load Kalori & Statistik Lari
      int todayCal = prefs.getInt('calories_$todayDate') ?? 0;
      final stats = _calculateTodayStats(prefs, todayDate);

      setState(() {
        _userName = name;
        _userEmail = email;
        _userPhone = phone;
        _profileImagePath = imagePath;

        _weightSaatIni = loadedCurrentWeight;
        _weightTarget = double.parse(loadedTargetWeight.toStringAsFixed(1));

        _todayCalories = todayCal;
        _todayRunCount = stats['count'] as int;
        _todayDurationStr = stats['duration'] as String;
        
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error loading account data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _calculateTodayStats(SharedPreferences prefs, String todayDate) {
    String? historyJson = prefs.getString('run_history_data');
    int runCount = 0;
    int totalSeconds = 0;

    if (historyJson != null) {
      try {
        List<dynamic> list = jsonDecode(historyJson);
        for (var item in list) {
          String runDateIso = item['dateTime'];
          if (runDateIso.substring(0, 10) == todayDate) {
             runCount++;
             String dur = item['duration'];
             List<String> parts = dur.split(':');
             if (parts.length == 3) {
                totalSeconds += int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(parts[2]);
             } else if (parts.length == 2) {
                totalSeconds += int.parse(parts[0]) * 60 + int.parse(parts[1]);
             }
          }
        }
      } catch (e) { debugPrint("Error parse history: $e"); }
    }

    int hours = totalSeconds ~/ 3600;
    int mins = (totalSeconds % 3600) ~/ 60;
    String durationStr = (totalSeconds < 60 && totalSeconds > 0) ? "< 1m" : "${hours}j ${mins}m";

    return {'count': runCount, 'duration': durationStr};
  }

  void _navigateToSetGoals() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AkunSetGoalsPage()),
    );
    _loadAllUserData();
  }

  void _navigateToProfileEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountProfileScreen(
          initialName: _userName,
          initialEmail: _userEmail,
          initialPhone: _userPhone,
          initialImagePath: _profileImagePath,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      _loadAllUserData(); 
      try {
        final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
        if (firebaseUid != null) {
           final Map<String, dynamic> payload = {
            'name': result['userName'],
            'email': result['userEmail'],
            'phone': result['userPhone'],
          };
          await BackendService.updateUserOnServer(context, firebaseUid, payload);
        }
      } catch (e) { debugPrint("Sync error: $e"); }
    }
  }

  ImageProvider _getAvatarImage() {
    if (_profileImagePath != null) {
      final file = File(_profileImagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    return const AssetImage('assets/icons/profile_placeholder.png');
  }

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (r) => false);
  }
  
  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
    if (index == 0) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomePage()));
    else if (index == 1) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LariPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE54721))) 
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              children: [
                // HEADER
                Container(
                  height: 220,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE54721),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.white), // Ganti icon logout jadi titik tiga agar rapi
                            onPressed: _handleLogout,
                          ),
                        ),
                        GestureDetector(
                          onTap: _navigateToProfileEdit,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundImage: _getAvatarImage(),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: Color(0xFFE54721), size: 16),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(_userEmail, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // CARD BERAT BADAN (SESUAI GAMBAR YANG KAMU KIRIM)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildWeightCard(),
                ),

                const SizedBox(height: 15),
                
                // STATISTIK CARD (3 Lingkaran - SESUAI GAMBAR)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTodayStatsCard(),
                ),

                const SizedBox(height: 20),
                
                // MENU BUTTONS
                _buildMenuButton("Set Goals", Icons.flag, _navigateToSetGoals),
                _buildMenuButton("Riwayat Lari", Icons.history, () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AkunRiwayatLariPage()));
                   _loadAllUserData();
                }),
                _buildMenuButton("Achievement Board", Icons.emoji_events, () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AkunAchievementPage()));
                }),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFFE54721),
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
          BottomNavigationBarItem(icon: Icon(Icons.run_circle), label: "Lari"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Akun"),
        ],
      ),
    );
  }

  // === WIDGET CARD BERAT BADAN (DIPERBAIKI VISUALNYA) ===
  Widget _buildWeightCard() {
    // Hitung progress (semakin dekat ke target, semakin penuh)
    // Asumsi: Berat Awal (misal 80kg) -> Target (60kg). Progress naik jika berat turun.
    // Sederhananya, kita visualisasikan seberapa dekat dengan target.
    
    double diffTotal = (_weightSaatIni - _weightTarget).abs(); 
    // Logika visual: Jika selisih 0, progress 100%. Jika selisih besar, progress kecil.
    double progress = 0.0;
    if (diffTotal < 1.0) progress = 1.0;
    else if (diffTotal < 5.0) progress = 0.8;
    else if (diffTotal < 10.0) progress = 0.5;
    else progress = 0.2;

    return Card(
      color: const Color(0xFFE54721), // Warna Oranye Gelap seperti gambar
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "BERAT BADAN", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0)
                ),
                 // Gambar Icon Body
                 SizedBox(
                  height: 40, width: 40,
                  child: Image.asset(
                    'assets/icons/body_target.png', // Pastikan aset ini ada
                    color: Colors.white,
                    errorBuilder: (ctx, err, trace) => const Icon(Icons.accessibility, color: Colors.white, size: 35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Progress Bar Tebal (Putih Transparan vs Putih Solid)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress, 
                backgroundColor: Colors.white.withOpacity(0.3), // Latar belakang redup
                color: Colors.white, // Progress putih terang
                minHeight: 10, // Lebih tebal
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Row Angka (Saat Ini & Target)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Saat Ini", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("${_weightSaatIni.toInt()} kg", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Target", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text("${_weightTarget.toInt()} kg", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // === WIDGET CARD STATISTIK HARIAN (3 LINGKARAN) ===
  Widget _buildTodayStatsCard() {
    // Menggunakan container transparan atau putih sesuai desain
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total Waktu", _todayDurationStr, Icons.access_time, Colors.orange),
          _buildStatItem("Terbakar", "$_todayCalories kal", Icons.local_fire_department, Colors.red),
          _buildStatItem("Latihan", "$_todayRunCount lari", Icons.fitness_center, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), // Warna lingkaran pudar
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30), // Icon berwarna
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildMenuButton(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDEAE4), // Latar belakang menu (pink muda)
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFFE54721), size: 30),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }
}