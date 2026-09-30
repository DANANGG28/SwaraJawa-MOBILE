import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/bottom_nav.dart';
import '../chat/chat_screen.dart';
import '../home/home_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../speech/latihan_ngomong_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final GlobalKey<LeaderboardScreenState> _leaderboardKey =
      GlobalKey<LeaderboardScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();

  void _onTap(int i) {
    final changed = i != _index;
    setState(() => _index = i);
    if (!changed) return;
    // Muat ulang data saat tab dibuka agar EXP/lencana selalu segar.
    if (i == 1) _leaderboardKey.currentState?.reload();
    if (i == 4) _profileKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          LeaderboardScreen(key: _leaderboardKey),
          const LatihanNgomongScreen(),
          const ChatScreen(),
          ProfileScreen(key: _profileKey),
        ],
      ),
      bottomNavigationBar: SjBottomNav(
        currentIndex: _index,
        onTap: _onTap,
      ),
    );
  }
}
