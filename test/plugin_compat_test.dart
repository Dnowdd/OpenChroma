import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/paths.dart';
import 'package:openchroma/src/plugins/js_transform.dart';
import 'package:openchroma/src/plugins/plugin_runtime.dart';
import 'package:openchroma/src/plugins/plugin_scanner.dart';

/// Runs every installed HID plugin through Validate, Initialize, a few
/// Render calls and Shutdown against a fake device that accepts every write
/// and answers every read with zeros. A fake device cannot satisfy plugins
/// that wait for real answers, so the test only fails on errors that point
/// at the host API itself (a missing function or object), which would break
/// real devices of that model too.
///
/// Needs QuickJS (next to a Windows build) and SignalRGB's plugins:
///   PATH=build/windows/x64/runner/Release;%PATH% OC_PLUGIN_TEST=1
///   OC_COMPAT_REPORT=report.json (optional, every plugin's outcome)
void main() {
  final install = SignalRgbPaths.detect().installDir;
  final enabled = Platform.environment['OC_PLUGIN_TEST'] == '1';

  test(
    'HID plugins run against a fake device',
    () async {
      final root = '$install${Platform.pathSeparator}Plugins';
      final files = Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.js') && !f.path.endsWith('.test.js'))
          .toList();
      final infos = [for (final f in files) scanPluginFile(f.path)]
          .where((i) => i.error == null && i.isHid && i.vendorId != null)
          .where((i) => i.path.contains(_only));
      // Each plugin runs in its own isolate with a deadline, so one stuck in
      // a loop waiting for the device cannot hold up the rest.
      final report = <Map<String, Object?>>[];
      final queue = infos.toList();
      // A few at a time; QuickJS runtimes are not free.
      while (queue.isNotEmpty) {
        final batch = queue.take(12).toList();
        queue.removeRange(0, batch.length);
        report.addAll(
          await Future.wait([
            for (final info in batch)
              Isolate.run(() => _run(info))
                  .timeout(
                    const Duration(seconds: 20),
                    onTimeout: () => _result(
                      info,
                      'waits',
                      null,
                      'loops waiting for the device',
                    ),
                  )
                  .catchError(
                    (Object e) => _result(info, 'device', null, '$e'),
                  ),
          ]),
        );
      }
      final apiGaps = report
          .where((r) => r['kind'] == 'api')
          .where((r) => !_notOurs.any('${r['plugin']}'.contains))
          .toList();
      final out = Platform.environment['OC_COMPAT_REPORT'];
      if (out != null) {
        File(
          out,
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      }
      final byKind = <String, int>{};
      for (final r in report) {
        byKind['${r['kind']}'] = (byKind['${r['kind']}'] ?? 0) + 1;
      }
      // ignore: avoid_print
      print('plugins: ${report.length} $byKind');
      expect(
        apiGaps,
        isEmpty,
        reason: apiGaps.map((r) => '${r['plugin']}: ${r['error']}').join('\n'),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !enabled
        ? 'set OC_PLUGIN_TEST=1 (needs the QuickJS DLL)'
        : install == null
        ? 'SignalRGB is not installed'
        : false,
  );
}

// Endpoints a typical RGB device exposes; plugins pick theirs in Validate.
final _endpoints = [
  for (var iface = -1; iface <= 6; iface++)
    for (final page in [
      0xFF00,
      0xFFC0,
      0xFF60,
      0xFF13,
      0xFF42,
      0xFF01,
      0x0001,
      0x000C,
      0xFF1C,
      0xFFC1,
    ])
      for (final usage in [0x0001, 0x0002, 0x0006, 0x0061, 0x0088, 0x0080])
        {
          'interface': iface,
          'usage': usage,
          'usage_page': page,
          'collection': 0,
          'length': 65,
        },
];

/// Failures that look like host gaps but are not, checked by hand:
const _notOurs = {
  // Its Shutdown passes LED positions where it expects indexes (a bug in
  // the plugin; it fails the same way in SignalRGB).
  'Steelseries_Rival_600_Mouse',
  // Read the keyboard layout from the device; the fake answers zeros.
  'Corsair_Legacy_Keyboard',
  // Endpoints come from a table keyed by the dongle's real product id.
  'Corsair_Headset_Controller_Bragi',
};

/// `OC_COMPAT_ONLY=part-of-a-path` runs only the matching plugins and keeps
/// their full error messages.
final _only = Platform.environment['OC_COMPAT_ONLY'] ?? '';

class _TooManyCalls implements Exception {}

Map<String, Object?> _run(PluginInfo info) {
  var calls = 0;
  final rt = PluginRuntime((method, args) {
    // Plugins that poll for an answer the fake device never gives would
    // loop forever.
    if (++calls > 20000) throw _TooManyCalls();
    int n(Object? v) => v is num ? v.toInt() : 0;
    switch (method) {
      case 'write':
      case 'send_report':
        return (args[0] as List).length;
      case 'read':
      case 'get_report':
      case 'input_report':
        final len = n(args[1]);
        return List<int>.filled(len > 0 ? len : 64, 0);
      case 'last_read_size':
        return 64;
      case 'set_endpoint':
        return true;
      case 'endpoints':
        return _endpoints;
      case 'hid_info':
        return {'writeLength': 65, 'readLength': 65, 'featureLength': 65};
      case 'pid':
        return info.productIds.first;
      case 'vid':
        return info.vendorId;
      case 'device_info':
        return {
          'vendorId': info.vendorId,
          'productId': info.productIds.first,
          'serial': 'TEST',
          'product': info.name,
          'manufacturer': '',
        };
      case 'brightness':
        return 100;
      case 'sysinfo':
        return {'model': '', 'manufacturer': '', 'vendor': '', 'version': ''};
      default:
        return null;
    }
  });
  String? stage;
  try {
    stage = 'load';
    rt.eval(transformPlugin(info.path));
    stage = 'validate';
    if (rt.hasFunction('Validate') &&
        !_endpoints.any((e) => rt.call('Validate', [e]) == true)) {
      return _result(info, 'rejected', stage, null);
    }
    stage = 'setup';
    rt.eval('''(function () {
      function t(f) { return typeof globalThis[f] === 'function' ? globalThis[f]() : undefined; }
      device.setName(t('Name') || '');
      device.setSize(t('Size') || [1, 1]);
      if (typeof LedNames === 'function') device.setControllableLeds(LedNames(), typeof LedPositions === 'function' ? LedPositions() : []);
      var params = t('ControllableParameters') || [];
      for (var i = 0; i < params.length; i++) device.addProperty(params[i]);
    })()''');
    stage = 'initialize';
    rt.callIfPresent('Initialize');
    stage = 'render';
    for (var i = 0; i < 3; i++) {
      final colors = List<int>.generate(6000, (k) => (k * 37 + i * 11) % 256);
      rt.eval(
        "__oc.setFrame({m: ${jsonEncode(colors)}, s: new Proxy({}, {get: function () { return ${jsonEncode(colors)}; }}), c: new Proxy({}, {get: function () { return ${jsonEncode(colors)}; }})})",
      );
      rt.callIfPresent('Render');
    }
    stage = 'shutdown';
    rt.callIfPresent('Shutdown', [false]);
    return _result(info, 'ok', null, null);
  } on _TooManyCalls {
    return _result(info, 'waits', stage, 'polls the device for an answer');
  } catch (e) {
    final msg = '$e';
    if (msg.contains('_TooManyCalls')) {
      return _result(info, 'waits', stage, 'polls the device for an answer');
    }
    // A missing host function or global is our gap; anything else comes
    // from the fake device's empty answers.
    final api = RegExp(
      r"(device|bus|mouse|keyboard|systeminfo|__oc)\b.*(is not a function|not defined|undefined)|is not defined|cannot read property '\w+' of undefined",
      caseSensitive: false,
    ).hasMatch(msg);
    return _result(
      info,
      api ? 'api' : 'device',
      stage,
      _only.isEmpty ? msg.split('\n').first : msg,
    );
  } finally {
    rt.dispose();
  }
}

Map<String, Object?> _result(
  PluginInfo info,
  String kind,
  String? stage,
  String? error,
) => {
  'plugin': info.path.split(RegExp(r'[\\/]Plugins[\\/]')).last,
  'type': info.deviceType,
  'kind': kind,
  'stage': ?stage,
  'error': ?error,
};
