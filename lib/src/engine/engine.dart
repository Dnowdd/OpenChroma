import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../effects/effect_library.dart';
import '../hid/hid_ffi.dart';
import '../paths.dart';
import '../plugins/plugin_scanner.dart';
import 'device_worker.dart';

/// Canvas size SignalRGB effects draw on; layout coordinates use this space.
const canvasWidth = 320.0;
const canvasHeight = 200.0;

/// The latest effect frame, downscaled RGB.
class CanvasFrame {
  CanvasFrame(this.width, this.height, this.rgb);
  final int width;
  final int height;
  final Uint8List rgb;
}

/// Placement of a device (or one of its subdevices / channels) on the canvas.
class LayoutItem {
  LayoutItem({required this.x, required this.y, required this.scale});
  double x;
  double y;
  double scale;

  Map<String, Object> toJson() => {'x': x, 'y': y, 'scale': scale};
  static LayoutItem fromJson(Map j) => LayoutItem(
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    scale: (j['scale'] as num).toDouble(),
  );
}

/// Something with LEDs drawn on the canvas: the device itself, a subdevice
/// or an ARGB channel. [positions] are in the zone's own LED grid.
class LedZone {
  LedZone({
    required this.key,
    required this.label,
    required this.width,
    required this.height,
    required this.positions,
    required this.names,
  });
  final String key;
  final String label;
  final int width;
  final int height;
  final List<List<int>> positions;
  final List<String> names;
}

class DeviceInstance {
  DeviceInstance(this.key, this.plugin, this.endpoints);

  final String key;
  PluginInfo plugin;
  final List<HidEndpointInfo> endpoints;
  Isolate? isolate;
  SendPort? port;
  ReceivePort? inbox;
  String status = 'starting';
  String? error;
  Map<String, dynamic> state = {};
  final List<String> logs = [];
  final List<PluginInfo> remainingCandidates = [];

  String get name {
    final n = state['name'] as String? ?? '';
    return n.isNotEmpty ? n : plugin.name;
  }

  String get imageUrl => state['image'] as String? ?? plugin.imageUrl;

  List<Map<String, dynamic>> get properties =>
      ((state['properties'] as List?) ?? []).cast<Map<String, dynamic>>();

  List<String> get channelNames =>
      ((state['channelOrder'] as List?) ?? []).cast<String>();

  Map<String, dynamic> channel(String name) =>
      ((state['channels'] as Map?)?[name] as Map?)?.cast<String, dynamic>() ??
      {};

  static List<List<int>> _positions(Object? v) => [
    for (final e in (v as List? ?? []))
      if (e is List && e.length >= 2)
        [(e[0] as num).toInt(), (e[1] as num).toInt()],
  ];

  /// Every LED zone this device currently exposes.
  List<LedZone> get zones {
    final out = <LedZone>[];
    final size = (state['size'] as List?) ?? plugin.size;
    out.add(
      LedZone(
        key: 'main',
        label: name,
        width: (size[0] as num).toInt().clamp(1, 512),
        height: (size[1] as num).toInt().clamp(1, 512),
        positions: _positions(state['ledPositions']),
        names: ((state['ledNames'] as List?) ?? []).map((e) => '$e').toList(),
      ),
    );
    final subs = (state['subdevices'] as Map?) ?? {};
    subs.forEach((id, v) {
      final s = v as Map;
      final sz = s['size'] as List? ?? [1, 1];
      out.add(
        LedZone(
          key: 'sub:$id',
          label: '${s['name'] ?? id}',
          width: (sz[0] as num).toInt().clamp(1, 512),
          height: (sz[1] as num).toInt().clamp(1, 512),
          positions: _positions(s['ledPositions']),
          names: ((s['ledNames'] as List?) ?? []).map((e) => '$e').toList(),
        ),
      );
    });
    for (final ch in channelNames) {
      final count = (channel(ch)['count'] as num?)?.toInt() ?? 0;
      if (count <= 0) continue;
      out.add(
        LedZone(
          key: 'ch:$ch',
          label: '$name - $ch',
          width: count,
          height: 1,
          positions: [
            for (var i = 0; i < count; i++) [i, 0],
          ],
          names: [for (var i = 0; i < count; i++) '$ch ${i + 1}'],
        ),
      );
    }
    return out;
  }
}

class Engine extends ChangeNotifier {
  Engine();

  final paths = SignalRgbPaths.detect();
  late final String dataDir = openChromaDataDir();
  late final Map<String, Map<String, String>> systemInfo = readSystemInfo();

