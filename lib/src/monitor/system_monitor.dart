import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// How the CPU temperature sensor is doing.
enum CpuSensorStatus {
  ok,

  /// The PawnIO driver only opens for elevated processes.
  needsAdmin,

  /// PawnIO is not installed.
  noDriver,

  /// Not an AMD Zen or Intel CPU.
  unsupported,

  /// The driver is still being opened.
  pending,

  /// The driver stopped answering.
  failed;

  static CpuSensorStatus parse(String? s) => switch (s) {
    'ok' => ok,
    'pending' => pending,
    'failed' => failed,
    'needs_admin' => needsAdmin,
    'no_driver' => noDriver,
    _ => unsupported,
  };
}

double? _d(Object? v) => (v as num?)?.toDouble();

class CpuReading {
  CpuReading(Map j)
    : name = j['name'] as String? ?? '',
      cores = j['cores'] as int? ?? 0,
      threads = j['threads'] as int? ?? 0,
      usage = _d(j['usage']),
      clock = _d(j['clock']),
      perThread = [for (final v in j['perThread'] as List? ?? []) _d(v)!],
      sensor = CpuSensorStatus.parse(j['sensor'] as String?),
      temp = _d(j['temp']),
      ccds = [for (final v in j['ccds'] as List? ?? []) _d(v)!],
      power = _d(j['power']);

  final String name;
  final int cores;
  final int threads;
  final double? usage;

  /// Effective clock in MHz.
  final double? clock;
  final List<double> perThread;
  final CpuSensorStatus sensor;
  final double? temp;
  final List<double> ccds;

  /// Package power in watts.
  final double? power;
}

class MemoryReading {
  MemoryReading(Map j)
    : total = _d(j['total']) ?? 0,
      used = _d(j['used']) ?? 0,
      available = _d(j['available']) ?? 0,
      committed = _d(j['committed']) ?? 0,
      commitLimit = _d(j['commitLimit']) ?? 0,
      cached = _d(j['cached']) ?? 0;

  final double total;
  final double used;
  final double available;
  final double committed;
  final double commitLimit;
  final double cached;

  double get percent => total > 0 ? used / total * 100 : 0;
}

class GpuReading {
  GpuReading(Map j)
    : name = j['name'] as String? ?? '',
      integrated = j['integrated'] as bool? ?? false,
      usage = _d(j['usage']),
      temp = _d(j['temp']),
      memUsed = _d(j['memUsed']),
      memTotal = _d(j['memTotal']),
      power = _d(j['power']),
      powerLimit = _d(j['powerLimit']),
      fan = _d(j['fan']),
      fanRpm = _d(j['fanRpm']),
      clock = _d(j['clock']),
      memClock = _d(j['memClock']);

  final String name;
  final bool integrated;
  final double? usage;
  final double? temp;
  final double? memUsed;
  final double? memTotal;
  final double? power;
  final double? powerLimit;

  /// Fan speed in percent.
  final double? fan;
  final double? fanRpm;
  final double? clock;
  final double? memClock;
}

class DiskReading {
  DiskReading(Map j)
    : number = j['number'] as int? ?? -1,
      model = j['model'] as String? ?? '',
      bus = j['bus'] as String? ?? '',
      temp = _d(j['temp']),
      active = _d(j['active']),
      read = _d(j['read']),
      write = _d(j['write']);

  final int number;
  final String model;
  final String bus;
  final double? temp;

  /// Percent of time busy.
  final double? active;

  /// Bytes per second.
  final double? read;
  final double? write;
}

class VolumeReading {
  VolumeReading(Map j)
    : letter = j['letter'] as String? ?? '',
      label = j['label'] as String? ?? '',
      fileSystem = j['fs'] as String? ?? '',
      total = _d(j['total']) ?? 0,
      free = _d(j['free']) ?? 0,
      disk = j['disk'] as int? ?? -1,
      removable = j['removable'] as bool? ?? false;

  final String letter;
  final String label;
  final String fileSystem;
  final double total;
  final double free;
  final int disk;
  final bool removable;

  double get used => total - free;
  double get percent => total > 0 ? used / total * 100 : 0;
}

class ProcessReading {
  ProcessReading(Map j)
    : name = j['name'] as String? ?? '',
      count = j['count'] as int? ?? 1,
      cpu = _d(j['cpu']) ?? 0,
      memory = _d(j['memory']) ?? 0;

  final String name;
  final int count;

  /// Percent of the whole CPU.
  final double cpu;

  /// Private working set in bytes.
  final double memory;
}

