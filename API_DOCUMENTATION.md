# Dokumentasi REST API — Sinau Jowo
**Platform Pembelajaran Interaktif Bahasa dan Budaya Jawa**
*Panduan Integrasi Aplikasi Mobile (Flutter) & Web API*

---

## 1. Ikhtisar & Ketentuan Umum

Dokumentasi ini ditujukan bagi pengembang aplikasi mobile (Flutter) untuk mengonsumsi layanan backend Sinau Jowo berbasis Laravel 11 dan PostgreSQL/SQLite.

### 1.1 Base URL
- **Pengembangan Lokal (Emulator Android):** `http://10.0.2.2:8000/api`
- **Pengembangan Lokal (Perangkat Fisik / LAN):** `http://<IP-KOMPUTER-ANDA>:8000/api`
- **Produksi / Staging:** `https://sinau.urisowonbangkalan.tech/api`

### 1.2 Header Standar HTTP
Setiap request dari aplikasi Flutter **wajib** menyertakan header berikut:
```http
Accept: application/json
Content-Type: application/json
```
Untuk endpoint yang membutuhkan autentikasi, sertakan token autentikasi (Laravel Sanctum):
```http
Authorization: Bearer <PERSONAL_ACCESS_TOKEN>
```
*Catatan:* Untuk request upload file (audio/gambar), gunakan `multipart/form-data` (jangan set `Content-Type: application/json` secara manual pada Dio/HTTP).

### 1.3 Format Respon Standar
- **Respon Sukses (200 / 201):**
```json
{
  "message": "Operasi berhasil.",
  "data": { ... }
}
```
- **Respon Galat Validasi Form (422 Unprocessable Content):**
```json
{
  "message": "Nama lengkap hanya boleh berisi huruf dan spasi.",
  "errors": {
    "nama_lengkap": [
      "Nama lengkap hanya boleh berisi huruf dan spasi."
    ]
  }
}
```
- **Respon Galat Autentikasi / Otorisasi (401 Unauthorized / 403 Forbidden):**
```json
{
  "message": "Unauthenticated."
}
```

---

## 2. Autentikasi & Akun Pengguna

### 2.1 Registrasi Mandiri Siswa
Mendaftarkan akun siswa baru.
- **Endpoint:** `POST /auth/siswa/register`
- **Akses:** Publik (tanpa token)
- **Aturan Validasi Form:**
  - `nama_lengkap` (wajib, string, max 255): **Hanya boleh huruf dan spasi** (`/^[a-zA-Z\s]+$/`). Tidak boleh ada angka atau simbol. Unik case-insensitive.
  - `nis` (wajib, string, min 4, max 30): **Hanya boleh angka** (`/^[0-9]+$/`). **Tidak unik** (duplikat diperbolehkan).
  - `jenis_kelamin` (wajib, enum): `'L'` atau `'P'`.
  - `kelas` (opsional, string, max 50): Contoh `'7A'`, `'8B'`.
  - `no_telpon` (opsional, string, min 9, max 20): Hanya angka (`/^[0-9]+$/`). **Wajib unik lintas seluruh akun** jika diisi.
  - `email` (wajib, email, max 255): Wajib unik case-insensitive.
  - `password` (wajib, string, min 8).

**Request Body (JSON):**
```json
{
  "nama_lengkap": "Andi Prasetyo",
  "nis": "2026010042",
  "jenis_kelamin": "L",
  "kelas": "7A",
  "no_telpon": "081234567890",
  "email": "andi@sinaujowo.test",
  "password": "password123"
}
```

**Respon Sukses (201 Created):**
```json
{
  "message": "Registrasi siswa berhasil.",
  "role": "siswa",
  "user": {
    "id": 1,
    "nis": "2026010042",
    "nama_lengkap": "Andi Prasetyo",
    "jenis_kelamin": "L",
    "kelas": "7A",
    "no_telpon": "081234567890",
    "email": "andi@sinaujowo.test",
    "created_at": "2026-09-29T08:00:00.000000Z"
  },
  "token": "1|qX8z9...plainTextToken"
}
```

---

### 2.2 Login Terpadu (Unified Login)
Login otomatis mendeteksi peran pengguna (`siswa`, `guru`, atau `superadmin`) dari email.
- **Endpoint:** `POST /auth/login`
- **Akses:** Publik

**Request Body (JSON):**
```json
{
  "email": "andi@sinaujowo.test",
  "password": "password123"
}
```

