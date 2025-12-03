import 'package:flutter/material.dart';
import 'package:flutter_frontend/akun_page.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'backend_service.dart';
import 'auth_service.dart'; // <--- Perubahan: Impor AuthService

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // GlobalKey untuk mengelola status Form dan validasi
  final _formKey = GlobalKey<FormState>();

  // PERUBAHAN: Instansiasi AuthService
  final AuthService _authService = AuthService();

  // Controllers untuk menangani input teks
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false; // State untuk mengelola tombol loading

  // Untuk Google Sign-In dan Phone Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _verificationId = '';
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  @override
  void dispose() {
    // Pastikan controllers dibersihkan ketika widget dihapus
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // Helper untuk menampilkan snackbar error/sukses
  void _showSnackBar(String message, {Color color = Colors.red}) {
    if (mounted) { // Tambahkan cek mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  // MARK: - FUNGSI PENDAFTARAN GOOGLE DENGAN SINKRONISASI (DIUBAH)
  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. Panggil fungsi signInWithGoogle dari AuthService
      final UserCredential? userCredential = await _authService.signInWithGoogle();

      if (userCredential == null) {
        _showSnackBar("Pendaftaran Google dibatalkan atau gagal.");
        return;
      }

      final User? user = userCredential.user;
      final String? uid = user?.uid;

      if (user != null && uid != null) {
        // 2. BUAT PAYLOAD DENGAN UID FIREBASE
        Map<String, dynamic> userDataPayload = {
          'userId': uid, // Kunci sinkronisasi ke Spring Boot
          'email': user.email ?? '',
          'name': user.displayName ?? '',
          'phone': user.phoneNumber ?? '',
        };

        // 3. PANGGIL FUNGSI SINKRONISASI KE SPRING BOOT
        bool syncSuccess = await BackendService.createUserOnServer(context, userDataPayload);

        if (syncSuccess) {
          _showSnackBar('Pendaftaran & Sinkronisasi Berhasil!', color: Colors.green);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          // Gagal sync ke MySQL, hapus user Firebase yang baru dibuat
          await user.delete();
          _showSnackBar('Gagal sinkronisasi ke server. Akun Firebase dihapus.');
        }
      }
    } catch (e) {
      print("Error Google Sign In: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal daftar dengan Google. Coba lagi."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // MARK: - FUNGSI PHONE AUTH (TETAP SAMA)
  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    if (phoneNumber.length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nomor telepon tidak valid."), backgroundColor: Colors.red),
        );
      }
      return;
    }

    await _auth.verifyPhoneNumber(
      // ... (Bagian verifikasi telepon tetap sama) ...
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up Telepon Berhasil!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
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
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
        });
        _showOtpInputModal(context, phoneNumber);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() {
          _verificationId = verificationId;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sesi verifikasi habis. Coba lagi."), backgroundColor: Colors.orange),
          );
        }
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _signInWithOtp() async {
    if (_verificationId.isEmpty || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan kode OTP terlebih dahulu."), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up berhasil dengan nomor telepon!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      print("Error OTP: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kode OTP salah atau kadaluarsa. Coba lagi."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// ... (Fungsi modal tetap sama) ...
  void _showOtpInputModal(BuildContext context, String phoneNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Masukkan Kode OTP",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text("Kode OTP telah dikirim ke $phoneNumber"),
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: "Kode OTP",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _signInWithOtp();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 233, 77, 38),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Verifikasi", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhoneInputModal(BuildContext context) {
    _phoneNumberController.clear();
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Login dengan Telepon'),
          content: TextField(
            controller: _phoneNumberController,
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
                String rawPhone = _phoneNumberController.text.trim();
                String formattedPhone;

                if (rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nomor telepon tidak boleh kosong.")),
                  );
                  return;
                }

                // Membersihkan karakter non-digit
                rawPhone = rawPhone.replaceAll(RegExp(r'\s|-'), '');

                // Formatting otomatis
                if (rawPhone.startsWith('+')) {
                  formattedPhone = rawPhone;
                } else if (rawPhone.startsWith('0')) {
                  formattedPhone = '+62' + rawPhone.substring(1);
                } else {
                  formattedPhone = '+62' + rawPhone;
                }

                // Validasi akhir
                if (!formattedPhone.startsWith('+')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Format harus dimulai dengan kode negara (+62)."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(ctx).pop();
                _verifyPhoneNumber(formattedPhone);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE54721)),
              child: const Text('Kirim Kode'),
            ),
          ],
        );
      },
    );
  }


  // MARK: - FUNGSI PENDAFTARAN EMAIL & PASSWORD (LOGIKA SINKRONISASI BARU)
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Kata Sandi dan Konfirmasi Kata Sandi tidak cocok!');
      return;
    }

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    try {
      // 1. Buat pengguna baru di Firebase Authentication (Gunakan AuthService)
      final UserCredential? userCredential = await _authService.signUpWithEmailPassword(email, password);

      if (userCredential == null) {
        // Peringatan umum karena error spesifik ditangani di AuthService
        _showSnackBar('Pendaftaran Firebase Gagal. Cek email atau password.');
        return;
      }

      // Ambil UID dari pengguna yang baru dibuat
      final String? uid = userCredential.user!.uid;

      // 2. PREPARASI DATA SINKRONISASI KE SPRING BOOT
      Map<String, dynamic> userDataPayload = {
        'userId': uid, // <--- Kunci Utama: UID dari Firebase
        'name': name,
        'phone': phone,
        'email': email,
      };

      // 3. PANGGIL FUNGSI SINKRONISASI KE SPRING BOOT (MySQL)
      bool syncSuccess = await BackendService.createUserOnServer(context, userDataPayload);

      if (syncSuccess) {
        _showSnackBar('Pendaftaran & Sinkronisasi berhasil!', color: Colors.green);

        // Navigasi ke halaman Akun/Set Goals
        // Simpan juga ke SharedPreferences agar profil langsung tampil di AccountPage
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_display_name', name);
          await prefs.setString('user_email', email);
          await prefs.setString('user_phone', phone);
        } catch (e) {
          debugPrint('Failed to save profile prefs: $e');
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AccountPage()),
        );
      } else {
        // Jika sinkronisasi ke Spring Boot gagal, hapus akun Firebase (rollback).
        await userCredential.user?.delete();
        _showSnackBar('Sinkronisasi ke server data gagal. Akun dibatalkan.');
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'weak-password') {
        errorMessage = 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email sudah digunakan oleh akun lain.';
      } else {
        errorMessage = 'Pendaftaran gagal: ${e.message}';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      // Tangani kesalahan lain
      _showSnackBar('Terjadi kesalahan tak terduga: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Bagian atas dengan teks "Belum Punya Akun?"
            Container(
              height: 200,
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 50.0),
              decoration: const BoxDecoration(
                color: Color(0xFFE54721),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(50.0)),
              ),
              child: const Text(
                'Belum Punya Akun?',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // Bagian bawah dengan form sign up
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
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                              );
                            },
                            child: const Text(
                              'Masuk',
                              style: TextStyle(color: Color(0xFFE54721), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                            onPressed: () {}, // Tombol 'Daftar' saat ini
                            child: const Text(
                              'Daftar',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Bungkus TextField dalam Form untuk validasi
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Input Nama
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration('Nama', Icons.person),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Input Nomor Telepon
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration('Nomor Telepon', Icons.phone),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nomor Telepon tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Input Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('Email', Icons.email),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            // Contoh validasi email sederhana dengan regex
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Input Kata Sandi
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: _passwordInputDecoration('Kata Sandi', _isPasswordVisible, (value) {
                            setState(() {
                              _isPasswordVisible = value;
                            });
                          }),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kata Sandi tidak boleh kosong';
                            }
                            if (value.length < 6) {
                              return 'Kata Sandi minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Input Konfirmasi Kata Sandi
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: _passwordInputDecoration('Konfirmasi Kata Sandi', _isConfirmPasswordVisible, (value) {
                            setState(() {
                              _isConfirmPasswordVisible = value;
                            });
                          }),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Konfirmasi Kata Sandi tidak boleh kosong';
                            }
                            if (value != _passwordController.text) {
                              return 'Kata Sandi tidak cocok';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Tombol Daftar yang memanggil fungsi _signUp
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp, // Nonaktifkan saat loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE54721),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : const Text('Daftar'),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'atau masuk dengan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _signInWithGoogle,
                        child: _buildSocialButton('assets/icons/google.png'),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => _showPhoneInputModal(context),
                        child: _buildSocialButton('assets/icons/telfon.png'),
                      ),
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

  // Helper untuk dekorasi input field umum
  InputDecoration _inputDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: const Color(0xFFE54721)),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // Helper untuk dekorasi input Kata Sandi (dengan toggle visibility)
  InputDecoration _passwordInputDecoration(String hintText, bool isVisible, Function(bool) toggleVisibility) {
    return _inputDecoration(hintText, Icons.lock).copyWith(
      suffixIcon: IconButton(
        icon: Icon(
          isVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey[700],
        ),
        onPressed: () {
          toggleVisibility(!isVisible);
        },
      ),
    );
  }

  Widget _buildSocialButton(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Image.asset(assetPath, height: 30, width: 30),
    );
  }
}