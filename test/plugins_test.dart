import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/plugins/js_runtime.dart';
import 'package:openchroma/src/plugins/plugin_library.dart';

/// Runs the bundled plugins against a fake device and checks the reports
/// they build. QuickJS only loads next to a Windows build, so these run
/// with OC_PLUGIN_TEST=1 and build\windows\x64\runner\Release on PATH.
void main() {
  final enabled = Platform.environment['OC_PLUGIN_TEST'] == '1';
  final skip = enabled ? false : 'set OC_PLUGIN_TEST=1 (needs the QuickJS DLL)';

  final files = Directory('assets/plugins')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.js'))
      .toList();

  test('bundled plugins exist', () => expect(files, isNotEmpty));

  for (final f in files) {
    test('${f.uri.pathSegments.last} declares its devices', () {
      final info = readPlugin(f.path, bundled: true);
      expect(info.error, isNull);
      expect(info.devices, isNotEmpty);
      expect(info.name, isNotEmpty);
    }, skip: skip);
  }

  test('a plugin stamp changes with its source', () {
    final dir = Directory.systemTemp.createTempSync('oc_plugin');
    final f = File('${dir.path}/test.js');
    String source(String name) =>
        "plugin({ name: '$name', devices: [{ vid: 1, pid: 2 }], zones: [] });";
    try {
      f.writeAsStringSync(source('A'));
      final a = readPlugin(f.path, bundled: false);
      expect(readPlugin(f.path, bundled: false).stamp, a.stamp);
      f.writeAsStringSync(source('B'));
      expect(readPlugin(f.path, bundled: false).stamp, isNot(a.stamp));
    } finally {
      dir.deleteSync(recursive: true);
    }
  }, skip: skip);

  test('DualShock 4 sends the light bar report over USB', () {
    final fake = _FakeDevice(
      'assets/plugins/sony-dualshock4.js',
      reads: [
        // One report for start() to tell USB from Bluetooth, one for poll().
        _report(0x01, {}),
        _report(0x01, {30: 0x1A}),
      ],
    );
    fake.start();
    fake.render([10, 20, 30]);
    expect(fake.writes.single, [0x05, 0x07, 0, 0, 0, 0, 10, 20, 30, 0, 0]);
    // The same color is not sent twice.
    fake.render([10, 20, 30]);
    expect(fake.writes, hasLength(1));
    // Battery nibble 0xA with the cable bit: 100%, charging.
    fake.poll();
    expect(fake.battery, [100, true]);
  }, skip: skip);

  test('DualShock 4 signs Bluetooth reports with CRC-32', () {
    final fake = _FakeDevice(
      'assets/plugins/sony-dualshock4.js',
      reads: [_report(0x11, {})],
    );
    fake.start();
    fake.render([1, 2, 3]);
    final w = fake.writes.single;
    expect(w.length, 78);
    expect(w.sublist(0, 11), [0x11, 0xC0, 0, 0x07, 0, 0, 0, 0, 1, 2, 3]);
    final crc = _crc32([0xA2, ...w.sublist(0, 74)]);
    expect(w.sublist(74), [
      crc & 0xFF,
      (crc >> 8) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 24) & 0xFF,
    ]);
  }, skip: skip);

  test('ROYUAN keyboard sends checksummed LED parameters', () {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [
        _endpoint(interface: 0),
        _endpoint(interface: 2, featureLength: 65),
      ],
    );
    expect(fake.start(), isTrue);
    fake.render([0x10, 0x20, 0x30]);
    final payload = [0x07, 0x01, 0x04, 0x04, 0x07, 0x10, 0x20, 0x30];
    final sum = payload.reduce((a, b) => a + b);
    var pow = 1;
    while (pow < sum) {
      pow <<= 1;
    }
    expect(fake.features.single, [0x00, ...payload, (pow - sum - 1) & 0xFF]);
    // Frames faster than the update rate are dropped.
    fake.render([0x11, 0x20, 0x30]);
    expect(fake.features, hasLength(1));
  }, skip: skip);

  test('ROYUAN keyboard switches to its own effect and back', () {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
    );
    fake.start();
    // Mode ids are numbers: 0x02 is breathing, sent with rainbow colors.
    fake.mode(2);
    expect(fake.features.last.sublist(1, 9), [
      0x07,
      0x02,
      4,
      4,
      0x08,
      255,
      255,
      255,
    ]);
    // Back to the app: the next frame is sent even if the color is the
    // same as before the effect.
    fake.mode(null);
    fake.render([1, 2, 3]);
    expect(fake.features.last.sublist(1, 9), [0x07, 0x01, 4, 4, 0x07, 1, 2, 3]);
  }, skip: skip);

  test('ROYUAN keyboard effects take speed, brightness and a color', () {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
    );
    fake.start();
    // Options reach the plugin as the app sends them: colors in 0xRRGGBB.
    fake.mode(0x05, {
      'speed': 1,
      'brightness': 2,
      'random': false,
      'colors': [0x102030],
    });
    expect(fake.features.last.sublist(1, 9), [
      0x07,
      0x05,
      1,
      2,
      0x07,
      0x10,
      0x20,
      0x30,
    ]);
  }, skip: skip);

  test('ROYUAN keyboard direct mode enters 0x15 once, then sends 0x0E', () {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
      settings: {'live': 'Ao vivo B'},
    );
    fake.start();
    fake.render([10, 20, 30]);
    expect(fake.features, hasLength(2));
    expect(fake.features[0].sublist(1, 3), [0x07, 0x15]);
    final payload = [0x0E, 10, 20, 30, 0, 0, 0];
    final sum = payload.reduce((a, b) => a + b);
    expect(fake.features[1], [0x00, ...payload, (0xFF - (sum & 0xFF)) & 0xFF]);
  }, skip: skip);

  test('the K86 takes live colors by default, at frame rate', () {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
      info: {'vid': 0x3151, 'pid': 0x4015},
    );
    fake.start();
    fake.features.clear(); // the model id question
    fake.render([10, 20, 30]);
    fake.render([11, 20, 30]);
    // Direct mode once, then one live color per frame, with no rate limit.
    expect(fake.features.map((f) => f[1]), [0x07, 0x0E, 0x0E]);
    expect(fake.features.first[2], 0x15);
    // The Attack Shark app's checksum: 255 minus the sum's low byte.
    expect(fake.features.last.sublist(1, 9), [
      0x0E,
      11,
      20,
      30,
      0,
      0,
      0,
      255 - ((0x0E + 11 + 20 + 30) & 255),
    ]);
    // Names saved by older versions still work.
    final old = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
      info: {'vid': 0x3151, 'pid': 0x4015},
      settings: {'live': 'Padrão'},
    );
    old.start();
    old.features.clear();
    old.render([10, 20, 30]);
    expect(old.features.single[1], 0x07);
  }, skip: skip);

  test('the K86 shows still effects key by key in picture 3', () async {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
      info: {'vid': 0x3151, 'pid': 0x4015},
      answers: {
        0x8F: [0x00, 0x8F, 0x90, 0x04, 0x00, 0x00], // model id 1168
      },
    );
    fake.start();
    // Set the clock at start, in local time: 2026-10-23 16:30:05.
    expect(fake.features.last.sublist(1, 2), [0x28]);
    expect(fake.features.last.sublist(9, 16), [0x07, 0xEA, 10, 23, 16, 30, 5]);
    final layout = fake.layout();
    final zone = (layout['zones'] as List).single as Map;
    expect([zone['width'], zone['height']], [37, 6]);
    final leds = (zone['map'] as List).where((v) => v != -1).length;
    expect(leds, 86);
    expect((layout['screen'] as Map)['width'], 240);
    expect(
      (layout['modes'] as List).map((m) => (m as Map)['id']),
      contains('picture3'),
    );
    // Different colors per key, held still: one write to picture 3.
    final colors = [
      for (var i = 0; i < leds; i++) ...[i, 255 - i, 0],
    ];
    fake.render(colors);
    fake.features.clear();
    fake.poll();
    expect(fake.features, isEmpty); // not still long enough yet
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    fake.poll();
    expect(fake.features.first.sublist(1, 6), [0x07, 0x0D, 4, 4, 2]);
    expect(fake.features.skip(1).map((f) => f.sublist(1, 6)).toList(), [
      for (var part = 0; part < 7; part++) [0x0C, 0, 0x80, 0x01, part],
    ]);
    // Esc (LED 0) sits in slot 0: its color leads the first part.
    expect(fake.features[1].sublist(9, 12), [0, 255, 0]);
    // The same frame again does not write the picture again.
    fake.features.clear();
    fake.render(colors);
    fake.poll();
    expect(fake.features, isEmpty);
  }, skip: skip);

  test('the K86 sends images to its screen column by column', () {
    final fake = _FakeDevice(
      'assets/plugins/royuan-keyboard.js',
      endpoints: [_endpoint(interface: 2, featureLength: 65)],
      info: {'vid': 0x3151, 'pid': 0x4015},
      answers: {
        0x8F: [0x00, 0x8F, 0x90, 0x04, 0x00, 0x00],
        0xA5: [0x00, 0xA5, 0x01],
      },
      frames: [
        // 2 x 2: red, green / blue, white, row by row.
        [255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255],
      ],
    );
    fake.start();
    fake.features.clear();
    expect(fake.screen(2, 2, [120]), isTrue);
    // Start: frame 0 of 1, 120 ms, 8 bytes, the whole 2 x 2 screen.
    expect(fake.features.first.sublist(1, 7), [0xA5, 0, 1, 120, 8, 0]);
    expect(fake.features.first.sublist(9, 13), [0, 0, 2, 2]);
    // Data: red, blue (first column), green, white, in RGB565.
    final data = fake.features.last;
    expect(data.sublist(1, 8), [0x25, 0, 1, 120, 0, 0, 8]);
    expect(data.sublist(9, 17), [
      0xF8,
      0x00,
      0x00,
      0x1F,
      0x07,
      0xE0,
      0xFF,
      0xFF,
    ]);
    expect(fake.progress, 1);
  }, skip: skip);

  test('Attack Shark X11 sends the lighting report checked on the mouse', () {
    final fake = _FakeDevice(
      'assets/plugins/attack-shark-x11.js',
      endpoints: [_endpoint(interface: 2, usagePage: 0x0B, featureLength: 134)],
      info: {'vid': 0x1D57, 'pid': 0xFA60},
    );
    fake.start();
    // Static red, as written to the mouse on 2026-10-23 (it turned red).
    fake.mode(1, {
      'brightness': 8,
      'colors': [0xFF0000],
    });
    expect(fake.features.last, [
      0x05, 0x0F, 0x01, 0x10, 0x03, 0xA8, 0xFF, 0x00, 0x00, //
      0x01, 0x04, 0x01, 0xBF, 0x00, 0x00,
    ]);
    // App colors go as a static color; the speed byte keeps its default.
    fake.mode(null);
    fake.render([10, 20, 30]);
    expect(fake.features.last.sublist(3, 13), [
      0x10, 0x03, 0xA8, 10, 20, 30, 0x01, 0x04, 0x00, 0xFC, //
    ]);
  }, skip: skip);

  test('Attack Shark X11 reads its battery from the event reports', () {
    final fake = _FakeDevice(
      'assets/plugins/attack-shark-x11.js',
      endpoints: [
        _endpoint(interface: 2, usagePage: 0x0B, featureLength: 134),
        _endpoint(interface: 2, usagePage: 0x0A),
      ],
      info: {'vid': 0x1D57, 'pid': 0xFA60},
      reads: [
        [0x03, 0x55, 0x40, 0x01, 0x64],
        [0x03, 0x55, 0x40, 0x03, 0x50],
      ],
    );
    fake.start();
    fake.poll();
    // The newest event: 80%, charging (state 3 through the receiver).
    expect(fake.battery, [0x50, true]);
  }, skip: skip);

  test('Attack Shark X11 pauses colors to hear its battery', () {
    final fake = _FakeDevice(
      'assets/plugins/attack-shark-x11.js',
      endpoints: [
        _endpoint(interface: 2, usagePage: 0x0B, featureLength: 134),
        _endpoint(interface: 2, usagePage: 0x0A),
      ],
      info: {'vid': 0x1D57, 'pid': 0xFA60},
    );
    fake.start();
    // No battery report yet: the next colors wait so one can come through.
    fake.poll();
    fake.render([1, 2, 3]);
    expect(fake.features, isEmpty);
  }, skip: skip);

  test('G403 HERO turns off saving and sets both zones', () {
    final fake = _FakeDevice(
      'assets/plugins/logitech-g403-hero.js',
      endpoints: [
        _endpoint(interface: 1, usagePage: 0xFF00, usage: 1),
        _endpoint(interface: 1, usagePage: 0xFF00, usage: 2),
      ],
    );
    fake.start();
    expect(fake.writes.first, [0x10, 0xFF, 0x0E, 0x8A, 1, 1, 0]);
    fake.writes.clear();
    fake.render([1, 2, 3, 4, 5, 6]);
    expect(fake.writes, hasLength(2));
    expect(fake.writes[0].sublist(0, 10), [
      0x11,
      0xFF,
      0x0E,
      0x3A,
      0,
      1,
      1,
      2,
      3,
      2,
    ]);
    expect(fake.writes[1].sublist(0, 10), [
      0x11,
      0xFF,
      0x0E,
      0x3A,
      1,
      1,
      4,
      5,
      6,
      2,
    ]);
  }, skip: skip);

  test('G403 HERO breathes in the chosen color, speed and brightness', () {
    final fake = _FakeDevice(
      'assets/plugins/logitech-g403-hero.js',
      endpoints: [
        _endpoint(interface: 1, usagePage: 0xFF00, usage: 1),
        _endpoint(interface: 1, usagePage: 0xFF00, usage: 2),
      ],
    );
    fake.start();
    fake.writes.clear();
    fake.mode('breathing', {
      'speed': 20,
      'brightness': 40,
      'colors': [0xFF8000],
    });
    // Saving back on, then one effect report per zone: 2000 ms, 40%.
    expect(fake.writes.first, [0x10, 0xFF, 0x0E, 0x8A, 0, 0, 0]);
    expect(fake.writes[1].sublist(4, 13), [
      0,
      3,
      0xFF,
      0x80,
      0x00,
      2000 >> 8,
      2000 & 0xFF,
      0,
      40,
    ]);
  }, skip: skip);
}

