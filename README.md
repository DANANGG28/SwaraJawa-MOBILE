# SINAU APP (sjmobile)

Aplikasi mobile pembelajaran Bahasa & Budaya Jawa. Frontend Flutter yang
menembak backend Laravel di `https://sinau-app.my.id/api`.

## Kebutuhan

- Flutter `3.47.6` (stable)
- JDK 17
- Android SDK, NDK `28.2.13676358` (`android/app/build.gradle.kts`)

## Konfigurasi API

Base URL diatur di `lib/core/config/app_config.dart`:

| Build | Base URL | Cara override |
|---|---|---|
| `--release` | `https://sinau-app.my.id/api` (produksi) | `--dart-define=SJ_BASE_URL=...` |
| debug/profile Android | `http://10.0.2.2:8000/api` | `--dart-define=SJ_BASE_URL=...` |
| debug/profile web/desktop | `http://localhost:8000/api` | `--dart-define=SJ_BASE_URL=...` |

Build rilis selalu menembak produksi; `SJ_BASE_URL` hanya dipakai untuk
menimpa backend saat menguji rilis lokal.

Login Google butuh `--dart-define=SJ_GOOGLE_SERVER_CLIENT_ID=<client-id web>`.
Tanpa nilai itu tombol Google Sign-In dinonaktifkan.

## Menjalankan

```bash
flutter pub get
flutter run                       # debug, backend dev
flutter test
flutter analyze
flutter build apk --release \
  --dart-define=SJ_GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
```

Skrip Windows yang sudah ada: `run_debug.bat`, `run_prod.bat`, `build_prod.bat`.

## CI — `.github/workflows/flutter_ci.yml`

Jalan pada push ke `main`, pull request ke `main`, dan `workflow_dispatch`.

1. **Analyze & test** — `flutter analyze`, `flutter test`.
2. **Android debug build** — `flutter build apk --debug` untuk mendeteksi
   kerusakan build native (Kotlin widget, NDK, manifest).

## CD — `.github/workflows/release_apk.yml`

Jalan saat tag `v*` dipush atau lewat `workflow_dispatch`.

1. Build `app-release.apk` dengan API produksi dan Google client ID produksi.
2. Verifikasi APK memuat host produksi (`sinau-app.my.id`); build gagal kalau tidak.
3. Upload APK sebagai artifact; pada tag, APK juga dilampirkan ke GitHub Release.
4. Versi APK: `--build-name` = tag tanpa `v` (dispatch: input `version`),
   `--build-number` = nomor run GitHub Actions.

Rilis:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

### Signing APK rilis

Tanpa secret, APK rilis ditandatangani debug keystore — hanya untuk uji coba,
tidak bisa meng-update aplikasi yang sudah terpasang. Untuk signing produksi,
set secrets repository berikut:

| Secret | Isi |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | keystore `.jks` dalam base64 (`base64 -w0 release.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | password keystore |
| `ANDROID_KEY_ALIAS` | alias key |
| `ANDROID_KEY_PASSWORD` | password key |

`android/app/build.gradle.kts` membaca `android/key.properties` (di-gitignore):

```properties
storeFile=release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

`storeFile` relatif terhadap `android/app/`. Bila `key.properties` ada, build
lokal juga otomatis memakai kunci rilis itu.

## Backend

Kontrak API: `API_DOCUMENTATION.md`. Rencana OAuth Google: `LARAVEL_GOOGLE_OAUTH_TASK.md`.
