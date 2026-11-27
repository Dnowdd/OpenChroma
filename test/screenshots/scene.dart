import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/alerts/alert_service.dart';
import 'package:openchroma/src/effects/effect_library.dart';
import 'package:openchroma/src/effects/ocfx_player.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/fans/fan_service.dart';
import 'package:openchroma/src/i18n/l10n.dart';
import 'package:openchroma/src/system/launch_settings.dart';
import 'package:openchroma/src/system/update_check.dart';
import 'package:openchroma/src/ui/accent.dart';
import 'package:openchroma/src/ui/auto_layout.dart';
import 'package:openchroma/src/ui/home_page.dart' show homeNow;
import 'package:openchroma/src/ui/logo.dart';
import 'package:openchroma/src/ui/shell.dart';
import 'package:openchroma/src/ui/theme.dart';
import 'package:path/path.dart' as p;

import 'demo_data.dart';

const pixelRatio = 2.0;
const _titleBarHeight = 46.0;

final outputDir = Directory(p.join('docs', 'screenshots'));

bool get safeAppData {
  final appData = Platform.environment['APPDATA'] ?? '';
  return appData.isNotEmpty &&
      p.isWithin(Directory.systemTemp.resolveSymbolicLinksSync(), appData);
}

Future<void> loadFonts() async {
  final windows = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  Future<void> family(String name, Iterable<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(bytes(file));
    }
    await loader.load();
  }

  String win(String file) => p.join(windows, 'Fonts', file);
  final segoe = [
    win('segoeuil.ttf'),
    win('segoeui.ttf'),
    win('seguisb.ttf'),
    win('segoeuib.ttf'),
  ];
  await family(Oc.font, segoe);
  await family(Oc.fontDisplay, segoe);
  await family(Oc.mono, [win('CascadiaMono.ttf')]);
  await family('MaterialIcons', [
    p.join(
      flutterRoot,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  ]);
}

class EffectCovers {
  EffectCovers._(this.effects, this.pngs);

  final List<EffectInfo> effects;
  final Map<String, Uint8List> pngs;

  static Future<EffectCovers> render() async {
    final effects = scanEffects(
      htmlRoots: const [],
      bundledDir: p.join('assets', 'effects'),
      importedDir: p.join(Directory.systemTemp.path, 'oc-no-imports'),
    );
    final pngs = <String, Uint8List>{};
    for (final e in effects) {
      final params = {
        for (final prop in e.properties) prop.name: prop.coerce(null),
      };
      final png = await renderOcfxCover(e, params);
      if (png != null) pngs[e.path] = png;
    }
    return EffectCovers._(effects, pngs);
  }
}

class Scene {
  Scene._(this.tester, this.covers, this.dir, this._playhead);

  final WidgetTester tester;
  final EffectCovers covers;
  final Directory dir;
  final double _playhead;
  final boundary = GlobalKey();

  late final DemoEngine engine;
  late final DemoMonitor monitor;
  late final FanService fans;
  late final DemoAi ai;
  late final AlertService alerts;
  late final LanguageController language;
  late final UpdateChecker updates;
  late final DemoDevices devices;
  late final AccentController titleAccent;
  late final DemoPlayback playback;

  static Future<Scene> open(
    WidgetTester tester,
    EffectCovers covers, {
    String effect = 'aurora.ocfx',
    double playhead = 6.2,
    double height = 900,
    int brightness = 85,
    Set<String> favorites = const {},
  }) async {
    tester.view
      ..physicalSize = Size(1440, height) * pixelRatio
      ..devicePixelRatio = pixelRatio;
    final dir = Directory.systemTemp.createTempSync('oc_shots');
    final scene = Scene._(tester, covers, dir, playhead);
    await scene._build(effect, brightness, favorites);
    return scene;
  }

