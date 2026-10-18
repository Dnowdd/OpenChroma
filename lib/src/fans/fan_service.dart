import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../monitor/system_monitor.dart';
import '../paths.dart';

/// Who drives a fan.
enum FanMode {
  /// The BIOS (motherboard headers) or the driver (GPU).
  auto,

  /// The shared profile curve, against a temperature.
  curve,

  /// A fixed duty cycle.
  fixed,
}

enum FanProfile { silent, balanced, turbo, custom }

enum TempSource { cpu, gpu }

/// A fan curve: (temperature °C, speed %) points, ordered by temperature.
typedef FanCurve = List<(double, double)>;

/// Why the motherboard headers can or cannot be used.
enum SuperIoStatus {
  ok,
  pending,

  /// PawnIO only opens for elevated processes.
  needsAdmin,

  /// PawnIO is not installed.
  noDriver,

  /// No supported Super I/O chip.
  notFound,

  /// Another program held the bus while probing.
  busy;

  static SuperIoStatus parse(String? s) => switch (s) {
    'ok' => ok,
    'needs_admin' => needsAdmin,
    'no_driver' => noDriver,
    'not_found' => notFound,
    'busy' => busy,
    _ => pending,
  };
}

double? _d(Object? v) => (v as num?)?.toDouble();

/// One fan channel as the native side reports it.
class FanReading {
  FanReading(Map j)
    : id = j['id'] as String? ?? '',
      gpu = j['group'] == 'gpu',
      device = j['device'] as String? ?? '',
      index = j['index'] as int? ?? 0,
      rpm = _d(j['rpm']),
      duty = _d(j['duty']),
      controllable = j['controllable'] as bool? ?? false,
      controlled = j['controlled'] as bool? ?? false;

  final String id;

  /// A GPU cooler, otherwise a motherboard header.
  final bool gpu;

  /// Chip or GPU name.
  final String device;
  final int index;
  final double? rpm;

  /// Duty cycle in percent; null while the BIOS drives a header.
  final double? duty;
  final bool controllable;

  /// OpenChroma currently holds this channel.
  final bool controlled;
}

class FanSnapshot {
  FanSnapshot(Map j)
    : elevated = j['elevated'] as bool? ?? false,
      superIo = SuperIoStatus.parse(j['superio'] as String?),
      chip = j['chip'] as String? ?? '',
      nvidia = j['nvidia'] as String? ?? '',
      conflict = j['conflict'] as String? ?? '',
      fans = [for (final f in j['fans'] as List? ?? []) FanReading(f as Map)];

  final bool elevated;
  final SuperIoStatus superIo;
  final String chip;
  final String nvidia;

  /// A running fan program that would fight over the fans, or ''.
  final String conflict;
  final List<FanReading> fans;
}

/// What the user chose for one fan.
class FanSettings {
  FanSettings();

  FanSettings.fromJson(Map j)
    : name = j['name'] as String?,
      mode = FanMode.values.asNameMap()[j['mode']] ?? FanMode.auto,
      fixed = (j['fixed'] as num?)?.toDouble() ?? 50,
      source = TempSource.values.asNameMap()[j['source']],
      zeroRpm = j['zeroRpm'] as bool? ?? false,
      pump = j['pump'] as bool? ?? false;

  /// User-given name; null keeps the default.
  String? name;
  FanMode mode = FanMode.auto;
  double fixed = 50;

  /// Null follows the default for the fan (GPU fans the GPU, others the CPU).
  TempSource? source;

  /// Stop the fan below [FanService.stopBelow].
  bool zeroRpm = false;

  /// A water cooling pump: never slower than [FanService.pumpMinimum], never
  /// stopped.
  bool pump = false;

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    'mode': mode.name,
    'fixed': fixed,
    if (source != null) 'source': source!.name,
    'zeroRpm': zeroRpm,
    'pump': pump,
  };
}

