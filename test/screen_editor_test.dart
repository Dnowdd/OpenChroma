import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/ui/screen_editor.dart';

Future<String> _png(Directory dir) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 64),
    Paint()..color = const Color(0xFF3366FF),
  );
  final image = await recorder.endRecording().toImage(64, 64);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/img.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}

void main() {
  testWidgets('texts are moved, resized and duplicated on the canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('oc_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = (await tester.runAsync(() => _png(dir)))!;

    ScreenEdit? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showScreenEditor(
              context,
              spec: const ScreenSpec(480, 480, round: true, liveValues: 5),
              path: path,
              initial: const ScreenEdit(
                texts: [ScreenText(text: 'CPU', size: .1)],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    for (
      var i = 0;
      i < 20 && find.byType(ScreenPreview).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final canvas = find.byType(ScreenPreview);
    expect(canvas, findsOneWidget);
    final box = tester.getRect(canvas);
    final inner = box.width - 24;

    final gesture = await tester.startGesture(box.center);
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(60, 60));
    await gesture.up();
    await tester.pump();

    final start = box.center + const Offset(100, 60);
    final rect = ScreenEdit.textRect(
      const ScreenText(text: 'CPU', size: .1),
      inner,
      inner,
    );
    final handle = start + Offset(rect.width / 2 + 6, rect.height / 2 + 6);
    final resize = await tester.startGesture(handle);
    await resize.moveBy(const Offset(30, 30));
    await resize.moveBy(Offset(rect.width / 2 + 6, rect.height / 2 + 6));
    await resize.up();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    await tester.tap(find.text('Send to screen'));
    await tester.pumpAndSettle();

    final texts = result!.texts;
    expect(texts, hasLength(2));
    final t = texts.first;
    expect(t.x, closeTo(.5 + 100 / inner - 1 / 480, .01));
    expect(t.y, closeTo(.5 + 60 / inner, .01));
    expect(t.size, greaterThan(.15));
    expect(texts.last.x, closeTo(t.x + .04, .001));
  });
}
