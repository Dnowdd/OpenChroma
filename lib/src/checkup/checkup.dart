import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../fans/fan_service.dart';
import '../i18n/l10n.dart';
import '../monitor/system_monitor.dart';
import '../paths.dart';
import '../system/launch_settings.dart';
import '../system/native_security.dart';
import '../system/system_paths.dart';
import 'minidump.dart';

/// The stress tests, by the id the native runner
/// (windows/runner/diagnostics.cpp) knows them.
enum CheckupTest {
  cpuSingle('cpu1'),
  cpuAll('cpu'),
  memory('memory'),
  gpu('gpu'),
  cpuGpu('cpugpu'),
  disk('disk');

  const CheckupTest(this.id);
  final String id;

  static CheckupTest? byId(String id) =>
      values.where((t) => t.id == id).firstOrNull;
}

enum CheckupPlan {
  quick,
  standard,
  long;

  /// Seconds per test (the disk test is sized in [diskMb] instead).
  int seconds(CheckupTest t) => switch (this) {
    quick => const {
      CheckupTest.cpuSingle: 15,
      CheckupTest.cpuAll: 40,
      CheckupTest.memory: 15,
      CheckupTest.gpu: 30,
      CheckupTest.cpuGpu: 30,
      CheckupTest.disk: 5,
    }[t]!,
    standard => const {
      CheckupTest.cpuSingle: 30,
      CheckupTest.cpuAll: 90,
      CheckupTest.memory: 45,
      CheckupTest.gpu: 60,
      CheckupTest.cpuGpu: 60,
      CheckupTest.disk: 10,
    }[t]!,
    long => const {
      CheckupTest.cpuSingle: 60,
      CheckupTest.cpuAll: 300,
      CheckupTest.memory: 180,
      CheckupTest.gpu: 240,
      CheckupTest.cpuGpu: 180,
      CheckupTest.disk: 20,
    }[t]!,
  };

  int get diskMb => switch (this) {
    quick => 1024,
    standard => 2048,
    long => 4096,
  };

  int get maxMemoryMb => switch (this) {
    quick => 2048,
    standard => 4096,
    long => 12288,
  };
}

double? _d(Object? v) => (v as num?)?.toDouble();

/// One second of sensor readings during a test.
class CheckupSample {
  CheckupSample({
    required this.t,
    this.cpuTemp,
    this.cpuPower,
    this.cpuClock,
    this.cpuUsage,
    this.gpuTemp,
    this.gpuPower,
    this.gpuUsage,
  });

  CheckupSample.fromJson(Map j)
    : t = _d(j['t']) ?? 0,
      cpuTemp = _d(j['ct']),
      cpuPower = _d(j['cp']),
      cpuClock = _d(j['cc']),
      cpuUsage = _d(j['cu']),
      gpuTemp = _d(j['gt']),
      gpuPower = _d(j['gp']),
      gpuUsage = _d(j['gu']);

  /// Seconds since the checkup started.
  final double t;
  final double? cpuTemp, cpuPower, cpuClock, cpuUsage;
  final double? gpuTemp, gpuPower, gpuUsage;

  Map<String, Object?> toJson() => {
    't': double.parse(t.toStringAsFixed(1)),
    if (cpuTemp != null) 'ct': cpuTemp,
    if (cpuPower != null) 'cp': cpuPower,
    if (cpuClock != null) 'cc': cpuClock,
    if (cpuUsage != null) 'cu': cpuUsage,
    if (gpuTemp != null) 'gt': gpuTemp,
    if (gpuPower != null) 'gp': gpuPower,
    if (gpuUsage != null) 'gu': gpuUsage,
  };
}

/// How one test went.
class TestResult {
  TestResult(this.test, {this.seconds = 0});

  TestResult.fromJson(Map j)
    : test = CheckupTest.byId(j['id'] as String? ?? '') ?? CheckupTest.cpuAll {
    _apply(j);
    samples = [
      for (final s in j['samples'] as List? ?? [])
        CheckupSample.fromJson(s as Map),
    ];
  }

  final CheckupTest test;

  /// pending, running, done, cancelled, failed or aborted.
  String status = 'pending';
  String error = '';
  int errors = 0, cpuErrors = 0, gpuErrors = 0;
  double seconds = 0, elapsed = 0;
  double cpuRate = 0;
  String cpuKernel = '';
  int threads = 0, megabytes = 0;
  double memWrite = 0, memRead = 0;
  double gpuTflops = 0;
  String gpuName = '';
  double diskWrite = 0, diskRead = 0;
  List<CheckupSample> samples = [];

