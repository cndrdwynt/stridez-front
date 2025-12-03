import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AccountProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPhone;
  final String? initialImagePath;

  const AccountProfileScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
    this.initialImagePath,
  });

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _profileImagePath = widget.initialImagePath;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  final TextStyle _labelStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black54,
  );

  // --- FUNGSI AMBIL GAMBAR ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50, // Kompres gambar biar tidak kegedean (penyebab crash)
      );

      if (pickedFile != null) {
        setState(() {
          _profileImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil gambar. Pastikan izin diberikan.')),
      );
    }
  }

  // --- FUNGSI SIMPAN (DIPERBAIKI) ---
  void _saveProfileAndReturn() {
    // 1. Validasi: Jangan biarkan kosong
    if (_nicknameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Email tidak boleh kosong')),
      );
      return;
    }

    // 2. PERBAIKAN KUNCI (KEYS): Disamakan dengan error log server (name, email, phone)
    final Map<String, dynamic> result = {
      'name': _nicknameController.text,       // Sebelumnya 'userName' -> Diubah ke 'name'
      'email': _emailController.text,         // Sebelumnya 'userEmail' -> Diubah ke 'email'
      'phone': _phoneController.text,         // Sebelumnya 'userPhone' -> Diubah ke 'phone'
      'profilePath': _profileImagePath,       // Path gambar lokal
    };
    
    // 3. Kirim balik ke halaman sebelumnya
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // Ambil padding atas aman (status bar)
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: Colors.white, // Pastikan background putih bersih
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // --- HEADER ---
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: statusBarHeight + 10.0, bottom: 30.0), 
              decoration: const BoxDecoration(
                color: Color(0xFFE54721),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50), 
                  bottomRight: Radius.circular(50),
                ),
              ),
              child: Column(
                children: <Widget>[
                  // Tombol Kembali & Judul
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Edit Profil', 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 20, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Foto Profil
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar( 
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 56,
                          backgroundImage: _getProfileImage(),
                        ),
                      ),
                      // Ikon Edit Kecil di Foto
                      Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Color(0xFFE54721), size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // Tombol Pilihan Gambar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _buildImageSourceButton(Icons.image, 'Galeri', () => _pickImage(ImageSource.gallery)),
                      const SizedBox(width: 15.0),
                      _buildImageSourceButton(Icons.camera_alt, 'Kamera', () => _pickImage(ImageSource.camera)),
                    ],
                  ),
                ],
              ),
            ),
            
            // --- FORM INPUT ---
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Nama Lengkap', style: _labelStyle),
                  const SizedBox(height: 8.0),
                  _buildInputField(_nicknameController, 'Masukkan nama', TextInputType.text),
                  
                  const SizedBox(height: 20.0),

                  Text('Email', style: _labelStyle),
                  const SizedBox(height: 8.0),
                  _buildInputField(_emailController, 'Contoh: user@email.com', TextInputType.emailAddress),
                  
                  const SizedBox(height: 20.0),

                  Text('Nomor Telepon', style: _labelStyle),
                  const SizedBox(height: 8.0),
                  _buildInputField(_phoneController, '08xxxxxxxxxx', TextInputType.phone),
                  
                  const SizedBox(height: 40.0),

                  // --- TOMBOL AKSI ---
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildActionButton(
                          'BATAL',
                          Colors.grey.shade200,
                          Colors.black,
                          () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 15.0),
                      Expanded(
                        child: _buildActionButton(
                          'SIMPAN',
                          const Color(0xFFE54721),
                          Colors.white,
                          _saveProfileAndReturn,
                        ),
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

  // --- HELPER WIDGETS ---

  ImageProvider _getProfileImage() {
    if (_profileImagePath != null) {
      return FileImage(File(_profileImagePath!));
    }
    // Jika tidak ada gambar baru, gunakan asset. Pastikan file ini ada!
    // Jika tidak ada, ganti dengan NetworkImage atau Icon sementara.
    return const AssetImage('assets/profile_placeholder.jpg'); 
  }

  Widget _buildImageSourceButton(IconData icon, String text, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: const Color(0xFFE54721)),
      label: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 2,
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, TextInputType keyboardType) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color backgroundColor, Color textColor, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 15.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        elevation: 0, 
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}