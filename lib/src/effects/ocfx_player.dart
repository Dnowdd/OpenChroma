import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../audio/audio_service.dart';
import '../diagnostics/frame_profiler.dart';
import '../engine/engine.dart';
import 'effect_library.dart';
import 'ocfx_renderer.dart';

/// Size of the frames effects hand to the engine (a quarter of the canvas).
const frameWidth = 160;
const frameHeight = 100;

/// Runs the current `.ocfx` effect and feeds its frames to the [Engine],
/// whether or not any window is showing.
class OcfxPlayer {
  OcfxPlayer(this.engine) {
    engine.addListener(_sync);
    _sync();
  }

  final Engine engine;
  Timer? _timer;
  OcfxRenderer? _renderer;
  String? _effectId;

  /// The effect and settings of the frame shown while frozen.
  String? _frozenKey;
  final _clock = Stopwatch();

  static const _interval = Duration(milliseconds: 33);

  void _sync() {
    final e = engine.currentEffect;
    final definition = e?.definition;
    if (e == null || e.kind != EffectKind.ocfx || definition == null) {
      _stop();
      return;
    }
    if (e.id != _effectId) {
      _effectId = e.id;
      _renderer = OcfxRenderer(
        definition,
        width: frameWidth,
        height: frameHeight,
      );
      _clock
        ..reset()
        ..start();
    }
    final params = effectPropValues(engine, e);
    _renderer!.params = params;
    if (engine.frozen) {
      _timer?.cancel();
      _timer = null;
      _clock.stop();
      final key = '${e.id}|${jsonEncode(params)}';
      if (engine.frame == null || key != _frozenKey) _tick(force: true);
      _frozenKey = key;
      return;
    }
    _frozenKey = null;
    _clock.start();
    _timer ??= Timer.periodic(_interval, (_) => _tick());
  }

  void _tick({bool force = false}) {
    final r = _renderer;
    if (r == null) return;
    r.audio = engine.audioNotifier.value;
    FrameProfiler.count('effectFrame');
    FrameProfiler.measure('effectFrame', () {
      final rgb = r.render(_clock.elapsedMicroseconds / 1e6);
      engine.onFrame(CanvasFrame(frameWidth, frameHeight, rgb), force: force);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _renderer = null;
    _effectId = null;
    _clock.stop();
  }

  void dispose() {
    engine.removeListener(_sync);
    _stop();
  }
}

Map<String, Object> effectPropValues(Engine engine, EffectInfo e) {
  final saved = engine.effectSettings(e);
  return {
    for (final prop in e.properties) prop.name: prop.coerce(saved[prop.name]),
  };
}

/// A full-size PNG cover for an `.ocfx` effect, as if a song were playing,
/// or null when the effect stays (almost) black. Runs off the UI isolate.
Future<Uint8List?> renderOcfxCover(EffectInfo e, Map<String, Object> params) {
  final definition = e.definition;
  if (definition == null) return Future.value();
  return Isolate.run(() => _renderCover(definition, params));
}

Uint8List? _renderCover(
  Map<String, dynamic> definition,
  Map<String, Object> params,
) {
  final w = canvasWidth.toInt(), h = canvasHeight.toInt();
  final r = OcfxRenderer(definition, width: w, height: h)..params = params;
  const step = 1 / 30;
  Uint8List? frame;
  for (final target in const [2.5, 4.0, 5.5, 7.0]) {
    // Stepped from the start so beat ripples build up as they would live.
    for (var t = target - 2.5; t < target; t += step) {
      r.audio = demoAudio(t);
      frame = r.render(t);
    }
    if (frame != null && !_dark(frame)) {
      return img.encodePng(
        img.Image.fromBytes(
          width: w,
          height: h,
          bytes: frame.buffer,
          numChannels: 3,
        ),
      );
    }
  }
  return null;
}

bool _dark(Uint8List rgb) {
  var sum = 0, n = 0;
  for (var i = 0; i + 2 < rgb.length; i += 3 * 97) {
    sum += rgb[i] + rgb[i + 1] + rgb[i + 2];
    n++;
  }
  return n == 0 || sum / n < 18;
}

/// Synthetic music for covers, so audio effects render as if a song played.
AudioFrame demoAudio(double t) {
  final bands = [
    for (var i = 0; i < 64; i++)
      (0.85 - i / 63 * 0.55 + 0.18 * math.sin(t * 3 + i * 0.7)).clamp(0.0, 1.0),
  ];
  return AudioFrame(
    bands,
    0.75,
    0.85,
    0.6,
    0.4,
    (t % 0.5) < 0.12 ? 1 : 0.2,
    (t / 0.5).floor(),
  );
}
