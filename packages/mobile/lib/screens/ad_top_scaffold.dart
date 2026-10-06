import 'package:flutter/material.dart';

import '../shell/shell.dart';

/// A menu screen with the banner above the title bar, not under it. The
/// banner takes the status-bar safe area, so the bar below drops its own
/// top padding.
class AdTopScaffold extends StatelessWidget {
  const AdTopScaffold({
    super.key,
    required this.adService,
    required this.title,
    required this.body,
  });

  final AdService adService;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(bottom: false, child: adService.buildBanner()),
          const SizedBox(height: 12),
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: AppBar(title: Text(title), toolbarHeight: 44),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
