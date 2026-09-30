# TASK UNTUK AI — Tambahkan Google OAuth di Backend Laravel "Sinau Jowo"

> **Instruksi ini ditujukan untuk AI/agent yang mengerjakan proyek backend Laravel.**
> Repo Flutter (`sjmobile`) sudah selesai di sisi client. Tugas Anda HANYA di backend.
> Jangan mengubah repo Flutter.

---

## 0. Ringkasan singkat

Aplikasi mobile Flutter melakukan **Google Sign-In native** dan mendapatkan **Google ID token**.
ID token itu dikirim ke backend, lalu backend harus:

1. Memverifikasi ID token ke Google.
2. Mencari / membuat user berdasarkan email.
3. Menerbitkan token **Laravel Sanctum**.
4. Mengembalikan JSON dengan bentuk yang persis diharapkan client.

Saat ini `POST /api/auth/google` mengembalikan **404** (belum ada). Itulah yang harus dibuat.

---

## 1. Kontrak API yang WAJIB dipenuhi

### Endpoint
```
POST /api/auth/google
Content-Type: application/json
Accept: application/json
```

### Request body
```json
{ "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6..." }
```

### Response sukses — `200 OK`
Bentuknya **harus sama** dengan `POST /api/auth/login`:
```json
{
  "message": "Login dengan Google berhasil.",
  "role": "siswa",
  "user": {
    "id": 1,
    "nama_lengkap": "Andi Prasetyo",
    "email": "andi@gmail.com",
    "nis": "2026010042",
    "kelas": "7A",
    "jenis_kelamin": "L",
    "no_telpon": "081234567890",
    "created_at": "2026-09-29T08:00:00.000000Z"
  },
  "token": "3|xxxxxxxxxxxxxxxxplainTextToken"
}
```

### Response gagal
- `422` — `id_token` tidak dikirim:
  ```json
  { "message": "The id token field is required.", "errors": { "id_token": ["..."] } }
  ```
- `401` — ID token invalid/kadaluarsa/audience salah:
  ```json
  { "message": "Token Google tidak valid." }
  ```

### Kenapa harus persis seperti ini
Client Flutter (`lib/services/auth_service.dart`) membaca:
- `data['token']` → disimpan ke secure storage.
- `data['role']` → default `"siswa"` bila kosong.
- `data['user']` → di-parse oleh `Siswa.fromJson()` (`lib/models/siswa.dart`).

Field di dalam `user` yang dipakai client: `id`, `nama_lengkap`, `nis`, `jenis_kelamin`,
`kelas`, `no_telpon`, `email`, `foto`, `foto_url`, `created_at`. Field yang tidak ada
akan dianggap `null`, jadi kirim semampunya (minimal `id`, `nama_lengkap`, `email`).

---

## 2. Langkah 0 — Kenali dulu struktur proyek Laravel

Sebelum menulis kode, **inspeksi** proyek dan laporkan temuan Anda:

1. Versi Laravel: baca `composer.json`.
2. Buka `routes/api.php` — cari route `auth/login`, `auth/siswa/register`, `me`, `auth/logout`.
3. Cari controller auth (mis. `app/Http/Controllers/Auth/...`) dan pahami:
   - Bagaimana login terpadu mendeteksi `role` (`siswa`/`guru`/`superadmin`) dari email.
   - Bagaimana token Sanctum dibuat (`createToken(...)->plainTextToken`).
   - Nama kolom `role`/`nama_lengkap`/`nis`/`jenis_kelamin` di model User/Siswa.
4. Cek apakah Laravel Sanctum & Socialite sudah terpasang (`composer.json`).
5. Cek model user yang dipakai dan relasinya (mis. `User` vs `Siswa`).

**Jangan menebak** nama kolom/tabel — sesuaikan dengan kode yang ada. Gunakan pola &
helper yang sudah dipakai endpoint login agar konsisten (validasi, format response,
pengecekan role, dsb).

---