**Respon Sukses (200 OK):**
```json
{
  "message": "Login berhasil.",
  "role": "siswa",
  "user": {
    "id": 1,
    "nama_lengkap": "Andi Prasetyo",
    "email": "andi@sinaujowo.test",
    "nis": "2026010042",
    "kelas": "7A"
  },
  "token": "2|kY7w1...plainTextToken"
}
```

---

### 2.3 Login Berdasarkan Peran Spesifik
Alternatif login bila aplikasi Flutter ingin membatasi form login hanya untuk siswa/guru/superadmin:
- `POST /auth/siswa/login`
- `POST /auth/guru/login`
- `POST /auth/superadmin/login`

**Request Body:** `{"email": "...", "password": "..."}`  
**Respon Sukses (200 OK):** Mengembalikan data user dan token bearer.

---

### 2.4 Data Profil Pengguna Saat Ini
Mengambil informasi lengkap profil pengguna yang sedang login.
- **Endpoint:** `GET /me`
- **Headers:** `Authorization: Bearer <token>`
- **Akses:** Siswa, Guru, Superadmin

**Respon Sukses (200 OK):**
```json
{
  "role": "siswa",
  "user": {
    "id": 1,
    "nis": "2026010042",
    "nama_lengkap": "Andi Prasetyo",
    "jenis_kelamin": "L",
    "kelas": "7A",
    "no_telpon": "081234567890",
    "email": "andi@sinaujowo.test",
    "exp": {
      "total_exp": 150
    },
    "strek": {
      "current_streak": 5,
      "highest_streak": 12,
      "last_activity_date": "2026-09-29"
    }
  }
}
```

---

### 2.5 Logout
Mencabut token sesi yang sedang aktif.
- **Endpoint:** `POST /auth/logout`
- **Headers:** `Authorization: Bearer <token>`
- **Respon Sukses (200 OK):** `{"message": "Logout berhasil."}`

---

## 3. Materi & Kurikulum Pembelajaran (Khusus Siswa)

Sistem menggunakan hierarki 3-tingkat: **Topik** → **Unit (`level_materi`)** → **Bagian (`pembahasan`)** → **Butir Soal (`soal`)**.

### 3.1 Daftar Unit Materi & Status Progres
Mengambil seluruh unit materi berurutan beserta status pembukaan untuk siswa yang login.
- **Endpoint:** `GET /materi`
- **Headers:** `Authorization: Bearer <token>`
- **Status level:** `'terkunci'`, `'berjalan'`, atau `'selesai'`.

**Respon Sukses (200 OK):**
```json
{
  "data": [
    {
      "id": 1,
      "nama_materi": "Salam & Unggah-Ungguh Dasar",
      "deskripsi": "Sinau salam nalika ketemu kanca, guru, lan tiyang sepuh.",
      "reward_exp": 100,
      "urutan": 1,
      "jumlah_soal": 6,
      "status": "selesai",
      "tanggal_selesai": "2026-09-28T10:15:00.000000Z"
    },
    {
      "id": 2,
      "nama_materi": "Tembung Krama Inggil",
      "deskripsi": "Sinau tembung krama kanggo pacelathon saben dinten.",
      "reward_exp": 120,
      "urutan": 2,
      "jumlah_soal": 8,
      "status": "berjalan",
      "tanggal_selesai": null
    },
    {
      "id": 3,
      "nama_materi": "Aksara Jawa Legena",
      "deskripsi": "Ngenal lan nulis 20 aksara Jawa nglegena.",
      "reward_exp": 150,
      "urutan": 3,
      "jumlah_soal": 10,
      "status": "terkunci",
      "tanggal_selesai": null
    }
  ]
}
```

---

### 3.2 Detail Unit Materi & Daftar Soal
Mengambil detail unit beserta butir soal di dalamnya untuk disajikan pada halaman kuis mobile.
- **Endpoint:** `GET /materi/{levelMateriId}`
- **Query Params:** `with_kunci=1` (opsional, hanya saat mode koreksi jika diizinkan).
- **Headers:** `Authorization: Bearer <token>`

