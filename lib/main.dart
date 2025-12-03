import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'login_page.dart';
import 'home_page.dart'; // <--- Pastikan HomePage diimpor
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Diperlukan untuk cek status
import 'firebase_options.dart';

// ✅ Tambahkan ini
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'goal_settings_notifier.dart';
// Ganti nilai ini sesuai kebutuhan. Untuk emulator Android biasanya gunakan
// 'http://10.0.2.2:8081', untuk perangkat fisik gunakan IP mesin dev
const String baseUrl = 'http://192.168.43.254:8081';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);

  final notifier = await GoalSettingsNotifier.loadFromPrefs();
  runApp(ChangeNotifierProvider<GoalSettingsNotifier>.value(
    value: notifier,
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stridez App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      // App dimulai dari SplashScreen
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  // MARK: - FUNGSI NAVIGASI BARU
  void _navigateToNextScreen() {
    if (!mounted) return;
    
    // PERUBAHAN UTAMA: Cek Status Login Firebase
    final user = FirebaseAuth.instance.currentUser;
    
    final Widget destination = (user != null) 
        ? const HomePage() // Sudah login
        : const LoginPage(); // Belum login

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  void initState() {
    super.initState();
    checkServer(); // ✅ panggil pas splash screen mulai

    // PERUBAHAN: Setelah waktu tunda, panggil fungsi cek status
    Future.delayed(const Duration(seconds: 8), () {
      _navigateToNextScreen();
    });
  }

  void checkServer() async {
    final url = Uri.parse('$baseUrl/api/users/ping');

    try {
      final response = await http.get(url);
      print("Response backend: ${response.body}");

      // biar muncul di HP juga — defer until first frame to ensure Scaffold exists
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backend: ${response.body}")),
        );
      });
    } catch (e) {
      print("Error: $e");
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error koneksi backend")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/Mask_group.png',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 16),
            const Text(
              'Stridez',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE54721),
              ),
            ),
          ],
        ),
      ),
    );
  }
}