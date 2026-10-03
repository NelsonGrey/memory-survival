import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "Relaxed clock" accessibility setting: when on, every clock tick
/// lasts `relaxedClockMultiplier` (lib/content/clock.dart) times as long. Off by default.
class RelaxedClockSetting extends ValueNotifier<bool> {
  RelaxedClockSetting() : super(false);

  static const _prefsKey = 'accessibility.relaxedClock';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> set(bool enabled) async {
    value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}
