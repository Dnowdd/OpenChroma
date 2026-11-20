import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import '../diagnostics/frame_profiler.dart';
import '../engine/engine.dart';
import '../paths.dart';
import '../ui/accent.dart';
import 'effect_library.dart';
import 'ocfx_player.dart';

/// Injected before an HTML effect's own scripts: declares the effect
/// parameters as globals (how HTML effects read them), stubs the `engine`
/// object and, when [stream] is set, streams the canvas back to Dart.
String _bootstrap(Map<String, Object> props, {required bool stream}) =>
    '''
(function () {
  var P = ${jsonEncode(props)};
  for (var k in P) window[k] = P[k];
  var zeros = function (n) { var a = []; for (var i = 0; i < n; i++) a.push(0); return a; };
  window.engine = window.engine || {
    audio: { level: -100, density: 0, width: 0, freq: zeros(200) },
    zone: { hue: zeros(${frameWidth * frameHeight}), saturation: zeros(${frameWidth * frameHeight}),
            lightness: zeros(${frameWidth * frameHeight}), imagedata: { data: zeros(4) } },
    vision: {}, getSensorValue: function () { return { value: 0 }; },
    keypressed: false
  };
  $_audioScript
  ${stream ? _streamScript : _demoAudioScript}
  // Run change handlers once so effects that derive state from them initialize.
  window.addEventListener('load', function () {
    for (var k in P) {
      var fn = window['on' + k + 'Changed'];
      if (typeof fn === 'function') { try { fn(); } catch (e) { console.error(e); } }
    }
  });
})();
''';

const _streamScript =
    '''
  var off = document.createElement('canvas');
  off.width = $frameWidth; off.height = $frameHeight;
  var octx = null;
  function grab() {
    var c = document.getElementById('exCanvas') || document.querySelector('canvas');
    if (!c || !window.chrome || !window.chrome.webview) return;
    octx = octx || off.getContext('2d', { willReadFrequently: true });
    octx.drawImage(c, 0, 0, $frameWidth, $frameHeight);
    var d = octx.getImageData(0, 0, $frameWidth, $frameHeight).data;
    var rgb = new Uint8Array($frameWidth * $frameHeight * 3);
    for (var i = 0, j = 0; i < d.length; i += 4) { rgb[j++] = d[i]; rgb[j++] = d[i + 1]; rgb[j++] = d[i + 2]; }
    var bin = '';
    for (var k = 0; k < rgb.length; k += 0x8000) bin += String.fromCharCode.apply(null, rgb.subarray(k, k + 0x8000));
    window.chrome.webview.postMessage({ f: btoa(bin) });
  }
  setInterval(grab, 33);
''';

/// Receives audio frames from the host and fills `engine.audio` the way
/// HTML audio effects read it (200 bins of 0..127, level in dB).
const _audioScript = '''
  window.__audio = { bands: [], level: 0, bass: 0, mid: 0, treble: 0, beat: 0 };
  if (window.chrome && window.chrome.webview) {
    window.chrome.webview.addEventListener('message', function (e) {
      var d = e.data;
      if (typeof d === 'string') { try { d = JSON.parse(d); } catch (_) { return; } }
      if (!d || !d.audio) return;
      var a = d.audio, b = a.bands || [], f = new Array(200);
      window.__audio = a;
      for (var i = 0; i < 200; i++) f[i] = Math.round((b[Math.floor(i * b.length / 200)] || 0) * 127);
      window.engine.audio.freq = f;
      window.engine.audio.level = a.level > 0 ? -60 + a.level * 60 : -100;
      window.engine.audio.density = a.treble;
    });
  }
''';

/// Synthetic music for the cover baker, so audio effects render as if a
/// song were playing.
const _demoAudioScript = '''
  setInterval(function () {
    var t = performance.now() / 1000, bands = [];
    for (var i = 0; i < 64; i++) {
      var x = i / 63;
      bands.push(Math.max(0, Math.min(1, 0.85 - x * 0.55 + 0.18 * Math.sin(t * 3 + i * 0.7))));
    }
    var beat = (t % 0.5) < 0.12 ? 1 : 0.2;
    window.__audio = { bands: bands, level: 0.75, bass: 0.85, mid: 0.6, treble: 0.4, beat: beat,
                       beats: Math.floor(t / 0.5) };
  }, 33);
''';

