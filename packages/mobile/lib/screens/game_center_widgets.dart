import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../gamecenter/game_center_connection.dart';

/// Home-screen Game Center status: a connect button when off, progress while
/// connecting, the player's alias with leaderboard/achievement shortcuts
/// when connected, and a retry when sign-in failed. Hidden off iOS/macOS.
class GameCenterBadge extends StatelessWidget {
  const GameCenterBadge({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final connection = services.connection;
    if (!connection.supported) return const SizedBox.shrink();
    final p = services.theme.palette;
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        switch (connection.status) {
          case GameCenterStatus.off:
            return TextButton.icon(
              onPressed: connection.connect,
              icon: const Icon(Icons.sports_esports_outlined),
              label: const Text('Connect Game Center'),
            );
          case GameCenterStatus.connecting:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Connecting to Game Center…',
                    style: TextStyle(color: p.textMuted),
                  ),
                ],
              ),
            );
          case GameCenterStatus.unavailable:
            return TextButton.icon(
              onPressed: connection.connect,
              icon: const Icon(Icons.refresh),
              label: const Text('Game Center unavailable — tap to retry'),
            );
          case GameCenterStatus.connected:
            return Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                color: p.cellFree,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_esports, size: 18, color: p.textMuted),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      connection.playerName ?? 'Game Center',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Leaderboard',
                    icon: const Icon(Icons.leaderboard),
                    onPressed: services.progress.showLeaderboard,
                  ),
                  IconButton(
                    tooltip: 'Achievements',
                    icon: const Icon(Icons.emoji_events),
                    onPressed: services.progress.showAchievements,
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

/// One-time invitation to connect, shown on the first visit to the home
/// screen. Either answer is remembered; Settings and the home badge stay
/// available afterward.
Future<void> showGameCenterPrompt(
  BuildContext context,
  GameCenterConnection connection,
) async {
  final connect = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connect to Game Center?'),
      content: const Text(
        'Post your score to the leaderboard, earn achievements, and keep '
        'your campaign progress across devices. Playing never requires it, '
        'and you can change your mind in Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Connect'),
        ),
      ],
    ),
  );
  if (connect == true) {
    await connection.connect();
  } else {
    await connection.decline();
  }
}
