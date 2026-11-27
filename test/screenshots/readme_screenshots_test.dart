import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/i18n/l10n.dart';

import 'cover.dart';
import 'scene.dart';

const _favorites = {
  'lava.ocfx',
  'rainbow.ocfx',
  'starry-sky.ocfx',
  'campfire.ocfx',
  'comet.ocfx',
  'digital-rain.ocfx',
  'embers.ocfx',
  'aurora.ocfx',
  'neon-rings.ocfx',
  'plasma.ocfx',
  'sunset.ocfx',
  'ocean.ocfx',
};

void main() {
  final enabled = Platform.environment['OC_SCREENSHOTS'] == '1';
  late EffectCovers covers;

  setUpAll(() async {
    if (!enabled) return;
    if (!safeAppData) {
      throw StateError(
        'Run through scripts/screenshots.ps1: APPDATA must point to a '
        'temporary folder so the real OpenChroma settings are never touched.',
      );
    }
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
    covers = await EffectCovers.render();
  });

  Future<void> scene(
    WidgetTester tester,
    Future<void> Function(Scene s) body, {
    double height = 900,
  }) async {
    final s = await Scene.open(
      tester,
      covers,
      height: height,
      favorites: _favorites,
    );
    try {
      await body(s);
    } finally {
      await s.close();
    }
  }

  const timeout = Timeout(Duration(minutes: 4));

  group(
    'README screenshots',
    skip: enabled ? false : 'Set OC_SCREENSHOTS=1 (scripts/screenshots.ps1).',
    () {
      testWidgets('home', timeout: timeout, (tester) async {
        await scene(tester, (s) => s.shoot('home.png'), height: 1380);
      });

      testWidgets('lighting', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavLighting);
          await s.shoot('lighting.png');
        });
      });

      testWidgets('layout', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavLighting);
          await s.tapText(l10n.shellTabLayout);
          await s.tapText('Nova K75 Keyboard', last: true);
          await s.shoot('layout.png');
        });
      });

      testWidgets('devices', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavDevices);
          await s.tapText('Nova X670E Aero');
          await s.shoot('devices.png');
        }, height: 1150);
      });

      testWidgets('fans', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavFans);
          await s.shoot('fans.png');
        }, height: 1500);
      });

      testWidgets('performance', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavPerformance);
          await s.shoot('performance.png');
        }, height: 1520);
      });

      testWidgets('checkup', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavPerformance);
          await s.tapText(l10n.shellTabDiagnostics);
          await s.shoot('checkup.png');
        }, height: 1560);
      });

      testWidgets('screen editor', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavDevices);
          await s.tapText('Nova Frost 360 AIO');
          await s.tapText(l10n.devicesTabScreen);
          await s.tapText(l10n.screenEdit);
          await s.shoot('screen-editor.png');
        });
      });

      testWidgets('cover social', timeout: timeout, (tester) async {
        await shootCover(
          tester,
          covers,
          'social-preview.png',
          const Size(1280, 640),
          ratio: 1,
        );
      });

      testWidgets('cover wide', timeout: timeout, (tester) async {
        await shootCover(
          tester,
          covers,
          'cover-wide.png',
          const Size(1600, 500),
        );
      });

      testWidgets('settings', timeout: timeout, (tester) async {
        await scene(tester, (s) async {
          await s.goTo(l10n.shellNavSettings);
          await s.shoot('settings.png');
        }, height: 2060);
      });
    },
  );
}
