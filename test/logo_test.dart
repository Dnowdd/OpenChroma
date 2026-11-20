import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/ui/accent.dart';
import 'package:openchroma/src/ui/logo.dart';

void main() {
  test('SVG path data turns into closed outlines', () {
    final p = parseSvgPath('M0 0H10V10L0 10ZM2 2C3 3 4 4 5 5Z');
    expect(p.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    expect(() => parseSvgPath('M0 0A1 1 0 0 0 2 2'), throwsFormatException);
  });

  testWidgets('the icon mark is drawn in the accent on a clear background', (
    tester,
  ) async {
    const accent = Color(0xFF2266FF);
    final rgba = (await tester.runAsync(() => renderLogoMark(accent, 32)))!;
    expect(rgba.length, 32 * 32 * 4);
    expect(rgba[3], 0);
    var lit = 0;
    for (var i = 0; i < rgba.length; i += 4) {
      if (rgba[i + 3] == 255 &&
          rgba[i] == 0x22 &&
          rgba[i + 1] == 0x66 &&
          rgba[i + 2] == 0xFF) {
        lit++;
      }
    }
    expect(lit, greaterThan(20));
  });

  testWidgets('the logo paints in the live accent', (tester) async {
    final dir = Directory.systemTemp.createTempSync('oc_logo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final controller = AccentController(Engine(dataDir: dir.path))
      ..value = const Color(0xFFFF4FD8);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            child: LiveAccent(
              controller: controller,
              child: const ColoredBox(
                color: Color(0xFF0C0C0E),
                child: OcLogo(height: 60),
              ),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(OcLogo));
    expect(size.height, 60);
    expect(size.width, closeTo(60 * 2136 / 386, .5));
    final logo = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(OcLogo),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(logo.painter, isNotNull);
    controller.dispose();
  });
}