## 3. Langkah 1 — Pasang Laravel Socialite

```bash
composer require laravel/socialite
```

Tambahkan konfigurasi Google di `config/services.php`:
```php
'google' => [
    'client_id'     => env('GOOGLE_CLIENT_ID'),
    'client_secret' => env('GOOGLE_CLIENT_SECRET'),
    'redirect'      => env('GOOGLE_REDIRECT_URI', 'http://localhost'),
],
```

Tambahkan ke `.env` (dan `.env.example` tanpa nilai rahasia nyata):
```env
GOOGLE_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxxxxxx
GOOGLE_REDIRECT_URI=http://localhost
```

> `GOOGLE_CLIENT_ID` = **Web application** OAuth client ID. Ini yang sama dengan
> `serverClientId` di aplikasi Flutter. Untuk verifikasi `id_token` via
> `userFromToken()`, client secret tidak selalu wajib, tapi isi saja untuk berjaga.

---

## 4. Langkah 2 — Buat controller & route

Buat controller, mis. `app/Http/Controllers/Auth/GoogleAuthController.php`.
**Sesuaikan** nama model, kolom, dan logika role dengan hasil inspeksi di Langkah 0.

```php
<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User; // sesuaikan: bisa User / Siswa
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Socialite\Facades\Socialite;

class GoogleAuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate([
            'id_token' => ['required', 'string'],
        ]);

        try {
            $google = Socialite::driver('google')
                ->stateless()
                ->userFromToken($request->input('id_token'));
        } catch (\Throwable $e) {
            report($e);
            return response()->json(
                ['message' => 'Token Google tidak valid.'],
                401
            );
        }

        $email = strtolower((string) $google->getEmail());
        if ($email === '') {
            return response()->json(
                ['message' => 'Akun Google tidak memiliki email.'],
                422
            );
        }

        // --- Cari user; jika belum ada, buat akun siswa otomatis. ---
        // SESUAIKAN dengan model & kolom proyek Anda.
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        if (! $user) {
            $user = DB::transaction(function () use ($google, $email) {
                return User::create([
                    'nama_lengkap'   => $google->getName() ?: Str::before($email, '@'),
                    'email'          => $email,
                    'jenis_kelamin'  => 'L',          // wajib diisi; minta user melengkapi nanti
                    'nis'            => null,          // boleh null; dilengkapi via profil
                    'kelas'          => null,
                    'no_telpon'      => null,
                    'password'       => Hash::make(Str::random(32)),
                    'role'           => 'siswa',       // sesuaikan mekanisme role di proyek
                    'email_verified_at' => now(),
                ]);
            });
        }

        $role  = $user->role ?? 'siswa';               // sesuaikan cara membaca role
        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'message' => 'Login dengan Google berhasil.',
            'role'    => $role,
            'user'    => $user->fresh(),
            'token'   => $token,
        ]);
    }
}
```

Daftarkan route di `routes/api.php` (di luar middleware `auth:sanctum`, karena publik):
```php
use App\Http\Controllers\Auth\GoogleAuthController;

Route::post('/auth/google', [GoogleAuthController::class, 'login']);
```

### Hal penting yang harus dicek AI saat menyesuaikan
- **Nama tabel/model**: jika proyek memakai model `Siswa` terpisah, sesuaikan.
- **Kolom `role`**: pakai mekanisme yang sama dengan login terpadu (mis. tabel `roles`,
  kolom `role`, atau pemisahan model). Jangan hardcode tanpa memeriksa.
- **Validasi unik**: email wajib unik case-insensitive (lihat aturan di
  `API_DOCUMENTATION.md`). `firstOrCreate` biasa bisa gagal karena case; gunakan
  pencarian `LOWER(email)` seperti contoh.
- **Kolom NOT NULL tanpa default**: `jenis_kelamin` wajib menurut dokumentasi.
  Beri nilai default `'L'` agar insert tidak gagal; user melengkapi lewat halaman profil.
  Jika ada kolom NOT NULL lain, beri default juga.
