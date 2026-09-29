import '../core/network/api_client.dart';
import '../models/level_materi.dart';
import '../models/soal.dart';
import '../models/topik.dart';

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

  /// Hierarki tingkat atas: daftar topik beserta ringkasan progres.
  Future<List<Topik>> daftarTopik() async {
    final data = await _client.getJson('/topik');
    final raw = (data['data'] ?? []) as List;
    return raw
        .whereType<Map>()
        .map((e) => Topik.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Detail topik: unit-unit beserta bagian (pembahasan) di dalamnya.
  Future<TopikDetail> detailTopik(int topikId) async {
    final data = await _client.getJson('/topik/$topikId');
    return TopikDetail.fromJson(data);
  }

  Future<List<LevelMateri>> daftarMateri() async {
    final data = await _client.getJson('/materi');
    final raw = (data['data'] ?? []) as List;
    return raw
        .whereType<Map>()
        .map((e) => LevelMateri.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MateriDetail> detail(int levelMateriId, {int? bagianId}) async {
    final data = await _client.getJson(
      '/materi/$levelMateriId',
      query: {
        'with_kunci': 1,
        if (bagianId != null) 'pembahasan_id': bagianId,
      },
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

  Future<void> mulai(int levelMateriId, {int? bagianId}) async {
    await _client.postJson(
      '/materi/$levelMateriId/mulai',
      query: {if (bagianId != null) 'pembahasan_id': bagianId},
    );
  }
}