/// One sample of everything the monitor shows.
class SystemSnapshot {
  SystemSnapshot(Map j)
    : uptime = Duration(seconds: j['uptime'] as int? ?? 0),
      elevated = j['elevated'] as bool? ?? false,
      cpu = CpuReading(j['cpu'] as Map? ?? {}),
      memory = MemoryReading(j['memory'] as Map? ?? {}),
      gpus = [for (final g in j['gpus'] as List? ?? []) GpuReading(g as Map)],
      disks = [
        for (final d in j['disks'] as List? ?? []) DiskReading(d as Map),
      ],
      volumes = [
        for (final v in j['volumes'] as List? ?? []) VolumeReading(v as Map),
      ],
      netDown = _d((j['network'] as Map?)?['down']) ?? 0,
      netUp = _d((j['network'] as Map?)?['up']) ?? 0,
      processes = [
        for (final p in j['processes'] as List? ?? []) ProcessReading(p as Map),
      ];

  final Duration uptime;
  final bool elevated;
  final CpuReading cpu;
  final MemoryReading memory;

  /// Discrete GPUs first.
  final List<GpuReading> gpus;
  final List<DiskReading> disks;
  final List<VolumeReading> volumes;

  /// Bytes per second over every network adapter.
  final double netDown;
  final double netUp;
  final List<ProcessReading> processes;
}

/// The last [capacity] values of one metric; null marks a missing reading.
class History {
  History([this.capacity = 60]);
  final int capacity;
  final List<double?> values = [];

  void add(double? v) {
    values.add(v);
    if (values.length > capacity) values.removeAt(0);
  }
}

/// Polls the native sampler (windows/runner/system_monitor.cpp) once per
/// second while [active], and keeps a minute of history for the charts.
class SystemMonitor extends ChangeNotifier {
  SystemMonitor() {
    try {
      final exe = DynamicLibrary.executable();
      _start = exe.lookupFunction<Void Function(), void Function()>(
        'OcSysmonStart',
      );
      _stop = exe.lookupFunction<Void Function(), void Function()>(
        'OcSysmonStop',
      );
      _read = exe
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)
          >('OcSysmonRead');
    } catch (_) {
      // Not available (tests, other platforms).
    }
  }

  void Function()? _start;
  void Function()? _stop;
  int Function(Pointer<Utf8>, int)? _read;

  Pointer<Utf8> _buf = nullptr;
  int _cap = 0;
  Timer? _timer;
  bool _active = false;

  SystemSnapshot? snapshot;
  DateTime? _activatedAt;

  /// True when no reading arrived within a few seconds of starting.
  bool get stalled =>
      snapshot == null &&
      _activatedAt != null &&
      DateTime.now().difference(_activatedAt!) > const Duration(seconds: 8);

  final cpuUsage = History();
  final cpuTemp = History();
  final gpuUsage = History();
  final gpuTemp = History();
  final memory = History();
  final netDown = History();
  final netUp = History();

  bool get available => _read != null;

  final _users = <Object>{};

  /// Samples only while some page that shows readings is on screen; each
  /// page registers itself as a [user].
  void setActive(Object user, bool on) {
    on ? _users.add(user) : _users.remove(user);
    active = _users.isNotEmpty;
  }

  set active(bool value) {
    if (value == _active || !available) return;
    _active = value;
    if (value) {
      _activatedAt ??= DateTime.now();
      _start!();
      // Pages turn sampling on while they build; reading now would notify
      // listeners mid-build, so take the first sample right after.
      Timer.run(() {
        if (_active) _poll();
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    } else {
      _timer?.cancel();
      _timer = null;
      _stop!();
    }
  }

  void _poll() {
    final read = _read!;
    var n = read(_buf, _cap);
    if (n == 0) {
      if (stalled) notifyListeners();
      return;
    }
    if (n >= _cap) {
      if (_buf != nullptr) malloc.free(_buf);
      _cap = n + 64 * 1024;
      _buf = malloc<Uint8>(_cap).cast();
      n = read(_buf, _cap);
      if (n == 0 || n >= _cap) return;
    }
    final Map json;
    try {
      json = jsonDecode(
        utf8.decode(_buf.cast<Uint8>().asTypedList(n), allowMalformed: true),
      ) as Map;
    } catch (_) {
      return;
    }
    final s = SystemSnapshot(json);
    snapshot = s;
    final gpu = s.gpus.firstOrNull;
    cpuUsage.add(s.cpu.usage);
    cpuTemp.add(s.cpu.temp);
    gpuUsage.add(gpu?.usage);
    gpuTemp.add(gpu?.temp);
    memory.add(s.memory.percent);
    netDown.add(s.netDown);
    netUp.add(s.netUp);
    notifyListeners();
  }

  @override
  void dispose() {
    active = false;
    if (_buf != nullptr) malloc.free(_buf);
    super.dispose();
  }
}