  void _apply(Map j) {
    status = j['status'] as String? ?? status;
    error = j['error'] as String? ?? '';
    errors = j['errors'] as int? ?? 0;
    cpuErrors = j['cpuErrors'] as int? ?? 0;
    gpuErrors = j['gpuErrors'] as int? ?? 0;
    seconds = _d(j['seconds']) ?? seconds;
    elapsed = _d(j['elapsed']) ?? 0;
    cpuRate = _d(j['cpuRate']) ?? 0;
    cpuKernel = j['cpuKernel'] as String? ?? '';
    threads = j['threads'] as int? ?? 0;
    megabytes = j['megabytes'] as int? ?? 0;
    memWrite = _d(j['memWrite']) ?? 0;
    memRead = _d(j['memRead']) ?? 0;
    gpuTflops = _d(j['gpuTflops']) ?? 0;
    gpuName = j['gpuName'] as String? ?? '';
    diskWrite = _d(j['diskWrite']) ?? 0;
    diskRead = _d(j['diskRead']) ?? 0;
  }

  bool get finished => status != 'pending' && status != 'running';
  bool get passed => status == 'done' && errors == 0;

  double? _max(double? Function(CheckupSample) f) {
    final v = samples.map(f).nonNulls;
    return v.isEmpty ? null : v.reduce(math.max);
  }

  double? _avg(double? Function(CheckupSample) f) {
    // The first seconds are the ramp-up.
    final v = samples.skip(math.min(3, samples.length ~/ 3)).map(f).nonNulls;
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  double? get maxCpuTemp => _max((s) => s.cpuTemp);
  double? get avgCpuPower => _avg((s) => s.cpuPower);
  double? get avgCpuClock => _avg((s) => s.cpuClock);
  double? get maxGpuTemp => _max((s) => s.gpuTemp);
  double? get avgGpuPower => _avg((s) => s.gpuPower);

  Map<String, Object?> toJson() => {
    'id': test.id,
    'status': status,
    'error': error,
    'errors': errors,
    'cpuErrors': cpuErrors,
    'gpuErrors': gpuErrors,
    'seconds': seconds,
    'elapsed': elapsed,
    'cpuRate': cpuRate,
    'cpuKernel': cpuKernel,
    'threads': threads,
    'megabytes': megabytes,
    'memWrite': memWrite,
    'memRead': memRead,
    'gpuTflops': gpuTflops,
    'gpuName': gpuName,
    'diskWrite': diskWrite,
    'diskRead': diskRead,
    'samples': [for (final s in samples) s.toJson()],
  };
}

class MemoryModule {
  MemoryModule.fromJson(Map j)
    : slot = j['slot'] as String? ?? '',
      bank = j['bank'] as String? ?? '',
      type = j['type'] as String? ?? '',
      megabytes = j['megabytes'] as int? ?? 0,
      speed = j['speed'] as int? ?? 0,
      configured = j['configured'] as int? ?? 0,
      maker = j['maker'] as String? ?? '',
      part = j['part'] as String? ?? '';

  final String slot, bank, type, maker, part;
  final int megabytes, speed, configured;

  /// Channel letter from the bank label ("P0 CHANNEL A", "ChannelB-DIMM0").
  String? get channel => RegExp(
    r'channel\s*([a-h])',
    caseSensitive: false,
  ).firstMatch('$bank $slot')?.group(1)?.toUpperCase();

  Map<String, Object?> toJson() => {
    'slot': slot,
    'bank': bank,
    'type': type,
    'megabytes': megabytes,
    'speed': speed,
    'configured': configured,
    'maker': maker,
    'part': part,
  };
}

/// The PC's state when the checkup started, with no load.
class SystemReport {
  SystemReport();

