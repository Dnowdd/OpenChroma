import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/engine.dart';
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
    expect(find.text('Tudo'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(BrightnessControl)));
    await tester.pump();
    expect(find.text('Tudo'), findsOneWidget);
    expect(find.text('Nenhum dispositivo conectado.'), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tudo'), findsNothing);

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
