import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../audio/audio_service.dart';
import '../effects/effect_library.dart';
import '../drivers/native_drivers.dart';
import '../hid/hid_ffi.dart';
import '../hid/serial_ffi.dart';
import '../i18n/l10n.dart';
import '../i18n/terms.dart';
import '../plugins/plugin_library.dart';
import '../plugins/plugin_trust.dart';
import '../plugins/plugin_worker.dart';
import '../plugins/thread_priority.dart';
import '../system/batteries.dart';
import '../system/launch_settings.dart' show Elevation;
import '../system/processes.dart';
import '../paths.dart';
import 'legacy_names.dart';
import 'screen_image.dart';

export 'screen_image.dart'
    show
        ScreenSpec,
        ScreenEdit,
        ScreenText,
        ScreenSource,
        maxTextSize,
        maxLiveSize,
        minTextSize;

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
  LayoutItem({
    required this.x,
    required this.y,
    required this.scale,
    this.turns = 0,
    this.flipX = false,
    this.flipY = false,
  });
  double x;
  double y;
  double scale;
  int turns;
  bool flipX;
  bool flipY;

  (int, int) sizeOf(LedZone zone) =>
      turns.isOdd ? (zone.height, zone.width) : (zone.width, zone.height);

  (double, double) pointOf(LedZone zone, double x, double y) {
    if (turns == 0 && !flipX && !flipY) return (x, y);
    final (width, height) = sizeOf(zone);
    final (u, v) = switch (turns % 4) {
      1 => (zone.height - y, x),
      2 => (zone.width - x, zone.height - y),
      3 => (y, zone.width - x),
      _ => (x, y),
    };
    return (flipX ? width - u : u, flipY ? height - v : v);
  }

  Map<String, Object> toJson() => {
    'x': x,
    'y': y,
    'scale': scale,
    if (turns != 0) 'turns': turns,
    if (flipX) 'flipX': true,
    if (flipY) 'flipY': true,
  };
  static LayoutItem fromJson(Map j) => LayoutItem(
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    scale: (j['scale'] as num).toDouble(),
    turns: ((j['turns'] as num?)?.toInt() ?? 0) % 4,
    flipX: j['flipX'] == true,
    flipY: j['flipY'] == true,
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
    this.model,
  });

  final String key;
  DriverDevice device;
  final DeviceSource source;

  /// The plugin driving it and which of its models it is, for
  /// [DeviceSource.plugin].
  final PluginInfo? plugin;
  final PluginDevice? model;

  /// starting, running, disabled, error, unsupported or stopped.
  String status = 'running';
  String? error;
  final List<String> logs = [];

  /// The device's own lighting effects.
  List<HardwareMode> modes = [];

  /// The hardware effect running instead of the app's colors, if any.
  String? activeMode;

  /// Charge of a wireless device (0-100) and whether it is charging.
  int? battery;
  bool charging = false;

  /// [battery] comes from Windows, not from the device's plugin.
  bool batteryFromSystem = false;

  /// The device's own screen, if its plugin drives one.
  ScreenSpec? screen;

  /// How far an image upload to [screen] is (0 to 1), while one runs, and
  /// why the last one failed.
  double? screenProgress;
  String? screenError;
  Completer<bool>? _screenDone;

  /// Plugin isolate link.
  SendPort? port;
  ReceivePort? inbox;
  Isolate? worker;
  int? workerThread;
  DateTime lastBeat = DateTime.now();

  /// While set, zone $1 shows the pure color ($2, $3, $4) and every other
  /// LED is dark (the color-order assistant).
  (int, int, int, int)? testColor;

  /// With [testColor], only the first this many LEDs of the zone light (the
  /// LED counting assistant).
  int? testCount;

  /// Last colors sent and when, to skip identical frames.
  Uint8List? lastSent;
  DateTime lastSentAt = DateTime(0);

  /// The frame and brightness [lastSent] came from, so a paused effect is
  /// not sampled again on every tick.
  CanvasFrame? _sentFrame;
  double _sentLevel = -1;

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
          : '$name · ${localizeTerm(z.name)}';
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
    required String name,
    required this.icon,
    this.effect,
    Map<String, dynamic>? props,
    this.brightness = 100,
    List<String>? apps,
  }) : props = props ?? {},
       apps = apps ?? [] {
    _name = name;
  }

  final String id;
  late String _name;

  static String? _builtinName(String id, AppLocalizations l) => switch (id) {
    'game' => l.engineProfileGame,
    'work' => l.engineProfileWork,
    'night' => l.engineProfileNight,
    'off' => l.engineProfileOff,
    _ => null,
  };

  /// The name to show: a built-in profile the user never renamed follows the
  /// UI language, whichever language its name was saved in.
  String get name {
    final builtin = _builtinName(id, l10n);
    if (builtin == null) return _name;
    final untouched = ['en', 'pt'].any(
      (code) => _builtinName(id, lookupAppLocalizations(Locale(code))) == _name,
    );
    return untouched ? builtin : _name;
  }

  set name(String value) => _name = value;

  /// Icon key, see the profiles card.
  String icon;

  /// Effect title (titles survive reinstalls; paths do not).
  String? effect;
  Map<String, dynamic> props;
  int brightness;

  /// Programs (executable names, lowercase) that turn this profile on while
  /// they run.
  List<String> apps;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': _name,
    'icon': icon,
    'effect': effect,
    'props': props,
    'brightness': brightness,
    if (apps.isNotEmpty) 'apps': apps,
  };

  static LightProfile fromJson(Map j) => LightProfile(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    icon: '${j['icon'] ?? 'star'}',
    effect: j['effect'] as String?,
    props: ((j['props'] as Map?) ?? {}).cast<String, dynamic>(),
    brightness: (j['brightness'] as num?)?.toInt() ?? 100,
    apps: [for (final a in j['apps'] as List? ?? []) '$a'.toLowerCase()],
  );

  static List<LightProfile> defaults() => [
    LightProfile(
      id: 'game',
      name: l10n.engineProfileGame,
      icon: 'game',
      effect: 'neon-rings.ocfx',
    ),
    LightProfile(
      id: 'work',
      name: l10n.engineProfileWork,
      icon: 'work',
      effect: 'ocean.ocfx',
      brightness: 60,
    ),
    LightProfile(
      id: 'night',
      name: l10n.engineProfileNight,
      icon: 'night',
      effect: 'breathing.ocfx',
      brightness: 20,
    ),
    LightProfile(
      id: 'off',
      name: l10n.engineProfileOff,
      icon: 'off',
      brightness: 0,
    ),
  ];
}

