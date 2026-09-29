import '../core/network/api_client.dart';
import '../models/progres.dart';

class ProgresService {
  ProgresService(this._client);

  final ApiClient _client;

  Future<ProgresData> ambil() async {
    final data = await _client.getJson('/progres');
    return ProgresData.fromJson(data);
  }
}
