import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/siswa.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/chat_service.dart';
import '../services/google_auth_service.dart';
import '../services/kuis_service.dart';
import '../services/leaderboard_service.dart';
import '../services/materi_service.dart';
import '../services/progres_service.dart';
import '../services/speech_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AppState extends ChangeNotifier {
  AppState() {
    client = ApiClient.instance;
    client.onUnauthorized = _handleUnauthorized;
    auth = AuthService(client);
    googleAuth = GoogleAuthService();
    materi = MateriService(client);
    kuis = KuisService(client);
    progres = ProgresService(client);
    leaderboard = LeaderboardService(client);
    chat = ChatService(client);
    speech = SpeechService(client);
    badge = BadgeService(client);
  }

  late final ApiClient client;
  late final AuthService auth;
  late final GoogleAuthService googleAuth;
  late final MateriService materi;
  late final KuisService kuis;
  late final ProgresService progres;
  late final LeaderboardService leaderboard;
  late final ChatService chat;
  late final SpeechService speech;
  late final BadgeService badge;

  AuthStatus status = AuthStatus.loading;
  Siswa? siswa;
  String role = 'siswa';

  bool get isAuthenticated => status == AuthStatus.authenticated && siswa != null;

  Future<void> bootstrap() async {
    status = AuthStatus.loading;
    notifyListeners();
    try {
      final user = await auth.me();
      if (user != null) {
        siswa = user.siswa;
        role = user.role;
        status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> afterLogin(AuthUser user) async {
    siswa = user.siswa;
    role = user.role;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> refreshSiswa() async {
    try {
      final user = await auth.me();
      if (user != null) {
        siswa = user.siswa;
        notifyListeners();
      }
    } catch (_) {
      // Diamkan — data lama tetap dipakai.
    }
  }

  void updateSiswaLocal(Siswa updated) {
    siswa = updated;
    notifyListeners();
  }

  Future<void> logout() async {
    await auth.logout();
    await googleAuth.signOut();
    siswa = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _handleUnauthorized() {
    siswa = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
