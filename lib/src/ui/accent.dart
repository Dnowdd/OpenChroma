import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/engine.dart';

/// The app's accent color, taken from the selected effect: when the effect
/// or one of its settings changes, a few seconds of its frames are sampled
/// and the most present color becomes the accent, fixed until the next
/// change. Strongly colored effects give their dominant hue (at a fixed
/// saturation and brightness so it reads on the dark surfaces); white or
/// grey ones give a neutral light accent.
class AccentController extends ChangeNotifier {
  AccentController(this.engine) {
    engine.addListener(_onEngine);
    engine.frameNotifier.addListener(_onFrame);
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _step());
    _onEngine();
  }

  final Engine engine;
  static const neutral = Color(0xFFEDEDF0);
  static const _bins = 36;

  // How long to look at an effect before settling, and the longest to wait
  // for light (sound-reactive effects are dark in silence).
  static const _window = Duration(milliseconds: 2500);
  static const _patience = Duration(seconds: 12);

  final _histogram = List<double>.filled(_bins, 0);
  double _grey = 0;
  double _lit = 0;
  int _frames = 0;
  DateTime? _since;
  String? _signature;
  final _cache = <String, Color>{};
  Timer? _timer;

  Color _target = neutral;
  Color value = neutral;

  void _onEngine() {
    final e = engine.currentEffect;
    final sig = e == null
        ? ''
        : '${e.path}|${e.title}|${jsonEncode(engine.effectSettings(e))}';
    if (sig == _signature) return;
    _signature = sig;
    final cached = _cache[sig];
    if (cached != null || e == null) {
      _target = cached ?? neutral;
      _since = null;
      return;
    }
    _histogram.fillRange(0, _bins, 0);
    _grey = _lit = 0;
    _since = DateTime.now();
  }

  void _onFrame() {
    final since = _since;
    final f = engine.frameNotifier.value;
    if (since == null || f == null) return;
    // A sparse grid on every other frame is plenty for "most present".
    if (_frames++ % 2 == 0) {
      final px = f.rgb;
      for (var y = 0; y < f.height; y += 5) {
        for (var x = 0; x < f.width; x += 5) {
          final o = (y * f.width + x) * 3;
          final hsv = HSVColor.fromColor(
            Color.fromARGB(255, px[o], px[o + 1], px[o + 2]),
          );
          if (hsv.value < .12) continue;
          final weight = hsv.value * hsv.value;
          _lit += weight;
          _grey += weight * (1 - hsv.saturation);
          _histogram[(hsv.hue / 10).floor() % _bins] += weight * hsv.saturation;
        }
      }
    }
    final age = DateTime.now().difference(since);
    // Settle once enough light was seen over the window, or give up waiting.
    if ((age >= _window && _lit > 40) || age >= _patience) _settle();
  }

  void _settle() {
    _since = null;
    final colored = _histogram.fold<double>(0, (a, b) => a + b);
    Color result;
    if (_lit < 1 || colored < _grey * .6) {
      result = neutral;
    } else {
      var best = 0;
      for (var i = 1; i < _bins; i++) {
        if (_histogram[i] > _histogram[best]) best = i;
      }
      // Average the winning bin with its neighbours for a smooth hue.
      double sx = 0, sy = 0;
      for (var d = -1; d <= 1; d++) {
        final i = (best + d) % _bins;
        final a = (i * 10 + 5) * math.pi / 180;
        sx += math.cos(a) * _histogram[i];
        sy += math.sin(a) * _histogram[i];
      }
      final hue = (math.atan2(sy, sx) * 180 / math.pi + 360) % 360;
      result = HSVColor.fromAHSV(1, hue, .55, 1).toColor();
    }
    if (_signature != null) _cache[_signature!] = result;
    _target = result;
  }

  void _step() {
    if (value == _target) return;
    final next = Color.lerp(value, _target, .14)!;
    // Snap once close enough so the timer goes quiet.
    final done =
        ((next.r - _target.r).abs() +
            (next.g - _target.g).abs() +
            (next.b - _target.b).abs()) <
        .01;
    value = done ? _target : next;
    notifyListeners();
  }

  @override
  void dispose() {
    engine.removeListener(_onEngine);
    engine.frameNotifier.removeListener(_onFrame);
    _timer?.cancel();
    super.dispose();
  }
}

/// Makes the live accent available below it; read it with [LiveAccent.of].
class LiveAccent extends InheritedNotifier<AccentController> {
  const LiveAccent({
    super.key,
    required AccentController controller,
    required super.child,
  }) : super(notifier: controller);

  static Color of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiveAccent>()
          ?.notifier
          ?.value ??
      AccentController.neutral;
}

/// Text/icon color that reads on top of an accent fill.
Color onAccent(Color accent) =>
    accent.computeLuminance() > .45 ? const Color(0xFF0C0C0E) : Colors.white;

/// The effect as it is being sent to the devices, drawn from the frames the
/// engine receives (no second WebView). Scales smoothly to any size; [blur]
/// turns it into an ambient glow.
class LiveCanvas extends StatefulWidget {
  const LiveCanvas({
    super.key,
    required this.engine,
    this.blur = 0,
    this.fallback,
  });
  final Engine engine;
  final double blur;

  /// Shown instead while the light is (nearly) off, e.g. a sound-reactive
  /// effect during silence.
  final Widget? fallback;

  @override
  State<LiveCanvas> createState() => _LiveCanvasState();
}

class _LiveCanvasState extends State<LiveCanvas> {
  ui.Image? _image;
  bool _decoding = false;
  bool _dark = true;

  @override
  void initState() {
    super.initState();
    widget.engine.frameNotifier.addListener(_onFrame);
    _onFrame();
  }

  @override
  void dispose() {
    widget.engine.frameNotifier.removeListener(_onFrame);
    _image?.dispose();
    super.dispose();
  }

  void _onFrame() {
    final f = widget.engine.frameNotifier.value;
    if (f == null || _decoding) return;
    _decoding = true;
    // "Off" when only a sliver of the canvas is lit (e.g. a spectrum's
    // idle baseline).
    var lit = 0, samples = 0;
    for (var i = 0; i + 2 < f.rgb.length; i += 3 * 23) {
      samples++;
      if (math.max(f.rgb[i], math.max(f.rgb[i + 1], f.rgb[i + 2])) > 40) lit++;
    }
    final dark = lit < samples * .06;
    final n = f.width * f.height;
    final rgba = Uint8List(n * 4);
    for (var i = 0, o = 0; i < n * 3; i += 3, o += 4) {
      rgba[o] = f.rgb[i];
      rgba[o + 1] = f.rgb[i + 1];
      rgba[o + 2] = f.rgb[i + 2];
      rgba[o + 3] = 255;
    }
    ui.decodeImageFromPixels(rgba, f.width, f.height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      _decoding = false;
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _image;
      setState(() {
        _image = image;
        _dark = dark;
      });
      // RawImage paints a clone; a post-frame dispose never runs while hidden and leaks.
      old?.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback;
    if (fallback == null) return _canvas();
    return Stack(
      fit: StackFit.expand,
      children: [
        _canvas(),
        AnimatedOpacity(
          opacity: _dark ? 1 : 0,
          duration: const Duration(milliseconds: 600),
          child: fallback,
        ),
      ],
    );
  }

  Widget _canvas() {
    final image = _image;
    if (image == null) return const ColoredBox(color: Colors.black);
    final raw = RawImage(
      image: image,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    if (widget.blur <= 0) return raw;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: widget.blur,
        sigmaY: widget.blur,
        tileMode: TileMode.clamp,
      ),
      child: raw,
    );
  }
}
