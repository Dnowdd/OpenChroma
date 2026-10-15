import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../hid/hid_ffi.dart';
import '../plugins/js_transform.dart';
import '../plugins/plugin_runtime.dart';

/// Arguments for [deviceWorkerMain].
class DeviceWorkerArgs {
  DeviceWorkerArgs({
    required this.sendPort,
    required this.pluginPath,
    required this.endpoints,
    required this.userProps,
    required this.channelCounts,
    required this.systemInfo,
  });

  final SendPort sendPort;
  final String pluginPath;
  final List<Map<String, Object>> endpoints;
  final Map<String, Object?> userProps;
  final Map<String, int> channelCounts;
  final Map<String, Map<String, String>> systemInfo;
}

/// Isolate entry point that runs one plugin instance against one physical
/// device. Messages to the host are maps with a `t` (type) key:
/// `log`, `state`, `rejected`, `ready`, `error`, `stopped`.
Future<void> deviceWorkerMain(DeviceWorkerArgs args) async {
  final inbox = ReceivePort();
  final out = args.sendPort;
  out.send({'t': 'port', 'port': inbox.sendPort});

  final endpoints = args.endpoints
      .map((e) => HidEndpointInfo.fromJson(e))
      .toList();
  final handles = <String, HidHandle>{};
  HidEndpointInfo? current;
  var lastReadSize = 0;
  var brightness = 100;

  void log(String msg) => out.send({'t': 'log', 'msg': msg});

  HidHandle? handle() {
    final ep = current;
    if (ep == null) return null;
    return handles[ep.path] ??=
        HidHandle.open(ep) ??
        (throw PluginError('Could not open HID endpoint ${ep.path}'));
  }

  HidEndpointInfo? findEndpoint(int iface, int usage, int usagePage, int col) {
    bool base(HidEndpointInfo e) =>
        e.interface == iface &&
        (usage < 0 || e.usage == usage) &&
        (usagePage < 0 || e.usagePage == usagePage);
    // Collection numbering is not confirmed against SignalRGB; prefer an exact
    // match and fall back to ignoring it.
    for (final e in endpoints) {
      if (base(e) && (col < 0 || e.collection == col)) return e;
    }
    for (final e in endpoints) {
      if (base(e)) return e;
    }
    return null;
  }

  Object? host(String method, List<dynamic> a) {
    // JS arrays may be sparse (holes arrive as null) and numbers may be strings.
    int n(Object? v) => v is num
        ? v.toInt()
        : (v is String ? (num.tryParse(v)?.toInt() ?? 0) : (v == true ? 1 : 0));
    List<int> bytes(Object? v) => v is List ? v.map(n).toList() : <int>[];
    switch (method) {
      case 'log':
        log(a[0].toString());
        return null;
      case 'pause':
        final ms = n(a[0]);
        if (ms > 0) sleep(Duration(milliseconds: ms));
        return null;
      case 'write':
        final data = bytes(a[0]);
        final len = n(a[1]);
        final h = handle();
        if (h == null) return -1;
        final buf = List<int>.filled(len > data.length ? len : data.length, 0)
          ..setRange(0, data.length, data);
        return h.write(buf);
      case 'send_report':
        final data = bytes(a[0]);
        final len = n(a[1]);
        final h = handle();
        if (h == null) return -1;
        final buf = List<int>.filled(len > data.length ? len : data.length, 0)
          ..setRange(0, data.length, data);
        return h.sendFeature(buf);
      case 'get_report':
        final r = handle()?.getFeature(bytes(a[0]), n(a[1])) ?? Uint8List(0);
        lastReadSize = r.length;
        return r.toList();
      case 'input_report':
        final r =
            handle()?.getInputReport(bytes(a[0]), n(a[1])) ?? Uint8List(0);
        lastReadSize = r.length;
        return r.toList();
      case 'read':
        final len = n(a[1]);
        final r = handle()?.read(len, n(a[2])) ?? Uint8List(0);
        lastReadSize = r.length;
        if (r.isEmpty) return List<int>.filled(len, 0);
        final res = List<int>.filled(len > r.length ? len : r.length, 0)
          ..setRange(0, r.length, r);
        return res;
      case 'last_read_size':
        return lastReadSize;
      case 'clear_read':
        handle()?.clearReadBuffer();
        return null;
      case 'set_endpoint':
        final ep = findEndpoint(n(a[0]), n(a[1]), n(a[2]), n(a[3]));
        if (ep == null) {
          log('set_endpoint: no endpoint matching ${a.join(', ')}');
          return false;
        }
        current = ep;
        return true;
      case 'endpoints':
        return endpoints.map((e) => e.toPluginEndpoint()).toList();
      case 'hid_info':
        final ep = current;
        return {
          'writeLength': ep?.outputLength ?? 0,
          'readLength': ep?.inputLength ?? 0,
          'featureLength': ep?.featureLength ?? 0,
        };
      case 'pid':
        return endpoints.first.productId;
      case 'vid':
        return endpoints.first.vendorId;
      case 'device_info':
        return {
          'vendorId': endpoints.first.vendorId,
          'productId': endpoints.first.productId,
          'serial': endpoints.first.serial,
          'product': endpoints.first.product,
          'manufacturer': endpoints.first.manufacturer,
        };
      case 'brightness':
        return brightness;
      case 'sysinfo':
        return args.systemInfo[a[0]] ?? {};
      case 'user_prop':
        out.send({'t': 'user_prop', 'name': a[0], 'value': a[1]});
        return null;
    }
    return null;
  }

  final rt = PluginRuntime(host);
  var running = true;
  Map<String, dynamic>? pendingFrame;
  final pendingProps = <MapEntry<String, Object?>>[];
  Map<String, int>? pendingCounts;
  final stop = Completer<void>();

  inbox.listen((msg) {
    final m = msg as Map;
    switch (m['t']) {
      case 'frame':
        pendingFrame = (m['frame'] as Map).cast<String, dynamic>();
        brightness = m['brightness'] as int? ?? brightness;
      case 'prop':
        pendingProps.add(MapEntry(m['name'] as String, m['value']));
      case 'channels':
        pendingCounts = (m['counts'] as Map).cast<String, int>();
      case 'stop':
        running = false;
        if (!stop.isCompleted) stop.complete();
    }
  });

  void sendState() {
    final s = rt.eval('__oc.takeState()');
    if (s is String) out.send({'t': 'state', 'state': s});
  }

  try {
    rt.eval(
      transformPlugin(args.pluginPath),
      name: p.basename(args.pluginPath),
    );
    rt.eval('__oc.setUserProps(${jsonEncode(args.userProps)})');

    // Validate against every endpoint, as SignalRGB does on enumeration.
    HidEndpointInfo? chosen;
    final hasValidate = rt.hasFunction('Validate');
    for (final e in endpoints) {
      if (!hasValidate || rt.call('Validate', [e.toPluginEndpoint()]) == true) {
        chosen = e;
        break;
      }
    }
    if (chosen == null) {
      out.send({'t': 'rejected'});
      rt.dispose();
      inbox.close();
      return;
    }
    current = chosen;

    // Base device description from the plugin's exports.
    rt.eval('''(function () {
      function t(f) { return typeof globalThis[f] === 'function' ? globalThis[f]() : undefined; }
      var size = t('Size') || [1, 1];
      device.setName(t('Name') || '');
      device.setSize(size);
      if (typeof LedNames === 'function') device.setControllableLeds(LedNames(), typeof LedPositions === 'function' ? LedPositions() : []);
      var img = t('ImageUrl'); if (img) device.setImageFromUrl(img);
      var params = t('ControllableParameters') || [];
      for (var i = 0; i < params.length; i++) device.addProperty(params[i]);
    })()''');
    if (args.channelCounts.isNotEmpty) {
      pendingCounts = args.channelCounts;
    }

    rt.callIfPresent('Initialize');
    if (pendingCounts != null) {
      rt.eval('__oc.setChannelCounts(${jsonEncode(pendingCounts)})');
      pendingCounts = null;
    }
    sendState();
    out.send({'t': 'ready', 'endpoint': chosen.toPluginEndpoint()});

    final sw = Stopwatch();
    while (running) {
      sw
        ..reset()
        ..start();
      // Let queued messages (frames, property edits, stop) be delivered.
      await Future<void>.delayed(Duration.zero);
      if (!running) break;
      for (final e in pendingProps) {
        rt.eval('''(function (n, v) {
          var p = device.getProperty(n);
          globalThis[n] = p ? __oc.coerce(p, v) : v;
          __oc.touch();
          if (typeof globalThis['on' + n + 'Changed'] === 'function') globalThis['on' + n + 'Changed']();
        })(${jsonEncode(e.key)}, ${jsonEncode(e.value)})''');
      }
      pendingProps.clear();
      if (pendingCounts != null) {
        rt.eval('__oc.setChannelCounts(${jsonEncode(pendingCounts)})');
        pendingCounts = null;
      }
      final f = pendingFrame;
      if (f != null) {
        rt.eval('__oc.setFrame(${jsonEncode(f)})');
        pendingFrame = null;
      }
      rt.callIfPresent('Render');
      sendState();
      final fps = (rt.eval('__oc.fps()') as num?)?.toInt() ?? 30;
      final budget = 1000 ~/ fps.clamp(1, 120);
      final wait = budget - sw.elapsedMilliseconds;
      await Future.any([
        Future<void>.delayed(Duration(milliseconds: wait > 1 ? wait : 1)),
        stop.future,
      ]);
    }
    try {
      rt.callIfPresent('Shutdown', [false]);
    } catch (e) {
      log('Shutdown failed: $e');
    }
  } catch (e) {
    out.send({'t': 'error', 'msg': e.toString()});
  } finally {
    for (final h in handles.values) {
      h.close();
    }
    rt.dispose();
    inbox.close();
    out.send({'t': 'stopped'});
  }
}
