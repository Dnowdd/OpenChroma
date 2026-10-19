import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import 'src/ai/ai_service.dart';
import 'src/ai/assistant.dart';
import 'src/alerts/alert_service.dart';
import 'src/diagnostics/frame_profiler.dart';
import 'src/effects/effect_host.dart';
import 'src/engine/engine.dart';
import 'src/fans/fan_service.dart';
import 'src/monitor/system_monitor.dart';
import 'src/paths.dart';
import 'src/ui/shell.dart';
import 'src/ui/theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Keep effects animating when the window is minimized or covered.
    await WebviewController.initializeEnvironment(
      userDataPath: p.join(openChromaDataDir(), 'webview'),
      additionalArguments:
          '--disable-background-timer-throttling '
          '--disable-renderer-backgrounding --disable-backgrounding-occluded-windows '
          '--autoplay-policy=no-user-gesture-required',
    );
  } catch (_) {
    // Already initialized (hot restart) or WebView2 missing; the preview reports it.
  }
  final engine = Engine();
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
  engine.addListener(() => monitor.setActive(engine, engine.reactive));
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
    this.initialPage,
  });
  final Engine engine;
  final SystemMonitor monitor;
  final FanService fans;
  final AlertService alerts;
  final AiService ai;
  final Assistant assistant;
  final int? initialPage;

  @override
  State<OpenChromaApp> createState() => _OpenChromaAppState();
}

class _OpenChromaAppState extends State<OpenChromaApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
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
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenChroma',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
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
      initialPage: widget.initialPage,
    ),
  );
}
