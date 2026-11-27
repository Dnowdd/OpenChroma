import 'dart:math' as math;
import 'dart:ui';

import '../engine/engine.dart';
import 'device_art.dart';

enum _Area { lighting, accessories, keyboard, pointer, pc }

Map<(String, String), LayoutItem> suggestLayout(
  Iterable<DeviceInstance> devices, {
  LayoutItem Function(DeviceInstance, String)? currentLayout,
}) {
  final groups = <_Area, List<(DeviceInstance, LedZone)>>{};
  final ordered = devices.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final device in ordered) {
    final area = switch (deviceKindOf(device.type, device.name)) {
      DeviceKind.strip => _Area.lighting,
      DeviceKind.keyboard => _Area.keyboard,
      DeviceKind.mouse || DeviceKind.mousepad => _Area.pointer,
      DeviceKind.motherboard ||
      DeviceKind.gpu ||
      DeviceKind.ram ||
      DeviceKind.fan ||
      DeviceKind.cooler ||
      DeviceKind.controller ||
      DeviceKind.pcCase => _Area.pc,
      _ => _Area.accessories,
    };
    for (final zone in device.zones) {
      if (zone.width > 0 && zone.height > 0 && zone.positions.isNotEmpty) {
        (groups[area] ??= []).add((device, zone));
      }
    }
  }

  const padding = 8.0;
  const right = canvasWidth - padding;
  const bottom = canvasHeight - padding;
  final hasDesk =
      groups.containsKey(_Area.accessories) ||
      groups.containsKey(_Area.keyboard) ||
      groups.containsKey(_Area.pointer);
  final hasPc = groups.containsKey(_Area.pc);
  final hasInput =
      groups.containsKey(_Area.keyboard) || groups.containsKey(_Area.pointer);
  final deskRight = hasPc && hasDesk ? 205.0 : right;
  final deskTop = groups.containsKey(_Area.lighting) && (hasDesk || hasPc)
      ? 48.0
      : padding;
  final inputTop = hasInput && (groups.containsKey(_Area.accessories) || hasPc)
      ? 103.0
      : deskTop;
  final pointerLeft =
      groups.containsKey(_Area.keyboard) && groups.containsKey(_Area.pointer)
      ? deskRight * .7
      : padding;
  final regions = {
    _Area.lighting: Rect.fromLTRB(
      padding,
      padding,
      right,
      deskTop == padding ? bottom : deskTop - padding,
    ),
    _Area.accessories: Rect.fromLTRB(
      padding,
      deskTop,
      deskRight,
      hasInput ? inputTop - padding : bottom,
    ),
    _Area.keyboard: Rect.fromLTRB(
      padding,
      inputTop,
      pointerLeft == padding ? deskRight : pointerLeft - padding,
      bottom,
    ),
    _Area.pointer: Rect.fromLTRB(pointerLeft, inputTop, deskRight, bottom),
    _Area.pc: Rect.fromLTRB(
      hasDesk ? deskRight + padding : padding,
      deskTop,
      right,
      bottom,
    ),
  };

  final result = <(String, String), LayoutItem>{};
  for (final MapEntry(key: area, value: zones) in groups.entries) {
    final region = regions[area]!;
    final columns = math
        .sqrt(zones.length * region.width / region.height)
        .round()
        .clamp(1, zones.length);
    final rows = (zones.length / columns).ceil();
    final width = region.width / columns;
    final height = region.height / rows;
    for (final (index, (device, zone)) in zones.indexed) {
      final row = index ~/ columns;
      final rowCount = math.min(columns, zones.length - row * columns);
      final centerX =
          region.center.dx + (index % columns + .5 - rowCount / 2) * width;
      final centerY = region.top + (row + .5) * height;
      final current = currentLayout?.call(device, zone.key);
      final (zoneWidth, zoneHeight) =
          current?.sizeOf(zone) ?? (zone.width, zone.height);
      final scale = math.min(
        40.0,
        math.min(width * .88 / zoneWidth, height * .84 / zoneHeight),
      );
      result[(device.key, zone.key)] = LayoutItem(
        x: centerX - zoneWidth * scale / 2,
        y: centerY - zoneHeight * scale / 2,
        scale: scale,
        turns: current?.turns ?? 0,
        flipX: current?.flipX ?? false,
        flipY: current?.flipY ?? false,
      );
    }
  }
  return result;
}
