# Laporan Proyek Akhir: Stridez Mobile Application

**Mata Kuliah:** Mobile Programming  
**Judul Proyek:** Stridez  

---

## 👥 Tim Pengembang

Proyek ini disusun dan dikembangkan oleh:

1.  **Natania Christin Agustina - 5024231014**
2.  **Aminah Nur'aini Muchayati - 5024231034**
3.  **Devanka Raditanti Citasevi - 5024231053**
4.  **Kadek Candra Dwi Yanti - 5024231067**
5.  **Aaron Smeraldo Olivier Manik - 5024231014**

---

LINK VIDEO DEMO PROJECT

---

## 1. Pendahuluan

### 1.1 Latar Belakang Masalah
Meningkatnya kesadaran masyarakat akan gaya hidup sehat mendorong kebutuhan akan alat bantu pemantauan aktivitas fisik yang praktis dan terjangkau. Namun, banyak aplikasi yang bergantung sepenuhnya pada koneksi internet stabil atau memerlukan perangkat *wearable* tambahan. **Stridez** dirancang sebagai solusi aplikasi *mobile* yang memanfaatkan sensor bawaan *smartphone* (accelerometer dan GPS) untuk menyediakan data aktivitas yang akurat, mandiri, dan terintegrasi dengan sistem penyimpanan berbasis *cloud*.

### 1.2 Rumusan Masalah
Tantangan utama dalam pengembangan aplikasi ini adalah:
1.  Bagaimana menghitung langkah kaki secara *real-time* menggunakan sensor perangkat keras tanpa menguras baterai secara berlebihan.
2.  Bagaimana melacak rute dan menghitung jarak lari menggunakan geolokasi dengan presisi tinggi.
3.  Bagaimana menyinkronkan data pengguna antara sistem autentikasi pihak ketiga (Firebase) dengan basis data internal (Backend Server).

### 1.3 Tujuan Proyek
* Menyediakan platform pelacakan aktivitas lari berbasis GPS dengan visualisasi rute interaktif.
* Mengimplementasikan algoritma penghitung langkah (pedometer) yang akurat.
* Membangun sistem autentikasi *hybrid* yang aman.
* Menyajikan analisis kesehatan dasar melalui perhitungan kalori dan BMI.

---

## 2. Metodologi & Proses Pengembangan

Pengembangan aplikasi ini mengikuti model **SDLC (Software Development Life Cycle)** dengan pendekatan *Iterative*, yang terdiri dari tahapan berikut:

### 2.1 Analisis Kebutuhan
* **Identifikasi Perangkat Keras:** Memastikan perangkat target memiliki sensor *Accelerometer*, *Gyroscope*, dan modul GPS.
* **Analisis API:** Menentukan kebutuhan Google Maps API untuk visualisasi rute dan Firebase SDK untuk autentikasi pengguna.

### 2.2 Perancangan Sistem (System Design)
* **Arsitektur:** Menggunakan pola **MVVM (Model-View-ViewModel)** secara implisit, memisahkan logika bisnis (Service Layer) dari antarmuka pengguna (UI Layer).
* **Manajemen State:** Menggunakan kombinasi `setState` untuk manajemen state lokal dan `Provider` untuk manajemen state global pada preferensi pengguna.

### 2.3 Implementasi (Coding)
Tahap penulisan kode dilakukan menggunakan **Flutter Framework** dengan bahasa **Dart**. Fokus utama pada tahap ini adalah integrasi sensor asinkron (`StreamSubscription`) untuk menangani aliran data sensor secara kontinu.

### 2.4 Pengujian (Testing)
* **Functional Testing:** Memastikan fitur login, logout, dan penyimpanan data berjalan sesuai skenario.
* **Field Testing:** Pengujian langsung pada perangkat fisik di luar ruangan untuk memvalidasi sensitivitas sensor langkah dan akurasi GPS.

---

## 3. Implementasi Fitur & Teknis