**Respon Sukses (200 OK):**
```json
{
  "data": {
    "level_materi": {
      "id": 1,
      "nama_materi": "Salam & Unggah-Ungguh Dasar",
      "deskripsi": "Sinau salam...",
      "reward_exp": 100,
      "urutan": 1
    },
    "status": "berjalan",
    "soal": [
      {
        "id": 10,
        "level_materi_id": 1,
        "tipe_soal": "pilihan_ganda",
        "pertanyaan": "Salam nalika ketemu kanca ing wayah esuk yaiku ...",
        "opsi_jawaban": [
          {"label": "A", "teks": "Sugeng enjing"},
          {"label": "B", "teks": "Sugeng siang"},
          {"label": "C", "teks": "Sugeng sonten"},
          {"label": "D", "teks": "Sugeng dalu"}
        ],
        "media_audio_url": null,
        "bobot_exp": 10
      },
      {
        "id": 11,
        "level_materi_id": 1,
        "tipe_soal": "susun_kalimat",
        "pertanyaan": "Susun dadi ukara kang bener.",
        "opsi_jawaban": ["sekolah", "Kula", "tindak", "badhe"],
        "media_audio_url": null,
        "bobot_exp": 15
      }
    ]
  }
}
```

---

### 3.3 Mulai Sesi Kuis Unit
Memvalidasi apakah prasyarat unit sebelumnya sudah diselesaikan.
- **Endpoint:** `POST /materi/{levelMateriId}/mulai`
- **Headers:** `Authorization: Bearer <token>`
- **Respon Sukses (200 OK):** `{"message": "Sesi quiz dimulai.", "level_materi_id": 2}`
- **Respon Error (403 Forbidden):** `{"message": "Materi belum tercapai. Selesaikan materi prasyarat terlebih dahulu."}`

---

## 4. Evaluasi & Pengerjaan Kuis

### 4.1 Menjawab Butir Soal
Mengirimkan jawaban untuk satu butir soal. Sistem secara otomatis mengevaluasi jawaban, memberikan skor (0-100), mencatat EXP, dan mengupdate streak siswa.
- **Endpoint:** `POST /kuis/jawab`
- **Headers:** `Authorization: Bearer <token>`

#### A. Format Jawaban per `tipe_soal`:
1. **Pilihan Ganda (`pilihan_ganda`):**
   ```json
   {
     "soal_id": 10,
     "jawaban": "A"
   }
   ```
2. **Susun Kalimat (`susun_kalimat`):**
   ```json
   {
     "soal_id": 11,
     "jawaban": ["Kula", "badhe", "tindak", "sekolah"]
   }
   ```
3. **Puzzle Pakaian Adat (`puzzle_pakaian_adat`):**
   ```json
   {
     "soal_id": 12,
     "jawaban": ["Blangkon", "Beskap", "Stagen", "Jarik", "Selop"]
   }
   ```
4. **Menulis Aksara Tracing (`menulis_aksara`):**
   Mengirim array goresan kurva koordinat `[[{x, y}, ...]]`:
   ```json
   {
     "soal_id": 13,
     "jawaban": {
       "paths": [
         [{"x": 50, "y": 40}, {"x": 55, "y": 70}, {"x": 80, "y": 70}]
       ]
     }
   }
   ```

**Respon Sukses (200 OK):**
```json
{
  "message": "Jawaban benar!",
  "benar": true,
  "skor": 100,
  "skor_tertinggi": 100,
  "detail": {
    "kunci": "Sugeng enjing",
    "jawaban": "Sugeng enjing"
  },
  "kunci_jawaban": {
    "jawaban": "A"
  },
  "exp_didapat": 10,
  "reward_exp": 0,
  "level_selesai": false,
  "level_berikutnya": null,
  "total_exp": 160,
  "current_streak": 5,
  "highest_streak": 12
}
```

---

### 4.2 Menyelesaikan Level Unit
Dipanggil saat seluruh butir soal dalam unit selesai dikerjakan untuk mengklaim `reward_exp` unit dan membuka unit materi berikutnya.
- **Endpoint:** `POST /kuis/selesai`
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
```json
{
  "level_materi_id": 1
}
```
**Respon Sukses (200 OK):**
```json
{
  "message": "Level Salam & Unggah-Ungguh Dasar selesai.",
  "reward_exp": 100,
  "total_exp": 260,
  "current_streak": 5
}
```

---

## 5. Gamifikasi & Progres Siswa

### 5.1 Rekap Capaian & Progres Belajar
- **Endpoint:** `GET /progres`
- **Headers:** `Authorization: Bearer <token>`

