import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/checkup/checkup.dart';

SystemReport _system({
  List<Map<String, Object?>> modules = const [],
  double memUsed = 4,
  int blueScreens = 0,
  Map<String, int> suspects = const {},
}) {
  final s = SystemReport.fromJson({
    'modules': modules,
    'memTotal': 16 * 1073741824.0,
    'memUsed': memUsed * 1073741824.0,
    'driveFree': 500e9,
    'driveTotal': 1000e9,
    'elevated': true,
    'suspects': suspects,
    'dumpsRead': suspects.isEmpty ? 0 : 13,
    'blueScreens': [
      for (var i = 0; i < blueScreens; i++)
        {'time': DateTime(2026, 10, i + 1).toIso8601String(), 'code': '0xA'},
    ],
  });
  return s;
}

Map<String, Object?> _dimm(
  String bank, {
  int speed = 5600,
  int configured = 5600,
}) => {
  'slot': 'DIMM',
  'bank': bank,
  'type': 'DDR5',
  'megabytes': 16384,
  'speed': speed,
  'configured': configured,
};

CheckupReport _report(SystemReport s, {List<TestResult> tests = const []}) =>
    CheckupReport(
      started: DateTime(2026, 10, 18),
      plan: CheckupPlan.quick,
      system: s,
    )..tests = tests;

TestResult _done(CheckupTest t, {int cpuErrors = 0, double? cpuTemp}) =>
    TestResult.fromJson({
      'id': t.id,
      'status': 'done',
      'cpuErrors': cpuErrors,
      'errors': cpuErrors,
      'samples': [
        if (cpuTemp != null) {'t': 1, 'ct': cpuTemp},
      ],
    });

void main() {
  test('reads the channel from SMBIOS bank labels', () {
    expect(MemoryModule.fromJson(_dimm('P0 CHANNEL A')).channel, 'A');
    expect(MemoryModule.fromJson(_dimm('ChannelB-DIMM0')).channel, 'B');
    expect(MemoryModule.fromJson(_dimm('BANK 0')).channel, isNull);
  });

  test('a healthy PC gets "all good" first', () {
    final s = _system(modules: [_dimm('CHANNEL A'), _dimm('CHANNEL B')]);
    final advice = recommendationsFor(
      _report(s, tests: [_done(CheckupTest.cpuAll, cpuTemp: 80)]),
    );
    expect(advice.first.severity, Severity.good);
    expect(
      advice.where((a) => a.severity.index >= Severity.warning.index),
      isEmpty,
    );
  });

  test('flags single channel, memory pressure and slow memory', () {
    final titles = recommendationsFor(
      _report(
        _system(modules: [_dimm('CHANNEL A', configured: 4800)], memUsed: 15),
      ),
    ).map((a) => a.title);
    expect(titles, contains('Single-channel memory'));
    expect(titles, contains('Memory almost full'));
    expect(titles, contains('The memory runs below what it supports'));
  });

  test('two modules on one channel are flagged', () {
    final titles = recommendationsFor(
      _report(_system(modules: [_dimm('CHANNEL A'), _dimm('CHANNEL A')])),
    ).map((a) => a.title);
    expect(titles, contains('The modules are on the same channel'));
  });

  test('errors and blue screens come first and name the suspect', () {
    final advice = recommendationsFor(
      _report(
        _system(
          modules: [_dimm('CHANNEL A'), _dimm('CHANNEL B')],
          blueScreens: 4,
          suspects: {'vigembus.sys': 13},
        ),
        tests: [_done(CheckupTest.cpuAll, cpuErrors: 3, cpuTemp: 96)],
      ),
    );
    expect(advice.first.severity, Severity.bad);
    final blue = advice.firstWhere((a) => a.title.contains('blue screens'));
    expect(blue.detail, contains('vigembus.sys'));
    expect(
      advice.map((a) => a.title),
      contains('The CPU made calculation errors under load'),
    );
    expect(
      advice.map((a) => a.title),
      contains('The CPU reaches 96 °C at full load'),
    );
    expect(advice.any((a) => a.severity == Severity.good), isFalse);
  });

  test('reports survive a save and load', () {
    final r = _report(
      _system(modules: [_dimm('CHANNEL A')]),
      tests: [_done(CheckupTest.gpu)],
    );
    final back = CheckupReport.fromJson(r.toJson());
    expect(back.tests.single.test, CheckupTest.gpu);
    expect(back.system.modules.single.channel, 'A');
    expect(back.plan, CheckupPlan.quick);
  });
}
