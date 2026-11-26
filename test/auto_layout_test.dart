import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/drivers/native_drivers.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/ui/accent.dart';
import 'package:openchroma/src/ui/auto_layout.dart';
import 'package:openchroma/src/ui/layout_page.dart';

DeviceInstance device(String type, List<int> counts) => DeviceInstance(
  type,
  DriverDevice.fromJson({
    'id': 1,
    'name': type,
    'type': type,
    'zones': [
      for (final (index, count) in counts.indexed)
        {'name': 'LEDs $index', 'count': count},
    ],
  }),
);

void main() {
  test('places all zones within the canvas without overlap', () {
    final keyboard = device('keyboard', [86]);
    final mouse = device('mouse', [3]);
    final pc = device('motherboard', [4, 16, 1024]);
    final strip = device('ledstrip', [120]);
    final devices = [keyboard, mouse, pc, strip];
    final proposal = suggestLayout(devices);
    final rectangles = <String, List<Rect>>{};
    final canvas = Rect.fromLTWH(0, 0, canvasWidth, canvasHeight);
    for (final device in devices) {
      rectangles[device.key] = [
        for (final zone in device.zones)
          Rect.fromLTWH(
            proposal[(device.key, zone.key)]!.x,
            proposal[(device.key, zone.key)]!.y,
            zone.width * proposal[(device.key, zone.key)]!.scale,
            zone.height * proposal[(device.key, zone.key)]!.scale,
          ),
      ];
    }
    final all = rectangles.values.expand((zones) => zones).toList();
    expect(proposal, hasLength(all.length));
    for (final (index, rect) in all.indexed) {
      expect(canvas.contains(rect.topLeft), isTrue);
      expect(canvas.contains(rect.bottomRight), isTrue);
      expect(all.skip(index + 1).any(rect.overlaps), isFalse);
    }
    expect(
      rectangles['keyboard']!.single.center.dx,
      lessThan(rectangles['mouse']!.single.center.dx),
    );
    expect(
      rectangles['keyboard']!.single.top,
      greaterThan(rectangles['ledstrip']!.single.bottom),
    );
    expect(
      rectangles['motherboard']!.every(
        (zone) => zone.left > rectangles['mouse']!.single.right,
      ),
      isTrue,
    );
    final reversed = suggestLayout(devices.reversed);
    expect(
      reversed.map((key, item) => MapEntry(key, item.toJson())),
      proposal.map((key, item) => MapEntry(key, item.toJson())),
    );
  });

  testWidgets('preview can be cancelled, applied and undone', (tester) async {
    final data = Directory.systemTemp.createTempSync('oc_layout');
    addTearDown(() => data.deleteSync(recursive: true));
    final keyboard = device('keyboard', [86]);
    final mouse = device('mouse', [3]);
    final engine = Engine(dataDir: data.path)
      ..devices.addAll({keyboard.key: keyboard, mouse.key: mouse});
    final zone = keyboard.zones.single.key;
    final original = engine.layoutOf(keyboard, zone).toJson();
    final proposed = suggestLayout(engine.devices.values);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LayoutPage(engine: engine)),
      ),
    );

    Future<void> tap(String text) async {
      await tester.tap(find.text(text));
      await tester.pump();
    }

    final zoneOverlay = find.byTooltip(keyboard.name);
    Offset position() =>
        tester.getTopLeft(zoneOverlay) -
        tester.getTopLeft(find.byType(LiveCanvas));
    final originalPosition = position();
    await tap('Auto Arrange');
    expect(find.text('Preview'), findsOneWidget);
    final previewPosition = position();
    expect(previewPosition, isNot(originalPosition));
    expect(engine.layoutOf(keyboard, zone).toJson(), original);
    await tap('Cancel');
    expect((position() - originalPosition).distance, lessThan(0.001));
    expect(engine.layoutOf(keyboard, zone).toJson(), original);
    await tap('Auto Arrange');
    await tap('Apply');
    expect(
      engine.layoutOf(keyboard, zone).toJson(),
      proposed[(keyboard.key, zone)]!.toJson(),
    );
    expect((position() - previewPosition).distance, lessThan(0.001));
    final manual = LayoutItem(x: 1, y: 2, scale: 3);
    engine.setLayout(mouse, mouse.zones.single.key, manual);
    await tap('Undo');
    expect(engine.layoutOf(keyboard, zone).toJson(), original);
    expect(
      engine.layoutOf(mouse, mouse.zones.single.key).toJson(),
      manual.toJson(),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
