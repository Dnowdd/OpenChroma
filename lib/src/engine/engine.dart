import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../audio/audio_service.dart';
import '../effects/effect_library.dart';
import '../effects/ocfx_runtime.dart';
import '../drivers/native_drivers.dart';
import '../hid/hid_ffi.dart';
import '../plugins/plugin_library.dart';
import '../plugins/plugin_worker.dart';
import '../paths.dart';

/// Canvas size effects draw on; layout coordinates use this space.
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

/// One group of LEDs placed on the canvas as a unit (a keyboard's key
/// matrix, a fan header, a strip). [positions] are cells of the zone's own
/// [width] x [height] grid; [leds] holds, for each position, the device LED
/// it lights.
class LedZone {
  LedZone({
    required this.key,
    required this.label,
    required this.width,
    required this.height,
    required this.positions,
    required this.leds,
  });
  final String key;
  final String label;
  final int width;
  final int height;
  final List<List<int>> positions;
  final List<int> leds;
}

/// Where a device's driver lives.
enum DeviceSource {
  /// The built-in drivers (oc_drivers.dll).
  native,

  /// An OpenChroma JavaScript plugin.
  plugin,
}

/// A device the drivers or a plugin found.
class DeviceInstance {
  DeviceInstance(
    this.key,
    this.device, {
    this.source = DeviceSource.native,
    this.plugin,
  });

  final String key;
  DriverDevice device;
  final DeviceSource source;

  /// The plugin driving it, for [DeviceSource.plugin].
  final PluginInfo? plugin;

  /// starting, running, disabled, error, unsupported or stopped.
  String status = 'running';
  String? error;
  final List<String> logs = [];

  /// The device's own lighting effects, as (id, name).
  List<(Object?, String)> modes = [];

  /// The hardware effect running instead of the app's colors, if any.
  String? activeMode;

  /// Charge of a wireless device (0-100) and whether it is charging.
  int? battery;
  bool charging = false;

  /// Plugin isolate link.
  SendPort? port;
  ReceivePort? inbox;

  /// Last colors sent and when, to skip identical frames.
  Uint8List? lastSent;
  DateTime lastSentAt = DateTime(0);

  String get name => device.name;
  String get type => device.type;

  /// Zones the user sizes (ARGB headers), with their index on the device.
  List<(int, DriverZone)> get resizableZones => [
    for (var i = 0; i < device.zones.length; i++)
      if (device.zones[i].resizable) (i, device.zones[i]),
  ];

  late List<LedZone> zones = _buildZones();

  void update(DriverDevice d) {
    device = d;
    zones = _buildZones();
  }

  List<LedZone> _buildZones() {
    final out = <LedZone>[];
    final used = <String>{};
    for (var i = 0; i < device.zones.length; i++) {
      final z = device.zones[i];
      if (z.count <= 0) continue;
      var key = 'zone:${z.name}';
      if (!used.add(key)) key = 'zone:${z.name}#$i';
      final label = device.zones.length == 1 || z.name.isEmpty
          ? name
          : '$name · ${z.name}';
      if (z.isMatrix) {
        final positions = <List<int>>[], leds = <int>[];
        for (var y = 0; y < z.height; y++) {
          for (var x = 0; x < z.width; x++) {
            final led = z.map[y * z.width + x];
            if (led == DriverZone.noLed || led >= z.count) continue;
            positions.add([x, y]);
            leds.add(z.start + led);
          }
        }
        out.add(
          LedZone(
            key: key,
            label: label,
            width: z.width,
            height: z.height,
            positions: positions,
            leds: leds,
          ),
        );
      } else {
        out.add(
          LedZone(
            key: key,
            label: label,
            width: z.count,
            height: 1,
            positions: [
              for (var x = 0; x < z.count; x++) [x, 0],
            ],
            leds: [for (var x = 0; x < z.count; x++) z.start + x],
          ),
        );
      }
    }
    return out;
  }
}

/// A saved lighting scene: an effect with its settings and a brightness.
class LightProfile {
  LightProfile({
    required this.id,
    required this.name,
    required this.icon,
    this.effect,
    Map<String, dynamic>? props,
    this.brightness = 100,
  }) : props = props ?? {};

  final String id;
  String name;

  /// Icon key, see the profiles card.
  String icon;

  /// Effect title (titles survive reinstalls; paths do not).
  String? effect;
  Map<String, dynamic> props;
  int brightness;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'effect': effect,
    'props': props,
    'brightness': brightness,
  };

  static LightProfile fromJson(Map j) => LightProfile(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    icon: '${j['icon'] ?? 'star'}',
    effect: j['effect'] as String?,
    props: ((j['props'] as Map?) ?? {}).cast<String, dynamic>(),
    brightness: (j['brightness'] as num?)?.toInt() ?? 100,
  );

  static List<LightProfile> defaults() => [
    LightProfile(id: 'game', name: 'Jogo', icon: 'game', effect: 'Anéis Neon'),
    LightProfile(
      id: 'work',
      name: 'Trabalho',
      icon: 'work',
      effect: 'Oceano',
      brightness: 60,
    ),
    LightProfile(
      id: 'night',
      name: 'Noite',
      icon: 'night',
      effect: 'Respiração',
      brightness: 20,
    ),
    LightProfile(id: 'off', name: 'Desligado', icon: 'off', brightness: 0),
  ];
}