**Respon Sukses (200 OK):**
```json
{
  "ringkasan": {
    "total_exp": 260,
    "current_streak": 5,
    "highest_streak": 12,
    "level_selesai": 1,
    "total_level": 5,
    "persentase": 20
  },
  "levels": [
    {
      "id": 1,
      "nama_materi": "Salam & Unggah-Ungguh Dasar",
      "urutan": 1,
      "status": "selesai",
      "tanggal_selesai": "2026-09-28T10:15:00.000000Z"
    },
    {
      "id": 2,
      "nama_materi": "Tembung Krama Inggil",
      "urutan": 2,
      "status": "berjalan",
      "tanggal_selesai": null
    }
  ]
}
```

---

### 5.2 Papan Peringkat (Leaderboard)
Menampilkan 50 siswa dengan perolehan EXP tertinggi.
- **Endpoint:** `GET /leaderboard`
- **Headers:** `Authorization: Bearer <token>`

**Respon Sukses (200 OK):**
```json
{
  "leaderboard": [
    {
      "peringkat": 1,
      "siswa_id": 2,
      "nama_lengkap": "Siti Rahayu",
      "kelas": "7A",
      "total_exp": 520,
      "streak": 12
    },
    {
      "peringkat": 2,
      "siswa_id": 1,
      "nama_lengkap": "Andi Prasetyo",
      "kelas": "7A",
      "total_exp": 260,
      "streak": 5
    }
  ]
}
```

---

## 6. AI Asisten Belajar (RAG Chatbot)

Chatbot edukasi khusus Bahasa & Budaya Jawa dengan guardrail korpus lokal.

### 6.1 Mengajukan Pertanyaan ke Chatbot
- **Endpoint:** `POST /chat`
- **Rate Limit:** 30 request / menit
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
```json
{
  "pertanyaan": "Kapan wektu sing bener kanggo matur nganggo basa krama alus?",
  "session_id": null
}
```
*Catatan:* Kirim `session_id` yang didapat dari respon sebelumnya jika ingin melanjutkan percakapan dalam sesi yang sama.

**Respon Sukses (200 OK):**
```json
{
  "jawaban": "Basa krama alus digunakake nalika matur marang tiyang ingkang langkung sepuh utawi kinurmatan, kados ta bapak, ibu, simbah, lan guru...",
  "sumber": [
    "Kamus Unggah-Ungguh Basa Jawa",
    "Korpus Tata Krama"
  ],
  "session_id": 4,
  "session_title": "Kapan wektu sing bener kanggo matur nganggo..."
}
```

---

### 6.2 Riwayat Sesi Chat Siswa
- **Endpoint:** `GET /chat/histori`
- **Headers:** `Authorization: Bearer <token>`
- **Respon Sukses (200 OK):** Daftar hingga 20 sesi chat terakhir milik siswa.

### 6.3 Detail Riwayat Percakapan
- **Endpoint:** `GET /chat/sesi/{sessionId}`
- **Respon Sukses (200 OK):**
```json
{
  "session": {
    "id": 4,
    "judul": "Kapan wektu sing bener...",
    "messages": [
      {"role": "user", "pesan": "Kapan wektu..."},
      {"role": "assistant", "pesan": "Basa krama alus digunakake..."}
    ]
  }
}
```

### 6.4 Hapus Sesi Chat
- **Endpoint:** `DELETE /chat/sesi/{sessionId}`
- **Respon Sukses (200 OK):** `{"message": "Sesi chat berhasil dihapus."}`

---

## 7. Layanan Suara (TTS, STT, STS & Kuis Suara)

### 7.1 Text-to-Speech (TTS)
Mengubah teks Bahasa Jawa menjadi audio lisan.
- **Endpoint:** `POST /speech/tts`
- **Headers:** `Authorization: Bearer <token>`
- **Request Body:**
```json
{
  "teks": "Sugeng rawuh ing aplikasi Sinau Jowo.",
  "voice": null
}
```
**Respon Sukses (200 OK):**
```json
{
  "audio_url": "/storage/audio/tts/tts_xyz123.mp3",
  "durasi_detik": 2.4,
  "mock": false
}
```

---

