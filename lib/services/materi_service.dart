import '../core/network/api_client.dart';
import '../models/level_materi.dart';
import '../models/soal.dart';

class MateriDetail {
  const MateriDetail({
    required this.level,
    required this.status,
    required this.soal,
  });

  final LevelMateri level;
  final String status;
  final List<Soal> soal;
}

class MateriService {
  MateriService(this._client);

  final ApiClient _client;

  Future<List<LevelMateri>> daftarMateri() async {
    final data = await _client.getJson('/materi');
    final raw = (data['data'] ?? []) as List;
    return raw
        .whereType<Map>()
        .map((e) => LevelMateri.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MateriDetail> detail(int levelMateriId) async {
    final data = await _client.getJson(
      '/materi/$levelMateriId',
      query: {'with_kunci': 1},
    );
    final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
    final level = Map<String, dynamic>.from(payload['level_materi'] as Map? ?? {});
    final rawSoal = (payload['soal'] ?? []) as List;
    return MateriDetail(
      level: LevelMateri.fromJson(level),
      status: (payload['status'] ?? 'terkunci').toString(),
      soal: rawSoal
          .whereType<Map>()
          .map((e) => Soal.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<void> mulai(int levelMateriId) async {
    await _client.postJson('/materi/$levelMateriId/mulai');
  }
}