/// Which temperature drives the reactive light.
enum ReactiveSource { cpu, gpu }

class Engine extends ChangeNotifier {
  Engine();

  /// Reads a temperature for the reactive light (wired to the system
  /// monitor by main.dart).
  double? Function(ReactiveSource source)? readTemperature;

  late final String dataDir = openChromaDataDir();

  List<EffectInfo> effects = [];
  final Map<String, DeviceInstance> devices = {};
  EffectInfo? currentEffect;
  CanvasFrame? frame;
  int brightness = 100;

  final audio = AudioService();
  AudioSource audioSource = AudioSource.system;

  /// Latest audio analysis, refreshed at ~30 Hz while an audio-reactive
  /// effect runs.
  final audioNotifier = ValueNotifier<AudioFrame>(AudioFrame.silent);
  bool scanning = false;

  /// Other RGB apps that are running and also drive the devices; writing
  /// from two programs at once makes the LEDs flicker.
  List<String> conflicts = [];
  bool _shuttingDown = false;

  Map<String, dynamic> _settings = {};
  Timer? _tick;
  Timer? _rescan;
  Timer? _devicePoll;
  Timer? _saveDebounce;

  String get _settingsFile => p.join(dataDir, 'settings.json');

  Future<void> start() async {
    _loadSettings();
    brightness = (_settings['brightness'] as int?) ?? 100;
    audioSource = AudioSource.byName(_settings['audioSource'] as String?);
    final r = (_settings['reactive'] as Map?) ?? {};
    reactive = r['on'] == true;
    reactiveSource = r['source'] == 'cpu'
        ? ReactiveSource.cpu
        : ReactiveSource.gpu;
    await _installBundledContent();
    _scanEffects();
    final saved = _settings['effect'] as String?;
    currentEffect =
        effects.where((e) => e.path == saved).firstOrNull ??
        effects.where((e) => e.title == 'Aurora').firstOrNull ??
        effects.firstOrNull;
    notifyListeners();

    // Left behind by versions that read third-party plugins.
    try {
      File(p.join(dataDir, 'plugin_cache.json')).deleteSync();
    } catch (_) {}

    // Plugins claim their devices before the native drivers look.
    await _loadPlugins();
    _scanPluginDevices();
    _pluginScan = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _scanPluginDevices(),
    );

