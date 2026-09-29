# Product Requirements Document (PRD)
## Sinau Jowo
**Platform Pembelajaran Interaktif Bahasa dan Budaya Jawa Berbasis Mobile & Web**

Versi 1.7.2 — Politeknik Negeri Jember (Polije), Tugas Kelompok Semester 3, 2026

> **Catatan revisi v1.1:** Menyempurnakan v1.0 berdasarkan flowchart alur sistem dan ERD yang sudah dibuat tim. Perubahan utama: (1) peran pengguna dipecah menjadi tiga — **Siswa, Guru, Superadmin** (sebelumnya "guru/admin" digabung), (2) penambahan Bagian 6A Model Data (ERD) dan Bagian 6B Alur Sistem (Flowchart), (3) penyesuaian Functional Requirements & User Stories agar konsisten dengan hak akses tiap peran di flowchart, (4) penambahan Open Questions baru dari temuan desain ERD; juga ditambahkan bagian Tech Stack (Laravel + PostgreSQL untuk web, Flutter untuk mobile).
>
> **Catatan revisi v1.2:** Menjawab sebagian Open Questions v1.1 — lihat Bagian 10.1 (Keputusan): metodologi uji hanya simulasi internal, struktur JSON soal diserahkan ke tim dev, kebutuhan tabel pivot progres siswa dikonfirmasi, pembatasan pemantauan guru per kelas, dan hak edit soal guru dibatasi ke miliknya sendiri. Untuk 2 pertanyaan yang belum diputuskan (sumber korpus & API TTS/STT), ditambahkan rekomendasi awal di Bagian 10.2.
>
> **Catatan revisi v1.3:** Menambahkan Bagian 6C — arsitektur Speech-to-Speech (STS), yang sebelumnya hanya disebut satu baris di FR-8 tanpa penjelasan. Pipeline STT (Google) → Modul Pemrosesan Respons → TTS (Azure) ditambahkan sebagai Opsi A, dengan risiko latensi gabungan ditambahkan ke Bagian 9.
>
> **Catatan revisi v1.4 (koreksi):** v1.3 sempat menyatakan tidak ada vendor dengan model STS native untuk Bahasa Jawa — **ini tidak akurat**. Ditemukan bahwa mode *Live Translation* pada Gemini Live API (`gemini-3.5-live-translate-preview`) resmi mendukung Bahasa Jawa (`jv`) sebagai model satu-panggilan (Opsi B di Bagian 6C), meski sifatnya murni penerjemah (bukan pengganti logika penilaian jawaban di Opsi A).
>
> **Catatan revisi v1.5 (sinkronisasi dengan Laporan Resmi Kelompok 1):** Menyesuaikan PRD dengan dokumen `LAPORAN_SISTEM_PEMBELAJARAN_BAHASA_BUDAYA_JAWA.pdf`. Perubahan: (1) Tujuan Produk (3.1) ditulis ulang mengikuti 5 Tujuan Khusus di laporan; (2) ditambahkan FR-21 Latihan Puzzle Pakaian Adat dan cakupan materi budaya (busana adat, rumah adat, kesenian tradisional) yang sebelumnya tidak tercakup; (3) NFR ditambah poin Kemudahan Penggunaan (Usability) terpisah dari Kompatibilitas; (4) relasi "Memantau" guru–siswa diperjelas mengikuti kalimat asli laporan ("sesuai kelas **atau mata pelajaran** terkait"), bukan hanya dibatasi per kelas; (5) ditambahkan catatan bahwa kelompok data "basis pengetahuan RAG" yang disebut di laporan belum benar-benar dimodelkan sebagai entitas ERD; (6) nama kolom ERD (6A) **sengaja distandarkan** (`jenis_kelamin`, `status_pegawaian`, `created_at`/`updated_at` konsisten di semua tabel) alih-alih menyalin penulisan tidak konsisten dari laporan asli (`jenis_klamin`, `st_pegawaian`, `update_at`, `create_at`).
>
> **Catatan revisi v1.6:** Menambahkan **FR-22 Latihan Menulis Aksara Jawa (Tracing)** dan Bagian 6D — kanvas dengan template bayangan yang ditelusuri siswa, skor kemiripan dihitung dengan algoritma geometris ringan ($1/$N Recognizer) sebelum goresan kasar siswa dianimasikan ("snap") menjadi bentuk baku. Risiko terkait toleransi algoritma pengenalan goresan ditambahkan ke Bagian 9.
>
> **Catatan revisi v1.7:** Menambahkan entitas **`test`** dan pivot **`test_soal`** ke Bagian 6A, serta **FR-23**. Keputusan: komposisi latihan diatur berdasarkan `tipe_soal` pada tiap butir soal (bukan "jenis test" terpisah yang mengunci satu tipe) — guru/superadmin bebas menyusun satu `test` berisi campuran beberapa tipe soal, atau hanya satu tipe soal yang sama, sesuai kebutuhan (variatif vs. remedial/drilling). Sistem tidak membatasi ini di level skema database.
>
> **Catatan revisi v1.7.1 (Sinkronisasi Fitur CRUD Akun & UI Detail Superadmin):** Menyempurnakan spesifikasi FR-17 & FR-18 terkait manajemen akun Guru dan Siswa oleh Superadmin. Penyesuaian mencakup: (1) pemisahan form pendaftaran (`create`) dan form sunting (`edit`) ke halaman antarmuka terpisah (`/superadmin/guru/tambah`, `/superadmin/guru/{id}/edit`, `/superadmin/siswa/tambah`, `/superadmin/siswa/{id}/edit`), (2) penambahan atribut `foto` pada entitas `guru`, `siswa`, dan `superadmin` beserta upload berkas foto profil ke direktori penyimpanan (`storage/image/...`), (3) penyediaan halaman rincian akun (`detail/show`) untuk melihat profil lengkap, kontak, status kepegawaian guru, serta capaian EXP & streak belajar siswa, (4) standardisasi antarmuka tabel dengan toolbar terpadu (pencarian real-time + filter kelas), 3 tombol aksi cepat berikon (Edit, Detail, Hapus), pagination 10 data per halaman, dan notifikasi animasi toast pop-up sukses/gagal di sudut kanan bawah.
>
> **Catatan revisi v1.7.2 (Sinkronisasi Implementasi Sistem: Struktur Hierarki Pembelajaran & Validasi Form Terpadu):** Menyesuaikan dokumen PRD secara penuh dengan kode produksi dan basis data yang berjalan di sistem:
> 1. **Struktur Hierarki Pembelajaran 3-Tingkat:** Sistem mengimplementasikan struktur kurikulum berjenjang: **Topik (`topik`)** → **Unit (`level_materi`)** → **Bagian (`pembahasan`)** → **Butir Soal (`soal`)**. Butir soal terikat langsung pada suatu unit dan dapat diasosiasikan secara opsional ke suatu bagian/pembahasan.
> 2. **Tipe Evaluasi Soal Aktif:** Lima tipe soal kuis aktif mencakup Pilihan Ganda (`pilihan_ganda`), Susun Kalimat (`susun_kalimat`), Puzzle Pakaian Adat (`puzzle_pakaian_adat`), Menulis Aksara Tracing (`menulis_aksara`), dan Kuis Suara (`kuis_suara`). Latihan penjodohan/pencocokan arti distandarkan ke format pilihan ganda interaktif terstruktur.
> 3. **Standar Validasi Form & Integritas Data Baru:**
>    - **Nama Lengkap (`nama_lengkap`):** Hanya boleh berisi huruf alfabet dan spasi (`/^[a-zA-Z\s]+$/`). Angka dan simbol dilarang keras di seluruh akun (Siswa, Guru, Superadmin). Nama bersifat unik secara case-insensitive per peran.
>    - **Nomor Induk Siswa (`nis`):** Hanya boleh berisi angka (`/^[0-9]+$/`), dan **tidak dibuat unik** (duplikasi NIS diizinkan untuk fleksibilitas administrasi). Constraint `unique` pada database resmi dihapus melalui migrasi.
>    - **Nomor Induk Pegawai (`nip`):** Hanya boleh berisi angka (`/^[0-9]+$/`) dan wajib unik untuk akun Guru.
>    - **Nomor Telepon (`no_telpon`):** Bersifat opsional (nullable), hanya boleh berisi angka (`/^[0-9]+$/`, min 9 digit), namun **wajib unik lintas seluruh akun pengguna** jika diisi. Nomor yang telah terdaftar di sistem tidak dapat digunakan kembali oleh akun mana pun.
>    - **Email (`email`):** Wajib berupa email valid dan unik secara case-insensitive lintas seluruh akun pengguna.
>    - **Pencegahan Duplikasi Case-Insensitive Konten:** Nama Topik (`topik.nama`), Nama Unit (`level_materi.nama_materi` per topik), Nama Bagian (`pembahasan.nama` per level materi), dan Pertanyaan Soal (`soal.pertanyaan` per level materi) diverifikasi secara case-insensitive (`LOWER(TRIM(...))`). Perbedaan huruf kapital/kecil tidak lagi dapat meloloskan penambahan soal, materi, maupun akun duplikat.

