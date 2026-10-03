import 'dart:async';
import 'dart:io';

import 'package:games_services/games_services.dart';

import 'app_user.dart';
import 'platform_game_auth_service.dart';

/// Real [PlatformGameAuthService] backed by Game Center, via the
/// `games_services` plugin's `GameAuth`/`Player` API.
///
/// iOS/macOS only for now — Play Games Services (Android) needs its own
/// Play Console setup (google-services.json, a Play Games project) that
/// hasn't happened yet. Games that need Android support should add a
/// sibling `PlayGamesAuthService` implementing [PlatformGameAuthService]
/// when that setup is done, rather than extending this class.
class GameCenterAuthService implements PlatformGameAuthService {
  GameCenterAuthService() {
    if (!_isSupportedPlatform) {
      throw UnsupportedError(
        'GameCenterAuthService is only supported on iOS/macOS.',
      );
    }
    // games_services has no synchronous "current player" getter, only the
    // `player` stream and async lookups — cache the stream's latest value
    // so `currentUser` can stay synchronous like the rest of [AuthService].
    _authStateChanges.listen((user) => _currentUser = user);
  }

  static bool get _isSupportedPlatform => Platform.isIOS || Platform.isMacOS;

  AppUser? _currentUser;

  Stream<AppUser?> get _authStateChanges => GameAuth.player.map(_toAppUser);

  AppUser? _toAppUser(PlayerData? player) => player?.playerID == null
      ? null
      : AppUser(uid: player!.playerID!, displayName: player.displayName);

  @override
  Stream<AppUser?> authStateChanges() => _authStateChanges;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signIn() async {
    await GameAuth.signIn();
    final player = await GameAuth.player.first;
    final user = _toAppUser(player);
    if (user == null) {
      throw StateError('Game Center did not return a signed-in player.');
    }
    _currentUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    // Game Center has no programmatic sign-out; the player manages their
    // session in the Game Center app/Settings. Nothing to do here.
  }
}
