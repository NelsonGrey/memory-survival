import 'dart:async';

import 'app_user.dart';
import 'platform_game_auth_service.dart';

/// Deterministic in-memory [PlatformGameAuthService] for tests and for
/// platforms (e.g. Android, until Play Games Services is wired up) where
/// there's no real game-services auth yet.
class FakePlatformGameAuthService implements PlatformGameAuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signIn() async {
    final user = const AppUser(
      uid: 'fake-platform-player-id',
      displayName: 'Test Player',
    );
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}
