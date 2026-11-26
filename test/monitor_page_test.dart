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
}
