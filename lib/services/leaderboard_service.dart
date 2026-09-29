import '../core/network/api_client.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService(this._client);

  final ApiClient _client;

  Future<List<LeaderboardEntry>> ambil({String? kelas, int limit = 50}) async {
    final data = await _client.getJson('/leaderboard', query: {
      if (kelas != null && kelas.isNotEmpty) 'kelas': kelas,
      'limit': limit,
    });
    final raw = (data['data'] ?? data['leaderboard'] ?? []) as List;
    return raw
        .whereType<Map>()
        .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
