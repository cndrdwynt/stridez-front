import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'backend_service.dart';

class AkunSetGoalsPage extends StatefulWidget {
  const AkunSetGoalsPage({super.key});

  @override
  State<AkunSetGoalsPage> createState() => _AkunSetGoalsPageState();
}

class _AkunSetGoalsPageState extends State<AkunSetGoalsPage> {
  // === STATE VARIABLES ===
  String _jenisKelamin = 'Pria';
  double _tinggiBadan = 170;
  int _beratBadan = 70;
  int _usia = 25;
  
  // Goals Lari
  double _langkahTarget = 8000;
  double _jarakTarget = 5;
  double _durasiTarget = 30;
  
  // Target Berat Badan (Dihitung Otomatis)
  double _targetWeightKg = 0.0;

  bool _isSavingGoals = false;
  bool _isInitialLoading = true;

  static const Color primaryColor = Color.fromARGB(255, 233, 77, 38);
  static const Color secondaryBoxColor = Color.fromARGB(255, 255, 230, 220);
  static const Color darkTextColor = Color.fromARGB(255, 140, 70, 50);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }
  
  // === FUNGSI LOAD DATA (PENTING AGAR TIDAK RESET) ===
  Future<void> _loadAllData() async {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      
      // 1. Load dari Lokal dulu (Prioritas Utama)
      _loadLocalData(prefs);

      // 2. Jika ada internet/user, coba update dari server (Opsional)
      if (user != null) {
          final userGoalsResponse = await BackendService.getUserFromServer(user.uid);
          if (userGoalsResponse != null) {
              _loadRemoteData(userGoalsResponse);
          }
      }
      
      setState(() {
          _isInitialLoading = false;
      });
  }

  void _loadLocalData(SharedPreferences prefs) {
    setState(() {
      // Gunakan Key yang KONSISTEN dengan saat menyimpan
      _langkahTarget = prefs.getDouble('target_langkah') ?? 8000;
      _jarakTarget = prefs.getDouble('target_jarak') ?? 5;
      _durasiTarget = prefs.getDouble('target_durasi') ?? 30;

      _jenisKelamin = prefs.getString('user_gender') ?? 'Pria';
      _tinggiBadan = prefs.getDouble('user_height') ?? 170;
      _beratBadan = prefs.getInt('user_weight') ?? 70;
      _usia = prefs.getInt('user_age') ?? 25;
    });
  }
  
  void _loadRemoteData(Map<String, dynamic> userData) {
      // Hanya update jika data lokal masih default/kosong
      // Atau bisa dipaksa update tergantung kebutuhan. Di sini kita pakai logika aman.
      setState(() {
          if (userData['gender'] != null) _jenisKelamin = userData['gender'];
          if (userData['height_cm'] != null) _tinggiBadan = (userData['height_cm'] as num).toDouble();
          if (userData['weight_kg'] != null) _beratBadan = (userData['weight_kg'] as num).toInt();
          if (userData['age'] != null) _usia = (userData['age'] as num).toInt();
      });
  }

  // === HITUNG TARGET BERAT BADAN (BMI = 22) ===
  double _calculateIdealWeightFromBMI() {
    double heightM = _tinggiBadan / 100.0;
    double idealWeight = 22.0 * (heightM * heightM);
    return double.parse(idealWeight.toStringAsFixed(1));
  }

  String _calculateLevel(double value, double min, double max) {
      double levelValue = (max - min) / 3;
      if (value < min + levelValue) return 'Pemula';
      if (value < max - levelValue * 0.5) return 'Sedang';
      return 'Atlet';
  }

  // === FUNGSI SIMPAN DATA ===
  Future<void> _saveAllData() async {
    setState(() => _isSavingGoals = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      
      // 1. Hitung Target Berat Badan Otomatis
      final double autoTargetWeight = _calculateIdealWeightFromBMI();

      // 2. Simpan ke Lokal (SharedPreferences)
      await prefs.setDouble('target_langkah', _langkahTarget);
      await prefs.setDouble('target_jarak', _jarakTarget);
      await prefs.setDouble('target_durasi', _durasiTarget);
      
      await prefs.setString('user_gender', _jenisKelamin);
      await prefs.setDouble('user_height', _tinggiBadan);
      await prefs.setInt('user_weight', _beratBadan);
      await prefs.setInt('user_age', _usia);
      
      // Simpan Target BMI yang baru dihitung
      await prefs.setDouble('target_weight_kg', autoTargetWeight);
      
      // Tanggal update
      final today = DateTime.now();
      await prefs.setString('goals_set_date', '${today.year}-${today.month}-${today.day}');

      // 3. Kirim ke Backend (Jika Login)
      if (user != null) {
        final baseProfileData = {
          'userId': user.uid,
          'user_id': user.uid,
          'gender': _jenisKelamin,
          'height_cm': _tinggiBadan.toInt(),
          'weight_kg': _beratBadan.toDouble(),
          'age': _usia,
          'target_weight_kg': autoTargetWeight,
          'date': today.toIso8601String().substring(0, 10),
        };

        // Kirim Profil Dasar
        await BackendService.sendGoals(baseProfileData); 
        // (Bisa ditambahkan kirim goals spesifik langkah/jarak jika backend support)
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals & Target BMI Berhasil Disimpan!'), backgroundColor: Colors.green),
        );
        // Kembali ke halaman sebelumnya dengan membawa data baru
        Navigator.pop(context, {
            'refresh': true
        });
      }

    } catch (e) {
       if(mounted) _showSnackBar('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSavingGoals = false);
    }
  }

  // --- WIDGET HELPERS ---

  Widget _buildGenderButton(String gender) {
    bool isSelected = _jenisKelamin == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _jenisKelamin = gender),
        child: Container(
          height: 100, 
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : secondaryBoxColor,
            borderRadius: BorderRadius.circular(15),
            border: isSelected ? null : Border.all(color: Colors.black12), 
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                gender == 'Pria' ? Icons.male : Icons.female,
                color: isSelected ? Colors.white : primaryColor, 
                size: 35,
              ),
              const SizedBox(height: 8),
              Text(gender, style: TextStyle(color: isSelected ? Colors.white : darkTextColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberControl({required String title, required String unit, required int value, required ValueChanged<int> onIncrement, required ValueChanged<int> onDecrement}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: secondaryBoxColor, 
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: darkTextColor)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$value $unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Row(
                  children: [
                    GestureDetector(onTap: () => onDecrement(value > 1 ? value : 1), child: const Icon(Icons.remove_circle_outline, color: primaryColor)),
                    const SizedBox(width: 4),
                    GestureDetector(onTap: () => onIncrement(value), child: const Icon(Icons.add_circle_outline, color: primaryColor)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLevelChip(String label, double value, double min, double max) {
      String currentLevel = _calculateLevel(value, min, max);
      bool isActive = currentLevel == label;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isActive ? primaryColor : darkTextColor.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : darkTextColor, fontWeight: FontWeight.bold)),
      );
  }

  Widget _buildGoalBox({required String title, required String unit, required double value, required double min, required double max, required ValueChanged<double> onChanged, required String assetPath}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: secondaryBoxColor, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                 Image.asset(assetPath, height: 35, errorBuilder: (_,__,___) => Icon(Icons.star, color: primaryColor, size: 35)),
                 const SizedBox(width: 8),
                 Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: primaryColor)),
              ]),
              Text('${value.toInt()} $unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: primaryColor)),
            ],
          ),
          Slider(
            value: value, min: min, max: max, 
            divisions: (max - min).toInt(),
            activeColor: primaryColor, inactiveColor: primaryColor.withOpacity(0.3),
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLevelChip('Pemula', value, min, max),
              _buildLevelChip('Sedang', value, min, max),
              _buildLevelChip('Atlet', value, min, max),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 243, 162, 130), 
      body: SingleChildScrollView(
        child: Container(
          color: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16.0), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: 40),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  const Text("STRIDEZ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.white54),
              const SizedBox(height: 20),

              // Title Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: const Row(
                  children: [
                    Icon(Icons.menu, color: primaryColor),
                    SizedBox(width: 20),
                    Text('SET GOALS', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Gender Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: secondaryBoxColor, borderRadius: BorderRadius.circular(15)),
                child: const Text('Jenis Kelamin', style: TextStyle(color: darkTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Row(children: [_buildGenderButton('Pria'), _buildGenderButton('Wanita')]),
              
              const SizedBox(height: 16),
              
              // Height Control
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: secondaryBoxColor, borderRadius: BorderRadius.circular(15)),
                child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Tinggi Badan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextColor)),
                        Text('${_tinggiBadan.round()} cm', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                    ]),
                    Slider(
                        value: _tinggiBadan, min: 140, max: 210, divisions: 70,
                        activeColor: primaryColor, inactiveColor: primaryColor.withOpacity(0.3),
                        onChanged: (v) => setState(() => _tinggiBadan = v),
                    )
                ]),
              ),

              const SizedBox(height: 16),
              Row(children: [
                  _buildNumberControl(
                      title: 'Berat Badan', unit: 'kg', value: _beratBadan,
                      onIncrement: (v) => setState(() => _beratBadan++),
                      onDecrement: (v) => setState(() => _beratBadan = v > 1 ? v - 1 : 1),
                  ),
                  _buildNumberControl(
                      title: 'Usia', unit: '', value: _usia,
                      onIncrement: (v) => setState(() => _usia++),
                      onDecrement: (v) => setState(() => _usia = v > 1 ? v - 1 : 1),
                  ),
              ]),

              const SizedBox(height: 16),
              _buildGoalBox(title: 'Langkah', unit: 'Steps', value: _langkahTarget, min: 3000, max: 15000, onChanged: (v) => setState(() => _langkahTarget = v), assetPath: 'assets/icons/langkah_kecil.png'),
              _buildGoalBox(title: 'Jarak', unit: 'KM', value: _jarakTarget, min: 1, max: 42, onChanged: (v) => setState(() => _jarakTarget = v), assetPath: 'assets/icons/lari_logo.png'),
              _buildGoalBox(title: 'Durasi', unit: 'Min', value: _durasiTarget, min: 15, max: 120, onChanged: (v) => setState(() => _durasiTarget = v), assetPath: 'assets/icons/durasi_logo.png'),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                    onPressed: _isSavingGoals ? null : _saveAllData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: primaryColor),
                    child: _isSavingGoals ? const CircularProgressIndicator() : const Text('SIMPAN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}