  SystemReport.fromJson(Map j)
    : board = j['board'] as String? ?? '',
      bios = j['bios'] as String? ?? '',
      slots = j['slots'] as int? ?? 0,
      modules = [
        for (final m in j['modules'] as List? ?? [])
          MemoryModule.fromJson(m as Map),
      ],
      cpuName = j['cpuName'] as String? ?? '',
      gpuName = j['gpuName'] as String? ?? '',
      avx2 = j['avx2'] as bool? ?? false,
      elevated = j['elevated'] as bool? ?? false,
      memTotal = _d(j['memTotal']) ?? 0,
      memUsed = _d(j['memUsed']) ?? 0,
      memCommitted = _d(j['memCommitted']) ?? 0,
      driveFree = _d(j['driveFree']),
      driveTotal = _d(j['driveTotal']),
      idleCpuTemp = _d(j['idleCpuTemp']),
      idleCpuUsage = _d(j['idleCpuUsage']),
      blueScreens = [
        for (final b in j['blueScreens'] as List? ?? [])
          BlueScreen.fromJson(b as Map),
      ],
      suspects = {
        for (final e in (j['suspects'] as Map? ?? {}).entries)
          e.key as String: e.value as int,
      },
      dumpsRead = j['dumpsRead'] as int? ?? 0,
      startupApps = j['startupApps'] as int?;

  String board = '', bios = '', cpuName = '', gpuName = '';
  int slots = 0;
  List<MemoryModule> modules = [];
  bool avx2 = false, elevated = false;
  double memTotal = 0, memUsed = 0, memCommitted = 0;
  double? driveFree, driveTotal, idleCpuTemp, idleCpuUsage;
  List<BlueScreen> blueScreens = [];

  /// Third-party drivers on blue screen stacks, with how many dumps had
  /// them; only read when elevated.
  Map<String, int> suspects = {};
  int dumpsRead = 0;
  int? startupApps;

  Map<String, Object?> toJson() => {
    'board': board,
    'bios': bios,
    'slots': slots,
    'modules': [for (final m in modules) m.toJson()],
    'cpuName': cpuName,
    'gpuName': gpuName,
    'avx2': avx2,
    'elevated': elevated,
    'memTotal': memTotal,
    'memUsed': memUsed,
    'memCommitted': memCommitted,
    'driveFree': driveFree,
    'driveTotal': driveTotal,
    'idleCpuTemp': idleCpuTemp,
    'idleCpuUsage': idleCpuUsage,
    'blueScreens': [for (final b in blueScreens) b.toJson()],
    'suspects': suspects,
    'dumpsRead': dumpsRead,
    'startupApps': startupApps,
  };
}

class BlueScreen {
  BlueScreen(this.time, this.code);

  BlueScreen.fromJson(Map j)
    : time = DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime(2000),
      code = j['code'] as String? ?? '';

  final DateTime time;
  final String code;

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'code': code,
  };
}

enum Severity { good, info, warning, bad }

class Recommendation {
  const Recommendation(this.severity, this.title, this.detail);
  final Severity severity;
  final String title;
  final String detail;
}

class CheckupReport {
  CheckupReport({
    required this.started,
    required this.plan,
    required this.system,
  });

  CheckupReport.fromJson(Map j)
    : started =
          DateTime.tryParse(j['started'] as String? ?? '') ?? DateTime.now(),
      plan = CheckupPlan.values.asNameMap()[j['plan']] ?? CheckupPlan.quick,
      system = SystemReport.fromJson(j['system'] as Map? ?? {}),
      abortReason = j['abortReason'] as String?,
      tests = [
        for (final t in j['tests'] as List? ?? [])
          TestResult.fromJson(t as Map),
      ];

  final DateTime started;
  final CheckupPlan plan;
  final SystemReport system;
  List<TestResult> tests = [];
  String? abortReason;

  bool get finished => tests.every((t) => t.finished);

  List<CheckupSample> get samples => [for (final t in tests) ...t.samples];

  Map<String, Object?> toJson() => {
    'started': started.toIso8601String(),
    'plan': plan.name,
    'system': system.toJson(),
    'abortReason': abortReason,
    'tests': [for (final t in tests) t.toJson()],
  };
}

