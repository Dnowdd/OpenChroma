import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;

import '../paths.dart';

/// Build with --dart-define=OC_PROFILE=true to log slow frames, UI thread
/// stalls and marked work to %APPDATA%\OpenChroma\profile.log.
const kProfile = bool.fromEnvironment('OC_PROFILE');

class FrameProfiler {
  static final _start = Stopwatch()..start();
  static IOSink? _out;
  static final _counts = <String, int>{};

  static void start() {
    if (!kProfile) return;
    _out = File(p.join(openChromaDataDir(), 'profile.log'))
        .openWrite(mode: FileMode.write);
    _log('start');
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    // Heartbeat: a timer that should fire every 4 ms; a late one means the
    // UI thread was busy (or blocked) for that long.
    var last = _start.elapsedMicroseconds;
    Timer.periodic(const Duration(milliseconds: 4), (_) {
      final now = _start.elapsedMicroseconds;
      final gap = (now - last) / 1000;
      last = now;
      if (gap > 25) _log('stall ${gap.toStringAsFixed(1)}ms');
    });
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (_counts.isEmpty) return;
      _log(
        'rates ${_counts.entries.map((e) => '${e.key}=${e.value}').join(' ')}',
      );
      _counts.clear();
    });
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds / 1000;
      final raster = t.rasterDuration.inMicroseconds / 1000;
      final total = t.totalSpan.inMicroseconds / 1000;
      if (total > 20 || build > 12 || raster > 12) {
        _log(
          'frame total=${total.toStringAsFixed(1)} '
          'build=${build.toStringAsFixed(1)} raster=${raster.toStringAsFixed(1)}',
        );
      }
    }
  }

  /// Times [work] and logs it when it takes over [thresholdMs].
  static T measure<T>(
    String name,
    T Function() work, {
    double thresholdMs = 2,
  }) {
    if (!kProfile) return work();
    final sw = Stopwatch()..start();
    final r = work();
    final ms = sw.elapsedMicroseconds / 1000;
    if (ms > thresholdMs) _log('$name ${ms.toStringAsFixed(1)}ms');
    return r;
  }

  /// Counts an event; per-second totals are logged.
  static void count(String name) {
    if (kProfile) _counts[name] = (_counts[name] ?? 0) + 1;
  }

  static void mark(String what) {
    if (kProfile) _log(what);
  }

  static void _log(String line) {
    _out?.writeln(
      '${(_start.elapsedMilliseconds / 1000).toStringAsFixed(3)} $line',
    );
  }
}
