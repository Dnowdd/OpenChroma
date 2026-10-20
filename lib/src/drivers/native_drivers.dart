import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// OpenRGB zone types, as oc_drivers.dll reports them.
abstract final class ZoneType {
  static const single = 0;
  static const linear = 1;
  static const matrix = 2;
}

/// One group of LEDs of a device: a whole keyboard, a fan header, a strip.
class DriverZone {
  DriverZone.fromJson(Map j, this.start)
    : name = '${j['name'] ?? ''}',
      type = (j['type'] as num?)?.toInt() ?? ZoneType.linear,
      count = (j['count'] as num?)?.toInt() ?? 0,
      min = (j['min'] as num?)?.toInt() ?? 0,
      max = (j['max'] as num?)?.toInt() ?? 0,
      width = (j['width'] as num?)?.toInt() ?? 0,
      height = (j['height'] as num?)?.toInt() ?? 0,
      map = [for (final v in j['map'] as List? ?? []) (v as num).toInt()];

  final String name;
  final int type;

  /// LEDs in the zone.
  final int count;

  /// LED count range for zones the user sizes (ARGB headers).
  final int min;
  final int max;

  /// Matrix layout: [map] has [width] x [height] cells, each the zone's LED
  /// index there or [noLed].
  final int width;
  final int height;
  final List<int> map;

  /// Index of the zone's first LED among the device's LEDs.
  final int start;

  static const noLed = 0xFFFFFFFF;

  bool get resizable => max > min;
  bool get isMatrix => width > 0 && height > 0 && map.length == width * height;
}

/// A device the drivers found.
class DriverDevice {
  DriverDevice.fromJson(Map j)
    : id = (j['id'] as num).toInt(),
      name = _name(j),
      vendor = '${j['vendor'] ?? ''}',
      description = '${j['description'] ?? ''}',
      location = '${j['location'] ?? ''}',
      serial = '${j['serial'] ?? ''}',
      version = '${j['version'] ?? ''}',
      type = '${j['type'] ?? 'other'}',
      ledCount = (j['leds'] as num?)?.toInt() ?? 0,
      modes = [for (final m in j['modes'] as List? ?? []) '$m'],
      zones = _zones(j['zones'] as List? ?? []);

  /// Some drivers leave the name empty (e.g. when the board model could not
  /// be read); fall back to what else they report.
  static String _name(Map j) {
    for (final k in ['name', 'description', 'vendor']) {
      final v = '${j[k] ?? ''}'.trim();
      if (v.isNotEmpty) return v;
    }
    return 'Dispositivo';
  }

  static List<DriverZone> _zones(List raw) {
    final out = <DriverZone>[];
    var start = 0;
    for (final z in raw) {
      final zone = DriverZone.fromJson(z as Map, start);
      out.add(zone);
      start += zone.count;
    }
    return out;
  }

  /// Handle for [NativeDrivers.setLeds]; changes between runs.
  final int id;
  final String name;
  final String vendor;
  final String description;

  /// Where it is connected (HID path, I2C address...).
  final String location;
  final String serial;
  final String version;
  final String type;
  final int ledCount;
  final List<String> modes;
  final List<DriverZone> zones;

  /// Identity that survives restarts and re-detection.
  String get key => '$type|$name|${serial.isNotEmpty ? serial : location}';
}

class DriverState {
  const DriverState({
    this.ready = false,
    this.detecting = false,
    this.percent = 0,
    this.step = '',
    this.devices = const [],
  });

  /// The drivers finished starting up.
  final bool ready;
  final bool detecting;
  final int percent;

  /// What detection is looking at right now.
  final String step;
  final List<DriverDevice> devices;
}

