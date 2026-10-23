import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

/// A device whose charge Windows reports (Bluetooth headsets, controllers,
/// mice...).
class WirelessBattery {
  const WirelessBattery(this.name, this.level, {this.vid, this.pid});

  WirelessBattery.fromJson(Map j)
    : name = '${j['name'] ?? ''}',
      level = (j['battery'] as num?)?.toInt() ?? 0,
      vid = _id(j['vid']),
      pid = _id(j['pid']);

  static int? _id(Object? v) {
    final n = (v as num?)?.toInt() ?? -1;
    return n < 0 ? null : n;
  }

  final String name;

  /// Charge in percent.
  final int level;

  /// USB-style ids, when Windows shows them (HID over Bluetooth).
  final int? vid;
  final int? pid;
}

/// Every battery Windows knows now, read off the UI isolate (it walks all
/// devices). Empty when the runner has no OcBatteries (tests).
Future<List<WirelessBattery>> readBatteries() => Isolate.run(() {
  try {
    final read = DynamicLibrary.executable()
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, int)
        >('OcBatteries');
    var cap = 4096;
    while (true) {
      final buf = malloc<Uint8>(cap);
      try {
        final n = read(buf.cast(), cap);
        if (n >= cap) {
          cap = n + 1;
          continue;
        }
        final list = jsonDecode(utf8.decode(buf.asTypedList(n))) as List;
        return [for (final j in list) WirelessBattery.fromJson(j as Map)];
      } finally {
        malloc.free(buf);
      }
    }
  } catch (_) {
    return <WirelessBattery>[];
  }
});