  Future<void> _build(
    String effectFile,
    int brightness,
    Set<String> favorites,
  ) async {
    await writeUpdateState(dir.path);
    writeCheckupState();
    final backdrop = (await tester.runAsync(
      () => writeScreenBackdrop(dir.path),
    ))!;
    engine = DemoEngine(dir.path, backdrop, demoScreenEdit);
    engine.effects = covers.effects;
    for (final e in engine.effects) {
      final png = covers.pngs[e.path];
      if (png != null) engine.saveCover(e, png);
    }
    monitor = DemoMonitor();
    fillMonitor(monitor);
    engine.readSensor = (key) => readDemoSensor(monitor.snapshot, key);
    engine.readTemperature = (source) => switch (source) {
      ReactiveSource.cpu => monitor.snapshot?.cpu.temp,
      ReactiveSource.gpu => monitor.snapshot?.gpus.firstOrNull?.temp,
    };
    fans = buildFans(monitor);
    ai = buildAi();
    final assistant = buildAssistant(ai, engine, monitor, fans);
    alerts = AlertService(monitor: monitor, fans: fans, engine: engine);
    language = LanguageController(dataDir: dir.path)
      ..language = AppLanguage.english;
    updates = UpdateChecker(dataDir: dir.path, currentVersion: '0.9.0');

    engine.plugins = bundledPlugins();
    Elevation.debugOverride = true;
    LaunchSettings.create = DemoLaunch.new;
    homeNow = () => demoNow;
    devices = buildDevices();
    for (final d in devices.all) {
      engine.devices[d.key] = d;
    }
    engine.setLayouts(
      suggestLayout(devices.all, currentLayout: engine.layoutOf),
    );

    final effect = engine.effects.firstWhere(
      (e) => p.basename(e.path) == effectFile,
    );
    for (final e in engine.effects) {
      if (favorites.contains(p.basename(e.path))) engine.toggleFavorite(e);
    }
    engine
      ..setBrightness(brightness)
      ..selectEffect(effect)
      ..saveProfile('game')
      ..setProfileApps('game', ['game.exe']);
    playback = DemoPlayback(effect, engine);
    titleAccent = AccentController(engine);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: const Locale('en', 'US'),
          supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => ExcludeSemantics(child: child!),
          home: ColoredBox(
            color: Oc.bg,
            child: Column(
              children: [
                LiveAccent(controller: titleAccent, child: const _TitleBar()),
                Expanded(
                  child: Shell(
                    engine: engine,
                    monitor: monitor,
                    fans: fans,
                    alerts: alerts,
                    ai: ai,
                    assistant: assistant,
                    language: language,
                    updates: updates,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settleAccent();
  }

  Future<void> settleAccent() async {
    var t = _playhead - 3.4;
    for (var i = 0; i < 110; i++) {
      engine.onFrame(playback.frameAfter(t += 1 / 30), force: true);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 32)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    await pumpFor(const Duration(milliseconds: 2400));
    engine.onFrame(playback.frameAfter(_playhead), force: true);
    await idle();
  }

  Future<void> pumpFor(Duration total) async {
    for (
      var elapsed = Duration.zero;
      elapsed < total;
      elapsed += const Duration(milliseconds: 50)
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> idle([int rounds = 14]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 70)),
      );
      await tester.pump(const Duration(milliseconds: 70));
    }
  }

  Future<void> goTo(String tooltip) async {
    await tester.tap(find.byTooltip(tooltip).first);
    await pumpFor(const Duration(milliseconds: 500));
    await idle();
  }

  Future<void> tapText(String text, {bool last = false}) async {
    final finder = find.text(text);
    await tester.tap(last ? finder.last : finder.first);
    await pumpFor(const Duration(milliseconds: 500));
    await idle();
  }

  Future<void> shoot(String name) async {
    await pumpFor(const Duration(milliseconds: 200));
    await capture(tester, boundary, name);
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpFor(const Duration(seconds: 2));
    Elevation.debugOverride = null;
    LaunchSettings.create = LaunchSettings.new;
    homeNow = DateTime.now;
    titleAccent.dispose();
    alerts.dispose();
    ai.dispose();
    fans.dispose();
    monitor.dispose();
    language.dispose();
    updates.dispose();
    tester.view.reset();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _titleBarHeight,
    child: Row(
      children: [
        const SizedBox(width: 30),
        const OcLogo(height: 20),
        const Spacer(),
        for (final (icon, size) in const [
          (Icons.remove_rounded, 16.0),
          (Icons.crop_square_rounded, 15.0),
          (Icons.close_rounded, 16.0),
        ])
          SizedBox(
            width: 44,
            height: 30,
            child: Icon(icon, size: size, color: Oc.textSecondary),
          ),
        const SizedBox(width: 6),
      ],
    ),
  );
}

Future<void> capture(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  double ratio = pixelRatio,
}) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  outputDir.createSync(recursive: true);
  File(p.join(outputDir.path, name)).writeAsBytesSync(bytes);
}
