import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/i18n/l10n.dart';
import 'package:openchroma/src/plugins/plugin_trust.dart';
import 'package:openchroma/src/ui/plugin_approval.dart';
import 'package:openchroma/src/ui/theme.dart';

UserPlugin _plugin(String name, PluginTrust trust, {bool replaces = false}) =>
    UserPlugin(
      file: PluginFile(
        name: name,
        path: 'C:/plugins/$name',
        size: 2048,
        modified: DateTime(2026, 10, 23, 16, 30),
        sha256: 'ab' * 32,
        source: '',
      ),
      trust: trust,
      changed: false,
      replacesBundled: replaces,
      overrides: const [],
    );

void main() {
  late Directory dir;
  late Engine engine;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('oc_approval');
    engine = Engine(dataDir: dir.path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: PluginApprovalBanner(engine: engine)),
    ),
  );

  testWidgets('the banner shows only while a plugin waits', (tester) async {
    await pump(tester);
    expect(find.text(l10n.pluginTrustReview), findsNothing);

    engine.userPlugins = [
      _plugin('a.js', PluginTrust.approved),
      _plugin('b.js', PluginTrust.pending),
    ];
    engine.notifyListeners();
    await tester.pump();
    expect(find.text(l10n.pluginTrustBanner(1)), findsOneWidget);
  });

  testWidgets('the dialog lists file facts and the warning', (tester) async {
    engine.userPlugins = [
      _plugin('lamp.js', PluginTrust.pending, replaces: true),
      _plugin('old.js', PluginTrust.denied),
    ];
    await pump(tester);
    await tester.tap(find.text(l10n.pluginTrustReview));
    await tester.pumpAndSettle();

    expect(find.text(l10n.pluginTrustIntro), findsOneWidget);
    expect(find.text('lamp.js'), findsOneWidget);
    expect(find.text('abababababab'), findsNWidgets(2));
    expect(find.text('2.0 KB'), findsNWidgets(2));
    expect(find.text('2026-10-23 16:30'), findsNWidgets(2));
    expect(find.text(l10n.pluginTrustReplaces), findsOneWidget);
    expect(find.text(l10n.pluginTrustApprove), findsNWidgets(2));
  });
}
