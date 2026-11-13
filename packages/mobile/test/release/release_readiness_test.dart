// Release-readiness checks that need no device, store account or network.
// They guard the mistakes that otherwise surface only at App Store review:
// metadata over its limit, claims the game does not back up, screenshots or
// icons in a rejected format, test ad IDs in a release, an iPad build for an
// iPhone-only game, and docs that drift from the IDs in code.
//
// Live App Store Connect state is checked separately by
// scripts/asc_preflight.py (CI job "ASC preflight").
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_survival/app/app_services.dart';
import 'package:memory_survival/engine/scenario.dart';
import 'package:memory_survival/gamecenter/game_center_ids.dart';

final _root = Directory.current.parent.parent; // repository root
File _repo(String path) => File('${_root.path}/$path');
File _mobile(String path) => File('${Directory.current.path}/$path');
Directory _mobileDir(String path) =>
    Directory('${Directory.current.path}/$path');
String _meta(String name) =>
    _mobile('ios/fastlane/metadata/en-US/$name.txt').readAsStringSync().trim();

/// (width, height, hasAlpha) read from a PNG header.
({int w, int h, bool alpha}) _png(File f) {
  final b = ByteData.sublistView(Uint8List.fromList(f.readAsBytesSync()));
  expect(b.getUint32(0), 0x89504E47, reason: '${f.path} is not a PNG');
  final colorType = b.getUint8(25); // 2 = RGB, 6 = RGBA, 4 = gray+alpha
  return (w: b.getUint32(16), h: b.getUint32(20), alpha: colorType >= 4);
}

String _source(String path) => _mobile(path).readAsStringSync();

