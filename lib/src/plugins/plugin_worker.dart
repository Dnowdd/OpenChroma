import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:image/image.dart' as img;

import '../hid/hid_ffi.dart';
import '../hid/serial_ffi.dart';
import '../i18n/l10n.dart';
import 'js_runtime.dart';
import 'thread_priority.dart';

/// Arguments for [pluginWorkerMain].
class PluginWorkerArgs {
  PluginWorkerArgs({
    required this.sendPort,
    required this.pluginName,
    required this.pluginSource,
    required this.allowedModels,
    required this.endpoints,
    required this.settings,
    required this.deviceName,
    this.serialBaud,
    this.language = 'en',
  });

  final SendPort sendPort;
  final String pluginName;

  /// What runs: the text the user approved, not a fresh read of the file.
  final String pluginSource;

  /// VID<<16|PID of the models the plugin declares; it can open no others.
  final Set<int> allowedModels;
  final List<Map<String, Object>> endpoints;
  final Map<String, Object?> settings;
  final String deviceName;

  /// Set for plugins that talk to a serial port instead of HID.
  final int? serialBaud;

  final String language;
}

/// Runs one plugin for one physical device, in its own isolate.
///
/// To the app: `port`, `layout` {zones, modes}, `battery`, `log`, `error`,
/// `rejected`, `stopped`, `thread` and `beat` (the watchdog's pulse). From the app: `frame` (RGB bytes per LED),
/// `mode` (hardware mode id, or null for the app's colors, and its
/// options), `setting`, `screen` (frames and delays for the device's
/// screen), `stop`. Screen uploads answer with `progress` and `screenDone`.
Future<void> pluginWorkerMain(PluginWorkerArgs args) async {
  l10n = lookupAppLocalizations(Locale(args.language));
  final inbox = ReceivePort();
  final out = args.sendPort;
  out.send({'t': 'port', 'port': inbox.sendPort});
  out.send({'t': 'thread', 'id': currentThreadId()});

  final endpoints =
      [for (final e in args.endpoints) HidEndpointInfo.fromJson(e)]
          .where(
            (e) => args.allowedModels.contains(e.vendorId << 16 | e.productId),
          )
          .toList();
  final pulse = Stopwatch()..start();
  void beat() {
    if (pulse.elapsedMilliseconds < 250) return;
    pulse.reset();
    out.send({'t': 'beat'});
  }

  final handles = <String, HidHandle>{};
  HidEndpointInfo? current;

  // The image waiting for the screen, and the frames of the one being sent
  // (RGB bytes, row by row).
  Map? pendingScreen;
  List<Uint8List> screenFrames = const [];
  var screenWidth = 0, screenHeight = 0;
  List<Uint8List> widgetGlyphs = const [];
  List? pendingValues;
  SerialHandle? serial;

  void log(String msg) => out.send({'t': 'log', 'msg': msg});

  SerialHandle port() {
    final ep = current ?? (throw PluginError(l10n.pluginsNoPort));
    return serial ??=
        SerialHandle.open(ep.path, args.serialBaud!) ??
        (throw PluginError(l10n.pluginsCannotOpen(ep.path)));
  }

  HidHandle handle() {
    final ep = current ?? (throw PluginError(l10n.pluginsNoInterface));
    return handles[ep.path] ??=
        HidHandle.open(ep) ??
        (throw PluginError(l10n.pluginsCannotOpen(ep.path)));
  }

  Object? host(String method, List<dynamic> a) {
    beat();
    int n(Object? v) => v is num ? v.toInt() : 0;
    List<int> bytes(Object? v) => v is List ? v.map(n).toList() : <int>[];
    switch (method) {
      case 'write':
        if (args.serialBaud == null) return handle().write(bytes(a[0]));
        final data = bytes(a[0]);
        final written = port().write(data);
        if (written >= 0) return written;
        // A device that restarts (a cooler applying a new theme) leaves the
        // open handle dead; a fresh one works again.
        serial?.close();
        serial = null;
        return port().write(data);
      case 'read':
        return (args.serialBaud != null
                ? port().read(n(a[0]), n(a[1]))
                : handle().read(n(a[0]), n(a[1])))
            .toList();
      case 'sendFeature':
        return handle().sendFeature(bytes(a[0]));
      case 'getFeature':
        return handle().getFeature([n(a[0])], n(a[1])).toList();
      case 'getInputReport':
        return handle().getInputReport([n(a[0])], n(a[1])).toList();
      case 'clearInput':
        args.serialBaud != null
            ? port().clearReadBuffer()
            : handle().clearReadBuffer();
        return null;
      case 'endpoints':
        return [for (final e in endpoints) e.toPluginEndpoint()];
      case 'useEndpoint':
        final m = (a[0] as Map?) ?? {};
        for (final e in endpoints) {
          final pe = e.toPluginEndpoint();
          if (m.entries.every((kv) => pe[kv.key] == kv.value)) {
            current = e;
            return true;
          }
        }
        return false;
      case 'sleep':
        final ms = n(a[0]).clamp(0, 5000);
        if (ms > 0) sleep(Duration(milliseconds: ms));
        pulse.reset();
        out.send({'t': 'beat'});
        return null;
      case 'log':
        log('${a[0]}');
        return null;
      case 'frame':
        final i = n(a[0]);
        return i >= 0 && i < screenFrames.length
            ? screenFrames[i].toList()
            : <int>[];
      case 'jpeg':
        final i = n(a[0]);
        if (i < 0 || i >= screenFrames.length) return <int>[];
        final frame = img.Image.fromBytes(
          width: screenWidth,
          height: screenHeight,
          bytes: screenFrames[i].buffer,
          numChannels: 3,
        );
        return img.encodeJpg(
          frame,
          quality: n(a[1]).clamp(10, 100),
          chroma: img.JpegChroma.yuv420,
        );
      case 'widgetGlyphs':
        final i = n(a[0]);
        return i >= 0 && i < widgetGlyphs.length
            ? widgetGlyphs[i]
            : Uint8List(0);
      case 'localTime':
        final t = DateTime.now();
        return [t.year, t.month, t.day, t.hour, t.minute, t.second];
      case 'progress':
        out.send({'t': 'progress', 'value': (a[0] as num).toDouble()});
        return null;
      case 'battery':
        out.send({
          't': 'battery',
          'level': a[0] == null ? null : n(a[0]),
          'charging': a[1] == true,
        });
        return null;
    }
    return null;
  }

  final rt = JsRuntime(host);
  var running = true;
  Uint8List? pendingFrame;
  // A mode id is whatever the plugin declared (a number or a string).
  Object? hardwareMode;
  Object? modeOptions;
  var modeChanged = false;
  final pendingSettings = <MapEntry<String, Object?>>[];
  Completer<void>? wake;

  inbox.listen((msg) {
    if (msg is! Map) return;
    final m = msg;
    switch (m['t']) {
      case 'frame':
        pendingFrame = m['rgb'] as Uint8List;
      case 'mode':
        hardwareMode = m['id'];
        modeOptions = m['options'];
        modeChanged = true;
      case 'setting':
        pendingSettings.add(MapEntry(m['name'] as String, m['value']));
      case 'screen':
        pendingScreen = m;
      case 'values':
        pendingValues = m['values'] as List;
      case 'stop':
        running = false;
        if (wake?.isCompleted == false) wake!.complete();
    }
  });

  try {
    if (endpoints.isEmpty) {
      out.send({'t': 'rejected'});
      return;
    }
    rt.eval(args.pluginSource, name: args.pluginName);
    final first = endpoints.first;
    rt.eval(
      '__oc.setInfo(${jsonEncode({'vid': first.vendorId, 'pid': first.productId, 'serial': first.serial, 'product': first.product, 'manufacturer': first.manufacturer, 'name': args.deviceName})})',
    );
    rt.eval('__oc.setSettings(${jsonEncode(args.settings)})');
    final pick = rt.evalJson(
      '__oc.pickEndpoint(${jsonEncode([for (final e in endpoints) e.toPluginEndpoint()])})',
    );
    final index = pick is num ? pick.toInt() : -1;
    if (index < 0 || index >= endpoints.length) {
      out.send({'t': 'rejected'});
      return;
    }
    current = endpoints[index];
    if (rt.eval('__oc.start()') != true) {
      out.send({'t': 'rejected'});
      return;
    }
    out.send({'t': 'layout', 'layout': rt.eval('__oc.layout()')});

    final fps = ((rt.eval('__oc.fps()') as num?) ?? 30).clamp(1, 60).toInt();
    final pollMs = ((rt.eval('__oc.pollMs()') as num?) ?? 1000).toInt();
    final clock = Stopwatch()..start();
    var lastPoll = -pollMs;
    // A callback that throws is logged (a few times) and the plugin keeps
    // running; one bad frame should not leave the device frozen.
    var failures = 0;
    void safe(String code) {
      try {
        rt.eval(code);
      } on PluginError catch (e) {
        if (failures++ < 5) log('error: $e');
      }
    }

    while (running) {
      beat();
      final frameStart = clock.elapsedMilliseconds;
      // Let queued messages (frames, settings, stop) arrive.
      await Future<void>.delayed(Duration.zero);
      if (!running) break;
      for (final s in pendingSettings) {
        safe('__oc.setSetting(${jsonEncode(s.key)}, ${jsonEncode(s.value)})');
      }
      pendingSettings.clear();
      final image = pendingScreen;
      if (image != null) {
        pendingScreen = null;
        screenFrames = (image['frames'] as List).cast<Uint8List>();
        screenWidth = image['width'] as int;
        screenHeight = image['height'] as int;
        widgetGlyphs = ((image['widgetGlyphs'] as List?) ?? const [])
            .cast<Uint8List>();
        var ok = false;
        try {
          ok =
              rt.eval(
                '__oc.screen(${jsonEncode({'width': image['width'], 'height': image['height'], 'frames': screenFrames.length, 'delays': image['delays'], 'widgets': image['widgets'] ?? const []})})',
              ) ==
              true;
        } on PluginError catch (e) {
          log('screen: $e');
        }
        screenFrames = const [];
        widgetGlyphs = const [];
        out.send({'t': 'screenDone', 'ok': ok});
        // A long upload: frames and settings queued meanwhile go on below.
      }
      final values = pendingValues;
      if (values != null) {
        pendingValues = null;
        safe('__oc.values(${jsonEncode(values)})');
      }
      if (modeChanged) {
        modeChanged = false;
        safe(
          '__oc.mode(${jsonEncode(hardwareMode)}, ${jsonEncode(modeOptions)})',
        );
      }
      final f = pendingFrame;
      if (f != null && hardwareMode == null) {
        pendingFrame = null;
        safe('__oc.render(${jsonEncode(f)})');
      }
      if (clock.elapsedMilliseconds - lastPoll >= pollMs) {
        lastPoll = clock.elapsedMilliseconds;
        safe('__oc.poll()');
      }
      final wait = 1000 ~/ fps - (clock.elapsedMilliseconds - frameStart);
      final tick = wake = Completer<void>();
      final timer = Timer(
        Duration(milliseconds: wait > 1 ? wait : 1),
        () => tick.isCompleted ? null : tick.complete(),
      );
      await tick.future;
      timer.cancel();
    }
    try {
      rt.eval('__oc.stop()');
    } catch (e) {
      log('stop: $e');
    }
  } catch (e) {
    out.send({'t': 'error', 'msg': '$e'});
  } finally {
    for (final h in handles.values) {
      h.close();
    }
    rt.dispose();
    inbox.close();
    out.send({'t': 'stopped'});
  }
}
