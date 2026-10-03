import 'dart:async';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/shell/shell.dart';
import 'package:memory_survival/gamecenter/connection_gated_progress_service.dart';
import 'package:memory_survival/gamecenter/fake_game_center_progress_service.dart';
import 'package:memory_survival/gamecenter/game_center_connection.dart';
import 'package:memory_survival/gamecenter/game_center_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAuth extends FakePlatformGameAuthService {
  @override
  Future<AppUser> signIn() async => throw StateError('no account');
}

class _HangingAuth extends FakePlatformGameAuthService {
  final completer = Completer<AppUser>();
  @override
  Future<AppUser> signIn() => completer.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GameCenterConnection', () {
    test('does nothing until the player connects', () async {
      final auth = FakePlatformGameAuthService();
      final c = GameCenterConnection(auth: auth, supported: true);
      await c.load();
      expect(c.status, GameCenterStatus.off);
      expect(auth.currentUser, isNull);
      expect(c.shouldPrompt, isTrue);
    });

    test(
      'connect signs in, remembers the choice, reconnects next launch',
      () async {
        final c = GameCenterConnection(
          auth: FakePlatformGameAuthService(),
          supported: true,
        );
        await c.load();
        await c.connect();
        expect(c.isConnected, isTrue);
        expect(c.playerName, 'Test Player');
        expect(c.shouldPrompt, isFalse);

        final relaunch = GameCenterConnection(
          auth: FakePlatformGameAuthService(),
          supported: true,
        );
        await relaunch.load();
        expect(relaunch.isConnected, isTrue);
      },
    );

    test('declining is remembered and does not sign in', () async {
      final c = GameCenterConnection(
        auth: FakePlatformGameAuthService(),
        supported: true,
      );
      await c.load();
      await c.decline();
      final relaunch = GameCenterConnection(
        auth: FakePlatformGameAuthService(),
        supported: true,
      );
      await relaunch.load();
      expect(relaunch.shouldPrompt, isFalse);
      expect(relaunch.status, GameCenterStatus.off);
    });

    test('disconnect persists', () async {
      final c = GameCenterConnection(
        auth: FakePlatformGameAuthService(),
        supported: true,
      );
      await c.load();
      await c.connect();
      await c.disconnect();
      expect(c.status, GameCenterStatus.off);
      final relaunch = GameCenterConnection(
        auth: FakePlatformGameAuthService(),
        supported: true,
      );
      await relaunch.load();
      expect(relaunch.status, GameCenterStatus.off);
    });

    test('failed sign-in is unavailable, not an exception', () async {
      final c = GameCenterConnection(auth: _FailingAuth(), supported: true);
      await c.load();
      await c.connect();
      expect(c.status, GameCenterStatus.unavailable);
    });

    test(
      'a sign-in that never returns times out, then recovers if it lands',
      () {
        fakeAsync((async) {
          final auth = _HangingAuth();
          final c = GameCenterConnection(auth: auth, supported: true);
          c.connect();
          async.flushMicrotasks();
          expect(c.status, GameCenterStatus.connecting);

          async.elapse(GameCenterConnection.signInTimeout);
          expect(c.status, GameCenterStatus.unavailable);

          auth.completer.complete(const AppUser(uid: 'p', displayName: 'Late'));
          async.flushMicrotasks();
          expect(c.status, GameCenterStatus.connected);
          expect(c.playerName, 'Late');
        });
      },
    );

    test('unsupported platform never connects or prompts', () async {
      final c = GameCenterConnection(
        auth: FakePlatformGameAuthService(),
        supported: false,
      );
      await c.load();
      await c.connect();
      expect(c.status, GameCenterStatus.off);
      expect(c.shouldPrompt, isFalse);
    });
  });

  group('ConnectionGatedProgressService', () {
    test('forwards nothing while disconnected', () async {
      final inner = FakeGameCenterProgressService();
      final g = ConnectionGatedProgressService(
        inner,
        GameCenterConnection(
          auth: FakePlatformGameAuthService(),
          supported: true,
        ),
      );
      await g.submitScore(10);
      await g.saveCloudProgress('x');
      await g.showLeaderboard();
      expect(inner.submittedScores, isEmpty);
      expect(inner.savedCloudProgress, isEmpty);
      expect(inner.showLeaderboardCount, 0);
      inner.cloudData = 'cloud';
      expect(await g.loadCloudProgress(), isNull);
    });

    test(
      'achievements earned while disconnected are granted on connect',
      () async {
        final inner = FakeGameCenterProgressService();
        final connection = GameCenterConnection(
          auth: FakePlatformGameAuthService(),
          supported: true,
        );
        final g = ConnectionGatedProgressService(inner, connection);
        await g.unlockAchievement(GameCenterIds.achievementFirstCompaction);
        expect(inner.unlockedAchievements, isEmpty);

        await connection.connect();
        await g.flushEarned();
        expect(inner.unlockedAchievements, [
          GameCenterIds.achievementFirstCompaction,
        ]);

        await g.flushEarned();
        expect(inner.unlockedAchievements, hasLength(1));
      },
    );

    test('forwards everything while connected', () async {
      final inner = FakeGameCenterProgressService();
      final g = ConnectionGatedProgressService(
        inner,
        GameCenterConnection.connectedFake(),
      );
      await g.submitScore(42);
      await g.unlockAchievement(GameCenterIds.achievementFirstAllocation);
      expect(inner.submittedScores, [42]);
      expect(inner.unlockedAchievements, hasLength(1));
    });
  });
}