    // Detection runs on the drivers' threads; poll the result.
    scanning = drivers.available;
    drivers.start(p.join(dataDir, 'drivers'));
    _devicePoll = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _pollDevices(),
    );
    _checkConflicts();
    _rescan = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConflicts(),
    );
    _tick = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _pollAudio();
      if (_alertUntil != null) {
        _alertFrame();
      } else if (reactive) {
        _reactiveFrame();
      }
      _pushFrames();
    });
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
  late final String bundledEffectsDir = p.join(dataDir, 'effects', 'bundled');
  late final String importedEffectsDir = p.join(dataDir, 'effects', 'imported');
  late final String runtimeDir = p.join(dataDir, 'runtime');

  /// Writes the `.ocfx` renderer page and the effects shipped as assets to
  /// disk, where the WebView can load them.
  Future<void> _installBundledContent() async {
    Directory(runtimeDir).createSync(recursive: true);
    File(p.join(runtimeDir, 'ocfx.html')).writeAsStringSync(ocfxRuntimeHtml);
    final dir = Directory(bundledEffectsDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    Directory(importedEffectsDir).createSync(recursive: true);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets()) {
      if (!asset.startsWith('assets/effects/')) continue;
      final data = await rootBundle.load(asset);
      File(p.join(bundledEffectsDir, p.basename(asset))).writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
  }

  void _scanEffects() {
    effects = scanEffects(
      // Only OpenChroma's own effects and the user's imports; effects that
      // belong to other apps are not listed.
      htmlRoots: const [],
      bundledDir: bundledEffectsDir,
      importedDir: importedEffectsDir,
    );
  }

  void selectEffect(EffectInfo e) {
    currentEffect = e;
    if (!_applyingProfile) _settings.remove('profile');
    _settings['effect'] = e.path;
    _save();
    notifyListeners();
  }

  void setEffectProperty(EffectInfo e, String name, Object value) {
    effectSettings(e)[name] = value;
    if (!_applyingProfile) _settings.remove('profile');
    _save();
    notifyListeners();
  }

  void setAudioSource(AudioSource source) {
    audioSource = source;
    _settings['audioSource'] = source.name;
    _save();
    notifyListeners();
  }

  /// Captures audio only while the running effect listens to it.
  void _pollAudio() {
    final listening = currentEffect?.usesAudio ?? false;
    audio.setSource(listening ? audioSource : AudioSource.off);
    if (listening) {
      audioNotifier.value = audio.read();
    } else if (audioNotifier.value.bands.isNotEmpty) {
      audioNotifier.value = AudioFrame.silent;
    }
  }

  void setBrightness(int v) {
    brightness = v.clamp(0, 100);
    if (!_applyingProfile) _settings.remove('profile');
    _settings['brightness'] = brightness;
    _save();
    notifyListeners();
  }

  // Favorites are stored by effect title, which survives reinstalls and
  // version-numbered install folders.
  Set<String> get _favorites =>
      ((_settings['favorites'] ??= <dynamic>[]) as List).cast<String>().toSet();

  bool isFavorite(EffectInfo e) => _favorites.contains(e.title);

  void toggleFavorite(EffectInfo e) {
    final favs = _favorites;
    if (!favs.remove(e.title)) favs.add(e.title);
    _settings['favorites'] = favs.toList()..sort();
    _save();
    notifyListeners();
  }

  /// Copies an `.ocfx`/`.json` or `.html` effect into the library and
  /// selects it. Throws [FormatException] with a user-facing message.
  EffectInfo importEffect(String sourcePath) {
    final ext = p.extension(sourcePath).toLowerCase();
    if (!{'.ocfx', '.json', '.html'}.contains(ext)) {
      throw const FormatException('Use um arquivo .ocfx, .json ou .html.');
    }
    // Validate before copying so a bad file never enters the library.
    final probe = ext == '.html'
        ? parseHtmlEffect(sourcePath, imported: true, force: true)
        : parseOcfx(sourcePath, imported: true);
    if (probe == null) {
      throw const FormatException('Não foi possível ler esse arquivo.');
    }
    Directory(importedEffectsDir).createSync(recursive: true);
    final base = probe.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final target = p.join(
      importedEffectsDir,
      '${base.isEmpty ? 'efeito' : base}${ext == '.json' ? '.ocfx' : ext}',
    );
    File(sourcePath).copySync(target);
    _scanEffects();
    final added = effects.firstWhere(
      (e) => p.equals(e.path, target),
      orElse: () => effects.firstWhere((e) => e.title == probe.title),
    );
    selectEffect(added);
    return added;
  }

  void removeEffect(EffectInfo e) {
    if (!e.imported) return;
    try {
      File(e.path).deleteSync();
    } catch (_) {}
    final cover = coverPath(e);
    if (File(cover).existsSync()) File(cover).deleteSync();
    _covers.remove(cover);
    _scanEffects();
    if (currentEffect?.path == e.path) {
      currentEffect = effects.firstOrNull;
      _settings['effect'] = currentEffect?.path;
    }
    _save();
    notifyListeners();
  }

  /// Fires on every effect frame (about 30 Hz) without rebuilding listeners
  /// of the engine itself.
  final frameNotifier = ValueNotifier<CanvasFrame?>(null);

  void onFrame(CanvasFrame f) {
    // The reactive light draws its own frames.
    if (_alertUntil != null || (reactive && _reactiveColor != null)) return;
    frame = f;
    frameNotifier.value = f;
  }

  // ------------------------------------------------------------ profiles
  bool _applyingProfile = false;

  List<LightProfile> get profiles {
    final raw = _settings['profiles'];
    if (raw is List && raw.isNotEmpty) {
      return [for (final p in raw) LightProfile.fromJson(p as Map)];
    }
    return LightProfile.defaults();
  }

  String? get activeProfile => _settings['profile'] as String?;

  /// Turns on the effect, settings and brightness saved in profile [id].
  void applyProfile(String id) {
    final profile = profiles.where((p) => p.id == id).firstOrNull;
    if (profile == null) return;
    _applyingProfile = true;
    try {
      final effect = profile.effect == null
          ? null
          : effects.where((e) => e.title == profile.effect).firstOrNull;
      if (effect != null) {
        effectSettings(effect)
          ..clear()
          ..addAll(profile.props);
        selectEffect(effect);
      }
      setBrightness(profile.brightness);
      _settings['profile'] = id;
      _save();
      notifyListeners();
    } finally {
      _applyingProfile = false;
    }
  }

  /// Saves what is on now (effect, its settings, brightness) into [id].
  void saveProfile(String id, {String? name}) {
    final list = profiles;
    final p = list.where((p) => p.id == id).firstOrNull;
    if (p == null) return;
    final e = currentEffect;
    p
      ..effect = e?.title
      ..props = e == null ? {} : Map.of(effectSettings(e))
      ..brightness = brightness;
    if (name != null && name.trim().isNotEmpty) p.name = name.trim();
    _settings['profiles'] = [for (final p in list) p.toJson()];
    _settings['profile'] = id;
    _save();
    notifyListeners();
  }

  void renameProfile(String id, String name) {
    if (name.trim().isEmpty) return;
    final list = profiles;
    for (final p in list) {
      if (p.id == id) p.name = name.trim();
    }
    _settings['profiles'] = [for (final p in list) p.toJson()];
    _save();
    notifyListeners();
  }

  void resetProfiles() {
    _settings.remove('profiles');
    _settings.remove('profile');
    _save();
    notifyListeners();
  }

  // ---------------------------------------------------------- alert flash
  DateTime? _alertUntil;
  int _alertTick = 0;

  /// Pulses every LED red for a few seconds, then the effect resumes.
  void flashAlert() {
    _alertUntil = DateTime.now().add(const Duration(seconds: 4));
    _alertTick = 0;
  }

  void _alertFrame() {
    if (DateTime.now().isAfter(_alertUntil!)) {
      _alertUntil = null;
      return;
    }
    final on = (_alertTick++ ~/ 8).isEven;
    const w = 160, h = 100;
    final rgb = Uint8List(w * h * 3);
    if (on) {
      for (var i = 0; i < rgb.length; i += 3) {
        rgb[i] = 255;
      }
    }
    final f = CanvasFrame(w, h, rgb);
    frame = f;
    frameNotifier.value = f;
  }

  // ------------------------------------------------------- reactive light
  /// The LEDs follow a temperature instead of the effect: blue when cool,
  /// through green and amber, to red when hot.
  bool reactive = false;
  ReactiveSource reactiveSource = ReactiveSource.gpu;
  static const reactiveLow = 30.0;
  static const reactiveHigh = 90.0;
  static const reactiveScale = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  double? _smoothTemp;
  Color? _reactiveColor;
  int _reactiveTick = 0;

  /// The smoothed temperature the reactive light shows, if any.
  double? get reactiveTemperature => _smoothTemp;

  void setReactive(bool on, {ReactiveSource? source}) {
    reactive = on;
    if (source != null && source != reactiveSource) {
      reactiveSource = source;
      _smoothTemp = null;
    }
    if (!on) _reactiveColor = null;
    _settings['reactive'] = {'on': on, 'source': reactiveSource.name};
    _save();
    notifyListeners();
  }

  static Color reactiveColorFor(double t) {
    final k = ((t - reactiveLow) / (reactiveHigh - reactiveLow)).clamp(
      0.0,
      1.0,
    );
    final x = k * (reactiveScale.length - 1);
    final i = x.floor().clamp(0, reactiveScale.length - 2);
    return Color.lerp(reactiveScale[i], reactiveScale[i + 1], x - i)!;
  }

  void _reactiveFrame() {
    final t = readTemperature?.call(reactiveSource);
    if (t == null) {
      // No sensor yet: keep showing the effect.
      _reactiveColor = null;
      return;
    }
    final smooth = _smoothTemp == null
        ? t
        : _smoothTemp! + (t - _smoothTemp!) * .05;
    _smoothTemp = smooth;
    final c = reactiveColorFor(smooth);
    _reactiveColor = c;
    // A slow breath keeps it alive; it quickens when hot.
    final hot = smooth >= 85;
    final phase = _reactiveTick++ * .033 * (hot ? 1.6 : .25) * 2 * math.pi;
    final level = hot
        ? .55 + .45 * (.5 + .5 * math.sin(phase))
        : .85 + .15 * math.sin(phase);
    const w = 160, h = 100;
    final rgb = Uint8List(w * h * 3);
    final r = (c.r * 255 * level).round(),
        g = (c.g * 255 * level).round(),
        b = (c.b * 255 * level).round();
    for (var i = 0; i < rgb.length; i += 3) {
      rgb[i] = r;
      rgb[i + 1] = g;
      rgb[i + 2] = b;
    }
    final f = CanvasFrame(w, h, rgb);
    frame = f;
    frameNotifier.value = f;
  }

  // ------------------------------------------------------------ covers
  // Effects without a preview image get a cover rendered from the effect
  // itself (see CoverBaker).
  late final String _coverDir = p.join(dataDir, 'covers');
  late final Set<String> _covers = {
    if (Directory(_coverDir).existsSync())
      for (final f in Directory(_coverDir).listSync().whereType<File>()) f.path,
  };

  String coverPath(EffectInfo e) {
    var h = 0x811c9dc5; // FNV-1a, stable across runs
    for (final c in '${e.path.toLowerCase()}|${e.title}'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return p.join(_coverDir, '${h.toRadixString(16)}.png');
  }

  /// The effect's own preview image, or the rendered cover, if any.
  String? thumbnailFor(EffectInfo e) {
    if (e.thumbnail != null) return e.thumbnail;
    final c = coverPath(e);
    return _covers.contains(c) ? c : null;
  }

  List<EffectInfo> get effectsWithoutCover =>
      effects.where((e) => thumbnailFor(e) == null).toList();

  void saveCover(EffectInfo e, Uint8List png) {
    final path = coverPath(e);
    Directory(_coverDir).createSync(recursive: true);
    File(path).writeAsBytesSync(png);
    _covers.add(path);
    notifyListeners();
  }

  // ---------------------------------------------------------------- plugins
  /// OpenChroma plugins (assets/plugins and the user's plugins folder).
  List<PluginInfo> plugins = [];
  late final String pluginsDir = p.join(dataDir, 'plugins');
  late final String _bundledPluginsDir = p.join(pluginsDir, 'bundled');
  final Map<int, (PluginInfo, PluginDevice)> _pluginModels = {};
  Timer? _pluginScan;
  bool _scanningPlugins = false;
  int _nextPluginId = -1;

  /// Copies the bundled plugins out of the assets and reads every plugin.
  /// Their devices are claimed before the native drivers start.
  Future<void> _loadPlugins() async {
    final dir = Directory(_bundledPluginsDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets()) {
      if (!asset.startsWith('assets/plugins/')) continue;
      File(p.join(_bundledPluginsDir, p.basename(asset)))
          .writeAsStringSync(await rootBundle.loadString(asset));
    }
    plugins = await loadPlugins(
      bundledDir: _bundledPluginsDir,
      userDir: pluginsDir,
    );
    for (final pl in plugins) {
      for (final model in pl.devices) {
        _pluginModels[model.key] = (pl, model);
        drivers.claimHid(model.vid, model.pid);
      }
    }
  }

  /// Starts a plugin for every claimed device that is plugged in, and stops
  /// those that were unplugged.
  Future<void> _scanPluginDevices() async {
    if (_shuttingDown || _pluginModels.isEmpty || _scanningPlugins) return;
    _scanningPlugins = true;
    try {
      // Enumerating opens every HID collection; keep it off the UI isolate.
      final endpoints = await Isolate.run(hidEnumerate);
      if (_shuttingDown) return;
      final groups = <String, List<HidEndpointInfo>>{};
      for (final e in endpoints) {
        if (!_pluginModels.containsKey(e.vendorId << 16 | e.productId)) {
          continue;
        }
        final key =
            'plugin|${e.vendorId.toRadixString(16)}:'
            '${e.productId.toRadixString(16)}|${e.serial}';
        (groups[key] ??= []).add(e);
      }
      var changed = false;
      for (final d in devices.values.toList()) {
        if (d.source == DeviceSource.plugin && !groups.containsKey(d.key)) {
          d.port?.send({'t': 'stop'});
          devices.remove(d.key);
          changed = true;
        }
      }
      for (final entry in groups.entries) {
        if (devices.containsKey(entry.key)) continue;
        final first = entry.value.first;
        final (plugin, model) =
            _pluginModels[first.vendorId << 16 | first.productId]!;
        final d = DeviceInstance(
          entry.key,
          DriverDevice.fromJson({
            'id': _nextPluginId--,
            'name': model.name,
            'vendor': plugin.vendor,
            'type': plugin.type,
            'serial': first.serial,
            'location':
                'HID ${first.vendorId.toRadixString(16).padLeft(4, '0')}:'
                '${first.productId.toRadixString(16).padLeft(4, '0')}',
          }),
          source: DeviceSource.plugin,
          plugin: plugin,
        )..status = 'starting';
        devices[d.key] = d;
        changed = true;
        await _spawnPlugin(d, entry.value);
      }
      if (changed) notifyListeners();
    } finally {
      _scanningPlugins = false;
    }
  }

  Future<void> _spawnPlugin(
    DeviceInstance d,
    List<HidEndpointInfo> endpoints,
  ) async {
    final inbox = ReceivePort();
    d.inbox = inbox;
    inbox.listen((msg) => _onPluginMessage(d, msg as Map));
    final ds = _deviceSettings(d.key);
    final values = <String, Object?>{
      for (final e in d.plugin!.settings.entries) e.key: e.value['default'],
      ...((ds['props'] as Map?) ?? {}).cast<String, Object?>(),
    };
    await Isolate.spawn(
      pluginWorkerMain,
      PluginWorkerArgs(
        sendPort: inbox.sendPort,
        pluginPath: d.plugin!.path,
        endpoints: [for (final e in endpoints) e.toJson()],
        settings: values,
        deviceName: d.device.name,
      ),
      debugName: 'plugin ${d.key}',
    );
  }

  /// Turns a plugin's zone list into the drivers' device description.
  static Map<String, Object?> _pluginLayout(DriverDevice base, List zones) {
    final out = <Map<String, Object?>>[];
    var leds = 0;
    for (final z in zones.cast<Map>()) {
      if (z['map'] is List) {
        final map = [
          for (final v in z['map'] as List)
            (v is num && v >= 0) ? v.toInt() : DriverZone.noLed,
        ];
        final count = map
            .where((v) => v != DriverZone.noLed)
            .fold<int>(0, (m, v) => v + 1 > m ? v + 1 : m);
        out.add({
          'name': '${z['name'] ?? ''}',
          'type': ZoneType.matrix,
          'count': count,
          'width': (z['width'] as num?)?.toInt() ?? 0,
          'height': (z['height'] as num?)?.toInt() ?? 0,
          'map': map,
        });
        leds += count;
      } else {
        final count = (z['leds'] as num?)?.toInt() ?? 1;
        out.add({
          'name': '${z['name'] ?? ''}',
          'type': count == 1 ? ZoneType.single : ZoneType.linear,
          'count': count,
        });
        leds += count;
      }
    }
    return {
      'id': base.id,
      'name': base.name,
      'vendor': base.vendor,
      'type': base.type,
      'serial': base.serial,
      'location': base.location,
      'leds': leds,
      'zones': out,
    };
  }

  void _onPluginMessage(DeviceInstance d, Map m) {
    switch (m['t']) {
      case 'port':
        d.port = m['port'] as SendPort;
      case 'layout':
        final j = jsonDecode(m['layout'] as String) as Map;
        d.update(
          DriverDevice.fromJson(
            _pluginLayout(d.device, j['zones'] as List? ?? []),
          ),
        );
        d.modes = [
          for (final mode in j['modes'] as List? ?? [])
            if (mode is Map) (mode['id'], '${mode['name'] ?? mode['id']}'),
        ];
        d.status = _deviceSettings(d.key)['disabled'] == true
            ? 'disabled'
            : 'running';
        _ensureLayout(d);
        _applySavedMode(d);
        notifyListeners();
      case 'battery':
        d.battery = m['level'] as int?;
        d.charging = m['charging'] == true;
        notifyListeners();
      case 'log':
        d.logs.add(m['msg'] as String);
        if (d.logs.length > 200) d.logs.removeAt(0);
        if (kDebugMode) debugPrint('[${d.name}] ${m['msg']}');
      case 'error':
        d.status = 'error';
        d.error = m['msg'] as String;
        notifyListeners();
      case 'rejected':
        d.status = 'unsupported';
        d.error = 'O plugin não reconheceu este dispositivo.';
        notifyListeners();
      case 'stopped':
        d.inbox?.close();
        d.port = null;
        if (d.status == 'running' || d.status == 'starting') {
          d.status = 'stopped';
          notifyListeners();
        }
    }
  }

  /// Changes one of a plugin's settings for device [d].
  void setPluginSetting(DeviceInstance d, String name, Object? value) {
    final props =
        (_deviceSettings(d.key)['props'] ??= <String, dynamic>{}) as Map;
    props[name] = value;
    _save();
    d.port?.send({'t': 'setting', 'name': name, 'value': value});
    notifyListeners();
  }

  /// Current value of a plugin setting for [d].
  Object? pluginSetting(DeviceInstance d, String name) =>
      ((_deviceSettings(d.key)['props'] as Map?) ?? {})[name] ??
      d.plugin?.settings[name]?['default'];

  // ---------------------------------------------------------- hardware modes
  /// Lets the device run one of its own effects ([name] from
  /// [DeviceInstance.modes]) instead of the app's; null goes back to the app.
  void setDeviceMode(DeviceInstance d, String? name) {
    final ds = _deviceSettings(d.key);
    if (name == null) {
      ds.remove('hwMode');
    } else {
      ds['hwMode'] = name;
    }
    _save();
    _sendMode(d, name);
    notifyListeners();
  }

  void _sendMode(DeviceInstance d, String? name) {
    final mode = name == null
        ? null
        : d.modes.where((m) => m.$2 == name).firstOrNull;
    d.activeMode = mode?.$2;
    d.lastSent = null;
    if (d.source == DeviceSource.plugin) {
      d.port?.send({'t': 'mode', 'id': mode?.$1});
    } else {
      drivers.setMode(d.device.id, mode == null ? -1 : mode.$1 as int);
    }
  }

  void _applySavedMode(DeviceInstance d) {
    final saved = _deviceSettings(d.key)['hwMode'] as String?;
    if (saved != null && d.modes.any((m) => m.$2 == saved)) {
      _sendMode(d, saved);
    }
  }

  // ---------------------------------------------------------------- devices
  /// The device drivers (oc_drivers.dll).
  final drivers = NativeDrivers();

  /// What detection is doing, for the devices page.
  String detectionStep = '';
  int detectionPercent = 0;

  /// Looks for devices again (plugged in or out).
  Future<void> refreshDevices() async {
    if (_shuttingDown) return;
    drivers.rescan();
  }

  void _pollDevices() {
    if (_shuttingDown) return;
    final s = drivers.poll();
    var changed =
        scanning != (!s.ready || s.detecting) ||
        detectionPercent != s.percent ||
        detectionStep != s.step;
    scanning = drivers.available && (!s.ready || s.detecting);
    detectionPercent = s.percent;
    detectionStep = s.step;
    final seen = <String>{};
    for (final dev in s.devices) {
      // Two identical devices without a serial get distinct keys.
      var key = dev.key;
      for (var n = 2; seen.contains(key); n++) {
        key = '${dev.key}#$n';
      }
      seen.add(key);
      final existing = devices[key];
      if (existing == null) {
        final d = DeviceInstance(key, dev);
        if (_deviceSettings(key)['disabled'] == true) d.status = 'disabled';
        d.modes = _nativeModes(dev);
        devices[key] = d;
        _applyZoneSizes(d);
        _ensureLayout(d);
        _applySavedMode(d);
        changed = true;
      } else if (existing.device.id != dev.id ||
          existing.device.ledCount != dev.ledCount ||
          existing.device.zones.length != dev.zones.length) {
        final redetected = existing.device.id != dev.id;
        existing.update(dev);
        existing.modes = _nativeModes(dev);
        // A new controller object (after "Procurar" or a replug) has not
        // received anything yet: colors, LED counts and mode go again.
        existing.lastSent = null;
        if (redetected) {
          _applyZoneSizes(existing);
          _applySavedMode(existing);
        }
        _ensureLayout(existing);
        changed = true;
      } else {
        existing.device = dev;
      }
    }
    final gone = devices.entries
        .where((e) => e.value.source == DeviceSource.native)
        .map((e) => e.key)
        .where((k) => !seen.contains(k))
        .toList();
    if (gone.isNotEmpty) {
      gone.forEach(devices.remove);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// A native device's own modes, minus the one that takes the app's
  /// colors.
  static List<(Object?, String)> _nativeModes(DriverDevice d) => [
    for (var i = 0; i < d.modes.length; i++)
      if (d.modes[i].toLowerCase() != 'direct') (i, d.modes[i]),
  ];

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

  /// Sets how many LEDs hang off a resizable zone (an ARGB header).
  void setZoneLedCount(DeviceInstance d, int zoneIndex, int count) {
    final z = d.device.zones[zoneIndex];
    final c = count.clamp(z.min, z.max);
    final sizes =
        (_deviceSettings(d.key)['zoneSizes'] ??= <String, dynamic>{}) as Map;
    sizes[z.name] = c;
    _save();
    drivers.resizeZone(d.device.id, zoneIndex, c);
  }

  /// Re-applies the user's LED counts after the device is detected.
  void _applyZoneSizes(DeviceInstance d) {
    _migrateLegacyChannels(d);
    final sizes = (_deviceSettings(d.key)['zoneSizes'] as Map?) ?? {};
    for (final (i, z) in d.resizableZones) {
      final want = (sizes[z.name] as num?)?.toInt();
      if (want != null && want != z.count) {
        drivers.resizeZone(d.device.id, i, want.clamp(z.min, z.max));
      }
    }
  }

  /// LED counts saved by versions before the built-in drivers, under a
  /// "vid:pid:serial" key and channel names of their own ("5v ARGB Header
  /// 1"). They are moved, in order, to a device with the same number of
  /// resizable zones that has no counts yet.
  void _migrateLegacyChannels(DeviceInstance d) {
    final ds = _deviceSettings(d.key);
    final zones = d.resizableZones;
    if (ds['zoneSizes'] != null || zones.isEmpty) return;
    final all = (_settings['devices'] as Map?) ?? {};
    final legacyKey = RegExp(r'^[0-9a-f]{4}:[0-9a-f]{4}:');
    for (final e in all.entries) {
      final v = e.value;
      if (!legacyKey.hasMatch('${e.key}') || v is! Map) continue;
      final channels = v['channels'];
      if (channels is! Map || channels.length != zones.length) continue;
      final names = channels.keys.map((k) => '$k').toList()..sort();
      final sizes = <String, dynamic>{};
      for (var i = 0; i < zones.length; i++) {
        final count = (channels[names[i]] as num?)?.toInt() ?? 0;
        sizes[zones[i].$2.name] = count.clamp(zones[i].$2.min, zones[i].$2.max);
      }
      ds['zoneSizes'] = sizes;
      v.remove('channels');
      _save();
      return;
    }
  }

  Future<void> setDeviceEnabled(DeviceInstance d, bool enabled) async {
    _deviceSettings(d.key)['disabled'] = !enabled;
    _save();
    d.status = enabled ? 'running' : 'disabled';
    // A disabled device is left dark rather than frozen on the last frame.
    if (!enabled) _sendColors(d, Uint8List(d.device.ledCount * 3));
    d.lastSent = null;
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
    if (zoneKey == d.zones.firstOrNull?.key) {
      var scale = 8.0;
      // Fit large devices on the canvas.
      final fit = [
        canvasWidth / w,
        canvasHeight / h,
      ].reduce((a, b) => a < b ? a : b);
      if (scale > fit) scale = fit;
      // Tiny single-zone devices (1x1 at scale 1) would be an invisible dot.
      final longest = w > h ? w : h;
      if (longest * scale < 24) scale = 24 / longest;
      return LayoutItem(
        x: (canvasWidth - w * scale) / 2,
        y: (canvasHeight - h * scale) / 2,
        scale: scale,
      );
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
  /// Writes into [out] (RGB per device LED) the canvas color under each LED
  /// of [zone] placed at [item].
  void _sampleZone(
    LedZone zone,
    LayoutItem item,
    CanvasFrame f,
    double b,
    Uint8List out,
  ) {
    final sx = f.width / canvasWidth, sy = f.height / canvasHeight;
    final cw = item.scale * sx, ch = item.scale * sy;
    // Average the frame pixels covered by the LED's cell (at most 4x4
    // samples) so a LED reflects its area, not one noisy pixel.
    final nx = cw.ceil().clamp(1, 4), ny = ch.ceil().clamp(1, 4);
    for (var i = 0; i < zone.positions.length; i++) {
      final o = zone.leds[i] * 3;
      if (o + 2 >= out.length) continue;
      final pos = zone.positions[i];
      final x0 = (item.x + pos[0] * item.scale) * sx,
          y0 = (item.y + pos[1] * item.scale) * sy;
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
      if (n == 0) continue;
      out[o] = (r / n * b).round();
      out[o + 1] = (g / n * b).round();
      out[o + 2] = (bl / n * b).round();
    }
  }

  /// [n] colors across the device's first zone as it is lit right now,
  /// left to right, for the device artwork. Empty when it is not lit.
  List<Color> previewColors(DeviceInstance d, int n) {
    final f = frame;
    if (f == null || d.status != 'running' || brightness == 0) return const [];
    final zone = d.zones.firstOrNull;
    if (zone == null) return const [];
    final item = layoutOf(d, zone.key);
    final w = zone.width * item.scale, h = zone.height * item.scale;
    // The hue, not the dimmed level: a thumbnail at 20% would just be grey.
    final sx = f.width / canvasWidth, sy = f.height / canvasHeight;
    final py = ((item.y + h / 2) * sy).floor().clamp(0, f.height - 1);
    return [
      for (var i = 0; i < n; i++)
        () {
          final px = ((item.x + w * (i + .5) / n) * sx).floor().clamp(
            0,
            f.width - 1,
          );
          final o = (py * f.width + px) * 3;
          return Color.fromARGB(255, f.rgb[o], f.rgb[o + 1], f.rgb[o + 2]);
        }(),
    ];
  }

  void _pushFrames() {
    final f = frame;
    if (f == null) return;
    // An alert flash must show even with the lights dimmed or off.
    final b = _alertUntil != null ? 1.0 : brightness / 100.0;
    for (final d in devices.values) {
      if (d.status != 'running' || d.device.ledCount == 0) continue;
      if (d.activeMode != null) continue;
      final out = Uint8List(d.device.ledCount * 3);
      for (final z in d.zones) {
        _sampleZone(z, layoutOf(d, z.key), f, b, out);
      }
      // Static effects would resend the same colors 30 times a second;
      // once a second is kept so a device that slips back to its own
      // effect is brought back.
      final last = d.lastSent;
      final now = DateTime.now();
      if (last != null &&
          listEquals(last, out) &&
          now.difference(d.lastSentAt) < const Duration(seconds: 1)) {
        continue;
      }
      d.lastSent = out;
      d.lastSentAt = now;
      _sendColors(d, out);
    }
  }

  void _sendColors(DeviceInstance d, Uint8List rgb) {
    if (d.source == DeviceSource.plugin) {
      d.port?.send({'t': 'frame', 'rgb': rgb});
    } else {
      drivers.setLeds(d.device.id, rgb);
    }
  }

  /// Saves settings and leaves the LEDs dark before the app exits.
  Future<void> shutdown() async {
    _shuttingDown = true;
    _tick?.cancel();
    _rescan?.cancel();
    _devicePoll?.cancel();
    _pluginScan?.cancel();
    audio.setSource(AudioSource.off);
    _saveDebounce?.cancel();
    try {
      File(_settingsFile).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_settings),
      );
    } catch (_) {}
    // Plugins get a moment to leave their devices in a sensible state.
    final running = devices.values.where((d) => d.port != null).toList();
    for (final d in running) {
      d.port!.send({'t': 'stop'});
    }
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (running.any((d) => d.port != null) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    drivers.shutdown();
  }
}
