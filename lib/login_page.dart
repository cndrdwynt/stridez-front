import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Wajib untuk otentikasi
import 'auth_service.dart';
import 'backend_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Variabel untuk Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  // Controller untuk Input Form Email/Password
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Controller untuk Otentikasi Telepon
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = ''; // Disimpan dari Firebase setelah verifikasi nomor
  
  bool _isPasswordVisible = false;

  // MARK: - FUNGSI LOGIN GOOGLE (LOGIKA KOREKSI)
  Future<void> _signInWithGoogle() async {
    // 1. Panggil AuthService.signInWithGoogle yang mengembalikan UserCredential
    final UserCredential? userCredential = await _authService.signInWithGoogle(); 

    if (userCredential != null) {
      // KODE BERJALAN JIKA LOGIN BERHASIL (result != null)
      if (!mounted) return;
      final user = userCredential.user; // Ambil user dari credential
      // On login, fetch user profile from backend (do NOT create on login)
      if (user != null) {
        try {
          final serverUser = await BackendService.getUserFromServer(user.uid);
          final prefs = await SharedPreferences.getInstance();
          if (serverUser != null) {
            await prefs.setString('user_display_name', serverUser['name'] ?? user.displayName ?? '');
            await prefs.setString('user_email', serverUser['email'] ?? user.email ?? '');
            await prefs.setString('user_phone', serverUser['phone'] ?? user.phoneNumber ?? '');
          } else {
            // If user not present in DB, keep Firebase info locally but do not create on server
            await prefs.setString('user_display_name', user.displayName ?? '');
            await prefs.setString('user_email', user.email ?? '');
            await prefs.setString('user_phone', user.phoneNumber ?? '');
          }
        } catch (e) {
          debugPrint('Error fetching user from server: $e');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Berhasil sebagai ${user?.displayName ?? user?.email}')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // KODE BERJALAN JIKA LOGIN GAGAL/DIBATALKAN (result == null)
      if (!mounted) return;
      // Pesan error ditampilkan secara umum karena error spesifik ada di dalam AuthService
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Google Gagal atau Dibatalkan.'), backgroundColor: Colors.red),
      );
    }
  }

  // MARK: - FUNGSI LOGIN EMAIL/PASSWORD (DIKOREKSI AGAR MENJADI METHOD TERPISAH)
  Future<void> _signInWithEmailPassword() async {
    final email = _nameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email dan password tidak boleh kosong.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // AuthService.signInWithEmailPassword mengembalikan String error atau null (sukses)
    final String? result = await _authService.signInWithEmailPassword(email, password);

    if (mounted) Navigator.of(context).pop();

    if (result == null) {
      // SUKSES
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      // On sign-in, fetch user profile from backend (do NOT create on login)
      if (user != null) {
        try {
          final serverUser = await BackendService.getUserFromServer(user.uid);
          final prefs = await SharedPreferences.getInstance();
          if (serverUser != null) {
            await prefs.setString('user_display_name', serverUser['name'] ?? user.displayName ?? '');
            await prefs.setString('user_email', serverUser['email'] ?? user.email ?? '');
            await prefs.setString('user_phone', serverUser['phone'] ?? user.phoneNumber ?? '');
          } else {
            await prefs.setString('user_display_name', user.displayName ?? '');
            await prefs.setString('user_email', user.email ?? '');
            await prefs.setString('user_phone', user.phoneNumber ?? '');
          }
        } catch (e) {
          debugPrint('Error fetching user from server: $e');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login berhasil sebagai ${user?.email ?? user?.displayName}')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // GAGAL
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red),
      );
    }
  }
  
  // MARK: - FUNGSI LOGIN TELEPON

  // 1. Meminta Firebase mengirim kode OTP
  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    // Validasi dasar
    if (phoneNumber.length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nomor telepon tidak valid."), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    // START VERIFIKASI via AuthService (positional callbacks)
    await _authService.verifyPhoneNumber(
      phoneNumber,
      (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Telepon Berhasil!')),
          );
          // On phone login, fetch profile from backend (do NOT create on login)
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              final serverUser = await BackendService.getUserFromServer(user.uid);
              final prefs = await SharedPreferences.getInstance();
              if (serverUser != null) {
                await prefs.setString('user_display_name', serverUser['name'] ?? user.displayName ?? '');
                await prefs.setString('user_email', serverUser['email'] ?? user.email ?? '');
                await prefs.setString('user_phone', serverUser['phone'] ?? user.phoneNumber ?? '');
              } else {
                await prefs.setString('user_display_name', user.displayName ?? '');
                await prefs.setString('user_email', user.email ?? '');
                await prefs.setString('user_phone', user.phoneNumber ?? '');
              }
            } catch (e) {
              debugPrint('Error fetching user from server: $e');
            }
          }
          // Navigasi setelah verifikasi otomatis
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      },
      (FirebaseAuthException e) {
        print(e.message);
        if (mounted) {
          String errorMessage = "Verifikasi gagal. Cek pengaturan Firebase/format nomor.";
          if (e.code == 'invalid-phone-number') {
            errorMessage = "Format nomor telepon tidak valid. Gunakan format internasional.";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      },
      // Dipanggil saat kode verifikasi telah dikirim
      (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
        });
        _showOtpInputModal(context, phoneNumber);
      },
      (String verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sesi verifikasi habis. Coba lagi."), backgroundColor: Colors.orange),
          );
        }
      },
    );
  }

  // 2. Login menggunakan ID Verifikasi dan Kode OTP
  Future<void> _signInWithOtp() async {
    if (_verificationId.isEmpty || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan OTP.")),
      );
      return;
    }

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );

      await _auth.signInWithCredential(credential);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Telepon Berhasil!')),
        );
        // On phone OTP sign-in, fetch profile from backend (do NOT create on login)
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final serverUser = await BackendService.getUserFromServer(user.uid);
            final prefs = await SharedPreferences.getInstance();
            if (serverUser != null) {
              await prefs.setString('user_display_name', serverUser['name'] ?? user.displayName ?? '');
              await prefs.setString('user_email', serverUser['email'] ?? user.email ?? '');
              await prefs.setString('user_phone', serverUser['phone'] ?? user.phoneNumber ?? '');
            } else {
              await prefs.setString('user_display_name', user.displayName ?? '');
              await prefs.setString('user_email', user.email ?? '');
              await prefs.setString('user_phone', user.phoneNumber ?? '');
            }
          } catch (e) {
            debugPrint('Error fetching user from server: $e');
          }
        }
        // Navigasi setelah verifikasi manual OTP
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP salah atau kedaluwarsa: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // MARK: - WIDGET MODAL UNTUK INPUT TELEPON DAN OTP

  // Modal Input Nomor Telepon
  void _showPhoneInputModal(BuildContext context) {
    _phoneController.clear(); 
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Login dengan Telepon'),
          content: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor Telepon',
              hintText: '+628xxxxxxxxxx (Wajib)', 
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                String rawPhone = _phoneController.text.trim();
                String formattedPhone;

                if (rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nomor telepon tidak boleh kosong.")),
                  );
                  return;
                }

                // 1. Membersihkan karakter non-digit
                rawPhone = rawPhone.replaceAll(RegExp(r'\s|-'), '');

                // 2. LOGIKA FORMATTING OTOMATIS
                if (rawPhone.startsWith('+')) {
                  formattedPhone = rawPhone;
                } else if (rawPhone.startsWith('0')) {
                  formattedPhone = '+62' + rawPhone.substring(1);
                } else {
                  formattedPhone = '+62' + rawPhone;
                }

                // 3. VALIDASI AKHIR
                if (!formattedPhone.startsWith('+')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Format harus dimulai dengan kode negara (+62)."), backgroundColor: Colors.red),
                    );
                    return;
                }

                Navigator.of(ctx).pop(); 
                _verifyPhoneNumber(formattedPhone); // Gunakan nomor yang sudah diformat
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE54721)),
              child: const Text('Kirim Kode'),
            ),
          ],
        );
      },
    );
  }

  // Modal Input OTP
  void _showOtpInputModal(BuildContext context, String phoneNumber) {
    _otpController.clear(); 
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Masukkan Kode OTP ke $phoneNumber'),
          content: TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Kode Verifikasi (6 digit)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                // Tutup modal OTP DENGAN context MODAL (ctx)
                Navigator.of(ctx).pop(); 
                _signInWithOtp(); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE54721)),
              child: const Text('Verifikasi'),
            ),
          ],
        );
      },
    );
  }

  // MARK: - WIDGET SOCIAL BUTTON
  Widget _buildSocialButton(String assetPath) {
    bool isGoogle = assetPath.contains('google'); 
    bool isPhone = assetPath.contains('telfon'); 
    
    return GestureDetector(
      onTap: () {
        if (isGoogle) {
          _signInWithGoogle();
        } else if (isPhone) {
          _showPhoneInputModal(context); // PANGGIL MODAL TELEPON
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fungsi login belum tersedia.')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Image.asset(assetPath, height: 30, width: 30),
      ),
    );
  }

  // MARK: - BUILD METHOD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              height: 200,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 50.0),
              decoration: const BoxDecoration(
                color: Color(0xFFE54721),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(50.0)),
              ),
              child: const Text(
                'Sudah Punya Akun?',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Form Login
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tombol Masuk/Daftar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE54721),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            // Diubah: Memanggil _signInWithEmailPassword
                            onPressed: _signInWithEmailPassword, 
                            child: const Text(
                              'Masuk',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEAE4),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const SignupPage()),
                              );
                            },
                            child: const Text(
                              'Daftar',
                              style: TextStyle(color: Color(0xFFE54721), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Input Nama (Email/Username)
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Nama (atau Email)',
                      filled: true,
                      fillColor: const Color(0xFFFDEAE4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFFE54721), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Input Kata Sandi
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Kata Sandi',
                      filled: true,
                      fillColor: const Color(0xFFFDEAE4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFFE54721), width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey[700],
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 200),
                  
                  // Tombol Masuk Utama (Email/Password)
                  ElevatedButton(
                    onPressed: _signInWithEmailPassword, // Panggil fungsi yang baru dikoreksi
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE54721),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Masuk'),
                  ),
                  
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'atau masuk dengan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // TOMBOL LOGIN SOSIAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton('assets/icons/google.png'), 
                      const SizedBox(width: 20),
                      _buildSocialButton('assets/icons/telfon.png'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}