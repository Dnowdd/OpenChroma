import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import 'src/engine/engine.dart';
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
  // --page=N reopens a page, e.g. after restarting as administrator.
  final page = args
      .map((a) => a.startsWith('--page=') ? int.tryParse(a.substring(7)) : null)
      .nonNulls
      .firstOrNull;
  runApp(OpenChromaApp(engine: engine, initialPage: page));
  engine.start();
}

class OpenChromaApp extends StatefulWidget {
  const OpenChromaApp({super.key, required this.engine, this.initialPage});
  final Engine engine;
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
        await widget.engine.shutdown();
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
    home: Shell(engine: widget.engine, initialPage: widget.initialPage),
  );
}