---

## 1. Overview

**Produk:** Sinau Jowo — aplikasi mobile Android dan website terintegrasi untuk pembelajaran Bahasa dan Budaya Jawa, menggunakan pendekatan gamifikasi (mirip Duolingo) yang diperkuat teknologi AI suara (TTS, STT, STS) dan chatbot RAG.

**Target Pengguna:** Tiga peran dengan hak akses berbeda (role-based access):
- **Siswa** (pengguna utama) — SMP/SMA, belajar via mobile/web.
- **Guru** — membuat & mengelola soal, unit materi, bagian pembahasan, topik, serta memantau progres siswa.
- **Superadmin** — mengelola seluruh akun (guru, siswa, dan superadmin), struktur hierarki materi (topik, unit, bagian), serta bank soal komprehensif di tingkat sistem.

**Selaras SDG:** SDG 10 (Berkurangnya Kesenjangan) target 10.2 — pemberdayaan akses belajar bahasa & budaya sendiri bagi kelompok yang tersisih darinya; didukung SDG 4 target 4.7 dan SDG 11 target 11.4.

**Tech Stack:**
- **Backend/Web:** Laravel (REST API & Blade Admin) dengan database **PostgreSQL** (driver `pgsql`) pada lingkungan server dan **SQLite** pada pengujian otomatis.
- **Mobile:** **Flutter**, mengonsumsi REST API yang sama dengan website (satu backend terintegrasi untuk web & mobile).

