import 'dart:io';
import 'dart:typed_data';

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
    'leds': counts.fold(0, (total, count) => total + count),
    'zones': [
      for (final (index, count) in counts.indexed)
        {'name': 'LEDs $index', 'count': count},
    ],
  }),
  source: DeviceSource.plugin,
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

  testWidgets('orientation changes the color sampled by each LED', (
    tester,
  ) async {
    final data = Directory.systemTemp.createTempSync('oc_orientation');
    addTearDown(() => data.deleteSync(recursive: true));
    final strip = device('ledstrip', [3]);
    final zone = strip.zones.single;
    final engine = Engine(dataDir: data.path)..devices[strip.key] = strip;
    final width = canvasWidth.toInt();
    final height = canvasHeight.toInt();
    final rgb = Uint8List(width * height * 3);
    for (var y = 0; y < 3; y++) {
      rgb[y * width * 3] = (y + 1) * 20;
    }
    engine.onFrame(CanvasFrame(width, height, rgb), force: true);
    final item = LayoutItem(x: 0, y: 0, scale: 1, turns: 1, flipY: true);
    engine.setLayout(strip, zone.key, item);
    engine.pushFrames();
    expect(strip.lastSent, [60, 0, 0, 40, 0, 0, 20, 0, 0]);
    final stored = engine.layoutOf(strip, zone.key);
    expect(stored.sizeOf(zone), (1, 3));
    expect(stored.toJson(), item.toJson());
    final suggested = suggestLayout([strip], currentLayout: engine.layoutOf);
    final placement = suggested[(strip.key, zone.key)]!;
    expect(
      (placement.turns, placement.flipX, placement.flipY),
      (1, false, true),
    );
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('identification flashes only its LEDs and restores the effect', (
    tester,
  ) async {
    final data = Directory.systemTemp.createTempSync('oc_identify');
    addTearDown(() => data.deleteSync(recursive: true));
    final deviceWithZones = device('motherboard', [0, 2, 1]);
    final engine = Engine(dataDir: data.path)
      ..devices[deviceWithZones.key] = deviceWithZones;
    final zone = deviceWithZones.zones.last;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: engine,
            builder: (context, _) => LayoutPage(engine: engine),
          ),
        ),
      ),
    );
    final overlay = find.byKey(ValueKey((deviceWithZones.key, zone.key)));
    await tester.tap(overlay);
    engine.pushFrames();
    expect(deviceWithZones.lastSent, [0, 0, 0, 0, 0, 0, 160, 160, 160]);
    engine.onFrame(CanvasFrame(1, 1, Uint8List.fromList([25, 50, 75])));
    await tester.pump(const Duration(milliseconds: 350));
    engine.pushFrames();
    expect(deviceWithZones.lastSent, [25, 50, 75, 25, 50, 75, 0, 0, 0]);
    await tester.pump(const Duration(milliseconds: 700));
    engine.pushFrames();
    expect(deviceWithZones.lastSent, [25, 50, 75, 25, 50, 75, 25, 50, 75]);
    await tester.tap(overlay);
    engine.setTestColor(deviceWithZones, 1, 255);
    await tester.pump(const Duration(milliseconds: 1050));
    engine.pushFrames();
    expect(deviceWithZones.lastSent, [255, 0, 0, 255, 0, 0, 0, 0, 0]);
    await tester.tap(find.text('Rotate 90°'));
    await tester.pump();
    expect(engine.layoutOf(deviceWithZones, zone.key).turns, 1);
    await tester.tap(find.text('Flip horizontal'));
    await tester.pump();
    expect(engine.layoutOf(deviceWithZones, zone.key).flipX, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
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
