import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/effects/effect_library.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/ui/accent.dart';
import 'package:openchroma/src/ui/lighting_controls.dart';

void main() {
  late Directory dir;
  late Engine engine;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('oc_engine');
    engine = Engine(dataDir: dir.path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('no brightness or a pause freezes the effect', () {
    expect(engine.frozen, isFalse);
    engine.setBrightness(0);
    expect(engine.frozen, isTrue);
    engine.setBrightness(40);
    expect(engine.frozen, isFalse);
    engine.setPaused(true);
    expect(engine.frozen, isTrue);
    engine.setPaused(false);
    expect(engine.frozen, isFalse);
  });

  test('the accent follows a frozen effect from its one frame', () async {
    final accent = AccentController(engine);
    addTearDown(accent.dispose);
    engine.currentEffect = EffectInfo(
      path: 'red.ocfx',
      title: 'Red',
      description: '',
      author: '',
      properties: const [],
      thumbnail: null,
      kind: EffectKind.ocfx,
      imported: false,
    );
    engine.setBrightness(0);
    final rgb = Uint8List(160 * 100 * 3);
    for (var i = 0; i < rgb.length; i += 3) {
      rgb[i] = 255;
    }
    engine.onFrame(CanvasFrame(160, 100, rgb));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final hue = HSVColor.fromColor(accent.value).hue;
    expect(accent.value, isNot(AccentController.neutral));
    expect(hue < 10 || hue > 350, isTrue);
  });

  test(
    'an effect color setting is the accent; darkness is the brand',
    () async {
      final accent = AccentController(engine);
      addTearDown(accent.dispose);
      final solid = EffectInfo(
        path: 'solid.ocfx',
        title: 'Solid',
        description: '',
        author: '',
        properties: [
          EffectProperty({
            'property': 'color',
            'type': 'color',
            'default': '#7C5CFF',
          }),
        ],
        thumbnail: null,
        kind: EffectKind.ocfx,
        imported: false,
      );
      engine.selectEffect(solid);
      engine.setEffectProperty(solid, 'color', '#0050FF');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(HSVColor.fromColor(accent.value).hue, closeTo(221, 3));

      engine.selectEffect(
        EffectInfo(
          path: 'dark.ocfx',
          title: 'Dark',
          description: '',
          author: '',
          properties: const [],
          thumbnail: null,
          kind: EffectKind.ocfx,
          imported: false,
        ),
      );
      engine.setBrightness(0);
      engine.onFrame(CanvasFrame(160, 100, Uint8List(160 * 100 * 3)));
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(accent.value, AccentController.neutral);
    },
  );

  testWidgets('near the bottom of the window the panel opens upwards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: SizedBox(
                height: 44,
                child: BrightnessControl(engine: engine),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(BrightnessControl)));
    await tester.pump();
    final panel = tester.getRect(find.byType(BrightnessPanel));
    final control = tester.getRect(find.byIcon(Icons.light_mode_rounded));
    expect(panel.bottom, lessThanOrEqualTo(control.top));
    expect(panel.top, greaterThanOrEqualTo(0));
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('hovering the brightness opens the panel, the button pauses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PauseButton(engine: engine),
                BrightnessControl(engine: engine),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('All'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(BrightnessControl)));
    await tester.pump();
    expect(find.text('All'), findsOneWidget);
    expect(find.text('No devices connected.'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('All'), findsNothing);

    await tester.tap(find.byType(PauseButton));
    await tester.pump();
    expect(engine.paused, isTrue);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    engine.setBrightness(0);
    await tester.pump();
    await tester.tap(find.byType(PauseButton));
    expect(engine.paused, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });
}
