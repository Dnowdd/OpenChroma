import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import '../fans/fan_service.dart';
import '../i18n/l10n.dart';
import '../monitor/system_monitor.dart';
import '../paths.dart';

enum AlertLevel { warning, critical }

/// Something about the PC that needs attention.
class PcAlert {
  const PcAlert(this.key, this.kind, this.title, this.detail, this.level);

  /// Stable identity, so the same problem is not announced twice.
  final String key;

  /// temp, memory, disk or fan (picks the icon).
  final String kind;
  final String title;
  final String detail;
  final AlertLevel level;
}

String _fmt(double v, int decimals) {
  final text = v.toStringAsFixed(decimals);
  return l10n.localeName == 'pt' ? text.replaceAll('.', ',') : text;
}

String _gb(double bytes) => '${_fmt(bytes / (1 << 30), 1)} GB';

/// Thresholds as (warm, hot) in °C.
const cpuLimits = (75.0, 90.0);
const gpuLimits = (75.0, 85.0);
const ssdLimits = (60.0, 70.0);

/// Everything worth flagging in one reading.
List<PcAlert> evaluateAlerts(SystemSnapshot s, {FanService? fans}) {
  final out = <PcAlert>[];
  void temp(String key, String what, double? t, (double, double) limits) {
    if (t == null || t < limits.$1) return;
    final hot = t >= limits.$2;
    out.add(
      PcAlert(
        'temp:$key',
        'temp',
        hot ? l10n.alertsTempHot(what) : l10n.alertsTempWarm(what),
        l10n.alertsTempNow(_fmt(t, 0)),
        hot ? AlertLevel.critical : AlertLevel.warning,
      ),
    );
  }

  temp('cpu', 'CPU', s.cpu.temp, cpuLimits);
  final gpu =
      s.gpus.where((g) => !g.integrated).firstOrNull ?? s.gpus.firstOrNull;
  temp('gpu', 'GPU', gpu?.temp, gpuLimits);
  for (final d in s.disks) {
    temp(
      'disk${d.number}',
      d.model.isEmpty ? l10n.alertsDiskFallback : d.model,
      d.temp,
      ssdLimits,
    );
  }
  if (s.memory.percent >= 90) {
    out.add(
      PcAlert(
        'memory',
        'memory',
        l10n.alertsMemoryTitle,
        l10n.alertsMemoryDetail(
          _fmt(s.memory.percent, 0),
          _gb(s.memory.available),
        ),
        s.memory.percent >= 95 ? AlertLevel.critical : AlertLevel.warning,
      ),
    );
  }
  for (final v in s.volumes) {
    if (v.percent < 90 || v.removable) continue;
    out.add(
      PcAlert(
        'volume:${v.letter}',
        'disk',
        l10n.alertsVolumeTitle(v.letter),
        l10n.alertsVolumeDetail(_gb(v.free), _gb(v.total)),
        v.percent >= 95 ? AlertLevel.critical : AlertLevel.warning,
      ),
    );
  }
  // A stopped pump cooks the CPU within minutes.
  final fs = fans?.snapshot;
  if (fans != null && fs != null) {
    for (final f in fs.fans) {
      if (!fans.settingsOf(f.id).pump) continue;
      final rpm = f.rpm;
      if (rpm != null && rpm < 300) {
        out.add(
          PcAlert(
            'pump:${f.id}',
            'fan',
            l10n.alertsPumpTitle,
            l10n.alertsPumpDetail(fans.nameOf(f), rpm.round()),
            AlertLevel.critical,
          ),
        );
      }
    }
  }
  return out;
}

/// Watches the PC in the background and tells the user about problems with
/// a Windows notification (and, optionally, a red flash on the LEDs), even
/// while the app sits in the tray. A problem must last a few seconds to
/// count, and the same one is announced at most every 15 minutes.
class AlertService extends ChangeNotifier {
  AlertService({
    required this.monitor,
    required this.fans,
    required this.engine,
  }) {
    _load();
    try {
      _notify = DynamicLibrary.executable()
          .lookupFunction<
            Void Function(Pointer<Utf16>, Pointer<Utf16>),
            void Function(Pointer<Utf16>, Pointer<Utf16>)
          >('OcTrayNotify');
    } catch (_) {}
    monitor.addListener(_onReading);
    _apply();
  }

  final SystemMonitor monitor;
  final FanService fans;
  final Engine engine;

  bool notify = true;
  bool flashLeds = false;

  void Function(Pointer<Utf16>, Pointer<Utf16>)? _notify;
  final _since = <String, DateTime>{};
  final _announced = <String, DateTime>{};

  static const _sustain = Duration(seconds: 8);
  static const _cooldown = Duration(minutes: 15);

  String get _file => p.join(openChromaDataDir(), 'alerts.json');

  void _load() {
    try {
      final j = jsonDecode(File(_file).readAsStringSync()) as Map;
      notify = j['notify'] as bool? ?? true;
      flashLeds = j['flashLeds'] as bool? ?? false;
    } catch (_) {}
  }

  void _save() {
    try {
      File(_file).writeAsStringSync(
        jsonEncode({'notify': notify, 'flashLeds': flashLeds}),
      );
    } catch (_) {}
  }

  void setNotify(bool v) {
    notify = v;
    _save();
    _apply();
    notifyListeners();
  }

  void setFlashLeds(bool v) {
    flashLeds = v;
    _save();
    _apply();
    notifyListeners();
  }

  /// Keeps the monitor sampling while someone wants to hear about problems.
  void _apply() => monitor.setActive(this, notify || flashLeds);

  void _onReading() {
    final s = monitor.snapshot;
    if (s == null) return;
    final now = DateTime.now();
    final current = evaluateAlerts(s, fans: fans);
    final keys = {for (final a in current) a.key};
    _since.removeWhere((k, _) => !keys.contains(k));
    for (final a in current) {
      // Only critical problems interrupt; warnings stay on the home page.
      if (a.level != AlertLevel.critical) continue;
      final since = _since.putIfAbsent(a.key, () => now);
      if (now.difference(since) < _sustain) continue;
      final last = _announced[a.key];
      if (last != null && now.difference(last) < _cooldown) continue;
      _announced[a.key] = now;
      _announce(a);
    }
  }

  void _announce(PcAlert a) {
    if (flashLeds) engine.flashAlert();
    final n = _notify;
    if (!notify || n == null) return;
    using((arena) {
      n(
        a.title.toNativeUtf16(allocator: arena),
        a.detail.toNativeUtf16(allocator: arena),
      );
    });
  }

  @override
  void dispose() {
    monitor.removeListener(_onReading);
    monitor.setActive(this, false);
    super.dispose();
  }
}
