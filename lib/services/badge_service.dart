import '../core/network/api_client.dart';
import '../models/badge.dart';

class BadgeService {
  BadgeService(this._client);

  final ApiClient _client;

  Future<BadgeCatalog> ambil() async {
    final data = await _client.getJson('/badge');
    return BadgeCatalog.fromJson(data);
  }
}