/// The effect (by path), its settings, the brightness and the profile on
/// at one moment.
typedef _Lighting = ({
  String? effect,
  Map<String, dynamic> props,
  int brightness,
  String? profile,
});

/// Which temperature drives the reactive light.
enum ReactiveSource { cpu, gpu }

class Engine extends ChangeNotifier {
  Engine({String? dataDir}) : dataDir = dataDir ?? openChromaDataDir();

  /// Reads a temperature for the reactive light (wired to the system
  /// monitor by main.dart).
  double? Function(ReactiveSource source)? readTemperature;

  /// Reads a live value for device screens ([ScreenSource.key]).
  double? Function(String key)? readSensor;

  /// Some device screen shows live values, so the sensors must be read.
  bool get needsSensors => devices.values.any(
    (d) => d.screen != null && screenEdit(d).sources.isNotEmpty,
  );

  final String dataDir;

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
  Timer? _identifyTimer;
  (DeviceInstance, LedZone, bool)? _identifiedZone;
  Timer? _rescan;
  Timer? _batteryCheck;
  Timer? _screenValues;
  Timer? _devicePoll;
  Timer? _saveDebounce;

  String get _settingsFile => p.join(dataDir, 'settings.json');

  Future<void> start() async {
    _loadSettings();
    if (migrateLegacyNames(_settings)) _save();
    brightness = (_settings['brightness'] as int?) ?? 100;
    _loadAuto();
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
        _effectByRef('aurora.ocfx') ??
        effects.firstOrNull;
    notifyListeners();

    // Left behind by versions that read third-party plugins.
    try {
      File(p.join(dataDir, 'plugin_cache.json')).deleteSync();
    } catch (_) {}

    // Plugins claim their devices before the native drivers look.
    _approvals = PluginApprovals.fromJson(_settings['pluginApprovals']);
    await _loadBundledPlugins();
    await _readPlugins();
    for (final key in _pluginModels.keys) {
      drivers.claimHid(key >> 16, key & 0xFFFF);
    }
    _watchPlugins();
    _scanPluginDevices();
    _pluginScan = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _scanPluginDevices(),
    );
    _pluginWatchdog = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkPluginHealth(),
    );

    // Detection runs on the drivers' threads; poll the result.
    scanning = drivers.available;
    drivers.start(p.join(dataDir, 'drivers'));
    _devicePoll = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _pollDevices(),
    );
    _checkProcesses();
    _rescan = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProcesses(),
    );
    _checkBatteries();
    _screenValues = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sendScreenValues(),
    );
    _batteryCheck = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkBatteries(),
    );
    _tick = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _pollAudio();
      if (_alertUntil != null) {
        _alertFrame();
      } else if (reactive && !frozen) {
        _reactiveFrame();
      }
      pushFrames();
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

  /// Writes the effects shipped as assets to disk.
  Future<void> _installBundledContent() async {
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
    paused = false;
    if (!_applyingProfile) {
      _settings.remove('profile');
      _keepUserChoice();
    }
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
    for (final d in devices.values) {
      if (hasScreenBrightness(d)) _sendScreenBrightness(d);
    }
    notifyListeners();
  }

  /// The user paused the effect: devices keep its last frame.
  bool paused = false;

  /// The effect stands still: paused, or nothing is lit (brightness 0), so
  /// no frames are drawn and the devices are not written again.
  bool get frozen => paused || brightness == 0;

  void setPaused(bool v) {
    if (paused == v) return;
    paused = v;
    notifyListeners();
  }

  /// [d]'s own LED brightness (0-100), applied on top of [brightness].
  int deviceBrightness(DeviceInstance d) =>
      ((_deviceSettings(d.key)['brightness'] as num?) ?? 100).toInt();

  void setDeviceBrightness(DeviceInstance d, int v) {
    _deviceSettings(d.key)['brightness'] = v.clamp(0, 100);
    _save();
    notifyListeners();
  }

  /// [d] has a screen whose brightness its plugin takes (a `brightness`
  /// setting), scaled by [brightness] like the LEDs.
  bool hasScreenBrightness(DeviceInstance d) =>
      d.screen != null && d.plugin?.settings['brightness'] != null;

  int screenBrightness(DeviceInstance d) =>
      ((pluginSetting(d, 'brightness') as num?) ?? 100).toInt();

  void setScreenBrightness(DeviceInstance d, int v) =>
      setPluginSetting(d, 'brightness', v);

  void _sendScreenBrightness(DeviceInstance d) => d.port?.send({
    't': 'setting',
    'name': 'brightness',
    'value': _pluginValue(d, 'brightness', pluginSetting(d, 'brightness')),
  });

  /// What a plugin gets for setting [name]: the screen brightness is
  /// scaled by the overall [brightness], within the setting's range.
  Object? _pluginValue(DeviceInstance d, String name, Object? value) {
    final spec = d.plugin?.settings[name];
    if (name != 'brightness' || d.screen == null || spec == null) return value;
    if (value is! num) return value;
    final min = (spec['min'] as num?) ?? 0, max = (spec['max'] as num?) ?? 100;
    return (value * brightness / 100).round().clamp(min, max);
  }

  // Favorites are stored by effect title, which survives reinstalls and
  // version-numbered install folders.
  Set<String> get _favorites =>
      ((_settings['favorites'] ??= <dynamic>[]) as List).cast<String>().toSet();

  /// Every name an effect has been known by: its file name, its title in
  /// each language it ships, so saved references keep working when the UI
  /// language (and so the title) changes.
  static Set<String> _effectRefs(EffectInfo e) {
    final doc = e.definition;
    final i18n = doc?['i18n'];
    return {
      e.title.toLowerCase(),
      p.basename(e.path).toLowerCase(),
      if (doc?['name'] case final String name) name.toLowerCase(),
      if (i18n is Map)
        for (final t in i18n.values)
          if (t is Map)
            if (t['name'] case final String name) name.toLowerCase(),
    };
  }

  EffectInfo? _effectByRef(String? ref) {
    if (ref == null) return null;
    final lower = ref.toLowerCase();
    return effects.where((e) => e.title == ref).firstOrNull ??
        effects.where((e) => _effectRefs(e).contains(lower)).firstOrNull;
  }

  bool isFavorite(EffectInfo e) {
    final refs = _effectRefs(e);
    return _favorites.any((f) => refs.contains(f.toLowerCase()));
  }

  void toggleFavorite(EffectInfo e) {
    final refs = _effectRefs(e);
    final favs = _favorites;
    final saved = favs.where((f) => refs.contains(f.toLowerCase())).toList();
    if (saved.isEmpty) {
      favs.add(e.baseTitle);
    } else {
      favs.removeAll(saved);
    }
    _settings['favorites'] = favs.toList()..sort();
    _save();
    notifyListeners();
  }

  /// Copies an `.ocfx`/`.json` or `.html` effect into the library and
  /// selects it. Throws [FormatException] with a user-facing message.
  EffectInfo importEffect(String sourcePath) {
    final ext = p.extension(sourcePath).toLowerCase();
    if (!{'.ocfx', '.json', '.html'}.contains(ext)) {
      throw FormatException(l10n.engineImportBadExtension);
    }
    // Validate before copying so a bad file never enters the library.
    final probe = ext == '.html'
        ? parseHtmlEffect(sourcePath, imported: true, force: true)
        : parseOcfx(sourcePath, imported: true);
    if (probe == null) {
      throw FormatException(l10n.engineImportUnreadable);
    }
    Directory(importedEffectsDir).createSync(recursive: true);
    final base = probe.baseTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final target = p.join(
      importedEffectsDir,
      '${base.isEmpty ? 'effect' : base}${ext == '.json' ? '.ocfx' : ext}',
    );
    File(sourcePath).copySync(target);
    _scanEffects();
    final added = effects.firstWhere(
      (e) => p.equals(e.path, target),
      orElse: () => effects.firstWhere((e) => e.baseTitle == probe.baseTitle),
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

  /// [force] shows [f] even while the effect is frozen (the effect or its
  /// settings changed meanwhile).
  void onFrame(CanvasFrame f, {bool force = false}) {
    // The reactive light draws its own frames.
    if (_alertUntil != null || (reactive && _reactiveColor != null)) return;
    if (frozen && frame != null && !force) return;
    frame = f;
    frameNotifier.value = f;
  }

  // ------------------------------------------------------------ profiles
  bool _applyingProfile = false;

  List<LightProfile> get profiles {
    final raw = _settings['profiles'];
    final list = raw is List && raw.isNotEmpty
        ? [for (final p in raw) LightProfile.fromJson(p as Map)]
        : LightProfile.defaults();
    for (final profile in list) {
      final effect = _effectByRef(profile.effect);
      if (effect != null) profile.effect = effect.title;
    }
    return list;
  }

  String? get activeProfile => _settings['profile'] as String?;

  /// Turns on the effect, settings and brightness saved in profile [id].
  void applyProfile(String id) {
    _keepUserChoice();
    _applyProfile(id);
  }

  void _applyProfile(String id) {
    final profile = profiles.where((p) => p.id == id).firstOrNull;
    if (profile == null) return;
    _applyingProfile = true;
    try {
      final effect = profile.effect == null
          ? null
          : _effectByRef(profile.effect);
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

  /// Programs that turn profile [id] on while they run.
  void setProfileApps(String id, List<String> apps) {
    final list = profiles;
    for (final p in list) {
      if (p.id == id) {
        p.apps = [
          for (final a in {for (final a in apps) a.trim().toLowerCase()})
            if (a.isNotEmpty) a,
        ];
      }
    }
    _settings['profiles'] = [for (final p in list) p.toJson()];
    _save();
    notifyListeners();
  }

  /// The profile a running program turned on, and that program.
  String? autoProfile;
  String? autoProfileApp;

  /// What was on before [autoProfile], to put back when the program
  /// closes; null once the user picks something else.
  _Lighting? _autoReturn;

  /// Turns on the first profile (in order) with a program in [running],
  /// and puts the lighting back when none runs any more.
  void _updateAutoProfile(Set<String> running) {
    final match = profileForPrograms(profiles, running);
    if (match?.$1.id == autoProfile) {
      if (autoProfileApp != match?.$2) {
        autoProfileApp = match?.$2;
        notifyListeners();
      }
      return;
    }
    if (match == null) {
      final back = _autoReturn;
      autoProfile = autoProfileApp = _autoReturn = null;
      _saveAuto();
      if (back != null) _restoreLighting(back);
      notifyListeners();
      return;
    }
    // From one program's profile to another's, the way back stays the
    // lighting from before the first.
    if (autoProfile == null) {
      final e = currentEffect;
      _autoReturn = (
        effect: e?.path,
        props: e == null ? {} : Map.of(effectSettings(e)),
        brightness: brightness,
        profile: activeProfile,
      );
    }
    autoProfile = match.$1.id;
    autoProfileApp = match.$2;
    _saveAuto();
    _applyProfile(match.$1.id);
  }

  /// The user picked an effect or profile: it stays after the program that
  /// turned a profile on closes.
  void _keepUserChoice() {
    if (_autoReturn == null) return;
    _autoReturn = null;
    _saveAuto();
  }

  /// Keeps the program's profile and the way back in the settings, so a
  /// restart in between still puts the lighting back.
  void _saveAuto() {
    final back = _autoReturn;
    if (autoProfile == null) {
      _settings.remove('autoProfile');
    } else {
      _settings['autoProfile'] = {
        'id': autoProfile,
        if (back != null)
          'back': {
            'effect': back.effect,
            'props': back.props,
            'brightness': back.brightness,
            'profile': back.profile,
          },
      };
    }
    _save();
  }

  void _loadAuto() {
    final j = _settings['autoProfile'];
    if (j is! Map) return;
    autoProfile = j['id'] as String?;
    final back = j['back'];
    if (back is Map) {
      _autoReturn = (
        effect: back['effect'] as String?,
        props: ((back['props'] as Map?) ?? {}).cast<String, dynamic>(),
        brightness: (back['brightness'] as num?)?.toInt() ?? brightness,
        profile: back['profile'] as String?,
      );
    }
  }

  /// The first of [profiles] with a program in [running], and that
  /// program.
  static (LightProfile, String)? profileForPrograms(
    List<LightProfile> profiles,
    Set<String> running,
  ) {
    for (final p in profiles) {
      final app = p.apps.where(running.contains).firstOrNull;
      if (app != null) return (p, app);
    }
    return null;
  }

  void _restoreLighting(_Lighting back) {
    _applyingProfile = true;
    try {
      final effect = effects.where((e) => e.path == back.effect).firstOrNull;
      if (effect != null) {
        effectSettings(effect)
          ..clear()
          ..addAll(back.props);
        selectEffect(effect);
      }
      setBrightness(back.brightness);
      if (back.profile == null) {
        _settings.remove('profile');
      } else {
        _settings['profile'] = back.profile;
      }
      _save();
    } finally {
      _applyingProfile = false;
    }
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
    if (_alertUntil == null) _beforeAlert = frame;
    _alertUntil = DateTime.now().add(const Duration(seconds: 4));
    _alertTick = 0;
  }

  /// The frame shown before the flash, put back after it while the effect
  /// is frozen and draws no new one.
  CanvasFrame? _beforeAlert;

  void _alertFrame() {
    if (DateTime.now().isAfter(_alertUntil!)) {
      _alertUntil = null;
      if (frozen && _beforeAlert != null) {
        frame = _beforeAlert;
        frameNotifier.value = frame;
      }
      _beforeAlert = null;
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
    for (final c in '${e.path.toLowerCase()}|${e.baseTitle}'.codeUnits) {
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
  List<PluginInfo> plugins = [];

  List<UserPlugin> userPlugins = [];
  late final String pluginsDir = p.join(dataDir, 'plugins');
  List<PluginFile> _bundledPlugins = [];
  PluginApprovals _approvals = PluginApprovals();
  final Map<int, (PluginInfo, PluginDevice)> _pluginModels = {};
  Timer? _pluginScan;
  Timer? _pluginWatchdog;
  bool _scanningPlugins = false;
  int _nextPluginId = -1;
  StreamSubscription<FileSystemEvent>? _pluginWatch;
  Timer? _pluginReloadDelay;
  Future<void> _pluginReload = Future.value();

  /// The built-in drivers still have to learn which devices plugins took.
  bool _claimsPending = false;

  int get pluginsPending =>
      userPlugins.where((u) => u.trust == PluginTrust.pending).length;

  Future<void> _loadBundledPlugins() async {
    try {
      Directory(p.join(pluginsDir, 'bundled')).deleteSync(recursive: true);
    } catch (_) {}
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = [
      for (final a in manifest.listAssets())
        if (a.startsWith('assets/plugins/') && a.endsWith('.js')) a,
    ]..sort();
    _bundledPlugins = [
      for (final a in assets)
        PluginFile.bundled(p.basename(a), await rootBundle.loadString(a)),
    ];
  }

  void _saveApprovals() {
    _settings['pluginApprovals'] = _approvals.toJson();
    _save();
  }

  Future<void> _readPlugins() async {
    final scan = await readAllPlugins(
      userDir: pluginsDir,
      bundled: _bundledPlugins,
      approvals: _approvals,
      elevated: Elevation.isElevated,
      language: l10n.localeName,
    );
    if (scan.approvalsChanged) _saveApprovals();
    plugins = scan.plugins;
    userPlugins = scan.userPlugins;
    _pluginModels.clear();
    for (final pl in [
      ...plugins.where((pl) => pl.bundled),
      ...plugins.where((pl) => !pl.bundled),
    ]) {
      for (final model in pl.devices) {
        _pluginModels[model.key] = (pl, model);
      }
    }
  }

  Future<void> approvePlugin(UserPlugin u) {
    _approvals.approve(u.file);
    _saveApprovals();
    return reloadPlugins();
  }

  Future<void> denyPlugin(UserPlugin u) {
    _approvals.deny(u.file);
    _saveApprovals();
    return reloadPlugins();
  }

  /// Reloads the plugins shortly after a .js file in [pluginsDir] changes
  /// (editors write a file in several steps).
  void _watchPlugins() {
    try {
      Directory(pluginsDir).createSync(recursive: true);
      _pluginWatch = Directory(pluginsDir)
          .watch()
          .where((e) => e.path.toLowerCase().endsWith('.js'))
          .listen((_) {
            _pluginReloadDelay?.cancel();
            _pluginReloadDelay = Timer(
              const Duration(milliseconds: 400),
              reloadPlugins,
            );
          });
    } catch (_) {
      // No watching (e.g. the folder is not writable): the button remains.
    }
  }

  /// Reads the plugins again without restarting the app. Devices whose
  /// plugin changed, appeared or went away start over, and the built-in
  /// drivers take or give back the devices whose claims changed.
  Future<void> reloadPlugins() =>
      _pluginReload = _pluginReload.then((_) => _reloadPlugins());

  Future<void> _reloadPlugins() async {
    if (_shuttingDown) return;
    final claimed = _pluginModels.keys.toSet();
    await _readPlugins();
    while (_scanningPlugins) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (_shuttingDown) return;
    _scanningPlugins = true;
    try {
      final stale = [
        for (final d in devices.values)
          if (d.source == DeviceSource.plugin && _pluginChanged(d)) d,
      ];
      for (final d in stale) {
        devices.remove(d.key);
      }
      notifyListeners();
      await _stopPlugins(stale);
    } finally {
      _scanningPlugins = false;
    }
    if (!setEquals(claimed, _pluginModels.keys.toSet())) {
      _claimsPending = true;
      _applyClaims();
    }
    await _scanPluginDevices();
    notifyListeners();
  }

  /// Whether the plugin now in charge of [d]'s model is not the one that
  /// is running it.
  bool _pluginChanged(DeviceInstance d) {
    final now = _pluginModels[d.model?.key]?.$1;
    return now == null ||
        now.path != d.plugin?.path ||
        now.stamp != d.plugin?.stamp;
  }

  void _applyClaims() {
    if (_claimsPending && drivers.setClaims(_pluginModels.keys)) {
      _claimsPending = false;
    }
  }

  /// Asks the plugins of [stopping] to leave their devices and waits (up to
  /// two seconds) for them to finish.
  Future<void> _stopPlugins(List<DeviceInstance> stopping) async {
    final running = stopping.where((d) => d.port != null).toList();
    for (final d in running) {
      d.port!.send({'t': 'stop'});
    }
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (running.any((d) => d.port != null) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Starts a plugin for every claimed device that is plugged in, and stops
  /// those that were unplugged.
  Future<void> _scanPluginDevices() async {
    if (_shuttingDown || _pluginModels.isEmpty || _scanningPlugins) return;
    _scanningPlugins = true;
    try {
      // Enumerating opens every HID collection; keep it off the UI isolate.
      final serialModels = {
        for (final e in _pluginModels.entries)
          if (e.value.$1.serialBaud != null) e.key,
      };
      final endpoints = [
        ...await Isolate.run(hidEnumerate),
        if (serialModels.isNotEmpty)
          ...await Isolate.run(serialEnumerateTask(serialModels)),
      ];
      if (_shuttingDown) return;
      final groups = <String, List<HidEndpointInfo>>{};
      for (final e in endpoints) {
        if (!_pluginModels.containsKey(e.vendorId << 16 | e.productId)) {
          continue;
        }
        if (e.usagePage == 0xF1D0) continue;
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
                '${plugin.serialBaud != null ? '${first.path} ' : 'HID '}${first.vendorId.toRadixString(16).padLeft(4, '0')}:'
                '${first.productId.toRadixString(16).padLeft(4, '0')}',
          }),
          source: DeviceSource.plugin,
          plugin: plugin,
          model: model,
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
    inbox.listen((msg) {
      if (msg is Map) {
        _onPluginMessage(d, msg);
      } else if (msg is List) {
        // An uncaught error in the plugin's isolate (it is about to exit).
        d.error = l10n.enginePluginStopped('${msg.first}');
      } else if (msg == null) {
        _onPluginExit(d);
      }
    });
    final ds = _deviceSettings(d.key);
    final values = <String, Object?>{
      for (final e in d.plugin!.settings.entries) e.key: e.value['default'],
      ...((ds['props'] as Map?) ?? {}).cast<String, Object?>(),
    }..updateAll((name, v) => _pluginValue(d, name, v));
    d.lastBeat = DateTime.now();
    d.worker = await Isolate.spawn(
      pluginWorkerMain,
      PluginWorkerArgs(
        sendPort: inbox.sendPort,
        pluginName: p.basename(d.plugin!.path),
        pluginSource: d.plugin!.source,
        allowedModels: {for (final m in d.plugin!.devices) m.key},
        endpoints: [for (final e in endpoints) e.toJson()],
        settings: values,
        deviceName: d.device.name,
        serialBaud: d.plugin!.serialBaud,
        language: l10n.localeName,
      ),
      debugName: 'plugin ${d.key}',
      onError: inbox.sendPort,
      onExit: inbox.sendPort,
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
      case 'thread':
        d.workerThread = m['id'] as int;
      case 'beat':
        d.lastBeat = DateTime.now();
      case 'layout':
        final j = jsonDecode(m['layout'] as String) as Map;
        d.update(
          DriverDevice.fromJson(
            _pluginLayout(d.device, j['zones'] as List? ?? []),
          ),
        );
        d.modes = [
          for (final mode in j['modes'] as List? ?? [])
            if (mode is Map) HardwareMode.fromPlugin(mode),
        ];
        d.screen = ScreenSpec.fromJson(j['screen']);
        d.status = _deviceSettings(d.key)['disabled'] == true
            ? 'disabled'
            : 'running';
        _ensureLayout(d);
        _applySavedMode(d);
        notifyListeners();
      case 'progress':
        final v = (m['value'] as num).toDouble();
        // Redraw only for visible steps: uploads report every chunk.
        if (d.screenProgress == null || (v - d.screenProgress!).abs() >= .01) {
          d.screenProgress = v;
          notifyListeners();
        }
      case 'screenDone':
        d.screenProgress = null;
        d._screenDone?.complete(m['ok'] == true);
        d._screenDone = null;
        notifyListeners();
      case 'battery':
        d.battery = m['level'] as int?;
        d.charging = m['charging'] == true;
        d.batteryFromSystem = false;
        notifyListeners();
      case 'log':
        d.logs.add(m['msg'] as String);
        if (d.logs.length > 200) d.logs.removeAt(0);
        _writePluginLog(d, m['msg'] as String);
        if (kDebugMode) debugPrint('[${d.name}] ${m['msg']}');
      case 'error':
        d.status = 'error';
        d.error = m['msg'] as String;
        notifyListeners();
      case 'rejected':
        d.status = 'unsupported';
        d.error = l10n.enginePluginRejected;
        notifyListeners();
      case 'stopped':
        d._screenDone?.complete(false);
        d._screenDone = null;
        d.inbox?.close();
        d.port = null;
        if (d.status == 'running' || d.status == 'starting') {
          d.status = 'stopped';
          notifyListeners();
        }
    }
  }

  // ---------------------------------------------------------------- screens
  /// The image last sent to [d]'s screen (a copy the app keeps), if any.
  String? screenImagePath(DeviceInstance d) {
    final path = _deviceSettings(d.key)['screenImage'] as String?;
    return path != null && File(path).existsSync() ? path : null;
  }

  /// How the image last sent to [d]'s screen was laid out.
  ScreenEdit screenEdit(DeviceInstance d) =>
      ScreenEdit.fromJson(_deviceSettings(d.key)['screenEdit']);

  /// Sends the picture or animation at [path] to [d]'s screen, where the
  /// device keeps it. True when the device took it.
  Future<bool> sendToScreen(
    DeviceInstance d,
    String path, {
    ScreenEdit edit = const ScreenEdit(),
  }) async {
    final spec = d.screen;
    final port = d.port;
    if (spec == null || port == null || d._screenDone != null) return false;
    d
      ..screenError = null
      ..screenProgress = 0;
    notifyListeners();
    try {
      if (edit.sources.length > spec.liveValues) {
        d.screenError = spec.liveValues == 0
            ? l10n.engineScreenNoLiveValues
            : l10n.engineScreenMaxLiveValues(spec.liveValues);
        return false;
      }
      final image = await loadScreenImage(path, spec, edit: edit);
      if (image.frames.isEmpty) throw const FormatException('empty image');
      final widgets = await renderScreenWidgets(spec, edit);
      final done = d._screenDone = Completer<bool>();
      port.send({
        't': 'screen',
        'width': spec.width,
        'height': spec.height,
        'frames': image.frames,
        'delays': image.delaysMs,
        'widgets': [for (final w in widgets) w.toJson()],
        'widgetGlyphs': [for (final w in widgets) w.glyphs],
      });
      final ok = await done.future;
      if (ok) {
        // Keep a copy for the preview: the original may move or vanish.
        final dir = Directory(p.join(dataDir, 'screens'))
          ..createSync(recursive: true);
        final name = d.key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
        final copy = p.join(
          dir.path,
          '$name${p.extension(path).toLowerCase()}',
        );
        final old = screenImagePath(d);
        if (old != null && old != copy) File(old).deleteSync();
        if (!p.equals(path, copy)) File(path).copySync(copy);
        _deviceSettings(d.key)
          ..['screenImage'] = copy
          ..['screenEdit'] = edit.toJson()
          ..remove('screenFill');
        _save();
      } else {
        d.screenError = l10n.engineScreenRejected;
      }
      return ok;
    } catch (e) {
      d.screenError = l10n.engineScreenCannotOpen;
      return false;
    } finally {
      d.screenProgress = null;
      d._screenDone = null;
      notifyListeners();
    }
  }

  /// Keeps plugin messages in %APPDATA%\OpenChroma\logs, one file per
  /// device, so they can be read after the fact.
  void _writePluginLog(DeviceInstance d, String msg) {
    try {
      final dir = Directory(p.join(dataDir, 'logs'))
        ..createSync(recursive: true);
      final name = d.key.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final file = File(p.join(dir.path, '$name.log'));
      if (file.existsSync() && file.lengthSync() > 512 * 1024) {
        file.writeAsStringSync('');
      }
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $msg\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  /// Sends each screen the live values its image shows.
  void _sendScreenValues() {
    final read = readSensor;
    if (read == null) return;
    for (final d in devices.values) {
      final port = d.port;
      if (d.screen == null || port == null || d._screenDone != null) continue;
      final sources = screenEdit(d).sources;
      if (sources.isEmpty) continue;
      port.send({
        't': 'values',
        'values': [for (final s in sources) read(s)?.round()],
      });
    }
  }

  /// The plugin's isolate ended. When that was not asked for (a crash), the
  /// device is dropped so the next scan starts the plugin again.
  void _onPluginExit(DeviceInstance d) {
    d._screenDone?.complete(false);
    d._screenDone = null;
    d.inbox?.close();
    d.port = null;
    if (_shuttingDown || devices[d.key] != d) return;
    if (d.status == 'running' || d.status == 'starting') {
      if (kDebugMode) debugPrint('[${d.name}] plugin exited: ${d.error}');
      devices.remove(d.key);
      notifyListeners();
    }
  }

  static const _pluginSilence = Duration(seconds: 20);

  // A JavaScript busy loop cannot be interrupted; park its thread instead.
  void _checkPluginHealth() {
    final now = DateTime.now();
    var changed = false;
    for (final d in devices.values) {
      if (d.source != DeviceSource.plugin || d.port == null) continue;
      if (d.status != 'running' && d.status != 'starting') continue;
      if (now.difference(d.lastBeat) < _pluginSilence) continue;
      d.status = 'error';
      d.error = l10n.pluginTrustUnresponsive;
      deprioritizeThread(d.workerThread ?? 0);
      d.worker?.kill(priority: Isolate.immediate);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Changes one of a plugin's settings for device [d].
  void setPluginSetting(DeviceInstance d, String name, Object? value) {
    final props =
        (_deviceSettings(d.key)['props'] ??= <String, dynamic>{}) as Map;
    props[name] = value;
    _save();
    d.port?.send({
      't': 'setting',
      'name': name,
      'value': _pluginValue(d, name, value),
    });
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

  /// The hardware effect [d] is running, if any.
  HardwareMode? activeHardwareMode(DeviceInstance d) =>
      d.modes.where((m) => m.name == d.activeMode).firstOrNull;

  /// Speed, brightness, colors... of [mode] on [d]: what the user chose,
  /// else what the device started with (see [HardwareMode.options]).
  Map<String, Object?> modeOptions(DeviceInstance d, HardwareMode mode) =>
      mode.options(
        ((_deviceSettings(d.key)['hwModeOptions'] as Map?) ?? {})[mode.name]
            as Map?,
      );

  /// Changes option [key] of the hardware effect [d] is running.
  void setModeOption(DeviceInstance d, String key, Object? value) {
    final name = d.activeMode;
    if (name == null) return;
    final all =
        (_deviceSettings(d.key)['hwModeOptions'] ??= <String, dynamic>{})
            as Map;
    ((all[name] ??= <String, dynamic>{}) as Map)[key] = value;
    _save();
    _sendMode(d, name);
    notifyListeners();
  }

  void _sendMode(DeviceInstance d, String? name) {
    final mode = name == null
        ? null
        : d.modes.where((m) => m.name == name).firstOrNull;
    d.activeMode = mode?.name;
    d.lastSent = null;
    final options = mode == null ? null : modeOptions(d, mode);
    if (d.source == DeviceSource.plugin) {
      d.port?.send({'t': 'mode', 'id': mode?.id, 'options': options});
    } else if (mode == null) {
      drivers.setMode(d.device.id, -1);
    } else {
      drivers.setModeOptions(
        d.device.id,
        mode.id as int,
        _driverModeOptions(mode, options!),
      );
    }
  }

  /// [options] as oc_drivers.dll takes them: the color source becomes
  /// OpenRGB's color mode.
  static Map<String, Object?> _driverModeOptions(
    HardwareMode mode,
    Map<String, Object?> options,
  ) => {
    for (final k in ['speed', 'brightness', 'direction'])
      if (options[k] != null) k: options[k],
    if (options['random'] == true)
      'colorMode': ModeColorMode.random
    else if (mode.hasColors) ...{
      'colorMode': ModeColorMode.modeSpecific,
      'colors': options['colors'],
    } else if (mode.ledColor) ...{
      'colorMode': ModeColorMode.perLed,
      'ledColor': options['ledColor'],
    },
  };

  void _applySavedMode(DeviceInstance d) {
    final saved = _deviceSettings(d.key)['hwMode'] as String?;
    if (saved != null && d.modes.any((m) => m.name == saved)) {
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
    _applyClaims();
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
        _applyDriverConfig(d);
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
          _applyDriverConfig(existing);
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
  static List<HardwareMode> _nativeModes(DriverDevice d) => [
    for (final m in d.modes)
      if (m.name.toLowerCase() != 'direct') m,
  ];

  static const _conflictingProcesses = {
    'signalrgb.exe': 'SignalRGB',
    'icue.exe': 'Corsair iCUE',
    'lghub.exe': 'Logitech G HUB',
    'rgbfusion.exe': 'Gigabyte RGB Fusion',
    'openrgb.exe': 'OpenRGB',
  };

  // ------------------------------------------------------------- batteries
  /// Batteries Windows reports for devices the app does not light (a
  /// Bluetooth headset, say); the others show on their device.
  List<WirelessBattery> otherBatteries = [];
  List<WirelessBattery> _batteries = [];

  Future<void> _checkBatteries() async {
    _batteries = await readBatteries();
    if (_shuttingDown) return;
    _applyBatteries();
  }

  /// Gives each device the battery Windows reports for its model, unless
  /// its plugin reports one itself.
  void _applyBatteries() {
    final matched = <WirelessBattery>{};
    for (final d in devices.values) {
      final model = hidModel(d);
      final b = model == null
          ? null
          : _batteries
                .where((b) => b.vid == model.$1 && b.pid == model.$2)
                .firstOrNull;
      if (b != null) matched.add(b);
      if (d.battery != null && !d.batteryFromSystem) continue;
      d
        ..battery = b?.level
        ..charging = false
        ..batteryFromSystem = b != null;
    }
    otherBatteries = [
      for (final b in _batteries)
        if (!matched.contains(b)) b,
    ];
    notifyListeners();
  }

  /// [d]'s USB vendor and product ids, from its plugin or from the HID path
  /// the drivers report ("...VID_3151&PID_4015...").
  static (int, int)? hidModel(DeviceInstance d) {
    final m = d.model;
    if (m != null) return (m.vid, m.pid);
    final match = RegExp(
      r'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})',
      caseSensitive: false,
    ).firstMatch(d.device.location);
    if (match == null) return null;
    return (int.parse(match[1]!, radix: 16), int.parse(match[2]!, radix: 16));
  }

  /// Looks at the running programs: other lighting apps that fight over
  /// the devices, and programs that turn a profile on.
  Future<void> _checkProcesses() async {
    try {
      final running = await runningProcesses();
      if (_shuttingDown) return;
      _updateAutoProfile(running);
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

  /// Changes a driver-specific option (see [DriverDevice.configSchema]); it
  /// is kept and applied again whenever the device is detected.
  void setDriverConfig(DeviceInstance d, Map<String, Object?> values) {
    final saved =
        (_deviceSettings(d.key)['driverConfig'] ??= <String, dynamic>{}) as Map;
    saved.addAll(values);
    _save();
    drivers.setConfig(d.device.id, values);
    d.lastSent = null;
    notifyListeners();
  }

  /// Lights only zone [zone] of [d] with a pure color; null goes back to
  /// the effect.
  void setTestColor(
    DeviceInstance d,
    int? zone, [
    int r = 0,
    int g = 0,
    int b = 0,
    int? count,
  ]) {
    if (zone != null && identical(_identifiedZone?.$1, d)) {
      stopIdentifyingZone();
    }
    d.testColor = zone == null ? null : (zone, r, g, b);
    d.testCount = zone == null ? null : count;
    d.lastSent = null;
  }

  void identifyZone(DeviceInstance device, LedZone zone) {
    if (_shuttingDown ||
        device.status != 'running' ||
        device.activeMode != null ||
        device.testColor != null ||
        zone.leds.isEmpty ||
        !device.zones.contains(zone)) {
      return;
    }
    stopIdentifyingZone();
    _identifiedZone = (device, zone, true);
    device.lastSent = null;
    _identifyTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (timer.tick >= 3 ||
          !identical(devices[device.key], device) ||
          !device.zones.contains(zone)) {
        stopIdentifyingZone();
        return;
      }
      _identifiedZone = (device, zone, timer.tick.isEven);
      device.lastSent = null;
    });
  }

  void stopIdentifyingZone() {
    _identifyTimer?.cancel();
    _identifyTimer = null;
    final identified = _identifiedZone;
    _identifiedZone = null;
    if (identified != null && frame != null) identified.$1.lastSent = null;
  }

  /// Puts [d] back as it was first detected: driver options (the values
  /// the hardware reported then), the app's effects instead of a hardware
  /// effect, plugin settings and its place in the layout. LED counts stay:
  /// they describe what is plugged in.
  void resetDevice(DeviceInstance d) {
    final ds = _deviceSettings(d.key);
    final original = (ds['driverConfigOriginal'] as Map?)
        ?.cast<String, Object?>();
    ds
      ..remove('driverConfig')
      ..remove('hwMode')
      ..remove('hwModeOptions')
      ..remove('props')
      ..remove('layout');
    if (original != null && original.isNotEmpty) {
      drivers.setConfig(d.device.id, original);
    }
    _sendMode(d, null);
    if (d.source == DeviceSource.plugin) {
      for (final e in d.plugin!.settings.entries) {
        d.port?.send({
          't': 'setting',
          'name': e.key,
          'value': e.value['default'],
        });
      }
    }
    _ensureLayout(d);
    _save();
    notifyListeners();
  }

  /// Whether [d] has anything to reset.
  bool isCustomized(DeviceInstance d) {
    final ds = _deviceSettings(d.key);
    return ds['driverConfig'] != null ||
        ds['hwMode'] != null ||
        ds['hwModeOptions'] != null ||
        ds['props'] != null;
  }

  /// The option's value: what the user chose, else what the driver reports.
  Object? driverConfigValue(DeviceInstance d, String key) =>
      ((_deviceSettings(d.key)['driverConfig'] as Map?) ?? {})[key] ??
      d.device.configValues[key];

  void _applyDriverConfig(DeviceInstance d) {
    final ds = _deviceSettings(d.key);
    if (ds['driverConfigOriginal'] == null &&
        d.device.configValues.isNotEmpty) {
      ds['driverConfigOriginal'] = Map.of(d.device.configValues);
      _save();
    }
    final saved = (ds['driverConfig'] as Map?) ?? {};
    if (saved.isEmpty) return;
    drivers.setConfig(d.device.id, saved.cast<String, Object?>());
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
    _writeLayout(d, zoneKey, item);
    _save();
    notifyListeners();
  }

  void setLayouts(Map<(String, String), LayoutItem> placements) {
    var changed = false;
    for (final MapEntry(key: (deviceKey, zoneKey), value: item)
        in placements.entries) {
      final device = devices[deviceKey];
      if (device == null || !device.zones.any((zone) => zone.key == zoneKey)) {
        continue;
      }
      _writeLayout(device, zoneKey, item);
      changed = true;
    }
    if (changed) {
      _save();
      notifyListeners();
    }
  }

  void _writeLayout(DeviceInstance d, String zoneKey, LayoutItem item) {
    final layout =
        (_deviceSettings(d.key)['layout'] ??= <String, dynamic>{}) as Map;
    item.x = item.x.clamp(-canvasWidth, canvasWidth * 2);
    item.y = item.y.clamp(-canvasHeight, canvasHeight * 2);
    item.scale = item.scale > 0 ? math.min(item.scale, 60) : .5;
    layout[zoneKey] = _layoutJson(d, zoneKey, item);
    d.lastSent = null;
  }

  /// [item] as saved, with the size of the zone's grid it was made for.
  Map<String, Object> _layoutJson(
    DeviceInstance d,
    String zoneKey,
    LayoutItem item,
  ) {
    final zone = d.zones.where((z) => z.key == zoneKey).firstOrNull;
    return {...item.toJson(), 'w': ?zone?.width, 'h': ?zone?.height};
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
      final saved = layout[z.key];
      // A place made for another grid (a plugin that now lights every key
      // instead of one color) would stretch the new one: start over.
      final stale =
          saved is Map &&
          (saved['w'] != null
              ? saved['w'] != z.width || saved['h'] != z.height
              : z.width * (saved['scale'] as num) > canvasWidth * 2 ||
                    z.height * (saved['scale'] as num) > canvasHeight * 2);
      if (saved is! Map || stale) {
        layout[z.key] = _layoutJson(d, z.key, _defaultLayout(d, z.key));
        changed = true;
      } else if (saved['w'] == null) {
        saved['w'] = z.width;
        saved['h'] = z.height;
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
      final (x, y) = item.pointOf(zone, pos[0] + .5, pos[1] + .5);
      final x0 = (item.x + (x - .5) * item.scale) * sx,
          y0 = (item.y + (y - .5) * item.scale) * sy;
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
    // The hue, not the dimmed level: a thumbnail at 20% would just be grey.
    final sx = f.width / canvasWidth, sy = f.height / canvasHeight;
    return [
      for (var i = 0; i < n; i++)
        () {
          final (x, y) = item.pointOf(
            zone,
            zone.width * (i + .5) / n,
            zone.height / 2,
          );
          final px = ((item.x + x * item.scale) * sx).floor().clamp(
            0,
            f.width - 1,
          );
          final py = ((item.y + y * item.scale) * sy).floor().clamp(
            0,
            f.height - 1,
          );
          final o = (py * f.width + px) * 3;
          return Color.fromARGB(255, f.rgb[o], f.rgb[o + 1], f.rgb[o + 2]);
        }(),
    ];
  }

  @visibleForTesting
  void pushFrames() {
    final f = frame;
    // An alert flash must show even with the lights dimmed or off.
    final alert = _alertUntil != null;
    final master = alert ? 1.0 : brightness / 100.0;
    final still = frozen && !alert;
    for (final d in devices.values) {
      if (d.status != 'running' || d.device.ledCount == 0) continue;
      if (d.activeMode != null) continue;
      final identified = _identifiedZone;
      final identify =
          !alert &&
              identified != null &&
              identical(identified.$1, d) &&
              d.zones.contains(identified.$2)
          ? identified
          : null;
      if (f == null && identify == null && d.lastSent == null) continue;
      final b = alert ? 1.0 : master * deviceBrightness(d) / 100;
      if (f != null &&
          still &&
          d.lastSent != null &&
          identical(d._sentFrame, f) &&
          d._sentLevel == b) {
        continue;
      }
      d._sentFrame = f;
      d._sentLevel = b;
      final out = Uint8List(d.device.ledCount * 3);
      final test = d.testColor;
      if (test != null) {
        final z = d.device.zones[test.$1];
        final lit = math.min(z.count, d.testCount ?? z.count);
        for (var i = z.start; i < z.start + lit; i++) {
          out[i * 3] = test.$2;
          out[i * 3 + 1] = test.$3;
          out[i * 3 + 2] = test.$4;
        }
      } else {
        if (f != null) {
          for (final z in d.zones) {
            _sampleZone(z, layoutOf(d, z.key), f, b, out);
          }
        }
        if (identify != null) {
          final level = identify.$3 ? 160 : 0;
          for (final led in identify.$2.leds) {
            final offset = led * 3;
            if (offset < 0 || offset + 2 >= out.length) continue;
            out[offset] = level;
            out[offset + 1] = level;
            out[offset + 2] = level;
          }
        }
      }
      // Static effects would resend the same colors 30 times a second;
      // once a second is kept so a device that slips back to its own
      // effect is brought back.
      final last = d.lastSent;
      final now = DateTime.now();
      if (last != null &&
          listEquals(last, out) &&
          (still ||
              now.difference(d.lastSentAt) < const Duration(seconds: 1))) {
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
    stopIdentifyingZone();
    _tick?.cancel();
    _rescan?.cancel();
    _devicePoll?.cancel();
    _pluginScan?.cancel();
    _pluginWatchdog?.cancel();
    _batteryCheck?.cancel();
    _screenValues?.cancel();
    _pluginWatch?.cancel();
    _pluginReloadDelay?.cancel();
    audio.setSource(AudioSource.off);
    _saveDebounce?.cancel();
    try {
      File(_settingsFile).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_settings),
      );
    } catch (_) {}
    // Plugins get a moment to leave their devices in a sensible state.
    await _stopPlugins(devices.values.toList());
    drivers.shutdown();
  }
}
