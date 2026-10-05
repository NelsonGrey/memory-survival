import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the player has been shown "How to play". The first Play shows it
/// once; after that it is only a tap away.
class HowToPlaySetting extends ValueNotifier<bool> {
  HowToPlaySetting() : super(false);

  static const _prefsKey = 'onboarding.howToPlaySeen';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> markSeen() async {
    if (value) return;
    value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }
}