/// The device drivers in oc_drivers.dll (built from the OpenRGB sources in
/// third_party/openrgb, see windows/drivers).
class NativeDrivers {
  NativeDrivers() {
    try {
      final lib = DynamicLibrary.open('oc_drivers.dll');
      _start = lib
          .lookupFunction<
            Int32 Function(Pointer<Utf8>),
            int Function(Pointer<Utf8>)
          >('OcdStart');
      _state = lib
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)
          >('OcdState');
      _setLeds = lib
          .lookupFunction<
            Void Function(Uint64, Pointer<Uint8>, Int32),
            void Function(int, Pointer<Uint8>, int)
          >('OcdSetLeds');
      _resize = lib
          .lookupFunction<
            Void Function(Uint64, Int32, Int32),
            void Function(int, int, int)
          >('OcdResizeZone');
      _rescan = lib.lookupFunction<Void Function(), void Function()>(
        'OcdRescan',
      );
      _claim = lib
          .lookupFunction<Void Function(Int32, Int32), void Function(int, int)>(
            'OcdClaimHid',
          );
      _setMode = lib
          .lookupFunction<
            Void Function(Uint64, Int32),
            void Function(int, int)
          >('OcdSetMode');
      _shutdown = lib
          .lookupFunction<
            Void Function(Uint8, Uint8, Uint8),
            void Function(int, int, int)
          >('OcdShutdown');
    } catch (_) {
      // Not available (tests, a build without the drivers).
    }
  }

  int Function(Pointer<Utf8>)? _start;
  int Function(Pointer<Utf8>, int)? _state;
  void Function(int, Pointer<Uint8>, int)? _setLeds;
  void Function(int, int, int)? _resize;
  void Function()? _rescan;
  void Function(int, int)? _claim;
  void Function(int, int)? _setMode;
  void Function(int, int, int)? _shutdown;

  bool get available => _start != null;

  Pointer<Utf8> _buf = nullptr;
  int _cap = 0;
  Pointer<Uint8> _colors = nullptr;
  int _colorsCap = 0;
  String _lastJson = '';
  DriverState _last = const DriverState();

  /// Starts detection; [configDir] holds the drivers' settings and logs.
  void start(String configDir) {
    final start = _start;
    if (start == null) return;
    using((arena) => start(configDir.toNativeUtf8(allocator: arena)));
  }

  /// The current device list. Cheap when nothing changed.
  DriverState poll() {
    final read = _state;
    if (read == null) return _last;
    var n = read(_buf, _cap);
    if (n >= _cap) {
      if (_buf != nullptr) malloc.free(_buf);
      _cap = n + 64 * 1024;
      _buf = malloc<Uint8>(_cap).cast();
      n = read(_buf, _cap);
      if (n >= _cap) return _last;
    }
    final text = utf8.decode(
      _buf.cast<Uint8>().asTypedList(n),
      allowMalformed: true,
    );
    if (text == _lastJson) return _last;
    _lastJson = text;
    try {
      final j = jsonDecode(text) as Map;
      _last = DriverState(
        ready: j['ready'] == true,
        detecting: j['detecting'] == true,
        percent: (j['percent'] as num?)?.toInt() ?? 0,
        step: '${j['step'] ?? ''}',
        devices: [
          for (final d in j['devices'] as List? ?? [])
            DriverDevice.fromJson(d as Map),
        ],
      );
    } catch (_) {}
    return _last;
  }

  /// Sends one color per LED (RGB bytes, device LED order).
  void setLeds(int id, Uint8List rgb) {
    final set = _setLeds;
    if (set == null || rgb.isEmpty) return;
    if (rgb.length > _colorsCap) {
      if (_colors != nullptr) malloc.free(_colors);
      _colorsCap = rgb.length;
      _colors = malloc<Uint8>(_colorsCap);
    }
    _colors.asTypedList(rgb.length).setAll(0, rgb);
    set(id, _colors, rgb.length ~/ 3);
  }

  void resizeZone(int id, int zone, int count) =>
      _resize?.call(id, zone, count);

  void rescan() => _rescan?.call();

  /// Leaves [vid]:[pid] to an OpenChroma plugin; call before [start].
  void claimHid(int vid, int pid) => _claim?.call(vid, pid);

  /// Runs the device's own mode [index] (see [DriverDevice.modes]); -1
  /// gives the LEDs back to the app.
  void setMode(int id, int index) => _setMode?.call(id, index);

  /// Leaves every device at one color (the app is exiting).
  void shutdown([int r = 0, int g = 0, int b = 0]) => _shutdown?.call(r, g, b);
}
