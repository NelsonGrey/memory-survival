import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Suggested placement": adds a one-tap button that places the selected
/// request in the tidiest spot. Off by default. A request placed that way is
/// worth its base points but earns no clean-run multiplier or streak, so the
/// assist never beats choosing for yourself.
class SuggestionsSetting extends ValueNotifier<bool> {
  SuggestionsSetting() : super(false);

  static const _prefsKey = 'assist.suggestedPlacement';

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