### 3.1 Algoritma Pedometer (Penghitung Langkah)
Fitur ini bekerja tanpa bergantung pada Google Fit API, melainkan memproses data sensor mentah secara mandiri.
* **Logika Deteksi:** Menggunakan **Magnitude Vector** dari data akselerometer 3-sumbu ($x, y, z$) dengan rumus $\sqrt{x^2 + y^2 + z^2}$.
* **Filterisasi:** Menerapkan *threshold* dinamis (batas bawah `10.5` dan batas atas `30.0`) untuk membedakan gerakan langkah kaki dengan getaran acak.
* **Cooldown Mechanism:** Menerapkan jeda waktu (*cooldown*) antar deteksi untuk mencegah perhitungan ganda (*double-counting*).

### 3.2 Pelacakan Lari Berbasis GPS (Geolocation)
* **Polyline Rendering:** Aplikasi merekam koordinat (`LatLng`) secara *real-time* dan menggambarkannya sebagai garis rute pada peta Google Maps.
* **Perhitungan Metrik:** Menggunakan formula *Haversine* untuk menghitung jarak tempuh, yang kemudian dikonversi menjadi kecepatan rata-rata (*Pace*) dan estimasi pembakaran kalori.

### 3.3 Autentikasi Hybrid & Sinkronisasi Data
Sistem login menggabungkan keamanan Firebase dengan fleksibilitas database backend SQL.
1.  **Firebase Auth:** Menangani validasi kredensial (Google Sign-In, OTP Telepon, Email).
2.  **Backend Sync:** Setelah login berhasil, aplikasi menyinkronkan UID dan profil pengguna ke server backend (`REST API`) untuk persistensi data jangka panjang.
3.  **Local Caching:** Data profil disimpan di `SharedPreferences` untuk akses cepat dan mode *offline*.

---

## 4. Hasil Akhir Proyek

Berdasarkan implementasi yang telah dilakukan, berikut adalah capaian fitur pada aplikasi Stridez:

### 4.1 Fungsionalitas Utama
* [x] **Dashboard Informatif:** Visualisasi langkah harian dan progres mingguan dengan grafik cincin (*ring chart*).
* [x] **Tracking Akurat:** Pedometer berfungsi baik pada berbagai posisi perangkat (saku/genggam).
* [x] **Manajemen Profil:** Fitur edit profil, unggah foto, dan kalkulator BMI otomatis.
* [x] **Riwayat Aktivitas:** Log aktivitas lari tersimpan lengkap dengan peta rute, durasi, dan jarak.

### 4.2 Tampilan Antarmuka (UI/UX)
Aplikasi mengusung desain modern dengan warna tema utama **Deep Orange** yang energik. Navigasi menggunakan *Bottom Navigation Bar* untuk kemudahan akses antar menu utama.

### 4.3 Kinerja Aplikasi
* **Efisiensi Baterai:** Penggunaan sensor dikelola dengan mematikan *stream* (`subscription.cancel()`) saat halaman tidak aktif.
* **Responsivitas:** Antarmuka berjalan lancar (60fps) berkat optimasi *rebuild* widget yang efisien.

---

## 5. Kesimpulan dan Saran

### 5.1 Kesimpulan
Tim pengembang berhasil menyelesaikan aplikasi Stridez sesuai dengan spesifikasi yang dirancang. Integrasi antara sensor perangkat keras, layanan peta digital, dan sinkronisasi basis data telah berjalan dengan stabil. Aplikasi ini membuktikan bahwa perangkat *mobile* standar dapat difungsikan sebagai alat pemantau kesehatan yang andal.

### 5.2 Saran Pengembangan
Untuk pengembangan selanjutnya, disarankan untuk:
* Menambahkan fitur sosial (Leaderboard/Sharing) untuk meningkatkan motivasi pengguna.
* Mengimplementasikan notifikasi lokal untuk pengingat aktivitas.
* Migrasi backend ke layanan Cloud publik (AWS/GCP) untuk aksesibilitas global.