---

## 2. Problem Statement

Penggunaan aktif Bahasa Jawa di kalangan generasi muda terus menurun akibat pergeseran bahasa (*language shift*), sementara media pembelajaran bahasa daerah di sekolah masih konvensional dan kurang menarik dibandingkan aplikasi belajar bahasa modern. Siswa yang ingin mendalami bahasa dan budaya leluhurnya sendiri tidak memiliki akses ke sarana belajar yang setara kualitasnya dengan sarana belajar bahasa asing.

---

## 3. Goals & Success Metrics

### 3.1 Tujuan Produk

Mengikuti rumusan Tujuan Khusus pada laporan resmi tim:

1. **Meningkatkan Keterlibatan Siswa melalui Gamifikasi** — mengimplementasikan EXP, streak, dan leaderboard untuk mendorong kebiasaan belajar yang konsisten dan kompetitif secara sehat.
2. **Menyediakan Asistensi Belajar Cerdas** — mengintegrasikan Chatbot RAG untuk memberikan respons dan bantuan belajar yang relevan secara mandiri bagi siswa.
3. **Menghadirkan Model Evaluasi Pembelajaran yang Variatif** — instrumen kuis multi-format mencakup pilihan ganda, susun kata/kalimat, puzzle pakaian adat, latihan menulis aksara Jawa kanvas tracing, serta evaluasi berbasis suara (TTS/STT).
4. **Mempermudah Pengawasan Akademik oleh Pengajar** — memfasilitasi guru melacak riwayat progres dan capaian belajar siswa secara terstruktur berdasarkan kelas maupun NIS.
5. **Mewujudkan Pengelolaan Data Terpusat dan Multi-Peran** — membangun hak akses bertingkat (Siswa, Guru, Superadmin) untuk tata kelola pembuatan soal, manajemen topik, unit, dan bagian pembahasan, serta pengelolaan akun pengguna secara efisien melalui satu basis data terintegrasi.

### 3.2 Metrik Keberhasilan (Success Metrics)

| Metrik | Target (MVP/Demo) | Cara Ukur |
|---|---|---|
| Jumlah pengguna aktif | ≥ 30 siswa uji coba | Jumlah akun terdaftar & aktif login ≥ 1x/minggu |
| Retensi (streak) | ≥ 40% siswa uji coba memiliki streak ≥ 3 hari | Data streak di database |
| Akurasi skor pelafalan (STT) | Skor konsisten dengan penilaian manual pada sampel uji | Bandingkan hasil STT vs penilaian guru pada 20 sampel ucapan |
| Guardrail chatbot | 0% jawaban di luar korpus tanpa penolakan | Uji dengan ≥ 20 pertanyaan di luar cakupan materi |
| Penyelesaian level | ≥ 50% siswa uji coba menyelesaikan Level 1 | Data progres di database |
| Adopsi panel admin | Guru & superadmin dapat menambah 1 unit materi + minimal 10 soal tanpa bantuan developer | Uji coba mandiri panel web oleh tim non-teknis |

> **Catatan metodologi pengujian:** untuk fase tugas ini, seluruh uji coba pada tabel di atas (termasuk "≥ 30 siswa uji coba") dilakukan sebagai **simulasi internal tim** (bukan uji coba dengan siswa sekolah nyata), untuk keperluan presentasi/demo di depan dosen penguji. Skala dan skenario data dapat disesuaikan agar merepresentasikan kondisi target secara meyakinkan meski sumber datanya simulasi.

---

## 4. Target Pengguna & Persona

**Persona 1 — Siswa (Andi, 14 tahun, SMP):** Tumbuh di lingkungan yang jarang memakai Bahasa Jawa sehari-hari, ingin bisa berbicara krama dengan sopan ke orang tua/guru, lebih suka belajar lewat HP dibanding buku.

**Persona 2 — Guru Bahasa Jawa (Bu Sri, 35 tahun):** Mengajar dengan jumlah siswa banyak dan waktu terbatas, butuh cara memantau siapa siswa yang tertinggal tanpa harus mengoreksi manual satu per satu, serta ingin bisa menambah soal latihan sendiri untuk kelasnya.

**Persona 3 — Superadmin (Pak Dedi, 40 tahun, operator sistem sekolah/tim pengembang):** Bertanggung jawab menjaga integritas data di seluruh sekolah — mendaftarkan akun guru baru, memantau jumlah pengguna terdaftar, menyusun struktur hierarki materi (topik, unit, bagian), dan menjadi otoritas tertinggi atas bank soal jika guru tidak dapat mengelolanya sendiri.

---

## 5. User Stories & Acceptance Criteria

