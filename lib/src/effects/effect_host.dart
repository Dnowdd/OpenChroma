import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import '../engine/engine.dart';
import 'effect_library.dart';

const _host = 'effect.openchroma';

/// Size of the frame sent back from the page (a quarter of 320x200 pixels).
const frameWidth = 160;
const frameHeight = 100;

/// Injected before the effect's own scripts: declares the effect properties
/// as globals (that is how SignalRGB exposes them), stubs the `engine` object,
/// and streams the effect canvas back to Dart.
String _bootstrap(Map<String, Object> props) =>
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
  // Run change handlers once so effects that derive state from them initialize.
  window.addEventListener('load', function () {
    for (var k in P) {
      var fn = window['on' + k + 'Changed'];
      if (typeof fn === 'function') { try { fn(); } catch (e) { console.error(e); } }
    }
  });
})();
''';

/// Runs the current SignalRGB HTML effect in WebView2 and feeds its canvas to
/// the [Engine]. The preview must stay on screen: WebView2 throttles
/// animation frames of hidden views.
class EffectPreview extends StatefulWidget {
  const EffectPreview({super.key, required this.engine});
  final Engine engine;

  @override
  State<EffectPreview> createState() => _EffectPreviewState();
}

class _EffectPreviewState extends State<EffectPreview> {
  final _controller = WebviewController();
  StreamSubscription<dynamic>? _messages;
  bool _ready = false;
  String? _error;
  String? _loadedPath;
  Map<String, dynamic> _sentProps = {};
  ScriptID? _scriptId;
  bool _mapped = false;

  @override
  void initState() {
    super.initState();
    _init();
    widget.engine.addListener(_sync);
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _messages = _controller.webMessage.listen(_onMessage);
      if (!mounted) return;
      setState(() => _ready = true);
      _sync();
    } catch (e) {
      if (mounted) setState(() => _error = 'WebView2 unavailable: $e');
    }
  }

  void _onMessage(dynamic msg) {
    if (msg is Map && msg['f'] is String) {
      widget.engine.onFrame(
        CanvasFrame(frameWidth, frameHeight, base64Decode(msg['f'])),
      );
    }
  }

  Map<String, Object> _propValues(EffectInfo e) {
    final saved = widget.engine.effectSettings(e);
    return {
      for (final prop in e.properties) prop.name: prop.coerce(saved[prop.name]),
    };
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
    if (!_ready) return;
    final e = widget.engine.currentEffect;
    if (e == null) return;
    final values = _propValues(e);
    if (e.path != _loadedPath) {
      _loadedPath = e.path;
      _sentProps = Map.of(values);
      if (_scriptId != null) {
        await _controller.removeScriptToExecuteOnDocumentCreated(_scriptId!);
      }
      _scriptId = await _controller.addScriptToExecuteOnDocumentCreated(
        _bootstrap(values),
      );
      if (_mapped) {
        try {
          await _controller.removeVirtualHostNameMapping(_host);
        } catch (_) {}
      }
      _mapped = true;
      await _controller.addVirtualHostNameMapping(
        _host,
        p.dirname(e.path),
        WebviewHostResourceAccessKind.allow,
      );
      await _controller.loadUrl(
        'https://$_host/${Uri.encodeComponent(p.basename(e.path))}',
      );
      return;
    }
    // Live property edits: set the global and fire on<name>Changed().
    for (final entry in values.entries) {
      if (_sentProps[entry.key] == entry.value) continue;
      _sentProps[entry.key] = entry.value;
      final n = jsonEncode(entry.key);
      await _controller.executeScript(
        'window[$n] = ${jsonEncode(entry.value)};'
        '(function () { var f = window["on" + $n + "Changed"]; if (typeof f === "function") f(); })();',
      );
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_sync);
    _messages?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    // Lay the page out at its native 320x200 and scale the texture to fit.
    return AspectRatio(
      aspectRatio: canvasWidth / canvasHeight,
      child: FittedBox(
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Webview(_controller, scaleFactor: 1.0),
        ),
      ),
    );
  }
}