- **Hash password**: user OAuth tidak login pakai password, isi random hash.
- **Sanctum**: pastikan model user memakai trait `HasApiTokens`.
- **Jangan** mengekspos `remember_token`/`password` di response. Gunakan
  `->makeHidden(['password','remember_token'])` atau Resource bila proyek punya.

---

## 5. Langkah 3 — Verifikasi (wajib dilakukan AI)

### 5.1 Route terdaftar
```bash
php artisan route:list | grep google
```

### 5.2 Validasi input
```bash
curl -i -X POST http://localhost:8000/api/auth/google \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{}'
# Harus 422, bukan 404
```

### 5.3 Token invalid
```bash
curl -i -X POST http://localhost:8000/api/auth/google \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"id_token":"dummy"}'
# Harus 401 "Token Google tidak valid.", bukan 500
```

### 5.4 Uji token asli (end-to-end)
Minta token nyata dari device/emulator yang menjalankan aplikasi Flutter, atau
pakai aplikasi Flutter langsung. Lalu:
```bash
curl -i -X POST http://localhost:8000/api/auth/google \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -d '{"id_token":"<ID_TOKEN_ASLI>"}'
# Harus 200 dengan { message, role, user, token }
```
Pastikan token hasilnya bisa dipakai:
```bash
curl -i http://localhost:8000/api/me -H "Accept: application/json" \
  -H "Authorization: Bearer <TOKEN>"
# Harus 200 dengan { role, user, ... }
```

### 5.5 Regression
- `POST /api/auth/login` dengan kredensial benar masih 200.
- `POST /api/auth/siswa/register` masih berfungsi.

---

## 6. Kriteria selesai (Definition of Done)

- [ ] `composer require laravel/socialite` terpasang.
- [ ] `config/services.php` punya blok `google`.
- [ ] `.env` / `.env.example` memuat `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`.
- [ ] `POST /api/auth/google` ada, publik (tanpa auth), tidak 404.
- [ ] Body `{}` → 422; `id_token` palsu → 401.
- [ ] `id_token` valid → 200 dengan `{ message, role, user, token }`.
- [ ] User baru otomatis dibuat bila email Google belum terdaftar (role siswa).
- [ ] User lama (email sudah ada) tetap login ke akun yang sama (tidak duplikat).
- [ ] Token bisa dipakai di `GET /api/me`.
- [ ] Login/registrasi email-password lama tidak rusak.
- [ ] Tidak ada password/secret yang bocor di response atau log.

---

## 7. Data Google Cloud yang sudah tersedia (untuk referensi)

- **Package name Android**: `com.example.sjmobile`
- **SHA-1 debug**:
  `95:2B:D3:3A:A9:23:CC:95:6D:A8:19:E1:C1:B0:FB:5A:AA:5E:BA:3A`
- **SHA-256 debug**:
  `52:AE:A5:5E:17:96:6D:96:E0:1C:38:B8:3F:54:D7:DB:D6:17:A0:F8:56:11:A6:65:B1:BB:A6:6D:D0:C1:FA:C6`
- **Web client ID** (untuk `GOOGLE_CLIENT_ID` & `serverClientId` Flutter):
  diisi oleh pemilik proyek saat build/konfigurasi.
- ID token diverifikasi oleh Socialite memakai **client ID = nilai `serverClientId`**
  yang dipakai aplikasi Android. Pastikan nilainya sama, kalau tidak Google akan
  menolak (audience mismatch).

---

## 8. Yang TIDAK perlu dilakukan AI di task ini

- Tidak mengubah repositori Flutter (`sjmobile`).
- Tidak membuat endpoint redirect/callback berbasis browser (flow yang dipakai
  adalah native `id_token`, stateless).
- Tidak mengubah endpoint login/register yang sudah ada, kecuali refactor kecil
  untuk berbagi helper pembuatan token (opsional, hanya bila aman).