| Peran | User Story | Acceptance Criteria |
|---|---|---|
| Siswa | Sebagai siswa, saya ingin mendaftar akun sendiri atau masuk dengan akun yang ada, agar saya bisa langsung mulai belajar. | Sistem mengecek status akun; jika belum punya akun, siswa diarahkan ke form Daftar dengan validasi nama (hanya huruf & spasi), NIS (angka saja, tidak dibuat unik), nomor telepon (angka saja, unik jika diisi), email (unik case-insensitive), serta sandi konfirmasi; jika sudah terdaftar, siswa langsung login dan dialihkan ke beranda. |
| Siswa | Sebagai siswa, saya ingin memilih topik dan menyelesaikan unit materi secara bertahap per bagian, agar pembelajaran terstruktur. | Halaman kuis menyajikan materi berdasarkan Topik → Unit → Bagian Pembahasan. Pengerjaan soal berpindah mulus antar-bagian dalam unit yang sama hingga seluruh butir soal tuntas. |
| Siswa | Sebagai siswa, saya ingin berlatih pelafalan Bahasa Jawa lewat suara, agar saya tahu apakah ucapan saya sudah benar. | STT membandingkan ucapan siswa dengan referensi dan memberi skor akurasi ≥ 1 kali percobaan; feedback ditampilkan < 3 detik. |
| Siswa | Sebagai siswa, saya ingin bertanya ke chatbot soal kapan pakai krama vs ngoko, agar saya tidak salah unggah-ungguh. | Chatbot menjawab dari korpus resmi; jika pertanyaan di luar cakupan, chatbot menyatakan tidak tahu, bukan mengarang jawaban. |
| Siswa | Sebagai siswa, saya ingin melihat streak dan XP saya serta leaderboard, agar saya termotivasi belajar tiap hari. | Streak bertambah otomatis saat siswa menyelesaikan ≥ 1 sesi latihan per hari; reset jika lewat 24 jam tanpa aktivitas; leaderboard menampilkan peringkat EXP tertinggi antar siswa. |
| Siswa | Sebagai siswa, saya ingin diberi tahu jika saya belum memenuhi syarat suatu materi, agar saya tahu harus menyelesaikan materi sebelumnya dulu. | Jika materi prasyarat belum tercapai, sistem menampilkan peringatan "Materi belum tercapai" dan tidak mengizinkan siswa memulai sesi quiz. |
| Guru | Sebagai guru, saya ingin login langsung dengan akun yang sudah didaftarkan superadmin, tanpa perlu mendaftar sendiri, agar identitas guru terverifikasi oleh sekolah. | Guru hanya dapat login (tidak ada opsi daftar mandiri); akun guru dibuat oleh superadmin terlebih dahulu dengan NIP unik. |
| Guru | Sebagai guru, saya ingin menambah dan mengelola topik, unit, bagian pembahasan, serta soal, agar konten latihan tetap relevan. | Guru dapat membuat topik, unit materi, bagian pembahasan, dan membuat soal baru (pilihan ganda, susun kalimat, puzzle pakaian adat, tracing aksara, kuis suara). Guru melakukan CRUD **hanya atas soal buatannya sendiri**. Sistem memvalidasi nama topik/unit/bagian/pertanyaan tidak boleh sama secara case-insensitive. |
| Guru | Sebagai guru, saya ingin melihat progres siswa berdasarkan kelas atau NIS, agar saya tahu siapa yang tertinggal. | Guru dapat mencari siswa berdasarkan kelas/NIS untuk kelas/mata pelajaran yang ia ampu. Menampilkan persentase penyelesaian level serta aktivitas terakhir. |
| Superadmin | Sebagai superadmin, saya ingin melihat dashboard ringkas jumlah guru, siswa, topik, dan unit terdaftar, agar saya punya gambaran skala penggunaan sistem. | Dashboard superadmin menampilkan statistik total akun guru, siswa, topik materi, serta unit pembelajaran secara real-time. |
| Superadmin | Sebagai superadmin, saya ingin mendaftarkan, melihat detail profil, menyunting, dan menghapus (CRUD) akun guru dan siswa, dengan validasi yang ketat dan konsisten. | Form input memvalidasi nama hanya huruf dan spasi, NIS angka saja tanpa batas keunikan, NIP unik numerik, nomor telepon numerik unik lintas seluruh akun jika diisi, dan email unik case-insensitive. Dilengkapi toast notifikasi, modal zoom foto, dan filter pencarian. |
| Superadmin | Sebagai superadmin, saya ingin membuat dan mengelola struktur kurikulum (Topik, Unit, Bagian) serta seluruh bank soal tanpa batasan guru, agar kualitas pembelajaran terjaga. | Superadmin dapat melakukan CRUD penuh pada Topik, Unit Materi, Bagian Pembahasan, dan Butir Soal di seluruh sistem dengan pengecekan keunikan case-insensitive agar tidak terjadi duplikasi data. |

---

## 6. Functional Requirements