  List<PluginInfo> plugins = [];
  List<EffectInfo> effects = [];
  final Map<String, DeviceInstance> devices = {};
  EffectInfo? currentEffect;
  CanvasFrame? frame;
  int brightness = 100;
  bool scanning = false;

  /// Running RGB apps that also drive the devices (e.g. SignalRGB); writing
  /// from two programs at once makes the LEDs flicker.
  List<String> conflicts = [];
  bool _shuttingDown = false;

  Map<String, dynamic> _settings = {};
  Timer? _tick;
  Timer? _rescan;
  Timer? _saveDebounce;

  String get _settingsFile => p.join(dataDir, 'settings.json');

  Future<void> start() async {
    _loadSettings();
    brightness = (_settings['brightness'] as int?) ?? 100;
    effects = scanEffects(paths.effectRoots);
    final saved = _settings['effect'] as String?;
    currentEffect =
        effects.where((e) => e.path == saved).firstOrNull ??
        effects.where((e) => e.title == 'Rainbow').firstOrNull ??
        effects.firstOrNull;
    notifyListeners();

    scanning = true;
    notifyListeners();
    plugins = await scanPlugins(
      paths.pluginRoots,
      p.join(dataDir, 'plugin_cache.json'),
    );
    scanning = false;
    notifyListeners();

    await refreshDevices();
    _checkConflicts();
    _rescan = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConflicts();
      refreshDevices();
    });
    _tick = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _pushFrames(),
    );
  }

  // ---------------------------------------------------------------- settings
  void _loadSettings() {
    try {
      _settings = jsonDecode(
        File(_settingsFile).readAsStringSync(),
      ) as Map<String, dynamic>;
    } catch (_) {
      _settings = {};
    }
  }

  void _save() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      try {
        File(_settingsFile).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(_settings),
        );
      } catch (_) {}
    });
  }

  Map<String, dynamic> _deviceSettings(String key) {
    final all =
        (_settings['devices'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    return (all[key] ??= <String, dynamic>{}) as Map<String, dynamic>;
  }

  Map<String, dynamic> effectSettings(EffectInfo e) {
    final all =
        (_settings['effectProps'] ??= <String, dynamic>{})
            as Map<String, dynamic>;
    return (all[e.path] ??= <String, dynamic>{}) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------- effects
  void selectEffect(EffectInfo e) {
    currentEffect = e;
    _effectSince = DateTime.now();
    _settings['effect'] = e.path;
    _save();
    notifyListeners();
  }

  void setEffectProperty(EffectInfo e, String name, Object value) {
    effectSettings(e)[name] = value;
    _save();
    notifyListeners();
  }

  void setBrightness(int v) {
    brightness = v.clamp(0, 100);
    _settings['brightness'] = brightness;
    _save();
    notifyListeners();
  }

  /// Fires on every effect frame (about 30 Hz) without rebuilding listeners
  /// of the engine itself.
  final frameNotifier = ValueNotifier<CanvasFrame?>(null);

  void onFrame(CanvasFrame f) {
    frame = f;
    frameNotifier.value = f;
    _maybeCaptureThumbnail(f);
  }

  // ------------------------------------------------------------ thumbnails
  // Effects without a preview image get one captured from their own canvas
  // after they have been running for a moment.
  late final String _thumbDir = p.join(dataDir, 'thumbs');
  late final Set<String> _capturedThumbs = {
    if (Directory(_thumbDir).existsSync())
      for (final f in Directory(_thumbDir).listSync().whereType<File>()) f.path,
  };
  DateTime _effectSince = DateTime.now();
  bool _capturing = false;

  String _thumbPath(EffectInfo e) {
    var h = 0x811c9dc5; // FNV-1a, stable across runs
    for (final c in e.path.toLowerCase().codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return p.join(_thumbDir, '${h.toRadixString(16)}.png');
  }

  /// The effect's own preview image, or one captured from it, if any.
  String? thumbnailFor(EffectInfo e) {
    if (e.thumbnail != null) return e.thumbnail;
    final t = _thumbPath(e);
    return _capturedThumbs.contains(t) ? t : null;
  }

  void _maybeCaptureThumbnail(CanvasFrame f) {
    final e = currentEffect;
    if (e == null || _capturing || thumbnailFor(e) != null) return;
    if (DateTime.now().difference(_effectSince) < const Duration(seconds: 3)) {
      return;
    }
    // Skip near-black frames (e.g. audio effects with no sound playing).
    var sum = 0;
    for (var i = 0; i < f.rgb.length; i += 9) {
      sum += f.rgb[i];
    }
    if (sum / (f.rgb.length / 9) < 6) return;
    _capturing = true;
    final rgba = Uint8List(f.width * f.height * 4);
    for (var i = 0, j = 0; i < f.rgb.length; i += 3, j += 4) {
      rgba[j] = f.rgb[i];
      rgba[j + 1] = f.rgb[i + 1];
      rgba[j + 2] = f.rgb[i + 2];
      rgba[j + 3] = 255;
    }
    ui.decodeImageFromPixels(rgba, f.width, f.height, ui.PixelFormat.rgba8888, (
      img,
    ) async {
      try {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        if (png != null) {
          final path = _thumbPath(e);
          Directory(_thumbDir).createSync(recursive: true);
          File(path).writeAsBytesSync(png.buffer.asUint8List());
          _capturedThumbs.add(path);
          notifyListeners();
        }
      } catch (_) {
      } finally {
        img.dispose();
        _capturing = false;
      }
    });
  }

  // ---------------------------------------------------------------- devices
  Future<void> refreshDevices() async {
    if (_shuttingDown || plugins.isEmpty) return;
    final groups = <String, List<HidEndpointInfo>>{};
    for (final e in hidEnumerate()) {
      final key =
          '${_hex(e.vendorId)}:${_hex(e.productId)}:${e.serial.isEmpty ? '-' : e.serial}';
      (groups[key] ??= []).add(e);
    }
    // Unplugged devices.
    for (final key in devices.keys.toList()) {
      if (!groups.containsKey(key)) {
        _stopDevice(devices.remove(key)!);
      }
    }
    for (final entry in groups.entries) {
      if (devices.containsKey(entry.key)) continue;
      final first = entry.value.first;
      final candidates = plugins
          .where(
            (pl) =>
                pl.error == null && pl.matches(first.vendorId, first.productId),
          )
          .toList();
      if (candidates.isEmpty) continue;
      if (_deviceSettings(entry.key)['disabled'] == true) {
        final d = DeviceInstance(entry.key, candidates.first, entry.value)
          ..status = 'disabled';
        devices[entry.key] = d;
        continue;
      }
      final d = DeviceInstance(entry.key, candidates.first, entry.value)
        ..remainingCandidates.addAll(candidates.skip(1));
      devices[entry.key] = d;
      await _spawn(d);
    }
    notifyListeners();
  }

  static const _conflictingProcesses = {
    'signalrgb.exe': 'SignalRGB',
    'icue.exe': 'Corsair iCUE',
    'lghub.exe': 'Logitech G HUB',
    'rgbfusion.exe': 'Gigabyte RGB Fusion',
    'openrgb.exe': 'OpenRGB',
  };

  Future<void> _checkConflicts() async {
    try {
      final r = await Process.run('tasklist', ['/fo', 'csv', '/nh']);
      final running = <String>{
        for (final line in (r.stdout as String).split('\n'))
          if (line.startsWith('"'))
            line.substring(1, line.indexOf('"', 1)).toLowerCase(),
      };
      final found = [
        for (final e in _conflictingProcesses.entries)
          if (running.contains(e.key)) e.value,
      ];
      if (found.join() != conflicts.join()) {
        conflicts = found;
        notifyListeners();
      }
    } catch (_) {}
  }

  static String _hex(int v) => v.toRadixString(16).padLeft(4, '0');

  Future<void> _spawn(DeviceInstance d) async {
    final ds = _deviceSettings(d.key);
    final inbox = ReceivePort();
    d.inbox = inbox;
    d.status = 'starting';
    d.error = null;
    inbox.listen((msg) => _onWorkerMessage(d, msg as Map));
    d.isolate = await Isolate.spawn(
      deviceWorkerMain,
      DeviceWorkerArgs(
        sendPort: inbox.sendPort,
        pluginPath: d.plugin.path,
        endpoints: d.endpoints.map((e) => e.toJson()).toList(),
        userProps: ((ds['props'] as Map?) ?? {}).cast<String, Object?>(),
        channelCounts: ((ds['channels'] as Map?) ?? {}).cast<String, int>(),
        systemInfo: systemInfo,
      ),
      debugName: 'device ${d.key}',
    );
  }

  void _onWorkerMessage(DeviceInstance d, Map m) {
    switch (m['t']) {
      case 'port':
        d.port = m['port'] as SendPort;
      case 'log':
        d.logs.add(m['msg'] as String);
        if (kDebugMode) debugPrint('[${d.plugin.name}] ${m['msg']}');
        if (d.logs.length > 300) d.logs.removeRange(0, d.logs.length - 300);
      case 'state':
        d.state = jsonDecode(m['state'] as String) as Map<String, dynamic>;
        _ensureLayout(d);
        notifyListeners();
      case 'ready':
        d.status = 'running';
        notifyListeners();
      case 'rejected':
        d.inbox?.close();
        if (d.remainingCandidates.isNotEmpty) {
          d.plugin = d.remainingCandidates.removeAt(0);
          _spawn(d);
        } else {
          d.status = 'unsupported';
          notifyListeners();
        }
      case 'error':
        d.status = 'error';
        d.error = m['msg'] as String;
        d.logs.add('ERROR: ${d.error}');
        if (kDebugMode) debugPrint('[${d.plugin.name}] ERROR ${d.error}');
        notifyListeners();
      case 'user_prop':
        final props =
            (_deviceSettings(d.key)['props'] ??= <String, dynamic>{}) as Map;
        props[m['name']] = m['value'];
        _save();
      case 'stopped':
        d.inbox?.close();
        d.port = null;
        if (d.status == 'running' || d.status == 'starting') {
          d.status = 'stopped';
        }
        notifyListeners();
    }
  }

  void _stopDevice(DeviceInstance d) {
    d.port?.send({'t': 'stop'});
  }

  void setDeviceProperty(DeviceInstance d, String name, Object? value) {
    final props =
        (_deviceSettings(d.key)['props'] ??= <String, dynamic>{}) as Map;
    props[name] = value;
    _save();
    d.port?.send({'t': 'prop', 'name': name, 'value': value});
  }

  void setChannelLedCount(DeviceInstance d, String channel, int count) {
    final ch = d.channel(channel);
    final limit = (ch['limit'] as num?)?.toInt() ?? 0;
    final c = limit > 0 ? count.clamp(0, limit) : count.clamp(0, 1000);
    final counts =
        (_deviceSettings(d.key)['channels'] ??= <String, dynamic>{}) as Map;
    counts[channel] = c;
    _save();
    d.port?.send({
      't': 'channels',
      'counts': {channel: c},
    });
  }

  int channelLedCount(DeviceInstance d, String channel) =>
      (((_deviceSettings(d.key)['channels'] as Map?) ?? {})[channel] as int?) ??
      0;

  Future<void> setDeviceEnabled(DeviceInstance d, bool enabled) async {
    _deviceSettings(d.key)['disabled'] = !enabled;
    _save();
    if (enabled && d.status == 'disabled') {
      await _spawn(d);
    } else if (!enabled) {
      _stopDevice(d);
      d.status = 'disabled';
    }
    notifyListeners();
  }

  Future<void> restartDevice(DeviceInstance d) async {
    _stopDevice(d);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    d.state = {};
    d.logs.clear();
    await _spawn(d);
    notifyListeners();
  }

  // ---------------------------------------------------------------- layout
  LayoutItem layoutOf(DeviceInstance d, String zoneKey) {
    final layout =
        (_deviceSettings(d.key)['layout'] ??= <String, dynamic>{}) as Map;
    final j = layout[zoneKey];
    if (j is Map) return LayoutItem.fromJson(j);
    return _defaultLayout(d, zoneKey);
  }

  void setLayout(DeviceInstance d, String zoneKey, LayoutItem item) {
    final layout =
        (_deviceSettings(d.key)['layout'] ??= <String, dynamic>{}) as Map;
    item.x = item.x.clamp(-canvasWidth, canvasWidth * 2);
    item.y = item.y.clamp(-canvasHeight, canvasHeight * 2);
    item.scale = item.scale.clamp(0.5, 60);
    layout[zoneKey] = item.toJson();
    _save();
    notifyListeners();
  }

  LayoutItem _defaultLayout(DeviceInstance d, String zoneKey) {
    final zone = d.zones.where((z) => z.key == zoneKey).firstOrNull;
    final w = zone?.width ?? 1, h = zone?.height ?? 1;
    if (zoneKey == 'main') {
      var scale = d.plugin.defaultScale > 0 ? d.plugin.defaultScale : 8.0;
      // Fit large devices on the canvas.
      final fit = [
        canvasWidth / w,
        canvasHeight / h,
      ].reduce((a, b) => a < b ? a : b);
      if (scale > fit) scale = fit;
      // Tiny single-zone devices (1x1 at scale 1) would be an invisible dot.
      final longest = w > h ? w : h;
      if (longest * scale < 24) scale = 24 / longest;
      var x = d.plugin.defaultPosition[0], y = d.plugin.defaultPosition[1];
      if (x + w * scale > canvasWidth || y + h * scale > canvasHeight) {
        x = (canvasWidth - w * scale) / 2;
        y = (canvasHeight - h * scale) / 2;
      }
      return LayoutItem(x: x, y: y, scale: scale);
    }
    // Extra zones go in a grid of 24px-tall cells along the left edge, so
    // none overlap; channels (one row of LEDs) span most of the width.
    final idx = d.zones.indexWhere((z) => z.key == zoneKey).clamp(1, 64) - 1;
    final scale = [24 / h, 280 / w, 10.0].reduce((a, b) => a < b ? a : b);
    const rows = 7;
    return LayoutItem(
      x: 8 + (idx ~/ rows) * (w * scale + 8),
      y: 8 + (idx % rows) * 27.0,
      scale: scale,
    );
  }

  void _ensureLayout(DeviceInstance d) {
    final layout =
        (_deviceSettings(d.key)['layout'] ??= <String, dynamic>{}) as Map;
    var changed = false;
    for (final z in d.zones) {
      if (!layout.containsKey(z.key)) {
        layout[z.key] = _defaultLayout(d, z.key).toJson();
        changed = true;
      }
    }
    if (changed) _save();
  }

  // ---------------------------------------------------------------- frames
  /// Samples the canvas for every LED cell of [zone] placed at [item].
  List<int> _sampleZone(LedZone zone, LayoutItem item, CanvasFrame f) {
    final out = List<int>.filled(zone.width * zone.height * 3, 0);
    final sx = f.width / canvasWidth, sy = f.height / canvasHeight;
    final b = brightness / 100.0;
    // Average the frame pixels covered by the LED's cell (at most 4x4
    // samples) so a LED reflects its area, not one noisy pixel.
    void cell(int x, int y) {
      final i = (y * zone.width + x) * 3;
      if (i + 2 >= out.length) return;
      final x0 = (item.x + x * item.scale) * sx,
          y0 = (item.y + y * item.scale) * sy;
      final cw = item.scale * sx, ch = item.scale * sy;
      final nx = cw.ceil().clamp(1, 4), ny = ch.ceil().clamp(1, 4);
      var r = 0, g = 0, bl = 0, n = 0;
      for (var j = 0; j < ny; j++) {
        final py = (y0 + (j + 0.5) * ch / ny).floor();
        if (py < 0 || py >= f.height) continue;
        for (var k = 0; k < nx; k++) {
          final px = (x0 + (k + 0.5) * cw / nx).floor();
          if (px < 0 || px >= f.width) continue;
          final src = (py * f.width + px) * 3;
          r += f.rgb[src];
          g += f.rgb[src + 1];
          bl += f.rgb[src + 2];
          n++;
        }
      }
      if (n == 0) return;
      out[i] = (r / n * b).round();
      out[i + 1] = (g / n * b).round();
      out[i + 2] = (bl / n * b).round();
    }

    if (zone.width * zone.height <= 4096 || zone.positions.isEmpty) {
      for (var y = 0; y < zone.height; y++) {
        for (var x = 0; x < zone.width; x++) {
          cell(x, y);
        }
      }
    } else {
      for (final pos in zone.positions) {
        cell(pos[0], pos[1]);
      }
    }
    return out;
  }

  void _pushFrames() {
    final f = frame;
    if (f == null) return;
    for (final d in devices.values) {
      final port = d.port;
      if (port == null || d.status != 'running') continue;
      final payload = <String, Object>{
        'm': <int>[],
        's': <String, Object>{},
        'c': <String, Object>{},
      };
      for (final z in d.zones) {
        final colors = _sampleZone(z, layoutOf(d, z.key), f);
        if (z.key == 'main') {
          payload['m'] = colors;
        } else if (z.key.startsWith('sub:')) {
          (payload['s'] as Map)[z.key.substring(4)] = colors;
        } else if (z.key.startsWith('ch:')) {
          (payload['c'] as Map)[z.key.substring(3)] = colors;
        }
      }
      port.send({'t': 'frame', 'frame': payload, 'brightness': brightness});
    }
  }

  /// Stops every worker so plugins can run Shutdown() (their shutdown color).
  Future<void> shutdown() async {
    _shuttingDown = true;
    _tick?.cancel();
    _rescan?.cancel();
    _saveDebounce?.cancel();
    try {
      File(_settingsFile).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_settings),
      );
    } catch (_) {}
    final running = devices.values.where((d) => d.port != null).toList();
    for (final d in running) {
      _stopDevice(d);
    }
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (running.any((d) => d.port != null) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