/// Reads the fans through the native sampler (windows/runner/fan_control.cpp)
/// once per second and drives the ones not left on [FanMode.auto]. Choices
/// live in %APPDATA%\OpenChroma\fans.json.
class FanService extends ChangeNotifier {
  FanService(this.monitor) {
    try {
      final exe = DynamicLibrary.executable();
      _start = exe.lookupFunction<Void Function(), void Function()>(
        'OcFansStart',
      );
      _read = exe
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)
          >('OcFansRead');
      _set = exe
          .lookupFunction<
            Void Function(Pointer<Utf8>, Int32),
            void Function(Pointer<Utf8>, int)
          >('OcFansSet');
    } catch (_) {
      // Not available (tests, other platforms).
    }
  }

  final SystemMonitor monitor;

  static const presets = <FanProfile, FanCurve>{
    // Modern CPUs idle warm and boost toward 95 °C, so the curves stay calm
    // through the 60s and 70s.
    FanProfile.silent: [(30, 20), (60, 25), (75, 40), (85, 65), (95, 100)],
    FanProfile.balanced: [(30, 30), (60, 35), (75, 55), (85, 80), (95, 100)],
    FanProfile.turbo: [(30, 45), (60, 60), (75, 80), (85, 100), (95, 100)],
  };

  /// Zero RPM: stops below this temperature and starts again 5 °C above.
  static const stopBelow = 40.0;
  static const pumpMinimum = 70.0;

  /// Largest change per second, so speed changes are heard as a ramp.
  static const _stepUp = 10.0;
  static const _stepDown = 4.0;

  void Function()? _start;
  int Function(Pointer<Utf8>, int)? _read;
  void Function(Pointer<Utf8>, int)? _set;

  Pointer<Utf8> _buf = nullptr;
  int _cap = 0;
  Timer? _timer;
  Timer? _saveDebounce;
  bool _stopped = false;

  FanSnapshot? snapshot;
  FanProfile profile = FanProfile.balanced;

  /// The user said which header holds the pump, or that there is none.
  /// Nothing on the hardware tells a pump from a fan, so the app asks.
  bool pumpAnswered = false;
  FanCurve customCurve = [...presets[FanProfile.balanced]!];
  final Map<String, FanSettings> _settings = {};

  /// Last duty sent per fan, the starting point of the next ramp step.
  final Map<String, double> _output = {};
  final Set<String> _resting = {};

  /// Fans seen spinning since launch; empty headers stay out of the way.
  final Set<String> _seenSpinning = {};

  bool get available => _read != null;

  String get _file => p.join(openChromaDataDir(), 'fans.json');

  void start() {
    if (!available || _timer != null) return;
    _load();
    _start!();
    Timer.run(_tick);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Hands every fan back to the BIOS / driver; call before exiting.
  void shutdown() {
    _stopped = true;
    _timer?.cancel();
    _save();
    releaseAll();
  }

  /// Returns every fan to firmware control, for exits that skip [shutdown].
  static void releaseAll() {
    try {
      DynamicLibrary.executable()
          .lookupFunction<Void Function(), void Function()>(
            'OcFansReleaseAll',
          )();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- Model

  FanSettings settingsOf(String id) => _settings[id] ?? FanSettings();

  FanSettings _edit(String id) => _settings.putIfAbsent(id, FanSettings.new);

  String defaultName(FanReading f) =>
      f.gpu ? 'GPU ${f.index + 1}' : 'Ventoinha ${f.index + 1}';

  String nameOf(FanReading f) {
    final n = _settings[f.id]?.name?.trim();
    return n == null || n.isEmpty ? defaultName(f) : n;
  }

  TempSource sourceOf(FanReading f) =>
      _settings[f.id]?.source ?? (f.gpu ? TempSource.gpu : TempSource.cpu);

  FanCurve get curve =>
      profile == FanProfile.custom ? customCurve : presets[profile]!;

  /// Fans worth showing: GPU coolers (they rest at idle), headers that spun
  /// at some point, and anything the user configured.
  /// Ask which fan is the pump: motherboard headers are connected and the
  /// question was never answered.
  bool get askPump =>
      !pumpAnswered &&
      !_settings.values.any((s) => s.pump) &&
      (snapshot?.fans.any((f) => !f.gpu && isConnected(f)) ?? false);

  /// Marks fan [id] as the pump, or with null records that there is none.
  void answerPump(String? id) {
    pumpAnswered = true;
    if (id != null) {
      setPump(id, true);
    } else {
      _changed();
    }
  }

  bool isConnected(FanReading f) =>
      f.gpu ||
      _seenSpinning.contains(f.id) ||
      settingsOf(f.id).mode != FanMode.auto;

  double? temperature(TempSource s) {
    final m = monitor.snapshot;
    return switch (s) {
      TempSource.cpu => m?.cpu.temp,
      TempSource.gpu =>
        m?.gpus.where((g) => !g.integrated).firstOrNull?.temp ??
            m?.gpus.firstOrNull?.temp,
    };
  }

  /// The temperatures curves follow: they rise within a few seconds and
  /// fall over about half a minute, so short spikes (CPU boost) do not rev
  /// the fans.
  final Map<TempSource, double> _smoothed = {};

  double? controlTemperature(TempSource s) => _smoothed[s] ?? temperature(s);

  void _smooth() {
    for (final source in TempSource.values) {
      final t = temperature(source);
      final prev = _smoothed[source];
      if (t == null) {
        _smoothed.remove(source);
      } else {
        _smoothed[source] = prev == null
            ? t
            : prev + (t - prev) * (t > prev ? .3 : .08);
      }
    }
  }

  /// Duty the curve asks for at [t].
  static double speedAt(FanCurve curve, double t) {
    if (t <= curve.first.$1) return curve.first.$2;
    for (var i = 1; i < curve.length; i++) {
      final (t1, s1) = curve[i];
      final (t0, s0) = curve[i - 1];
      if (t <= t1) return t1 == t0 ? s1 : s0 + (s1 - s0) * (t - t0) / (t1 - t0);
    }
    return curve.last.$2;
  }

  /// Why fan [f] cannot be driven from here, or null.
  String? blockedReason(FanReading f) {
    final s = snapshot;
    if (s != null && s.conflict.isNotEmpty) return '${s.conflict} está aberto';
    if (!f.controllable) {
      return s != null && !s.elevated
          ? 'Controlar pede o modo administrador'
          : 'Somente leitura';
    }
    return null;
  }

  // ---------------------------------------------------------------- Edits

  void rename(String id, String name) {
    _edit(id).name = name.trim().isEmpty ? null : name.trim();
    _changed();
  }

  void setMode(String id, FanMode mode) {
    final s = _edit(id);
    if (s.mode == mode) return;
    s.mode = mode;
    // Ramp from what the fan does now, not from a stale value.
    _output.remove(id);
    _changed(apply: true);
  }

  void setFixed(String id, double value) {
    _edit(id).fixed = value.clamp(0, 100).roundToDouble();
    _changed(apply: true);
  }

  void setSource(String id, TempSource source) {
    _edit(id).source = source;
    _changed(apply: true);
  }

  void setZeroRpm(String id, bool on) {
    _edit(id).zeroRpm = on;
    _changed(apply: true);
  }

  void setPump(String id, bool on) {
    pumpAnswered = true;
    final s = _edit(id)..pump = on;
    if (on) s.zeroRpm = false;
    _changed(apply: true);
  }

  void setProfile(FanProfile value) {
    if (profile == value) return;
    profile = value;
    _changed(apply: true);
  }

  /// Moves point [i] of the custom curve, keeping temperatures ordered.
  void moveCustomPoint(int i, double t, double s) {
    final lo = i == 0 ? 20.0 : customCurve[i - 1].$1 + 1;
    final hi = i == customCurve.length - 1 ? 100.0 : customCurve[i + 1].$1 - 1;
    customCurve[i] = (
      t.clamp(lo, math.max(lo, hi)).roundToDouble(),
      s.clamp(0, 100).roundToDouble(),
    );
    profile = FanProfile.custom;
    _changed(apply: true);
  }

  /// Starts the custom curve from the current one before editing it.
  void beginCustomEdit() {
    if (profile == FanProfile.custom) return;
    customCurve = [...curve];
    profile = FanProfile.custom;
    _changed();
  }

  void _changed({bool apply = false}) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _save);
    if (apply) _control();
    notifyListeners();
  }

  // ---------------------------------------------------------------- Loop

  void _tick() {
    if (_stopped) return;
    final s = _readSnapshot();
    if (s != null) {
      snapshot = s;
      for (final f in s.fans) {
        if ((f.rpm ?? 0) > 0) _seenSpinning.add(f.id);
      }
    }
    _smooth();
    _control();
    notifyListeners();
  }

  FanSnapshot? _readSnapshot() {
    final read = _read!;
    var n = read(_buf, _cap);
    if (n == 0) return null;
    if (n >= _cap) {
      if (_buf != nullptr) malloc.free(_buf);
      _cap = n + 16 * 1024;
      _buf = malloc<Uint8>(_cap).cast();
      n = read(_buf, _cap);
      if (n == 0 || n >= _cap) return null;
    }
    try {
      return FanSnapshot(
        jsonDecode(
          utf8.decode(_buf.cast<Uint8>().asTypedList(n), allowMalformed: true),
        ) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  /// Computes and sends every fan's duty. Sending also feeds the native
  /// watchdog, which releases fans that stop getting commands.
  void _control() {
    final s = snapshot;
    if (s == null || _stopped) return;
    var curves = false;
    for (final f in s.fans) {
      final cfg = settingsOf(f.id);
      if (cfg.mode == FanMode.curve) curves = true;
      final target = blockedReason(f) == null
          ? _target(f, cfg, track: true)
          : null;
      if (target == null) {
        if (_output.remove(f.id) != null || f.controlled) _send(f.id, -1);
        continue;
      }
      // Ramp curve changes; fixed values apply at once, and a resting fan
      // goes straight to its target (a small duty may not start it).
      var out = target;
      final prev = _output[f.id] ?? f.duty;
      if (cfg.mode == FanMode.curve && prev != null && prev >= 1) {
        out = target > prev
            ? math.min(target, prev + _stepUp)
            : math.max(target, prev - _stepDown);
      }
      _output[f.id] = out;
      _send(f.id, out.round());
    }
    // Curves need temperatures even with no page showing them.
    monitor.setActive(this, curves);
  }

  /// With [track], also updates the zero RPM hysteresis.
  double? _target(FanReading f, FanSettings cfg, {bool track = false}) {
    double v;
    switch (cfg.mode) {
      case FanMode.auto:
        return null;
      case FanMode.fixed:
        v = cfg.fixed;
      case FanMode.curve:
        final t = controlTemperature(sourceOf(f));
        // No reading: the BIOS / driver curve is the safe fallback.
        if (t == null) return null;
        v = speedAt(curve, t);
        if (cfg.zeroRpm && !cfg.pump) {
          if (track && t < stopBelow) _resting.add(f.id);
          if (track && t >= stopBelow + 5) _resting.remove(f.id);
          if (_resting.contains(f.id) || t < stopBelow) v = 0;
        }
    }
    if (cfg.pump) v = math.max(v, pumpMinimum);
    return v.clamp(0, 100).toDouble();
  }

  /// The duty fan [f] is heading to under its settings, for the UI.
  double? targetOf(FanReading f) =>
      blockedReason(f) == null ? _target(f, settingsOf(f.id)) : null;

  void _send(String id, int percent) {
    final set = _set;
    if (set == null) return;
    using((arena) => set(id.toNativeUtf8(allocator: arena), percent));
  }

  // ---------------------------------------------------------------- Storage

  void _load() {
    try {
      final f = File(_file);
      if (!f.existsSync()) return;
      // Editors on Windows may add a byte order mark.
      final text = f.readAsStringSync().replaceFirst('﻿', '');
      final j = jsonDecode(text) as Map;
      profile = FanProfile.values.asNameMap()[j['profile']] ?? profile;
      pumpAnswered = j['pumpAnswered'] as bool? ?? false;
      final c = j['custom'] as List?;
      if (c != null && c.length >= 2) {
        customCurve = [
          for (final pt in c)
            ((pt as List)[0] as num, pt[1] as num).toDoubles(),
        ];
      }
      final fans = j['fans'] as Map? ?? {};
      for (final e in fans.entries) {
        _settings[e.key as String] = FanSettings.fromJson(e.value as Map);
      }
    } catch (_) {
      // A broken file starts from the defaults.
    }
  }

  void _save() {
    _saveDebounce?.cancel();
    try {
      File(_file).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'profile': profile.name,
          'pumpAnswered': pumpAnswered,
          'custom': [
            for (final (t, s) in customCurve) [t, s],
          ],
          'fans': {for (final e in _settings.entries) e.key: e.value.toJson()},
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    shutdown();
    if (_buf != nullptr) malloc.free(_buf);
    super.dispose();
  }
}

extension on (num, num) {
  (double, double) toDoubles() => ($1.toDouble(), $2.toDouble());
}