Prioritas menggunakan kerangka MoSCoW (Must / Should / Could / Won't untuk fase ini).

| ID | Fitur | Deskripsi | Peran Terkait | Prioritas |
|---|---|---|---|---|
| FR-1 | Autentikasi & Profil Pengguna | Sistem HARUS menyediakan autentikasi multi-peran (Siswa, Guru, Superadmin). Registrasi mandiri khusus Siswa; Guru dan Superadmin didaftarkan oleh Superadmin. **Aturan Validasi Formil:**<br>1. `nama_lengkap`: Hanya boleh berisi huruf dan spasi (`/^[a-zA-Z\s]+$/`), tidak boleh ada angka atau simbol. Unik case-insensitive.<br>2. `nis`: Khusus siswa, hanya berisi angka (`/^[0-9]+$/`), **tidak dibuat unik** (duplikasi diizinkan).<br>3. `nip`: Khusus guru, hanya angka (`/^[0-9]+$/`), wajib unik.<br>4. `no_telpon`: Opsional, hanya angka (`/^[0-9]+$/`, 9-16/20 digit), **wajib unik lintas seluruh entitas pengguna** jika diisi.<br>5. `email`: Wajib unik case-insensitive (`LOWER(TRIM(...))`) lintas seluruh pengguna sistem. | Semua | Must |
| FR-2 | Kurikulum Materi Berjenjang (Topik–Unit–Bagian) | Sistem HARUS menyusun materi dalam hierarki 3-tingkat: **Topik (`topik`)** → **Unit (`level_materi`)** → **Bagian (`pembahasan`)**. Unit materi terkunci berurutan sesuai progres; jika prasyarat belum terpenuhi, sistem memblokir akses kuis dengan pesan peringatan. Materi mencakup bahasa (Dasar, Unggah-Ungguh, Aksara, dsb.) dan artefak budaya (busana adat, rumah adat, kesenian). | Siswa | Must |
| FR-3 | Latihan Pilihan Ganda | Sistem HARUS menyediakan soal pilihan ganda dengan opsi terstruktur, validasi jawaban otomatis, feedback instan, dan penyesuaian bobot EXP. | Siswa | Must |
| FR-4 | Latihan Susun Kalimat | Sistem HARUS menyediakan latihan interaktif menyusun kata acak menjadi kalimat Jawa yang benar (ngoko maupun krama). | Siswa | Must |
| FR-5 | Latihan Evaluasi Budaya (Puzzle Pakaian Adat) | Sistem HARUS menyediakan latihan puzzle interaktif menyusun potongan/urutan busana adat Jawa (misal: pakaian adat kakung dari kepala hingga kaki). Latihan pencocokan arti kosakata diintegrasikan ke dalam format pilihan ganda komprehensif. | Siswa | Must |
| FR-6 | Text-to-Speech (TTS) | Sistem HARUS dapat membacakan teks materi/kosakata dalam Bahasa Jawa dengan pelafalan jelas menggunakan layanan TTS (Edge TTS/Azure Speech). File audio referensi soal disimpan pada field `media_audio_url`. | Siswa | Must |
| FR-7 | Speech-to-Text (STT) | Sistem HARUS dapat menangkap rekaman suara siswa dan mengubahnya menjadi teks untuk dicocokkan dengan jawaban referensi kuis pelafalan. | Siswa | Must |
| FR-8 | Speech-to-Speech (STS) & Kuis Suara | Sistem HARUS menyediakan kuis suara (`kuis_suara`): audio siswa ditranskripsikan, dinilai akurasi pelafalannya, dan diberikan umpan balik interaktif dengan panduan lafal yang benar. | Siswa | Must |
| FR-9 | Chatbot RAG | Sistem HARUS menyediakan chatbot asisten belajar yang menjawab pertanyaan tata bahasa/unggah-ungguh berdasarkan korpus lokal terkurasi (`unggah-ungguh-translation.json`, `gatra-javanese.json`, dll.) dan menolak menjawab di luar konteks. | Siswa | Must |
| FR-10 | Gamifikasi (XP/Streak/Leaderboard) | Sistem HARUS mencatat perolehan XP (`exp`), streak harian (`strek`, bertambah jika aktif tiap hari dan reset jika vakum >24 jam), serta menampilkan papan peringkat (leaderboard) EXP tertinggi antar siswa. | Siswa | Must |
| FR-11 | Dashboard Progres Siswa (Guru) | Website HARUS menyediakan panel pemantauan progres belajar siswa (per kelas/NIS) khusus untuk kelas/mata pelajaran yang diampu guru tersebut. | Guru | Must |
| FR-12 | Manajemen Soal & Materi oleh Guru | Website HARUS memfasilitasi guru untuk mengelola Topik, Unit Materi, Bagian Pembahasan, serta membuat/menyunting/menghapus soal miliknya sendiri. Validasi sistem mewajibkan nama topik, unit (per topik), bagian (per unit), dan pertanyaan soal (per unit) **unik secara case-insensitive** (perbedaan huruf besar/kecil tidak boleh meloloskan duplikat). | Guru | Must |
| FR-13 | Notifikasi Pengingat Belajar | Sistem SEBAIKNYA mengirimkan pengingat untuk menjaga konsistensi streak harian siswa. | Siswa | Should |
| FR-14 | Mode Offline Sebagian | Sistem DAPAT menyimpan materi teks pembelajaran untuk dibaca tanpa jaringan internet. | Siswa | Could |
| FR-15 | Ekspansi Bahasa Daerah Lain | Arsitektur disiapkan untuk ekspansi bahasa daerah nusantara lain di masa mendatang. | — | Won't (fase ini) |
| FR-16 | Dashboard & Ringkasan Superadmin | Website HARUS menampilkan ringkasan metriks jumlah akun guru, siswa, topik, dan unit materi yang terdaftar. | Superadmin | Should |
| FR-17 | Manajemen Akun Guru (Superadmin) | Superadmin HARUS dapat mendaftarkan akun guru (`create`) beserta foto profil, melihat detail profil (`detail/show`), memperbarui data/kontak/password (`update/edit`), serta menghapus guru (`delete`). Validasi nama alfabet murni, NIP unik numerik, nomor telepon unik jika diisi, dan email unik case-insensitive. | Superadmin | Must |
| FR-18 | Manajemen Akun Siswa (Superadmin) | Superadmin HARUS dapat mengelola akun siswa (`create`, `read` pagination 10 baris + filter, `detail` capaian EXP/streak, `update`, `delete`). Validasi nama alfabet murni, NIS angka saja tanpa batas keunikan, nomor telepon unik jika diisi, dan email unik case-insensitive. | Superadmin | Must |
| FR-19 | Manajemen Topik, Unit, & Bagian (Superadmin) | Superadmin HARUS dapat mengelola struktur hierarki pembelajaran: Topik, Unit Level Materi, dan Bagian Pembahasan. Seluruh nama entitas kurikulum divalidasi unik secara case-insensitive dalam lingkup induknya masing-masing. | Superadmin | Must |
| FR-20 | Manajemen Seluruh Bank Soal (Superadmin) | Superadmin HARUS memiliki hak akses penuh membuat, mengedit, dan menghapus soal di seluruh unit materi tanpa dibatasi kepemilikan guru. Pertanyaan soal divalidasi unik secara case-insensitive per unit materi. | Superadmin | Must |
| FR-21 | Manajemen Media Soal (Gambar & Audio) | Sistem HARUS mendukung upload media pendukung soal: file gambar (maksimal 5 MB) dan file audio (maksimal 10 MB) yang disimpan di storage lokal publik (`storage/app/public/soal_media`). | Guru, Superadmin | Must |
| FR-22 | Latihan Menulis Aksara Jawa (Tracing Kanvas) | Sistem HARUS menyediakan kanvas interaktif menulis aksara Jawa: siswa menelusuri template aksara, goresan dihitung kemiripannya ($1/$N Recognizer), dan path template digenerate secara otomatis di server menggunakan engine konversi aksara. | Siswa | Must |
| FR-23 | Pengerjaan Kuis Berkelanjutan (Flow Pembahasan) | Sistem HARUS mengeksekusi pengerjaan soal secara berurutan dalam suatu unit materi: saat suatu bagian pembahasan selesai, sistem secara otomatis mengalirkan siswa ke bagian pembahasan berikutnya dalam unit yang sama hingga unit tuntas. | Siswa | Must |

---

## 6A. Model Data (Entity-Relationship Overview)

Ringkasan entitas, atribut utama, dan aturan validasi data pada sistem Sinau Jowo:

| Entitas | Atribut Utama | Keterangan & Validasi |
|---|---|---|
| **siswa** | id, nis, nama_lengkap, jenis_kelamin, kelas, no_telpon, email, password, foto, created_at, updated_at | `nama_lengkap` hanya huruf & spasi (unik case-insensitive); `nis` numerik (non-unik); `no_telpon` numerik (nullable, unik lintas akun); `email` unik case-insensitive. |
| **guru** | id, nip, nama_lengkap, jenis_kelamin, status_pegawaian, no_telpon, email, password, foto, created_at, updated_at | `nip` numerik & unik; `nama_lengkap` huruf & spasi (unik case-insensitive); `no_telpon` nullable unik; `email` unik case-insensitive; `foto` path file gambar di storage. |
| **superadmin** | id, nama_lengkap, email, no_telpon, password, foto, created_at, updated_at | `nama_lengkap` huruf & spasi (unik case-insensitive); `email` unik case-insensitive; `no_telpon` nullable unik. |
| **topik** | id, nama, deskripsi, urutan, created_at, updated_at | Tingkat teratas kurikulum; `nama` wajib unik secara case-insensitive (`LOWER(TRIM(nama))`). |
| **level_materi** (Unit) | id, topik_id (FK nullable), nama_materi, deskripsi, reward_exp, urutan, created_at, updated_at | Unit pembelajaran; `nama_materi` wajib unik secara case-insensitive per `topik_id`. |
| **pembahasan** (Bagian) | id, level_materi_id (FK), nama, deskripsi, urutan, created_at, updated_at | Bagian modul dalam unit; `nama` wajib unik secara case-insensitive per `level_materi_id`. |
| **soal** | id, level_materi_id (FK), pembahasan_id (FK nullable), tipe_soal, pertanyaan, soal_latin, soal_aksara, opsi_jawaban, kunci_jawaban, media_audio_url, media_gambar_url, bobot_exp, guru_id (FK nullable), superadmin_id (FK nullable), created_at, updated_at | Butir evaluasi; `pertanyaan` wajib unik secara case-insensitive per `level_materi_id`; opsi & kunci disimpan sebagai format JSON terstruktur. |
| **jawaban_siswa** | id, siswa_id (FK), soal_id (FK), jawaban_diberikan, skor_tertinggi, status_lulus, exp_diberikan, created_at, updated_at | Riwayat jawaban siswa per butir soal untuk tracking skor & exp bertahap. |
| **progres_siswa** | id, siswa_id (FK), level_materi_id (FK), status, tanggal_selesai, created_at, updated_at | Pivot status penyelesaian unit (terkunci, berjalan, selesai). |
| **exp** | id, siswa_id (FK), total_exp, created_at, updated_at | Satu-ke-satu dengan siswa, merekam akumulasi poin EXP. |
| **strek** | id, siswa_id (FK), current_streak, highest_streak, last_activity_date, created_at, updated_at | Satu-ke-satu dengan siswa, merekam rekor keaktifan harian. |
| **chat_sessions** | id, siswa_id (FK), title, created_at, updated_at | Sesi percakapan chatbot RAG asisten siswa. |
| **chat_messages** | id, session_id (FK), role (user/assistant), message, created_at, updated_at | Riwayat pesan obrolan dalam sesi RAG. |

**Relasi Utama:**
- **topik – level_materi (Unit):** satu-ke-banyak — satu topik memayungi beberapa unit materi pembelajaran.
- **level_materi – pembahasan (Bagian):** satu-ke-banyak — satu unit materi dibagi menjadi beberapa bagian pembahasan modul.
- **level_materi – soal:** satu-ke-banyak — butir soal wajib terikat pada unit materi terkait.
- **pembahasan – soal:** satu-ke-banyak — butir soal dapat diasosiasikan ke bagian pembahasan spesifik (nullable).
- **siswa – exp & siswa – strek:** satu-ke-satu — pencatatan gamifikasi individu siswa.
- **siswa – level_materi (via `progres_siswa`):** banyak-ke-banyak — pelacakan pembukaan dan kelulusan unit materi.
- **siswa – soal (via `jawaban_siswa`):** banyak-ke-banyak — pencatatan log jawaban, skor tertinggi, dan riwayat pengerjaan.
- **guru – soal:** satu-ke-banyak — hak kepemilikan pembuatan dan penyuntingan soal oleh guru.
- **superadmin – guru / siswa / level_materi / soal:** otoritas penuh pengelolaan akun dan konten secara terpusat.

---

## 6B. Alur Sistem (Ringkasan Flowchart)

**Alur Siswa:**
1. Masuk aplikasi → Pilih peran "Siswa".
2. Autentikasi: Daftar akun baru (validasi nama alfabet, NIS numerik non-unik, no telpon unik, email unik) atau Masuk akun terdaftar.
3. Beranda Siswa: Menampilkan total EXP, status streak harian, dan ringkasan unit aktif.
4. Memilih Materi:
   - Pilih Topik Pembelajaran → Pilih Unit Materi yang terbuka (prasyarat tuntas).
   - Memulai Sesi Kuis: Soal disajikan berurutan per Bagian Pembahasan.
   - Menjawab Soal (Pilihan Ganda, Susun Kalimat, Puzzle Pakaian Adat, Tracing Aksara Jawa, atau Kuis Suara).
   - Evaluasi & Feedback Instan: Jawaban dicatat di `jawaban_siswa`, EXP ditambahkan, streak diperbarui.
   - Transisi Otomatis: Saat bagian pembahasan tuntas, sistem lanjut ke bagian pembahasan berikutnya dalam unit yang sama hingga unit selesai dan unit berikutnya terbuka.
5. Menu Pendukung: Chatbot Asisten AI (RAG) untuk konsultasi unggah-ungguh dan Leaderboard Peringkat EXP.

**Alur Guru:**
1. Masuk aplikasi web → Login menggunakan email & sandi akun yang telah dibuatkan Superadmin.
2. Dashboard Guru: Menampilkan statistik kelas, total materi, dan ringkasan siswa binaan.
3. Manajemen Pembelajaran:
   - Mengelola Topik, Unit Level Materi, dan Bagian Pembahasan.
   - Mengelola Soal: Melihat bank soal, menambah soal baru pada unit dan bagian yang dipilih, serta menyunting/menghapus soal miliknya sendiri. Sistem mencegah duplikasi pertanyaan secara case-insensitive.
4. Pemantauan Siswa: Memantau progres belajar, riwayat penyelesaian unit, dan statistik capaian siswa pada kelas yang diampu.

**Alur Superadmin:**
1. Masuk aplikasi web → Login Superadmin.
2. Dashboard Ringkasan: Statistik total akun guru, siswa, topik, dan unit materi.
3. Manajemen Akun Guru: Pendaftaran akun baru, detail profil, upload & preview foto, pengubahan kredensial, dan penghapusan akun.
4. Manajemen Akun Siswa: Pendaftaran akun siswa baru, filter per kelas/NIS, rincian detail capaian EXP/streak, pengubahan data profil/sandi, dan penghapusan akun.
5. Manajemen Kurikulum (Topik, Unit, Bagian): CRUD hirarkis kurikulum pembelajaran dengan penegakan keunikan case-insensitive nama materi/bagian.
6. Manajemen Bank Soal Global: Otoritas tertinggi membuat dan mengelola seluruh soal di sistem lintas guru.

---

## 6C. Arsitektur Speech-to-Speech (STS) & Audio

1. **Text-to-Speech (TTS):** Menghasilkan pengucapan audio Bahasa Jawa alami untuk panduan lafal materi dan soal kuis suara, terintegrasi via service internal.
2. **Speech-to-Text (STT) & Scoring:** Menerima input audio rekaman siswa dari peramban/aplikasi, mentranskripsikan ucapan siswa, membandingkannya dengan teks target Jawa menggunakan algoritma Text Similarity, dan memberikan skor kelulusan lafal secara real-time.

---

## 6D. Arsitektur Latihan Menulis Aksara Jawa (Tracing)

1. **Generasi Template Aksara di Server:** Service `AksaraJawaConverterService` mengonversi teks Latin menjadi aksara Jawa secara baku (mendukung mode swara, pepet, dan spasi).
2. **Kanvas Tracing Interaktif:** Siswa menarik goresan garis mengikuti panduan template transparan di atas kanvas web/mobile.
3. **Pengenalan & Penilaian Geometris:** Menggunakan algoritma pengenalan pola goresan ($1 Unistroke / $N Multistroke Recognizer) untuk menilai presisi bentuk tulisan siswa terhadap path acuan sebelum animasi snap disajikan.

---

## 7. Non-Functional Requirements

- **Performa:** Respons latihan teks < 1 detik; pemrosesan evaluasi suara < 3 detik pada koneksi internet normal.
- **Integritas & Validasi Data:** Penegakan aturan validasi komprehensif pada lapisan controller, Form Request/Rule, dan skema database (nama alfabetis murni, NIS numerik non-unik, keunikan nomor telepon lintas pengguna, serta pencegahan duplikasi case-insensitive pada nama topik, unit, bagian, dan pertanyaan soal).
- **Keamanan:** Kredensial pengguna diamankan dengan hashing Bcrypt (cost round 12); isolasi akses berbasis peran (RBAC guard: `siswa`, `guru`, `superadmin`); otorisasi kepemilikan soal via Policy (`SoalPolicy`).
- **Skalabilitas:** Backend REST API Laravel terpusat yang melayani klien web dan mobile Flutter secara modular.

---

## 8. Scope

### 8.1 Dalam Cakupan (MVP)
- Website dan aplikasi mobile Android terpadu.
- Tiga peran pengguna: Siswa, Guru, Superadmin.
- Struktur kurikulum 3-tingkat: Topik → Unit → Bagian Pembahasan.
- 5 format latihan kuis aktif: Pilihan Ganda, Susun Kalimat, Puzzle Pakaian Adat, Tracing Aksara Jawa, Kuis Suara.
- Gamifikasi komprehensif: XP, streak harian, leaderboard peringkat.
- Chatbot RAG berbasis korpus unggah-ungguh Jawa terkurasi.
- Panel kelola mandiri guru (soal milik sendiri & pemantauan kelas) dan panel kelola penuh superadmin (seluruh akun, kurikulum, bank soal).

### 8.2 Di Luar Cakupan (Fase Ini)
- Bahasa daerah di luar Bahasa Jawa.
- Aplikasi iOS.
- Fitur transaksi/pembayaran komersial.
- Pendaftaran akun mandiri untuk peran guru dan superadmin.

---

## 9. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi yang Telah Diterapkan |
|---|---|---|
| Duplikasi data akibat perbedaan huruf kapital/kecil | Terjadi redundansi materi atau soal ganda yang membingungkan siswa | Validasi kustom case-insensitive (`UniqueCaseInsensitive`) diterapkan pada Topik, Unit, Bagian, Soal, Nama Pengguna, dan Email. |
| Konflik nomor telepon antar-pengguna | Akun tertukar atau nomor disalahgunakan untuk pendaftaran berulang | Validasi nomor telepon unik lintas seluruh peran pengguna (`UniquePhoneNumber`) jika diisi. |
| Inkonsistensi format nama (simbol/angka) | Kualitas data siswa/guru tidak formal dan rentan kesalahan input | Validasi regex ketat (`/^[a-zA-Z\s]+$/`) pada nama lengkap di seluruh form dan API. |
| Hambatan pendaftaran siswa karena NIS bentrok | Siswa gagal mendaftar karena nomor NIS sama dengan sekolah/jenjang lain | Constraint unik pada NIS dihapus (`remove_unique_from_siswa_nis`), NIS diperlakukan sebagai atribut identitas akademik numerik. |
| Konflik wewenang soal Guru vs Superadmin | Soal terhapus/terubah tanpa izin pembuat asli | Implementasi `SoalPolicy` dan filter kepemilikan: guru hanya dapat mengubah soal miliknya; superadmin memiliki hak pengawasan global. |

---

## 10. Keputusan yang Ditetapkan

1. **Uji Coba Sistem:** Menggunakan data simulasi internal tim yang mencakup skenario riil multi-kelas, multi-guru, dan multi-topik untuk keperluan demonstrasi akademis.
2. **Struktur Konten Pembelajaran:** Kurikulum diatur dalam 3 tingkat: Topik (`topik`) → Unit (`level_materi`) → Bagian (`pembahasan`) → Soal (`soal`).
3. **Format Soal & Payload JSON:** Opsi dan kunci jawaban disimpan sebagai JSON terstruktur yang fleksibel sesuai kebutuhan tipe soal kuis.
4. **Pencatatan Progres Pembelajaran:** Status progres unit dicatat di `progres_siswa`, sedangkan riwayat butir soal dicatat di `jawaban_siswa`.
5. **Standar Validasi Form:**
   - Nama lengkap hanya alfabet dan spasi, unik case-insensitive.
   - NIS hanya numerik dan tidak unik.
   - NIP hanya numerik dan wajib unik untuk guru.
   - Nomor telepon opsional, numerik, dan wajib unik lintas seluruh akun jika diisi.
   - Pencegahan duplikasi case-insensitive wajib ditegakkan pada penambahan soal, unit, bagian, topik, maupun pengguna.
