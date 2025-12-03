<?php
// Pengaturan Koneksi
$servername = "localhost";
$username = "root"; // Username default XAMPP
$password = ""; // Password default XAMPP
$dbname = "stridez"; // Nama database kamu

// Buat koneksi
$conn = new mysqli($servername, $username, $password, $dbname);

// Cek koneksi
if ($conn->connect_error) {
    die("Koneksi gagal: " . $conn->connect_error);
}

// Query untuk mengambil data
$sql = "SELECT * FROM users";
$result = $conn->query($sql);

$data = array();
if ($result->num_rows > 0) {
    // Ambil setiap baris data
    while($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
}

// Set header ke JSON dan tampilkan data
header('Content-Type: application/json');
echo json_encode($data);

$conn->close();
?>