import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_services.dart';
import 'screens/home_screen.dart';
import 'theme/game_theme.dart';

void main() {
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const MemorySurvivalApp());
}

/// The bundled font's OFL text, so it shows on the in-app licences page
/// (the OFL requires the licence to travel with the font).
Stream<LicenseEntry> _fontLicenses() async* {
  yield LicenseEntryWithLineBreaks([
    'Sora',
  ], await rootBundle.loadString('assets/fonts/Sora-OFL.txt'));
}

class MemorySurvivalApp extends StatefulWidget {
  const MemorySurvivalApp({super.key, AppServices? services})
    : _injectedServices = services;

  /// Tests inject fakes here instead of letting the real
  /// UMP/AdMob/IAP services run: widget tests should construct the Fake*
  /// services directly.
  final AppServices? _injectedServices;

  @override
  State<MemorySurvivalApp> createState() => _MemorySurvivalAppState();
}

class _MemorySurvivalAppState extends State<MemorySurvivalApp> {
  late final _services = widget._injectedServices ?? AppServices();
  late final Future<void> _ready = _services.initialize();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _services.theme,
      builder: (context, id, _) => MaterialApp(
        title: 'Memory Survival',
        debugShowCheckedModeBanner: false,
        theme: materialThemeFor(gameThemePalettes[id]!),
        home: FutureBuilder<void>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return HomeScreen(services: _services);
          },
        ),
      ),
    );
  }
}
