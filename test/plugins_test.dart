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
  }) : _reads = [...reads],
       _endpoints = endpoints ?? [_endpoint()] {
    _rt = JsRuntime(_host);
    _rt.eval(File(path).readAsStringSync(), name: path);
    _rt.eval('__oc.setInfo({"vid": 1, "pid": 2})');
    _rt.eval('__oc.setSettings({})');
  }

  late final JsRuntime _rt;
  final List<List<int>> _reads;
  final List<Map<String, Object>> _endpoints;
  final writes = <List<int>>[];
  final features = <List<int>>[];
  List<Object?>? battery;

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
    }
    return null;
  }

  bool start() {
    final index = _rt.evalJson('__oc.pickEndpoint(${jsonEncode(_endpoints)})');
    if (index is! num || index < 0) return false;
    return _rt.eval('__oc.start()') == true;
  }

  void render(List<int> rgb) => _rt.eval('__oc.render(${jsonEncode(rgb)})');
  void poll() => _rt.eval('__oc.poll()');
}
