import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/monitor/system_monitor.dart';
import 'package:openchroma/src/ui/monitor_page.dart';

class _TestMonitor extends SystemMonitor {
  @override
  bool get available => true;
}

void main() {
  test('process samples stay aligned with bounded metric histories', () {
    final monitor = SystemMonitor();
    addTearDown(monitor.dispose);
    for (var index = 0; index < 65; index++) {
      monitor.recordSnapshot(
        SystemSnapshot({
          'cpu': {'usage': index},
          'memory': {'total': 100, 'used': index},
          'processes': [
            {'name': 'Process $index', 'cpu': index},
          ],
        }),
        capturedAt: DateTime(2026, 11, 26, 12, 0, index),
      );
    }
    expect(monitor.samples, hasLength(60));
    expect(monitor.samples.first.snapshot.processes.single.name, 'Process 5');
    expect(monitor.samples.last.snapshot.processes.single.name, 'Process 64');
    expect(
      monitor.samples.map((sample) => sample.snapshot.cpu.usage),
      monitor.cpuUsage.values,
    );
    expect(
      monitor.samples.map((sample) => sample.snapshot.memory.percent),
      monitor.memory.values,
    );
  });

  testWidgets('CPU and Memory headers change descending process order', (
    tester,
  ) async {
    final data = Directory.systemTemp.createTempSync('oc_monitor');
    addTearDown(() => data.deleteSync(recursive: true));
    final monitor = _TestMonitor()
      ..snapshot = SystemSnapshot({
        'memory': {'total': 8589934592, 'used': 1073741824},
        'processes': [
          {'name': 'Browser.exe', 'cpu': 1, 'memory': 805306368},
          {'name': 'Compiler.exe', 'cpu': 65, 'memory': 268435456},
        ],
      });
    addTearDown(monitor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonitorPage(
            engine: Engine(dataDir: data.path),
            monitor: monitor,
            active: false,
          ),
        ),
      ),
    );

    final cpu = find.widgetWithText(TextButton, 'CPU');
    final memory = find.widgetWithText(TextButton, 'Memory');
    await tester.ensureVisible(cpu);
    await tester.pumpAndSettle();
    final browser = find.text('Browser');
    final compiler = find.text('Compiler');
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    Finder arrow(Finder header) => find.descendant(
      of: header,
      matching: find.byIcon(Icons.arrow_downward_rounded),
    );

    expect(top(compiler), lessThan(top(browser)));
    expect(arrow(cpu), findsOneWidget);
    await tester.tap(memory);
    await tester.pumpAndSettle();
    expect(top(browser), lessThan(top(compiler)));
    expect(arrow(memory), findsOneWidget);
    await tester.tap(cpu);
    await tester.pumpAndSettle();
    expect(top(compiler), lessThan(top(browser)));
    expect(arrow(cpu), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('chart inspection keeps the processes from the clicked sample', (
    tester,
  ) async {
    final data = Directory.systemTemp.createTempSync('oc_inspect');
    addTearDown(() => data.deleteSync(recursive: true));
    final monitor = _TestMonitor();
    addTearDown(monitor.dispose);
    monitor.recordSnapshot(
      SystemSnapshot({
        'cpu': {'usage': 90},
        'memory': {'total': 1000, 'used': 800},
        'processes': [
          {'name': 'Browser.exe', 'cpu': 1, 'memory': 700},
          {'name': 'Compiler.exe', 'cpu': 65, 'memory': 100},
        ],
      }),
      capturedAt: DateTime(2026, 11, 26, 12, 30, 1),
    );
    final current = SystemSnapshot({
      'cpu': {'usage': 10},
      'memory': {'total': 1000, 'used': 100},
      'processes': [
        {'name': 'Current.exe', 'cpu': 10, 'memory': 100},
      ],
    });
    monitor.recordSnapshot(current);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonitorPage(
            engine: Engine(dataDir: data.path),
            monitor: monitor,
            active: false,
          ),
        ),
      ),
    );

    Future<void> inspect(String key, int slot) async {
      final chart = find.byKey(ValueKey(key));
      await tester.ensureVisible(chart);
      await tester.pumpAndSettle();
      final rect = tester.getRect(chart);
      await tester.tapAt(
        Offset(rect.left + rect.width * slot / 59, rect.center.dy),
      );
      await tester.pumpAndSettle();
    }

    await inspect('cpu-usage-history', 0);
    expect(find.byType(Dialog), findsNothing);
    await inspect('cpu-usage-history', 58);
    expect(find.text('Processes at 12:30:01'), findsOneWidget);
    final dialog = find.byType(Dialog);
    Finder process(String name) =>
        find.descendant(of: dialog, matching: find.text(name));
    expect(
      tester.getTopLeft(process('Compiler')).dy,
      lessThan(tester.getTopLeft(process('Browser')).dy),
    );
    monitor.recordSnapshot(current);
    await tester.pump();
    expect(process('Compiler'), findsOneWidget);
    expect(process('Current'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await inspect('memory-usage-history', 57);
    expect(find.text('Processes at 12:30:01'), findsOneWidget);
    expect(
      tester.getTopLeft(process('Browser')).dy,
      lessThan(tester.getTopLeft(process('Compiler')).dy),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