void main() {
  group('App Store text', () {
    test('every field is within its App Store Connect limit', () {
      expect(_meta('name').length, lessThanOrEqualTo(30));
      expect(_meta('subtitle').length, lessThanOrEqualTo(30));
      expect(_meta('keywords').length, lessThanOrEqualTo(100));
      expect(_meta('promotional_text').length, lessThanOrEqualTo(170));
      expect(_meta('description').length, lessThanOrEqualTo(4000));
      expect(_meta('release_notes'), isNotEmpty);
    });

    test('keywords do not repeat the name or contain spaces after commas', () {
      final keywords = _meta('keywords');
      expect(keywords, isNot(contains(', ')));
      final words = keywords.split(',');
      expect(words.toSet().length, words.length, reason: 'duplicate keyword');
      expect(words, isNot(contains('memory survival')));
    });

    test('the URLs are https pages on the Nelson Grey site', () {
      for (final f in ['privacy_url', 'support_url']) {
        final u = Uri.parse(_meta(f));
        expect(u.scheme, 'https');
        expect(u.host, 'nelsongrey.com');
        expect(u.path, startsWith('/games/memory-survival/'));
      }
    });

    test('the copyright names the product and the company', () {
      final c = _mobile(
        'ios/fastlane/metadata/copyright.txt',
      ).readAsStringSync();
      expect(c, contains('Memory Survival'));
      expect(c, contains('Nelson Grey LLC'));
    });
  });

  group('MAS-BR-014: store claims match the game', () {
    test('the scenario count in the description is the real count', () {
      final claimed = RegExp(
        r'(\d+) authored scenarios',
      ).firstMatch(_meta('description'));
      expect(claimed, isNotNull, reason: 'description states no count');
      expect(int.parse(claimed!.group(1)!), scenarios.length);
    });

    test('the description does not promise features the app lacks', () {
      final d = _meta('description').toLowerCase();
      // Each promise is tied to something that exists in code.
      if (d.contains('game center')) {
        expect(GameCenterIds.leaderboardEndlessScore, isNotEmpty);
        expect(GameCenterIds.achievementFirstAllocation, isNotEmpty);
      }
      if (d.contains('one-time purchase')) {
        expect(adRemovalProductId, isNotEmpty);
      }
      if (d.contains('relaxed clock')) {
        expect(
          _source('lib/settings/relaxed_clock_setting.dart'),
          contains('Relaxed clock'),
        );
      }
      if (d.contains('daily run')) {
        expect(_mobile('lib/settings/daily_challenge.dart').existsSync(), true);
      }
    });

    test('nothing in the listing quotes a price or an unverifiable claim', () {
      final all = [
        _meta('description'),
        _meta('promotional_text'),
        _meta('subtitle'),
      ].join(' ').toLowerCase();
      expect(all, isNot(contains(r'$')));
      for (final banned in ['#1', 'best ', 'free of charge', 'no ads']) {
        expect(all, isNot(contains(banned)), reason: 'claim "$banned"');
      }
    });
  });

  group('Screenshots and icons', () {
    test('the App Store screenshots are opaque 1206x2622 PNGs', () {
      final dir = _mobileDir('ios/fastlane/screenshots/en-US');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      expect(files.length, inInclusiveRange(3, 10));
      for (final f in files) {
        final p = _png(f);
        expect((p.w, p.h), (1206, 2622), reason: f.path);
        expect(p.alpha, isFalse, reason: '${f.path} has an alpha channel');
      }
    });

    test('every Game Center achievement and the leaderboard have art', () {
      final dir = 'ios/fastlane/game_center_icons';
      final ids = [
        GameCenterIds.achievementFirstAllocation,
        GameCenterIds.achievementFirstCompaction,
        GameCenterIds.achievementCampaignComplete,
      ];
      for (final id in ids) {
        final p = _png(_mobile('$dir/$id.png'));
        expect((p.w, p.h), (1024, 1024), reason: id);
        expect(p.alpha, isFalse, reason: '$id has an alpha channel');
      }
      final lb = _png(_mobile('$dir/leaderboard-1024.png'));
      expect((lb.w, lb.h), (1024, 1024));
    });

    test(
      'the Unlock Premium purchase image is a 1024 square without alpha',
      () {
        final p = _png(
          _repo(
            'marketing/assets/store/app-store/in-app-purchase/'
            'remove-ads-1024x1024.png',
          ),
        );
        expect((p.w, p.h), (1024, 1024));
        expect(p.alpha, isFalse);
      },
    );

    test('the app icon set has the 1024 marketing icon without alpha', () {
      final dir = _mobileDir('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final icon = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('1024'))
          .toList();
      expect(icon, isNotEmpty);
      expect(_png(icon.first).alpha, isFalse);
    });
  });

  group('Ads', () {
    final appServices = _source('lib/app/app_services.dart');
    final plist = _source('ios/Runner/Info.plist');

    String iosValue(String field) {
      final m = RegExp("$field: '([^']+)'").firstMatch(appServices);
      expect(m, isNotNull, reason: '$field not found in app_services.dart');
      return m!.group(1)!;
    }

    test('a release never uses Google test ad IDs on iOS', () {
      for (final f in ['iosAppId', 'iosBannerId', 'iosInterstitialId']) {
        expect(
          iosValue(f),
          isNot(contains('3940256099942544')),
          reason: '$f is still a Google test ID',
        );
      }
    });

    test('Info.plist carries the same AdMob app ID as the code', () {
      final m = RegExp(
        r'GADApplicationIdentifier</key>\s*<string>([^<]+)</string>',
      ).firstMatch(plist);
      expect(m!.group(1), iosValue('iosAppId'));
    });

    test('the units belong to the same AdMob publisher as the app', () {
      final publisher = iosValue('iosAppId').split('~').first;
      expect(iosValue('iosBannerId'), startsWith('$publisher/'));
      expect(iosValue('iosInterstitialId'), startsWith('$publisher/'));
    });

    test('the tracking prompt text and privacy manifest are present', () {
      expect(plist, contains('NSUserTrackingUsageDescription'));
      final manifest = _source('ios/Runner/PrivacyInfo.xcprivacy');
      expect(manifest, contains('NSPrivacyTracking'));
      expect(manifest, contains('NSPrivacyCollectedDataTypes'));
    });
  });

  group('Project settings', () {
    test('the game is iPhone-only', () {
      final pbx = _source('ios/Runner.xcodeproj/project.pbxproj');
      final families = RegExp(
        r'TARGETED_DEVICE_FAMILY = ([^;]+);',
      ).allMatches(pbx).map((m) => m.group(1)!.replaceAll('"', ''));
      expect(families, isNotEmpty);
      expect(families.toSet(), {'1'});
      expect(_source('ios/Runner/Info.plist'), isNot(contains('~ipad')));
    });

    test('the bundle ID is the registered one', () {
      expect(
        _source('ios/Runner.xcodeproj/project.pbxproj'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.memorysurvival.app.ios;'),
      );
      expect(
        _mobile('ios/fastlane/Appfile').readAsStringSync(),
        contains('com.memorysurvival.app.ios'),
      );
    });

    test(
      'export compliance is declared and the Game Center entitlement set',
      () {
        expect(
          _source('ios/Runner/Info.plist'),
          contains('ITSAppUsesNonExemptEncryption'),
        );
        expect(
          _source('ios/Runner/Runner.entitlements'),
          contains('com.apple.developer.game-center'),
        );
      },
    );

    test('the Runner target signs automatically and pods match iOS 15', () {
      final pbx = _source('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        RegExp(
          r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;\s*CODE_SIGN_STYLE = Automatic;',
        ).allMatches(pbx),
        hasLength(3),
      );
      expect(_source('ios/Podfile'), contains("platform :ios, '15.0'"));
    });

    test('submit for review keeps the metadata release notes', () {
      final fastfile = _source('ios/fastlane/Fastfile');
      expect(
        fastfile,
        isNot(contains('Bug fixes and performance improvements')),
      );
      expect(fastfile, contains('release_notes.txt'));
    });

    test('the version is major.minor.patch+build', () {
      expect(
        RegExp(
          r'^version: \d+\.\d+\.\d+\+\d+$',
          multiLine: true,
        ).hasMatch(_source('pubspec.yaml')),
        isTrue,
      );
    });
  });

  group('Docs match the code', () {
    final setup = _repo('docs/GAME_CENTER_SETUP.md').readAsStringSync();
    final store = _repo('docs/STORE_SETUP.md').readAsStringSync();

    test('GAME_CENTER_SETUP.md lists every ID the code uses', () {
      for (final id in [
        GameCenterIds.leaderboardEndlessScore,
        GameCenterIds.achievementFirstAllocation,
        GameCenterIds.achievementFirstCompaction,
        GameCenterIds.achievementCampaignComplete,
      ]) {
        expect(setup, contains('`$id`'), reason: '$id missing from the doc');
      }
    });

    test('STORE_SETUP.md names the purchase product ID the code uses', () {
      expect(store, contains(adRemovalProductId));
    });
  });
}
