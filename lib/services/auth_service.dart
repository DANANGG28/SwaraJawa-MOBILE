import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../models/siswa.dart';

class AuthUser {
  const AuthUser({required this.role, required this.siswa});

  final String role;
  final Siswa siswa;
}

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<AuthUser> login({required String email, required String password}) async {
    final data = await _client.postJson('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _persist(data);
  }

  /// Tukar Google ID token dengan token Sanctum melalui backend.
  Future<AuthUser> loginWithGoogle({required String idToken}) async {
    final data = await _client.postJson('/auth/google', data: {
      'id_token': idToken,
    });
    return _persist(data);
  }

  Future<AuthUser> _persist(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token != null) await TokenStorage.instance.write(token);
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
    return AuthUser(
      role: (data['role'] ?? 'siswa').toString(),
      siswa: Siswa.fromJson(user),
    );
  }

  Future<AuthUser> registerSiswa({
    required String namaLengkap,
    required String nis,
    required String jenisKelamin,
    required String email,
    required String password,
    String? kelas,
    String? noTelpon,
  }) async {
    final data = await _client.postJson('/auth/siswa/register', data: {
      'nama_lengkap': namaLengkap,
      'nis': nis,
      'jenis_kelamin': jenisKelamin,
      'email': email,
      'password': password,
      if (kelas != null && kelas.isNotEmpty) 'kelas': kelas,
      if (noTelpon != null && noTelpon.isNotEmpty) 'no_telpon': noTelpon,
    });
    final token = data['token']?.toString();
    if (token != null) await TokenStorage.instance.write(token);
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
    return AuthUser(role: 'siswa', siswa: Siswa.fromJson(user));
  }

  Future<AuthUser?> me() async {
    final token = await TokenStorage.instance.read();
    if (token == null || token.isEmpty) return null;
    final data = await _client.getJson('/me');
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
    final exp = data['exp'] is Map ? Map<String, dynamic>.from(data['exp'] as Map) : null;
    final strek = data['strek'] is Map ? Map<String, dynamic>.from(data['strek'] as Map) : null;
    if (exp != null) user['exp'] = exp;
    if (strek != null) user['strek'] = strek;
    return AuthUser(
      role: (data['role'] ?? 'siswa').toString(),
      siswa: Siswa.fromJson(user),
    );
  }

  Future<void> logout() async {
    try {
      await _client.postJson('/auth/logout');
    } catch (_) {
      // Abaikan kegagalan jaringan saat logout.
    }
    await TokenStorage.instance.clear();
  }
}