/// Runs the checkup: collects the system report, drives the native tests,
/// records the sensors while they run and stops them when something gets
/// dangerous. The last report is kept in %APPDATA%\OpenChroma\checkup.json.
class CheckupService extends ChangeNotifier {
  CheckupService({required this.monitor, required this.fans}) {
    try {
      final exe = DynamicLibrary.executable();
      _start = exe
          .lookupFunction<
            Int32 Function(Pointer<Utf8>),
            int Function(Pointer<Utf8>)
          >('OcDiagStart');
      _cancel = exe.lookupFunction<Void Function(), void Function()>(
        'OcDiagCancel',
      );
      _read = exe
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)
          >('OcDiagRead');
      _info = exe
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Int32),
            int Function(Pointer<Utf8>, int)
          >('OcDiagSystemInfo');
    } catch (_) {
      // Not available (tests, other platforms).
    }
    _load();
  }

  final SystemMonitor monitor;
  final FanService fans;

  /// Stops a test when the CPU passes this for [_strikes] seconds.
  static const maxCpuTemp = 98.0;
  static const maxGpuTemp = 92.0;
  static const _strikes = 3;

  int Function(Pointer<Utf8>)? _start;
  void Function()? _cancel;
  int Function(Pointer<Utf8>, int)? _read;
  int Function(Pointer<Utf8>, int)? _info;

  bool get available => _start != null;

  CheckupPlan plan = CheckupPlan.quick;
  final Set<CheckupTest> selected = {...CheckupTest.values};

  /// The running checkup, or the last one.
  CheckupReport? report;
  bool running = false;

  /// Collecting the system report before the tests start.
  bool preparing = false;
  DateTime? _startedAt;
  Timer? _timer;
  int _hotCpu = 0, _hotGpu = 0, _slowPump = 0;

  String get _file => p.join(openChromaDataDir(), 'checkup.json');

  int get plannedSeconds =>
      selected.fold(0, (sum, t) => sum + plan.seconds(t)) + 3 * selected.length;

  int? get currentIndex {
    final r = report;
    if (r == null || !running) return null;
    final i = r.tests.indexWhere((t) => t.status == 'running');
    return i < 0 ? null : i;
  }

  double get elapsed => _startedAt == null
      ? 0
      : DateTime.now().difference(_startedAt!).inMilliseconds / 1000;

  void setPlan(CheckupPlan value) {
    if (running) return;
    plan = value;
    notifyListeners();
  }

  void toggle(CheckupTest t) {
    if (running) return;
    selected.contains(t) ? selected.remove(t) : selected.add(t);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Run

  Future<void> start() async {
    if (!available || running || preparing || selected.isEmpty) return;
    preparing = true;
    monitor.setActive(this, true);
    notifyListeners();
    // A few monitor samples for the idle readings, averaged: one alone
    // catches whatever happened to run that second.
    final idleTemps = <double>[], idleUsage = <double>[];
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final s = monitor.snapshot;
      if (s?.cpu.temp != null) idleTemps.add(s!.cpu.temp!);
      if (s?.cpu.usage != null) idleUsage.add(s!.cpu.usage!);
    }
    final system = await _collectSystem();
    double? mean(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    system
      ..idleCpuTemp = mean(idleTemps)
      ..idleCpuUsage = mean(idleUsage);
    final order = CheckupTest.values.where(selected.contains).toList();
    final r = CheckupReport(started: DateTime.now(), plan: plan, system: system)
      ..tests = [
        for (final t in order)
          TestResult(t, seconds: plan.seconds(t).toDouble()),
      ];
    final memMb = _memoryTestMb();
    final planText = [
      for (final t in order)
        switch (t) {
          CheckupTest.cpuSingle => 'cpu1:${plan.seconds(t)}:1',
          CheckupTest.cpuAll => 'cpu:${plan.seconds(t)}:0',
          CheckupTest.memory => 'memory:${plan.seconds(t)}:$memMb',
          CheckupTest.gpu => 'gpu:${plan.seconds(t)}',
          CheckupTest.cpuGpu => 'cpugpu:${plan.seconds(t)}:0',
          CheckupTest.disk => 'disk:${plan.seconds(t)}:${plan.diskMb}',
        },
    ].join(',');
    final ok = using((a) => _start!(planText.toNativeUtf8(allocator: a))) == 1;
    preparing = false;
    if (!ok) {
      monitor.setActive(this, false);
      notifyListeners();
      return;
    }
    report = r;
    running = true;
    _startedAt = DateTime.now();
    _hotCpu = _hotGpu = _slowPump = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    notifyListeners();
  }

  void cancel([String? reason]) {
    if (!running) return;
    if (reason != null) report?.abortReason = reason;
    _cancel?.call();
  }

  int _memoryTestMb() {
    final m = monitor.snapshot?.memory;
    if (m == null || m.available <= 0) return 512;
    final availableMb = m.available / (1024 * 1024);
    return (availableMb * .6).clamp(256, plan.maxMemoryMb.toDouble()).round();
  }

  void _poll() {
    final r = report;
    if (r == null) return;
    final state = _readJson(_read);
    if (state != null) {
      final steps = state['steps'] as List? ?? [];
      for (var i = 0; i < steps.length && i < r.tests.length; i++) {
        r.tests[i]._apply(steps[i] as Map);
      }
    }
    final current = r.tests.where((t) => t.status == 'running').firstOrNull;
    final sample = _sample();
    if (current != null) {
      current.samples.add(sample);
      _checkSafety(sample);
    }
    if (state != null && state['running'] == false) _finish();
    notifyListeners();
  }

  CheckupSample _sample() {
    final s = monitor.snapshot;
    final gpu =
        s?.gpus.where((g) => !g.integrated).firstOrNull ?? s?.gpus.firstOrNull;
    return CheckupSample(
      t: elapsed,
      cpuTemp: s?.cpu.temp,
      cpuPower: s?.cpu.power,
      cpuClock: s?.cpu.clock,
      cpuUsage: s?.cpu.usage,
      gpuTemp: gpu?.temp,
      gpuPower: gpu?.power,
      gpuUsage: gpu?.usage,
    );
  }

  void _checkSafety(CheckupSample s) {
    _hotCpu = (s.cpuTemp ?? 0) >= maxCpuTemp ? _hotCpu + 1 : 0;
    _hotGpu = (s.gpuTemp ?? 0) >= maxGpuTemp ? _hotGpu + 1 : 0;
    final pumps = [
      for (final f in fans.snapshot?.fans ?? const <FanReading>[])
        if (fans.settingsOf(f.id).pump) f,
    ];
    final pumpStopped = pumps.any((f) => (f.rpm ?? 1000) < 500);
    _slowPump = pumpStopped ? _slowPump + 1 : 0;
    if (_hotCpu >= _strikes) {
      cancel(l10n.checkupAbortCpuTemp(maxCpuTemp.round()));
    } else if (_hotGpu >= _strikes) {
      cancel(l10n.checkupAbortGpuTemp(maxGpuTemp.round()));
    } else if (_slowPump >= _strikes) {
      cancel(l10n.checkupAbortPump);
    }
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    running = false;
    final r = report;
    if (r != null && r.abortReason != null) {
      for (final t in r.tests) {
        if (t.status == 'cancelled' && t.samples.isNotEmpty) {
          t.status = 'aborted';
        }
      }
    }
    monitor.setActive(this, false);
    _save();
  }

  Map? _readJson(int Function(Pointer<Utf8>, int)? read) {
    if (read == null) return null;
    final n = read(nullptr, 0);
    if (n <= 0) return null;
    final buf = malloc<Uint8>(n + 1);
    try {
      read(buf.cast(), n + 1);
      return jsonDecode(utf8.decode(buf.asTypedList(n), allowMalformed: true))
          as Map;
    } catch (_) {
      return null;
    } finally {
      malloc.free(buf);
    }
  }

  // ---------------------------------------------------------------- System

  Future<SystemReport> _collectSystem() async {
    final r = SystemReport()..elevated = Elevation.isElevated;
    final info = _readJson(_info);
    if (info != null && info['available'] == true) {
      r.board = [
        _shortMaker(info['boardMaker'] as String? ?? ''),
        info['board'],
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      r.bios = info['biosVersion'] as String? ?? '';
      r.slots = info['slots'] as int? ?? 0;
      r.avx2 = info['avx2'] as bool? ?? false;
      r.modules = [
        for (final m in info['modules'] as List? ?? [])
          MemoryModule.fromJson(m as Map),
      ];
    }
    final s = monitor.snapshot;
    if (s != null) {
      r.cpuName = s.cpu.name;
      r.gpuName =
          (s.gpus.where((g) => !g.integrated).firstOrNull ?? s.gpus.firstOrNull)
              ?.name ??
          '';
      r.memTotal = s.memory.total;
      r.memUsed = s.memory.used;
      r.memCommitted = s.memory.committed;
      final systemDrive = (Platform.environment['SystemDrive'] ?? 'C:')
          .substring(0, 1);
      final v = s.volumes
          .where((v) => v.letter.toUpperCase() == systemDrive.toUpperCase())
          .firstOrNull;
      r.driveFree = v?.free;
      r.driveTotal = v?.total;
    }
    final results = await Future.wait([
      _blueScreens(),
      _startupApps(),
      if (r.elevated) _dumpSuspects() else Future.value(null),
    ]);
    r.blueScreens = results[0] as List<BlueScreen>;
    r.startupApps = results[1] as int?;
    final dumps = results.length > 2
        ? results[2] as (Map<String, int>, int)?
        : null;
    if (dumps != null) {
      r.suspects = dumps.$1;
      r.dumpsRead = dumps.$2;
    }
    return r;
  }

  /// Blue screens of the last 30 days, from the System event log.
  Future<List<BlueScreen>> _blueScreens() async {
    try {
      final res = await Process.run(SystemPaths.tool('wevtutil'), [
        'qe',
        'System',
        "/q:*[System[Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting'] "
            'and (EventID=1001) and TimeCreated[timediff(@SystemTime) <= 2592000000]]]',
        '/f:xml',
        '/c:200',
      ]);
      final out = '${res.stdout}';
      final list = <BlueScreen>[];
      for (final e in RegExp(r'<Event[\s\S]*?</Event>').allMatches(out)) {
        final x = e.group(0)!;
        final time = RegExp(r"SystemTime='([^']+)'").firstMatch(x)?.group(1);
        final code = RegExp(r'0x[0-9a-fA-F]{8}').firstMatch(x)?.group(0) ?? '';
        list.add(
          BlueScreen(
            DateTime.tryParse(time ?? '')?.toLocal() ?? DateTime.now(),
            code.isEmpty
                ? ''
                : '0x${int.parse(code.substring(2), radix: 16).toRadixString(16).toUpperCase()}',
          ),
        );
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Programs that start with Windows (Run keys and Startup folders), minus
  /// those disabled in Task Manager.
  Future<int?> _startupApps() async {
    try {
      const run = r'Software\Microsoft\Windows\CurrentVersion\Run';
      const approved =
          r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved';
      Future<Map<String, String>> values(String key) async {
        final res = await Process.run(SystemPaths.tool('reg'), ['query', key]);
        final out = <String, String>{};
        for (final m in RegExp(
          r'^\s{4}(.+?)\s{4}REG_\w+\s{4}(.*)$',
          multiLine: true,
        ).allMatches('${res.stdout}')) {
          out[m.group(1)!] = m.group(2)!.trim();
        }
        return out;
      }

      final names = <String>{};
      final disabled = <String>{};
      for (final root in ['HKCU', 'HKLM']) {
        names.addAll((await values('$root\\$run')).keys);
        for (final sub in ['Run', 'Run32', 'StartupFolder']) {
          final v = await values('$root\\$approved\\$sub');
          // First byte 03 marks an entry turned off in Task Manager.
          disabled.addAll(
            v.entries.where((e) => e.value.startsWith('03')).map((e) => e.key),
          );
        }
      }
      names.addAll(
        (await values(
          r'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        )).keys,
      );
      for (final dir in [
        p.join(
          Platform.environment['APPDATA'] ?? '',
          r'Microsoft\Windows\Start Menu\Programs\Startup',
        ),
        p.join(
          Platform.environment['ProgramData'] ?? '',
          r'Microsoft\Windows\Start Menu\Programs\StartUp',
        ),
      ]) {
        final d = Directory(dir);
        if (d.existsSync()) {
          names.addAll(
            d
                .listSync()
                .whereType<File>()
                .map((f) => p.basename(f.path))
                .where((n) => n != 'desktop.ini'),
          );
        }
      }
      return names.where((n) => !disabled.contains(n)).length;
    } catch (_) {
      return null;
    }
  }

  /// Reads the kernel dumps Windows kept (needs admin) and counts the
  /// non-Microsoft drivers on the blue screens' stacks.
  Future<(Map<String, int>, int)?> _dumpSuspects() async {
    try {
      final windows = SystemPaths.windows;
      final programData =
          Platform.environment['ProgramData'] ?? r'C:\ProgramData';
      final files = <File>[];
      void add(String dir, {bool recursive = false}) {
        final d = Directory(dir);
        if (!d.existsSync()) return;
        for (final e in d.listSync(recursive: recursive, followLinks: false)) {
          if (e is File &&
              e.path.toLowerCase().endsWith('.dmp') &&
              NativeSecurity.fileOwnerTrusted(e.path)) {
            files.add(e);
          }
        }
      }

      add(p.join(windows, 'Minidump'));
      for (final q in ['ReportQueue', 'ReportArchive']) {
        final d = Directory(p.join(programData, r'Microsoft\Windows\WER', q));
        if (!d.existsSync()) continue;
        for (final k in d.listSync(followLinks: false).whereType<Directory>()) {
          if (p.basename(k.path).startsWith('Kernel_')) add(k.path);
        }
      }
      final since = DateTime.now().subtract(const Duration(days: 180));
      final counts = <String, int>{};
      var read = 0;
      for (final f in files) {
        if (f.lastModifiedSync().isBefore(since)) continue;
        final dump = KernelDump.read(f);
        if (dump == null || !dump.isDriverFault) continue;
        read++;
        for (final m in dump.stackModules.toSet()) {
          if (!microsoftDrivers.contains(m)) counts[m] = (counts[m] ?? 0) + 1;
        }
      }
      // Drop drivers whose file says Microsoft; the list above is not complete.
      for (final name in counts.keys.toList()) {
        final company = NativeSecurity.driverCompany(name);
        if (company != null && company.toLowerCase().contains('microsoft')) {
          counts.remove(name);
        }
      }
      return (counts, read);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- Storage

  void _load() {
    try {
      final f = File(_file);
      if (!f.existsSync()) return;
      final j =
          jsonDecode(f.readAsStringSync().replaceFirst('\uFEFF', '')) as Map;
      report = CheckupReport.fromJson(j);
      plan = report!.plan;
    } catch (_) {}
  }

  void _save() {
    try {
      final r = report;
      if (r != null) File(_file).writeAsStringSync(jsonEncode(r.toJson()));
    } catch (_) {}
  }

  @override
  void dispose() {
    cancel();
    _timer?.cancel();
    super.dispose();
  }
}

/// "Gigabyte Technology Co., Ltd." -> "Gigabyte".
String _shortMaker(String maker) {
  final m = maker.toLowerCase();
  for (final (key, name) in const [
    ('gigabyte', 'Gigabyte'),
    ('asustek', 'ASUS'),
    ('asus', 'ASUS'),
    ('micro-star', 'MSI'),
    ('msi', 'MSI'),
    ('asrock', 'ASRock'),
    ('biostar', 'Biostar'),
    ('nzxt', 'NZXT'),
    ('dell', 'Dell'),
    ('hewlett', 'HP'),
    ('lenovo', 'Lenovo'),
    ('acer', 'Acer'),
    ('intel', 'Intel'),
  ]) {
    if (m.contains(key)) return name;
  }
  return maker.split(RegExp(r'[ ,]')).first;
}

// ---------------------------------------------------------------- Advice

String _gb(double bytes) {
  final text = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
  return l10n.localeName == 'pt' ? text.replaceAll('.', ',') : text;
}

/// Plain-rule advice from a report, worst first.
List<Recommendation> recommendationsFor(CheckupReport r) {
  final out = <Recommendation>[];
  final s = r.system;

  if (r.abortReason != null) {
    out.add(
      Recommendation(
        Severity.bad,
        l10n.checkupAdviceAbortedTitle(r.abortReason!),
        l10n.checkupAdviceAbortedDetail,
      ),
    );
  }
  for (final t in r.tests) {
    if (t.status != 'done' && t.status != 'aborted') continue;
    if (t.cpuErrors > 0) {
      out.add(
        Recommendation(
          Severity.bad,
          l10n.checkupAdviceCpuErrorsTitle,
          l10n.checkupAdviceCpuErrorsDetail,
        ),
      );
    }
    if (t.gpuErrors > 0) {
      out.add(
        Recommendation(
          Severity.bad,
          l10n.checkupAdviceGpuErrorsTitle,
          l10n.checkupAdviceGpuErrorsDetail,
        ),
      );
    }
    if (t.test == CheckupTest.memory && t.errors > 0) {
      out.add(
        Recommendation(
          Severity.bad,
          l10n.checkupAdviceMemoryErrorsTitle,
          l10n.checkupAdviceMemoryErrorsDetail,
        ),
      );
    }
    if (t.test == CheckupTest.disk && t.errors > 0) {
      out.add(
        Recommendation(
          Severity.bad,
          l10n.checkupAdviceDiskErrorsTitle,
          l10n.checkupAdviceDiskErrorsDetail,
        ),
      );
    }
  }

  if (s.blueScreens.isNotEmpty) {
    final top = s.suspects.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final suspect = top.firstOrNull;
    out.add(
      Recommendation(
        Severity.bad,
        l10n.checkupAdviceBlueScreensTitle(s.blueScreens.length),
        suspect != null
            ? l10n.checkupAdviceBlueScreensSuspect(
                suspect.key,
                suspect.value,
                s.dumpsRead,
              )
            : s.elevated
            ? l10n.checkupAdviceBlueScreensNoSuspect
            : l10n.checkupAdviceBlueScreensNeedAdmin,
      ),
    );
  }

  final cpuMax = [for (final t in r.tests) t.maxCpuTemp].nonNulls
      .fold<double?>(null, (a, b) => a == null ? b : math.max(a, b));
  if (cpuMax != null && cpuMax >= 90) {
    out.add(
      Recommendation(
        Severity.warning,
        l10n.checkupAdviceCpuHotTitle(cpuMax.round()),
        l10n.checkupAdviceCpuHotDetail,
      ),
    );
  }
  final gpuMax = [for (final t in r.tests) t.maxGpuTemp].nonNulls
      .fold<double?>(null, (a, b) => a == null ? b : math.max(a, b));
  if (gpuMax != null && gpuMax >= 83) {
    out.add(
      Recommendation(
        Severity.warning,
        l10n.checkupAdviceGpuHotTitle(gpuMax.round()),
        l10n.checkupAdviceGpuHotDetail,
      ),
    );
  }

  final mods = s.modules;
  if (mods.length == 1) {
    out.add(
      Recommendation(
        Severity.warning,
        l10n.checkupAdviceSingleChannelTitle,
        l10n.checkupAdviceSingleChannelDetail,
      ),
    );
  } else if (mods.length >= 2) {
    final channels = mods.map((m) => m.channel).nonNulls.toSet();
    if (channels.length == 1 && mods.every((m) => m.channel != null)) {
      out.add(
        Recommendation(
          Severity.warning,
          l10n.checkupAdviceSameChannelTitle,
          l10n.checkupAdviceSameChannelDetail,
        ),
      );
    }
  }
  final m = mods.firstOrNull;
  if (m != null) {
    final lowBase =
        (m.type == 'DDR5' && m.configured > 0 && m.configured <= 4800) ||
        (m.type == 'DDR4' && m.configured > 0 && m.configured <= 2400);
    if (m.speed > m.configured + 100) {
      out.add(
        Recommendation(
          Severity.warning,
          l10n.checkupAdviceSlowMemoryTitle,
          l10n.checkupAdviceSlowMemoryDetail(m.configured, m.speed),
        ),
      );
    } else if (lowBase) {
      out.add(
        Recommendation(
          Severity.info,
          l10n.checkupAdviceProfileOffTitle,
          l10n.checkupAdviceProfileOffDetail(m.configured),
        ),
      );
    }
  }
  if (s.memTotal > 0 && s.memUsed / s.memTotal > .85) {
    out.add(
      Recommendation(
        Severity.warning,
        l10n.checkupAdviceMemoryFullTitle,
        l10n.checkupAdviceMemoryFullDetail(
          _gb(s.memUsed),
          _gb(s.memTotal),
          _gb(s.memCommitted),
        ),
      ),
    );
  }
  final free = s.driveFree, total = s.driveTotal;
  if (free != null &&
      total != null &&
      total > 0 &&
      (free / total < .1 || free < 20e9)) {
    out.add(
      Recommendation(
        Severity.warning,
        l10n.checkupAdviceDriveFullTitle,
        l10n.checkupAdviceDriveFullDetail(_gb(free)),
      ),
    );
  }
  if ((s.startupApps ?? 0) > 12) {
    out.add(
      Recommendation(
        Severity.info,
        l10n.checkupAdviceStartupTitle(s.startupApps!),
        l10n.checkupAdviceStartupDetail,
      ),
    );
  }
  if ((s.idleCpuUsage ?? 0) > 20) {
    out.add(
      Recommendation(
        Severity.info,
        l10n.checkupAdviceBusyTitle,
        l10n.checkupAdviceBusyDetail(s.idleCpuUsage!.round()),
      ),
    );
  }
  if (r.tests.any(
        (t) => t.test != CheckupTest.disk && t.test != CheckupTest.memory,
      ) &&
      r.tests.every((t) => t.maxCpuTemp == null)) {
    out.add(
      Recommendation(
        Severity.info,
        l10n.checkupAdviceNoCpuTempTitle,
        l10n.checkupAdviceNoCpuTempDetail,
      ),
    );
  }
  if (out.every((a) => a.severity == Severity.info) &&
      r.tests.every((t) => t.passed)) {
    out.insert(
      0,
      Recommendation(
        Severity.good,
        l10n.checkupAllGood,
        l10n.checkupAdviceAllGoodDetail,
      ),
    );
  }
  // Worst first; "all good" leads when there is nothing worse.
  int rank(Recommendation a) =>
      a.severity == Severity.good ? 0 : 4 - a.severity.index;
  out.sort((a, b) => rank(a).compareTo(rank(b)));
  return out;
}
