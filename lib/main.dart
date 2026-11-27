import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/ai/ai_service.dart';
import 'src/ai/assistant.dart';
import 'src/alerts/alert_service.dart';
import 'src/diagnostics/frame_profiler.dart';
import 'src/effects/effect_host.dart';
import 'src/effects/ocfx_player.dart';
import 'src/engine/engine.dart';
import 'src/fans/fan_service.dart';
import 'src/i18n/l10n.dart';
import 'src/monitor/system_monitor.dart';
import 'src/system/background_trim.dart';
import 'src/system/update_check.dart';
import 'src/ui/shell.dart';
import 'src/ui/theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = LanguageController();
  final updates = UpdateChecker()..start();
  final engine = Engine();
  OcfxPlayer(engine);
  final monitor = SystemMonitor();
  // Fans run for the whole session, whichever page is open.
  final fans = FanService(monitor)..start();
  // The reactive light reads the same sensors the monitor shows, and needs
  // them sampled while it is on, whichever page is open.
  engine.readTemperature = (source) => switch (source) {
    ReactiveSource.cpu => monitor.snapshot?.cpu.temp,
    ReactiveSource.gpu =>
      monitor.snapshot?.gpus.where((g) => !g.integrated).firstOrNull?.temp ??
          monitor.snapshot?.gpus.firstOrNull?.temp,
  };
  engine.readSensor = (key) {
    final s = monitor.snapshot;
    if (s == null) return null;
    final gpu =
        s.gpus.where((g) => !g.integrated).firstOrNull ?? s.gpus.firstOrNull;
    return switch (key) {
      'cpu.temp' => s.cpu.temp,
      'cpu.usage' => s.cpu.usage,
      'cpu.clock' => s.cpu.clock,
      'cpu.power' => s.cpu.power,
      'gpu.temp' => gpu?.temp,
      'gpu.usage' => gpu?.usage,
      'gpu.clock' => gpu?.clock,
      'gpu.power' => gpu?.power,
      'gpu.fan' => gpu?.fan,
      'ram.usage' => s.memory.percent,
      _ => null,
    };
  };
  engine.addListener(
    () => monitor.setActive(engine, engine.reactive || engine.needsSensors),
  );
  final alerts = AlertService(monitor: monitor, fans: fans, engine: engine);
  final ai = AiService();
  final assistant = Assistant(
    ai: ai,
    engine: engine,
    monitor: monitor,
    fans: fans,
  );
  // --page=N reopens a page, e.g. after restarting as administrator.
  final page = args
      .map((a) => a.startsWith('--page=') ? int.tryParse(a.substring(7)) : null)
      .nonNulls
      .firstOrNull;
  FrameProfiler.start();
  if (kProfile) engine.addListener(() => FrameProfiler.count('engine'));
  runApp(
    OpenChromaApp(
      engine: engine,
      monitor: monitor,
      fans: fans,
      alerts: alerts,
      ai: ai,
      assistant: assistant,
      language: language,
      updates: updates,
      initialPage: page,
    ),
  );
  engine.start();
}

class OpenChromaApp extends StatefulWidget {
  const OpenChromaApp({
    super.key,
    required this.engine,
    required this.monitor,
    required this.fans,
    required this.alerts,
    required this.ai,
    required this.assistant,
    required this.language,
    required this.updates,
    this.initialPage,
  });
  final Engine engine;
  final SystemMonitor monitor;
  final FanService fans;
  final AlertService alerts;
  final AiService ai;
  final Assistant assistant;
  final LanguageController language;
  final UpdateChecker updates;
  final int? initialPage;

  @override
  State<OpenChromaApp> createState() => _OpenChromaAppState();
}

class _OpenChromaAppState extends State<OpenChromaApp> {
  late final AppLifecycleListener _lifecycle;
  final _trim = BackgroundTrim();
  int? _page;

  @override
  void initState() {
    super.initState();
    widget.language.addListener(() => _page = Pages.settings);
    // Give plugins a chance to apply their shutdown color before exiting.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        // Fans go back to the BIOS / driver before anything else.
        widget.fans.shutdown();
        await widget.engine.shutdown();
        // Before the embedder tears the engine down (see disposeAllWebviews).
        await disposeAllWebviews();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _trim.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.language,
    builder: (context, _) => MaterialApp(
      key: ValueKey(widget.language.locale),
      title: 'OpenChroma',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: widget.language.locale,
      supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The Windows embedder's accessibility bridge crashes (null dereference
      // in accessibility_bridge.cc) after it fails to apply semantics updates
      // that move nodes between parents, which this UI does on filtering and
      // resizing. Publishing no semantics tree avoids that code path.
      builder: (context, child) => ExcludeSemantics(child: child!),
      home: Shell(
        engine: widget.engine,
        monitor: widget.monitor,
        fans: widget.fans,
        alerts: widget.alerts,
        ai: widget.ai,
        assistant: widget.assistant,
        language: widget.language,
        updates: widget.updates,
        initialPage: _page ?? widget.initialPage,
      ),
    ),
  );
}