Future<void>? _environment;

/// Starts WebView2 the first time an HTML effect needs it; `.ocfx` effects
/// never do, so most sessions run without a browser.
Future<void> _ensureEnvironment() => _environment ??= () async {
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
    // Already initialized (hot restart) or WebView2 missing; initialize()
    // on the controller reports it.
  }
}();

Future<WebviewController> _newWebview() async {
  await _ensureEnvironment();
  final c = WebviewController();
  _liveWebviews.add(c);
  await c.initialize();
  await c.setBackgroundColor(Colors.black);
  await c.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
  return c;
}

void _disposeWebview(WebviewController c) {
  if (_liveWebviews.remove(c)) c.dispose();
}

/// Loads HTML effects into one WebView: maps the effect's folder to a
/// virtual HTTPS host and installs the bootstrap script for each load.
class _EffectLoader {
  _EffectLoader(this.controller, this.host);
  final WebviewController controller;
  final String host;
  ScriptID? _scriptId;
  bool _mapped = false;

  Future<void> load(
    EffectInfo e,
    Map<String, Object> props, {
    required bool stream,
  }) async {
    if (_scriptId != null) {
      await controller.removeScriptToExecuteOnDocumentCreated(_scriptId!);
    }
    _scriptId = await controller.addScriptToExecuteOnDocumentCreated(
      _bootstrap(props, stream: stream),
    );
    if (_mapped) {
      try {
        await controller.removeVirtualHostNameMapping(host);
      } catch (_) {}
    }
    _mapped = true;
    await controller.addVirtualHostNameMapping(
      host,
      p.dirname(e.path),
      WebviewHostResourceAccessKind.allow,
    );
    await controller.loadUrl(
      'https://$host/${Uri.encodeComponent(p.basename(e.path))}',
    );
  }
}

/// Set when WebView2, which renders HTML effects, cannot start (usually
/// because the runtime is not installed).
final webviewProblem = ValueNotifier<String?>(null);

/// Every live WebView, so they can be torn down before the app exits.
///
/// The Windows embedder destroys the engine (and its texture registrar)
/// before plugins; a WebView still registered then unregisters its texture
/// from freed memory and crashes the exit (the 0x1e8 null read in
/// crash.log). Disposing them first leaves the plugin nothing to clean up.
final _liveWebviews = <WebviewController>{};

Future<void> disposeAllWebviews() async {
  final all = _liveWebviews.toList();
  _liveWebviews.clear();
  await Future.wait([
    for (final c in all)
      c
          .dispose()
          .timeout(const Duration(seconds: 1), onTimeout: () {})
          .catchError((_) {}),
  ]);
}

/// The running effect, small: `.ocfx` effects are drawn by [OcfxPlayer]
/// and shown from the engine's frames; HTML effects run in a WebView here.
class EffectPreview extends StatelessWidget {
  const EffectPreview({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => AspectRatio(
      aspectRatio: canvasWidth / canvasHeight,
      child: engine.currentEffect?.kind == EffectKind.html
          ? _HtmlEffectPreview(engine: engine)
          : LiveCanvas(engine: engine),
    ),
  );
}

/// Runs the current HTML effect in WebView2 and feeds its canvas to the
/// [Engine]. It must stay on screen: WebView2 throttles animation frames
/// of hidden views.
class _HtmlEffectPreview extends StatefulWidget {
  const _HtmlEffectPreview({required this.engine});
  final Engine engine;

  @override
  State<_HtmlEffectPreview> createState() => _HtmlEffectPreviewState();
}

class _HtmlEffectPreviewState extends State<_HtmlEffectPreview> {
  WebviewController? _controller;
  _EffectLoader? _loader;
  StreamSubscription<dynamic>? _messages;
  String? _error;
  String? _loadedKey;
  Map<String, dynamic> _sentProps = {};

