import 'dart:async';

import 'app_user.dart';

/// Sign-in through a platform's own game-services identity (Game Center on
/// iOS/macOS, Play Games Services on Android), as an alternative to
/// [AuthService] for games that don't want a Firebase-backed account.
///
/// Unlike Google/Apple sign-in, the platform picks the identity for you —
/// there's no `signInWithX` choice, just one [signIn] call that authenticates
/// the local player.
abstract class PlatformGameAuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;

  Future<AppUser> signIn();

  /// Game Center/Play Games have no real "sign out" — the platform owns the
  /// session. Implementations may treat this as a local-state reset only.
  Future<void> signOut();
}
