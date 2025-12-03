import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AkunAchievementPage extends StatefulWidget {
  const AkunAchievementPage({super.key});

  @override
  State<AkunAchievementPage> createState() => _AkunAchievementPageState();
}

class _AkunAchievementPageState extends State<AkunAchievementPage> {
  // --- TARGET (GOALS) ---
  double _targetLangkah = 8000;
  double _targetJarak = 25;
  double _targetDurasi = 60;
  bool _hasSetGoals = false;

  // --- PROGRESS (REALISASI HARI INI) ---
  int _currentLangkah = 0;
  double _currentJarak = 0.0;
  int _currentDurasiMenit = 0; // Dalam menit

  // --- LOGIC PENCAPAIAN ---
  bool get _isLangkahAchieved => _currentLangkah >= _targetLangkah;
  bool get _isJarakAchieved => _currentJarak >= _targetJarak;
  bool get _isDurasiAchieved => _currentDurasiMenit >= _targetDurasi;
  bool get _allAchieved => _isLangkahAchieved && _isJarakAchieved && _isDurasiAchieved;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // FUNGSI LOAD DATA GABUNGAN (TARGET + HASIL LARI)
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    setState(() {
      // 1. AMBIL TARGET (DARI HALAMAN SET GOALS)
      // Cek apakah user pernah set goals
      if (prefs.containsKey('target_langkah')) {
        _hasSetGoals = true;
        _targetLangkah = prefs.getDouble('target_langkah') ?? 8000;
        _targetJarak = prefs.getDouble('target_jarak') ?? 25;
        _targetDurasi = prefs.getDouble('target_durasi') ?? 60;
      }

      // 2. AMBIL REALISASI (DARI HASIL LARI HARI INI)
      // Key ini sesuai dengan yang disimpan di LariStartPage (_saveDailyData)
      _currentLangkah = prefs.getInt('steps_$today') ?? 0;
      _currentJarak = prefs.getDouble('distance_$today') ?? 0.0;
      
      // Durasi di LariStartPage disimpan dalam detik ('duration_$today')
      int durasiDetik = prefs.getInt('duration_$today') ?? 0;
      _currentDurasiMenit = (durasiDetik / 60).floor(); // Konversi ke menit
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- HEADER ---
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE54721),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          // Placeholder Nama App
                          const Text(
                            'Stridez',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 1,
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Ikon Trophy Besar
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
                    const SizedBox(height: 8),
                    const Text(
                      'ACHIEVEMENT BOARD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // --- CONTENT ---
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (!_hasSetGoals) ...[
                      // TAMPILAN JIKA BELUM PERNAH SET GOALS
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Belum ada target 🎯',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Atur target lari harian Anda di menu "Set Goals" agar pencapaian bisa dilacak.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context), // Kembali ke Akun
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE54721),
                              ),
                              child: const Text('Atur Sekarang', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                    ] else ...[
                      // KARTU LANGKAH
                      _buildAchievementCard(
                        icon: Icons.directions_walk,
                        title: 'Langkah',
                        // Menampilkan: Capaian / Target
                        valueText: '$_currentLangkah / ${_targetLangkah.toInt()} langkah',
                        progress: _currentLangkah / _targetLangkah,
                        isAchieved: _isLangkahAchieved,
                      ),
                      const SizedBox(height: 16),

                      // KARTU JARAK
                      _buildAchievementCard(
                        icon: Icons.map,
                        title: 'Jarak Lari',
                        valueText: '${_currentJarak.toStringAsFixed(2)} / ${_targetJarak.toInt()} km',
                        progress: _currentJarak / _targetJarak,
                        isAchieved: _isJarakAchieved,
                      ),
                      const SizedBox(height: 16),

                      // KARTU DURASI
                      _buildAchievementCard(
                        icon: Icons.timer,
                        title: 'Durasi',
                        valueText: '$_currentDurasiMenit / ${_targetDurasi.toInt()} menit',
                        progress: _currentDurasiMenit / _targetDurasi,
                        isAchieved: _isDurasiAchieved,
                      ),

                      // BANNER SELAMAT (JIKA SEMUA TERCAPAI)
                      if (_allAchieved) ...[
                        const SizedBox(height: 30),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE54721),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE54721).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.celebration, color: Colors.white, size: 40),
                              SizedBox(height: 12),
                              Text(
                                'LUAR BIASA!!!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'ANDA TELAH MENYELESAIKAN\nSEMUA TARGET HARI INI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard({
    required IconData icon,
    required String title,
    required String valueText,
    required double progress,
    required bool isAchieved,
  }) {
    // Clamp progress agar tidak error di LinearProgressIndicator (> 1.0)
    final displayProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isAchieved ? Colors.green : Colors.grey[300]!,
          width: isAchieved ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE54721).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFE54721), size: 30),
              ),
              const SizedBox(width: 16),
              
              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valueText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Check Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAchieved ? Colors.green : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAchieved ? Icons.check : Icons.circle_outlined,
                  color: isAchieved ? Colors.white : Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: displayProgress,
              backgroundColor: Colors.grey[200],
              color: isAchieved ? Colors.green : const Color(0xFFE54721),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}