  // Every texture frame makes Flutter redraw the window, visible or not,
  // and effects animate at the display's rate (120-144 Hz here). The LEDs
  // sample at 30 Hz, so the preview needs no more, and nothing while the
  // window is hidden. The effect itself keeps its own pace either way.
  static const _fps = 30;
  static const _hiddenFps = 1;

  bool _hidden = false;
  int? _fpsSet;

  late final _lifecycle = AppLifecycleListener(
    onHide: () => _applyFps(hidden: true),
    onShow: () => _applyFps(hidden: false),
  );

  Future<void> _applyFps({bool? hidden}) async {
    _hidden = hidden ?? _hidden;
    final fps = _hidden || widget.engine.frozen ? _hiddenFps : _fps;
    final c = _controller;
    if (c == null || fps == _fpsSet) return;
    _fpsSet = fps;
    await c.setFpsLimit(fps);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _init();
    widget.engine.addListener(_sync);
    widget.engine.audioNotifier.addListener(_sendAudio);
  }

  bool _sendingAudio = false;

  void _sendAudio() {
    final frame = widget.engine.audioNotifier.value;
    final c = _controller;
    if (c == null || _sendingAudio || frame.bands.isEmpty) return;
    _sendingAudio = true;
    c
        .postWebMessage(jsonEncode({'audio': frame.toJson()}))
        .whenComplete(() => _sendingAudio = false);
  }

  Future<void> _init() async {
    try {
      final c = await _newWebview();
      if (!mounted) {
        _disposeWebview(c);
        return;
      }
      _hidden = switch (SchedulerBinding.instance.lifecycleState) {
        AppLifecycleState.hidden || AppLifecycleState.paused => true,
        _ => false,
      };
      _fpsSet = _hidden || widget.engine.frozen ? _hiddenFps : _fps;
      await c.setFpsLimit(_fpsSet!);
      _messages = c.webMessage.listen(_onMessage);
      if (!mounted) return;
      setState(() {
        _controller = c;
        _loader = _EffectLoader(c, 'effect.openchroma');
      });
      _sync();
    } catch (e) {
      webviewProblem.value = '$e';
      if (mounted) setState(() => _error = 'WebView2 unavailable: $e');
    }
  }

  void _onMessage(dynamic msg) {
    if (msg is Map && msg['f'] is String) {
      FrameProfiler.count('effectFrame');
      FrameProfiler.measure(
        'effectFrame',
        () => widget.engine.onFrame(
          CanvasFrame(frameWidth, frameHeight, base64Decode(msg['f'])),
        ),
      );
    }
  }

  Future<void>? _syncing;
  bool _resync = false;

  /// Serializes [_doSync]; engine notifications arrive far faster than
  /// WebView2 calls complete.
  Future<void> _sync() async {
    if (_syncing != null) {
      _resync = true;
      return;
    }
    do {
      _resync = false;
      _syncing = _doSync();
      try {
        await _syncing;
      } catch (e) {
        debugPrint('effect sync failed: $e');
      }
      _syncing = null;
    } while (_resync && mounted);
  }

  Future<void> _doSync() async {
    final c = _controller, loader = _loader;
    if (c == null || loader == null) return;
    await _applyFps();
    final e = widget.engine.currentEffect;
    if (e == null || e.kind != EffectKind.html) return;
    final values = effectPropValues(widget.engine, e);
    final key = '${e.path}|${e.title}';
    if (key != _loadedKey) {
      _loadedKey = key;
      _sentProps = Map.of(values);
      await loader.load(e, values, stream: true);
      return;
    }
    // Live property edits: set the global and fire on<name>Changed().
    for (final entry in values.entries) {
      if (_sentProps[entry.key] == entry.value) continue;
      _sentProps[entry.key] = entry.value;
      final n = jsonEncode(entry.key);
      await c.executeScript(
        'window[$n] = ${jsonEncode(entry.value)};'
        '(function () { var f = window["on" + $n + "Changed"]; if (typeof f === "function") f(); })();',
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.engine.removeListener(_sync);
    widget.engine.audioNotifier.removeListener(_sendAudio);
    _messages?.cancel();
    final c = _controller;
    if (c != null) _disposeWebview(c);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error != null || c == null) {
      return Tooltip(
        message: _error ?? '',
        child: ColoredBox(
          color: Colors.black,
          child: _error == null
              ? null
              : const Icon(
                  Icons.videocam_off_outlined,
                  size: 16,
                  color: Colors.white38,
                ),
        ),
      );
    }
    // Lay the page out at its native 320x200 and scale the texture to fit.
    return FittedBox(
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Webview(c, scaleFactor: 1.0),
      ),
    );
  }
}

/// Renders covers for effects that have none. `.ocfx` effects are drawn
/// directly; HTML effects run for a few seconds in a WebView that exists
/// only while one is waiting. Devices are not affected.
///
/// Must be in the widget tree (it may be covered by other widgets).
class CoverBaker extends StatefulWidget {
  const CoverBaker({super.key, required this.engine});
  final Engine engine;

