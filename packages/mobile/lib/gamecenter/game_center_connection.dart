import 'dart:async';

import 'package:flutter/foundation.dart';
import '../shell/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameCenterStatus {
  /// The player hasn't connected (or chose to disconnect).
  off,
  connecting,
  connected,

  /// The player wants Game Center but sign-in failed (no account on the
  /// device, offline, declined). Retry is available.
  unavailable,
}

/// Whether the player has opted in to Game Center, and whether that
/// connection is live right now. Nothing Game Center-related happens until
/// the player connects: sign-in is triggered only by [connect] (first-run
/// prompt, home badge, or Settings), then silently repeated on later
/// launches while the choice stands.
///
/// Game Center has no programmatic sign-out, so [disconnect] only makes
/// this game stop using it; the player manages the account in iOS Settings.
class GameCenterConnection extends ChangeNotifier {
  GameCenterConnection({required this._auth, required this.supported});

  /// Test/preview stand-in that is already connected as "Test Player",
  /// with no persistence.
  GameCenterConnection.connectedFake([PlatformGameAuthService? auth])
    : _auth = auth ?? FakePlatformGameAuthService(),
      supported = true,
      _status = GameCenterStatus.connected,
      _playerName = 'Test Player',
      _prompted = true,
      _enabled = true,
      _isFake = true;

  /// Test/capture stand-in for platforms where Game Center is unavailable.
  GameCenterConnection.unsupportedFake([PlatformGameAuthService? auth])
    : _auth = auth ?? FakePlatformGameAuthService(),
      supported = false,
      _prompted = true,
      _isFake = true;

  static const _enabledKey = 'gamecenter.enabled';
  static const _promptedKey = 'gamecenter.prompted';

  final PlatformGameAuthService _auth;

  /// False off iOS/macOS, where there's no Game Center: every Game Center
  /// control hides itself.
  final bool supported;

  /// Runs after each successful sign-in (syncs progress, grants achievements
  /// earned while disconnected). Set by `AppServices`.
  Future<void> Function()? onConnected;

  SharedPreferences? _prefs;
  GameCenterStatus _status = GameCenterStatus.off;
  String? _playerName;
  bool _enabled = false;
  bool _prompted = false;
  bool _isFake = false;

  GameCenterStatus get status => _status;
  bool get isConnected => _status == GameCenterStatus.connected;

  /// The player's Game Center alias while connected.
  String? get playerName => _playerName;

  /// True until the player has answered the first-run prompt.
  bool get shouldPrompt => supported && !_prompted;

  /// Reads the saved choice and, if the player opted in, reconnects.
  Future<void> load() async {
    if (_isFake) return;
    final prefs = _prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _prompted = prefs.getBool(_promptedKey) ?? false;
    if (supported && _enabled) await _signIn();
  }

  /// The player said yes: remember it and sign in (Game Center may show its
  /// own sign-in sheet).
  Future<void> connect() async {
    if (!supported) return;
    _enabled = true;
    _prompted = true;
    await _save();
    await _signIn();
  }

  /// The player declined the first-run prompt; they can still connect later.
  Future<void> decline() async {
    _prompted = true;
    await _save();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _enabled = false;
    _prompted = true;
    _status = GameCenterStatus.off;
    _playerName = null;
    await _save();
    notifyListeners();
  }

  /// How long to wait for Game Center before giving up. The platform call
  /// doesn't return until the player finishes signing in, so with no account
  /// on the device (or a dismissed sheet) it would otherwise never return.
  static const signInTimeout = Duration(seconds: 20);

  Future<void> _signIn() async {
    _status = GameCenterStatus.connecting;
    notifyListeners();
    final attempt = _auth.signIn();
    try {
      await _markConnected(await attempt.timeout(signInTimeout));
    } on TimeoutException {
      _markUnavailable();
      // If the player does finish signing in later, pick it up.
      unawaited(
        attempt
            .then((user) async {
              if (_enabled && !isConnected) await _markConnected(user);
            })
            .catchError((_) {}),
      );
    } catch (_) {
      _markUnavailable();
    }
  }

  Future<void> _markConnected(AppUser user) async {
    _playerName = user.displayName;
    _status = GameCenterStatus.connected;
    notifyListeners();
    await onConnected?.call();
  }

  void _markUnavailable() {
    _playerName = null;
    _status = GameCenterStatus.unavailable;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_enabledKey, _enabled);
    await prefs.setBool(_promptedKey, _prompted);
  }
}