### 7.2 Evaluasi Kuis Suara (Pelafalan Berbobot EXP)
Mengirimkan file rekaman audio ucapan siswa untuk dinilai kecocokan lafalnya terhadap referensi soal kuis.
- **Endpoint:** `POST /soal/{soalId}/quiz-suara`
- **Content-Type:** `multipart/form-data`
- **Headers:** `Authorization: Bearer <token>`
- **Form Fields:**
  - `audio`: File audio (`mp3`, `wav`, `m4a`, `webm`, `ogg`, `flac`, max 10 MB).
  - `mock_transcript`: String teks (opsional, untuk testing emulator).

**Respon Sukses (200 OK):**
```json
{
  "mock": false,
  "transkripsi": "sugeng enjing",
  "skor": 95,
  "kategori": "benar",
  "audio_umpan_balik_url": "/storage/audio/tts/feedback_abc.mp3",
  "exp_didapat": 20,
  "total_exp": 280,
  "current_streak": 5
}
```

---

### 7.3 Latihan Ngomong Bebas (Tanpa EXP)
Latihan pelafalan bebas dengan feedback kualitatif dari AI RAG tanpa mengurangi kesempatan kuis.
- **Endpoint:** `POST /soal/{soalId}/latihan-ngomong`
- **Content-Type:** `multipart/form-data`
- **Headers:** `Authorization: Bearer <token>`

---

## 8. Contoh Implementasi Klien Flutter (Dart)

Berikut adalah contoh arsitektur kode service pada Flutter menggunakan package `dio`:

### 8.1 Setup `ApiClient` Terpusat
```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  final Dio dio;
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            // Arahkan ke halaman login (token expired/invalid)
          }
          return handler.next(error);
        },
      ),
    );
  }
}
```

### 8.2 Registrasi Siswa dengan Penanganan Error Form
```dart
Future<void> registerSiswa({
  required String namaLengkap,
  required String nis,
  required String jenisKelamin,
  required String email,
  required String password,
  String? noTelpon,
  String? kelas,
}) async {
  try {
    final response = await apiClient.dio.post(
      '/auth/siswa/register',
      data: {
        'nama_lengkap': namaLengkap,
        'nis': nis,
        'jenis_kelamin': jenisKelamin,
        'email': email,
        'password': password,
        if (noTelpon != null && noTelpon.isNotEmpty) 'no_telpon': noTelpon,
        if (kelas != null && kelas.isNotEmpty) 'kelas': kelas,
      },
    );

    final token = response.data['token'];
    await apiClient.storage.write(key: 'auth_token', value: token);
  } on DioException catch (e) {
    if (e.response?.statusCode == 422) {
      final errors = e.response?.data['errors'] as Map<String, dynamic>;
      // Tangani pesan error per field (misal nama hanya huruf, telpon duplikat, dll.)
      throw Exception(errors.values.first[0]);
    }
    throw Exception('Gagal registrasi: ${e.message}');
  }
}
```

### 8.3 Mengirim Jawaban Kuis
```dart
Future<Map<String, dynamic>> submitJawaban({
  required int soalId,
  required dynamic jawaban,
}) async {
  final response = await apiClient.dio.post(
    '/kuis/jawab',
    data: {
      'soal_id': soalId,
      'jawaban': jawaban,
    },
  );
  return response.data;
}
```

---

## 9. Ringkasan Kode Status HTTP (HTTP Status Codes)

| Kode | Keterangan | Penanganan di Flutter |
|---|---|---|
| **200 OK** | Permintaan sukses dan data dikembalikan. | Parsing data JSON ke model Dart. |
| **201 Created** | Data/akun baru berhasil dibuat. | Simpan token auth atau perbarui antarmuka. |
| **401 Unauthorized** | Token tidak valid, kadaluarsa, atau kredensial login salah. | Bersihkan token di storage dan arahkan user ke layar Login. |
| **403 Forbidden** | Akun tidak memiliki hak akses (misal siswa mencoba akses unit materi yang masih terkunci). | Tampilkan dialog peringatan prasyarat materi. |
| **404 Not Found** | Data soal atau unit materi tidak ditemukan. | Tampilkan pesan bahwa data tidak tersedia. |
| **422 Unprocessable Content** | Validasi input form gagal (nama tidak valid, format NIS salah, no telpon duplikat). | Tampilkan pesan error di bawah text field form terkait. |
| **429 Too Many Requests** | Terkena limit pemanggilan (misal chatbot melebihi 30 rpm). | Tampilkan pesan tunggu beberapa saat. |
| **500 Server Error** | Terjadi kendala internal server atau koneksi pihak ketiga. | Tampilkan snackbar galat sistem. |