  @override
  State<CoverBaker> createState() => _CoverBakerState();
}

class _CoverBakerState extends State<CoverBaker> {
  WebviewController? _controller;
  _EffectLoader? _loader;
  bool _running = false;
  final _failed = <String>{};

  // Returns a PNG data URL of the effect canvas, or null while it is still
  // (almost) black.
  static const _snapshot = '''
(function () {
  var c = document.getElementById('exCanvas') || document.querySelector('canvas');
  if (!c) return null;
  var s = document.createElement('canvas'); s.width = 32; s.height = 20;
  var x = s.getContext('2d'); x.drawImage(c, 0, 0, 32, 20);
  var d = x.getImageData(0, 0, 32, 20).data, sum = 0;
  for (var i = 0; i < d.length; i += 4) sum += d[i] + d[i + 1] + d[i + 2];
  if (sum / (d.length / 4) < 18) return null;
  return c.toDataURL('image/png');
})()''';

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_kick);
    _kick();
  }

  void _kick() {
    if (!_running) _bake();
  }

  Future<void> _bake() async {
    _running = true;
    try {
      while (mounted) {
        final pending = widget.engine.effectsWithoutCover
            .where((e) => !_failed.contains(e.id))
            .toList();
        if (pending.isEmpty) break;
        final e = pending.first;
        final params = effectPropValues(widget.engine, e);
        final png = e.kind == EffectKind.ocfx
            ? await renderOcfxCover(e, params)
            : await _bakeHtml(e, params);
        if (!mounted) return;
        if (png == null) {
          _failed.add(e.id);
          continue;
        }
        widget.engine.saveCover(e, png);
      }
    } catch (e) {
      debugPrint('cover baker stopped: $e');
    } finally {
      _running = false;
      _closeWebview();
    }
  }

  Future<Uint8List?> _bakeHtml(EffectInfo e, Map<String, Object> params) async {
    var loader = _loader;
    if (loader == null) {
      try {
        final c = await _newWebview();
        // Hidden under the UI and read through scripts, never on screen.
        await c.setFpsLimit(1);
        if (!mounted) {
          _disposeWebview(c);
          return null;
        }
        loader = _EffectLoader(c, 'cover.openchroma');
        setState(() {
          _controller = c;
          _loader = loader;
        });
      } catch (_) {
        // Without a WebView, HTML effects keep their generated artwork.
        return null;
      }
    }
    await loader.load(e, params, stream: false);
    for (var attempt = 0; attempt < 4; attempt++) {
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 2500 : 1500),
      );
      final r = await loader.controller.executeScript(_snapshot);
      if (r is String && r.startsWith('data:image/png;base64,')) {
        return base64Decode(r.substring(r.indexOf(',') + 1));
      }
    }
    return null;
  }

  void _closeWebview() {
    final c = _controller;
    if (c == null) return;
    _controller = null;
    _loader = null;
    _disposeWebview(c);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.engine.removeListener(_kick);
    final c = _controller;
    if (c != null) _disposeWebview(c);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: c == null ? null : Webview(c, scaleFactor: 1.0),
    );
  }
}