Map<String, Object> _endpoint({
  int interface = 0,
  int usagePage = 1,
  int usage = 5,
  int featureLength = 0,
}) => {
  'interface': interface,
  'usagePage': usagePage,
  'usage': usage,
  'collection': 0,
  'inputLength': 64,
  'outputLength': 64,
  'featureLength': featureLength,
};

List<int> _report(int id, Map<int, int> bytes) {
  final r = List<int>.filled(78, 0)..[0] = id;
  bytes.forEach((i, v) => r[i] = v);
  return r;
}

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// A plugin running against recorded I/O instead of a real device.
class _FakeDevice {
  _FakeDevice(
    String path, {
    List<List<int>> reads = const [],
    List<Map<String, Object>>? endpoints,
    Map<String, Object?> settings = const {},
    Map<String, Object?> info = const {'vid': 1, 'pid': 2},
    this.answers = const {},
    this.frames = const [],
  }) : _reads = [...reads],
       _endpoints = endpoints ?? [_endpoint()] {
    _rt = JsRuntime(_host);
    _rt.eval(File(path).readAsStringSync(), name: path);
    _rt.eval('__oc.setInfo(${jsonEncode(info)})');
    _rt.eval('__oc.setSettings(${jsonEncode(settings)})');
  }

  late final JsRuntime _rt;
  final List<List<int>> _reads;
  final List<Map<String, Object>> _endpoints;
  final writes = <List<int>>[];
  final features = <List<int>>[];
  List<Object?>? battery;
  num? progress;

  /// Feature report answers by the command last sent (its first byte).
  final Map<int, List<int>> answers;

  /// Screen frames the plugin reads with dev.frame(i).
  final List<List<int>> frames;

  Object? _host(String method, List<dynamic> a) {
    List<int> bytes(Object? v) => [
      for (final x in v as List) (x as num).toInt(),
    ];
    switch (method) {
      case 'write':
        writes.add(bytes(a[0]));
        return writes.last.length;
      case 'sendFeature':
        features.add(bytes(a[0]));
        return features.last.length;
      case 'read':
        return _reads.isEmpty ? <int>[] : _reads.removeAt(0);
      case 'endpoints':
        return _endpoints;
      case 'useEndpoint':
        return true;
      case 'battery':
        battery = [a[0], a[1]];
        return null;
      case 'getFeature':
        final last = features.isEmpty ? null : features.last;
        return last == null || last.length < 2
            ? <int>[]
            : answers[last[1]] ?? <int>[];
      case 'frame':
        return frames[(a[0] as num).toInt()];
      case 'progress':
        progress = a[0] as num;
        return null;
      case 'localTime':
        return [2026, 10, 23, 16, 30, 5];
    }
    return null;
  }

  Map<String, Object?> layout() =>
      (jsonDecode(_rt.eval('__oc.layout()') as String) as Map)
          .cast<String, Object?>();

  bool screen(int width, int height, List<int> delays) =>
      _rt.eval(
        '__oc.screen(${jsonEncode({'width': width, 'height': height, 'frames': frames.length, 'delays': delays})})',
      ) ==
      true;

  bool start() {
    final index = _rt.evalJson('__oc.pickEndpoint(${jsonEncode(_endpoints)})');
    if (index is! num || index < 0) return false;
    return _rt.eval('__oc.start()') == true;
  }

  void render(List<int> rgb) => _rt.eval('__oc.render(${jsonEncode(rgb)})');
  void poll() => _rt.eval('__oc.poll()');
  void mode(Object? id, [Map<String, Object?>? options]) =>
      _rt.eval('__oc.mode(${jsonEncode(id)}, ${jsonEncode(options)})');
}
