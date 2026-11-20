import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/audio_service.dart';

/// Draws OpenChroma's declarative `.ocfx` effects straight into an RGB
/// buffer, without a browser.
///
/// Effects are authored for a 320x200 canvas; this renders that space at
/// [width] x [height], with each pixel covering its share of the canvas.
/// Layers are drawn bottom to top from the elapsed time, so the output is
/// deterministic and frame-rate independent (except beat ripples, which
/// keep the rings they spawned).
class OcfxRenderer {
  OcfxRenderer(this.definition, {this.width = 160, this.height = 100})
    : _sx = width / _w,
      _sy = height / _h,
      _r = Float64List(width * height),
      _g = Float64List(width * height),
      _b = Float64List(width * height);

  final Map<String, dynamic> definition;
  final int width;
  final int height;

  /// The effect's parameter values, by name.
  Map<String, Object> params = const {};
  AudioFrame audio = AudioFrame.silent;

  static const _w = 320.0;
  static const _h = 200.0;
  final double _sx, _sy;
  final Float64List _r, _g, _b;

  double _alpha = 1;
  _Blend _blend = _Blend.normal;
  final _ripples = <int, _RippleState>{};

  /// Renders the frame at [t] seconds as RGB bytes, row by row.
  Uint8List render(double t) {
    _alpha = 1;
    _blend = _Blend.normal;
    final bg = _color(_val(definition['background'])) ?? _black;
    _r.fillRange(0, _r.length, bg.r);
    _g.fillRange(0, _g.length, bg.g);
    _b.fillRange(0, _b.length, bg.b);
    final layers = definition['layers'];
    if (layers is List) {
      for (var i = 0; i < layers.length; i++) {
        final l = layers[i];
        if (l is! Map) continue;
        final type = l['type'];
        if (_val(l['enabled']) == false) continue;
        _blend = _blends[l['blend']] ?? _Blend.normal;
        _alpha = _selfAlpha.contains(type) ? 1 : _frac(l['opacity'], 1);
        try {
          _drawLayer(type, l, t, i);
        } catch (_) {}
      }
    }
    final out = Uint8List(width * height * 3);
    for (var i = 0, o = 0; i < _r.length; i++) {
      out[o++] = _byte(_r[i]);
      out[o++] = _byte(_g[i]);
      out[o++] = _byte(_b[i]);
    }
    return out;
  }

  static int _byte(double v) => v <= 0 ? 0 : (v >= 255 ? 255 : v.round());

  void _drawLayer(Object? type, Map l, double t, int idx) {
    switch (type) {
      case 'plasma':
        _plasma(l, t);
      case 'noise':
        _noise(l, t);
      case 'fire':
        _fire(l, t);
      case 'rain':
        _rain(l, t, idx);
      case 'stars':
        _stars(l, t, idx);
      case 'heartbeat':
        _heartbeat(l, t);
      case 'strobe':
        _strobe(l, t);
      case 'bars':
        _bars(l);
      case 'meter':
        _meter(l);
      case 'flash':
        _flash(l);
      case 'ripple':
        _ripple(l, idx);
      case 'solid':
        _fillRect(0, 0, _w, _h, _solid(_color(_val(l['color'])) ?? _white));
      case 'gradient':
        _loopGradient(l, t, _colorList(_val(l['colors'])) ?? [_black, _white]);
      case 'spectrum':
        final s = _num(l['saturation'], 100), li = _num(l['lightness'], 50);
        _loopGradient(l, t, [
          for (var h = 0; h < 360; h += 30) _hsl(h.toDouble(), s, li),
        ]);
      case 'pulse':
        _pulse(l, t);
      case 'wave':
        _wave(l, t);
      case 'sweep':
        _sweep(l, t);
      case 'rings':
        _rings(l, t);
      case 'sparkle':
        _sparkle(l, t, idx);
    }
  }

  // ------------------------------------------------------------- values
  double _signal(String name) => switch (name) {
    'level' => audio.level,
    'bass' => audio.bass,
    'mid' => audio.mid,
    'treble' => audio.treble,
    'beat' => audio.beat,
    'beats' => audio.beats.toDouble(),
    _ => 0,
  };

  Object? _val(Object? v) {
    if (v is String && v.startsWith('@')) return _signal(v.substring(1)) * 100;
    if (v is String && v.startsWith(r'$')) {
      final name = v.substring(1);
      final g = params[name];
      if (g != null) return g;
      final decl = (definition['params'] as Map?)?[name];
      return decl is Map && decl['default'] != null ? decl['default'] : 0;
    }
    if (v is List) return [for (final e in v) _val(e)];
    return v;
  }

  double _num(Object? v, double d) {
    final x = _val(v);
    if (x is num) return x.toDouble();
    if (x is bool) return x ? 1 : 0;
    if (x is String) {
      final s = x.trim();
      if (s.isEmpty) return 0;
      return double.tryParse(s) ?? d;
    }
    return d;
  }

  /// 0..1 literals, or 0..100 from a parameter or written as a percentage.
  double _frac(Object? v, double d) {
    final n = _num(v, d);
    final ref = v is String && (v.startsWith(r'$') || v.startsWith('@'));
    return ref || n > 1 ? n / 100 : n;
  }

  static bool _truthy(Object? v) =>
      v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);

  double _rate(Map l) => _num(l['speed'], 40) / 100 * 0.6;

  List<_Rgba>? _colorList(Object? v) {
    if (v is! List || v.isEmpty) return null;
    return [for (final c in v) _color(c) ?? _black];
  }

  List<_Rgba> _rgbList(Object? v, List<String> fallback) {
    final list = v is List && v.isNotEmpty ? v : fallback;
    return [for (final c in list) _hexOrWhite(c)];
  }

  // -------------------------------------------------------------- paint
  /// Source-over (or the layer's blend) of [c] with extra [cover] alpha.
  void _put(int i, double r, double g, double b, double a) {
    if (a <= 0) return;
    if (a > 1) a = 1;
    final br = _r[i], bg = _g[i], bb = _b[i];
    double nr, ng, nb;
    switch (_blend) {
      case _Blend.normal:
        nr = r;
        ng = g;
        nb = b;
      case _Blend.screen:
        nr = br + r - br * r / 255;
        ng = bg + g - bg * g / 255;
        nb = bb + b - bb * b / 255;
      case _Blend.add:
        _r[i] = math.min(255, br + r * a);
        _g[i] = math.min(255, bg + g * a);
        _b[i] = math.min(255, bb + b * a);
        return;
      case _Blend.multiply:
        nr = br * r / 255;
        ng = bg * g / 255;
        nb = bb * b / 255;
      case _Blend.overlay:
        nr = _overlay(br, r);
        ng = _overlay(bg, g);
        nb = _overlay(bb, b);
    }
    _r[i] = br + (nr - br) * a;
    _g[i] = bg + (ng - bg) * a;
    _b[i] = bb + (nb - bb) * a;
  }

  static double _overlay(double cb, double cs) =>
      cb <= 127.5 ? 2 * cb * cs / 255 : 255 - 2 * (255 - cb) * (255 - cs) / 255;

  /// Fills the canvas rectangle with [paint], antialiased at its edges.
  void _fillRect(double x, double y, double w, double h, _Paint paint) {
    if (w < 0) {
      x += w;
      w = -w;
    }
    if (h < 0) {
      y += h;
      h = -h;
    }
    if (w == 0 || h == 0 || !x.isFinite || !y.isFinite) return;
    final x0 = x * _sx, x1 = (x + w) * _sx, y0 = y * _sy, y1 = (y + h) * _sy;
    final px0 = math.max(0, x0.floor()), px1 = math.min(width, x1.ceil());
    final py0 = math.max(0, y0.floor()), py1 = math.min(height, y1.ceil());
    final c = _Rgba.mutable();
    for (var py = py0; py < py1; py++) {
      final cy = math.min(py + 1.0, y1) - math.max(py.toDouble(), y0);
      if (cy <= 0) continue;
      final ly = (py + 0.5) / _sy;
      for (var px = px0; px < px1; px++) {
        final cx = math.min(px + 1.0, x1) - math.max(px.toDouble(), x0);
        if (cx <= 0) continue;
        paint((px + 0.5) / _sx, ly, c);
        _put(py * width + px, c.r, c.g, c.b, c.a * _alpha * cx * cy);
      }
    }
  }

  /// Strokes a full circle of radius [r] and line width [lw].
  void _strokeCircle(double cx, double cy, double r, double lw, _Rgba c) {
    final half = lw / 2, s = _sx;
    final reach = r + half + 1 / s;
    final px0 = math.max(0, ((cx - reach) * _sx).floor());
    final px1 = math.min(width, ((cx + reach) * _sx).ceil());
    final py0 = math.max(0, ((cy - reach) * _sy).floor());
    final py1 = math.min(height, ((cy + reach) * _sy).ceil());
    for (var py = py0; py < py1; py++) {
      final dy = (py + 0.5) / _sy - cy;
      for (var px = px0; px < px1; px++) {
        final dx = (px + 0.5) / _sx - cx;
        final d = math.sqrt(dx * dx + dy * dy);
        final cover = ((half - (d - r).abs()) * s + 0.5).clamp(0.0, 1.0);
        if (cover > 0) {
          _put(py * width + px, c.r, c.g, c.b, c.a * _alpha * cover);
        }
      }
    }
  }

  _Paint _solid(_Rgba c) =>
      (x, y, out) => out.set(c);

  _Paint _linear(double x0, double y0, double x1, double y1, _Stops stops) {
    final dx = x1 - x0, dy = y1 - y0, len2 = dx * dx + dy * dy;
    return (x, y, out) {
      final t = len2 == 0 ? 0.0 : ((x - x0) * dx + (y - y0) * dy) / len2;
      stops.at(t, out);
    };
  }

  _Paint _radial(double cx, double cy, double r, _Stops stops) => (x, y, out) {
    final dx = x - cx, dy = y - cy;
    stops.at(r <= 0 ? 1 : math.sqrt(dx * dx + dy * dy) / r, out);
  };

  // ------------------------------------------------------- pixel layers
  static const _pw = 80, _ph = 50;
  final _pr = Float64List(_pw * _ph);
  final _pg = Float64List(_pw * _ph);
  final _pb = Float64List(_pw * _ph);

  /// Fills an 80x50 buffer from fn(u, v) and draws it smoothly scaled over
  /// the whole canvas.
  void _pixels(void Function(double u, double v, List<double> out) fn) {
    final c = [0.0, 0.0, 0.0];
    for (var y = 0, o = 0; y < _ph; y++) {
      for (var x = 0; x < _pw; x++, o++) {
        fn(x / (_pw - 1), y / (_ph - 1), c);
        _pr[o] = c[0].clamp(0, 255).roundToDouble();
        _pg[o] = c[1].clamp(0, 255).roundToDouble();
        _pb[o] = c[2].clamp(0, 255).roundToDouble();
      }
    }
    for (var py = 0; py < height; py++) {
      final v = ((py + 0.5) / _sy * _ph / _h - 0.5).clamp(0.0, _ph - 1.0);
      final y0 = v.floor(), y1 = math.min(_ph - 1, y0 + 1), fy = v - y0;
      for (var px = 0; px < width; px++) {
        final u = ((px + 0.5) / _sx * _pw / _w - 0.5).clamp(0.0, _pw - 1.0);
        final x0 = u.floor(), x1 = math.min(_pw - 1, x0 + 1), fx = u - x0;
        final a = y0 * _pw + x0, b = y0 * _pw + x1;
        final c0 = y1 * _pw + x0, d = y1 * _pw + x1;
        double lerp2(Float64List p) {
          final top = p[a] + (p[b] - p[a]) * fx;
          final bottom = p[c0] + (p[d] - p[c0]) * fx;
          return top + (bottom - top) * fy;
        }

        _put(py * width + px, lerp2(_pr), lerp2(_pg), lerp2(_pb), _alpha);
      }
    }
  }

  static void _rampRgb(List<_Rgba> cols, double t, List<double> out) {
    final n = cols.length;
    if (n == 1) {
      out[0] = cols[0].r;
      out[1] = cols[0].g;
      out[2] = cols[0].b;
      return;
    }
    final x = math.min(0.9999, math.max(0.0, t)) * (n - 1);
    final i = x.floor(), f = x - i;
    final a = cols[i], b = cols[i + 1];
    out[0] = a.r + (b.r - a.r) * f;
    out[1] = a.g + (b.g - a.g) * f;
    out[2] = a.b + (b.b - a.b) * f;
  }

  static double _hash(double x, double y, double z) {
    final h = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
    return h - h.floorToDouble();
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);

  static double _vnoise(double x, double y, double z) {
    final xi = x.floorToDouble(),
        yi = y.floorToDouble(),
        zi = z.floorToDouble();
    final xf = _smooth(x - xi), yf = _smooth(y - yi), zf = _smooth(z - zi);
    double c(double dx, double dy, double dz) =>
        _hash(xi + dx, yi + dy, zi + dz);
    double lerp(double a, double b, double t) => a + (b - a) * t;
    return lerp(
      lerp(
        lerp(c(0, 0, 0), c(1, 0, 0), xf),
        lerp(c(0, 1, 0), c(1, 1, 0), xf),
        yf,
      ),
      lerp(
        lerp(c(0, 0, 1), c(1, 0, 1), xf),
        lerp(c(0, 1, 1), c(1, 1, 1), xf),
        yf,
      ),
      zf,
    );
  }

  static double _fbm(double x, double y, double z) =>
      _vnoise(x, y, z) * 0.55 +
      _vnoise(x * 2.1, y * 2.1, z * 1.3) * 0.3 +
      _vnoise(x * 4.3, y * 4.3, z * 1.7) * 0.15;

  void _plasma(Map l, double t) {
    final cols = _rgbList(_val(l['colors']), const [
      '#FF0080',
      '#7928CA',
      '#0070F3',
      '#00DFD8',
    ]);
    final sc = math.max(0.2, _num(l['scale'], 1)), sp = t * _rate(l) * 4;
    _pixels((x, y, out) {
      final u = x * 3 / sc, v = y * 3 / sc;
      final k =
          math.sin(u + sp) +
          math.sin(v * 1.3 - sp * 0.7) +
          math.sin((u + v) * 0.7 + sp * 0.5) +
          math.sin(math.sqrt(u * u + v * v) * 1.2 - sp);
      _rampRgb(cols, (k + 4) / 8, out);
    });
  }

  void _noise(Map l, double t) {
    final cols = _rgbList(_val(l['colors']), const [
      '#1A0000',
      '#C2410C',
      '#FACC15',
    ]);
    final sc = math.max(0.2, _num(l['scale'], 1)), z = t * _rate(l) * 1.5;
    _pixels((x, y, out) {
      final n = _fbm(x * 4 / sc, y * 2.5 / sc, z);
      _rampRgb(cols, math.min(1, math.max(0, n * 1.4 - 0.2)), out);
    });
  }

  void _fire(Map l, double t) {
    final cols = _rgbList(_val(l['colors']), const [
      '#000000',
      '#7F1D1D',
      '#EA580C',
      '#FACC15',
      '#FEF9C3',
    ]);
    final hgt = _frac(l['height'], 0.7), z = t * _rate(l) * 3;
    _pixels((x, y, out) {
      final up = 1 - y;
      final n = _fbm(x * 5, y * 4 + z * 2, z * 0.5);
      final k = (1 - up / math.max(0.05, hgt)) + (n - 0.5) * 0.9;
      _rampRgb(cols, math.min(1, math.max(0, k)), out);
    });
  }

  // ------------------------------------------------------ shape layers
  void _rain(Map l, double t, int idx) {
    final col = _val(l['color']) ?? '#22C55E';
    final n = _num(l['density'], 30).round();
    final len = _frac(l['length'], 0.35) * _h;
    final rand = _Rng(4321 + idx * 31);
    final sp = 0.4 + _rate(l) * 3;
    final stops = _Stops([
      (0, _hexA(col, 0)),
      (0.85, _hexA(col, 0.9)),
      (1, _white),
    ]);
    for (var i = 0; i < n; i++) {
      final x = (rand() * _w / 6).floorToDouble() * 6 + 3;
      final off = rand(), v = 0.6 + rand() * 0.8;
      final y = _mod(t * sp * v + off, 1) * (_h + len) - len;
      _fillRect(x - 2, y, 4, len, _linear(0, y, 0, y + len, stops));
    }
  }

  void _stars(Map l, double t, int idx) {
    final col = _color(_val(l['color']) ?? '#ffffff') ?? _white;
    final n = _num(l['density'], 60).round();
    final rand = _Rng(777 + idx * 13);
    final sp = _rate(l) * 40;
    final opacity = _frac(l['opacity'], 1);
    for (var i = 0; i < n; i++) {
      final depth = 0.3 + rand() * 0.7, y = rand() * _h, x0 = rand() * _w;
      final x = _mod(x0 - t * sp * depth, _w);
      final tw = 0.6 + 0.4 * math.sin(t * 3 * depth + i);
      _alpha = depth * tw * opacity;
      final s = 1 + depth * 2.5;
      _fillRect(x, y, s, s, _solid(col));
    }
  }

  void _heartbeat(Map l, double t) {
    final p = _mod(t * math.max(0.2, _rate(l) * 2.5), 1);
    final k =
        math.exp(-math.pow((p - 0.1) / 0.04, 2)) +
        0.7 * math.exp(-math.pow((p - 0.28) / 0.05, 2));
    final c = _hexA(
      _val(l['color']) ?? '#EF4444',
      math.min(1, k) * _frac(l['opacity'], 1),
    );
    _fillRect(0, 0, _w, _h, _solid(c));
  }

  void _strobe(Map l, double t) {
    final raw = _val(l['colors']);
    final cols = raw is List && raw.isNotEmpty
        ? raw
        : const ['#EF4444', '#3B82F6'];
    final hz = 0.5 + _rate(l) * 10, phase = t * hz;
    final i = phase.floor() % cols.length;
    if (_mod(phase, 1) > 0.55) return;
    final c = _solid(_color(cols[i]) ?? _black);
    if (_truthy(_val(l['split']))) {
      _fillRect(i.isOdd ? _w / 2 : 0, 0, _w / 2, _h, c);
    } else {
      _fillRect(0, 0, _w, _h, c);
    }
  }

  List<double> _bandsFor(int count) {
    final b = audio.bands, out = <double>[];
    for (var i = 0; i < count; i++) {
      final a0 = (i * b.length / count).floor();
      final a1 = math.max(a0 + 1, ((i + 1) * b.length / count).floor());
      var m = 0.0;
      for (var j = a0; j < a1; j++) {
        if (j < b.length) m = math.max(m, b[j]);
      }
      out.add(m);
    }
    return out;
  }

  _Rgba _ramp(Object? colors, double t) {
    if (colors == 'spectrum' || colors is! List || colors.isEmpty) {
      return _hsl((t * 300).roundToDouble(), 100, 55);
    }
    final n = colors.length;
    if (n == 1) return _color(colors[0]) ?? _black;
    return _color(colors[math.min(n - 1, (t * (n - 1)).round())]) ?? _black;
  }

  void _bars(Map l) {
    final mirror = _truthy(_val(l['mirror']));
    final center = _val(l['from']) == 'center';
    final count = math.max(4, _num(l['count'], 32).round());
    final bands = _bandsFor(mirror ? (count / 2).ceil() : count);
    final cols = _val(l['colors']) ?? 'spectrum';
    final gap = _frac(l['gap'], 0.2);
    final bw = _w / count;
    final curve = _num(l['curve'], 1.3), gain = _frac(l['gain'], 1);
    for (var i = 0; i < count; i++) {
      final k = mirror
          ? (i - (count - 1) / 2).abs() / ((count - 1) / 2)
          : i / (count - 1);
      var v = mirror
          ? bands[math.min(bands.length - 1, (k * bands.length).floor())]
          : bands[i];
      v = math.pow(v, curve) * gain * 1.15;
      final h = math.max(1.0, math.min(1.0, v) * _h);
      final y = center ? (_h - h) / 2 : _h - h;
      _fillRect(
        i * bw + bw * gap / 2,
        y,
        bw * (1 - gap),
        h,
        _solid(_ramp(cols, k)),
      );
    }
  }

  void _meter(Map l) {
    final v = math.min(
      1.0,
      _frac(l.containsKey('value') ? l['value'] : '@level', 0),
    );
    final cols =
        _colorList(_val(l['colors'])) ??
        [_hex('#22C55E'), _hex('#FACC15'), _hex('#EF4444')];
    final stops = _Stops([
      for (var i = 0; i < cols.length; i++)
        (cols.length == 1 ? 0.0 : i / (cols.length - 1), cols[i]),
    ]);
    final paint = _linear(0, 0, _w, 0, stops);
    if (_val(l['from']) == 'center') {
      _fillRect(_w / 2 * (1 - v), 0, _w * v, _h, paint);
    } else {
      _fillRect(0, 0, _w * v, _h, paint);
    }
  }

  void _flash(Map l) {
    final k = math.min(
      1.0,
      _frac(l.containsKey('value') ? l['value'] : '@beat', 0) *
          _frac(l['strength'], 1),
    );
    _fillRect(0, 0, _w, _h, _solid(_hexA(_val(l['color']) ?? '#ffffff', k)));
  }

  void _ripple(Map l, int idx) {
    final beats = audio.beats;
    final raw = _val(l['colors']);
    final cols = raw is List && raw.isNotEmpty ? raw : const ['#ffffff'];
    final st = _ripples[idx] ??= _RippleState(beats);
    if (beats != st.last) {
      st.rings.add(_Ring(_color(cols[st.n++ % cols.length]) ?? _white));
      st.last = beats;
    }
    final cx = _num(l['x'], 0.5) * _w, cy = _num(l['y'], 0.5) * _h;
    final maxR = math.sqrt(_w * _w + _h * _h) / 1.5;
    final step = 2 + _num(l['speed'], 50) / 10;
    final lw = math.max(2.0, _num(l['thickness'], 14));
    st.rings.removeWhere((r) {
      r.r += step;
      return r.r >= maxR;
    });
    for (final r in st.rings) {
      _alpha = math.max(0, 1 - r.r / maxR);
      _strokeCircle(cx, cy, r.r, lw, r.color);
    }
  }

  void _loopGradient(Map l, double t, List<_Rgba> colors) {
    final ang = _num(l['angle'], 0) * math.pi / 180;
    final len =
        (_w * math.cos(ang).abs() + _h * math.sin(ang).abs()) *
        math.max(0.2, _num(l['scale'], 1));
    final off = _mod(t * _rate(l) * len, len);
    final dx = math.cos(ang), dy = math.sin(ang);
    final cx = _w / 2 - dx * (len + off), cy = _h / 2 - dy * (len + off);
    final n = colors.length;
    final stops = _Stops([
      for (var p = 0; p < 3; p++)
        for (var i = 0; i <= n; i++)
          (math.min(1.0, (p + i / n) / 3), colors[i % n]),
    ]);
    _fillRect(
      0,
      0,
      _w,
      _h,
      _linear(cx, cy, cx + dx * len * 3, cy + dy * len * 3, stops),
    );
  }

  void _pulse(Map l, double t) {
    final lo = _frac(l['min'], 0), hi = _frac(l['max'], 1);
    final k =
        lo + (hi - lo) * (0.5 - 0.5 * math.cos(t * _rate(l) * math.pi * 2));
    _fillRect(0, 0, _w, _h, _solid(_hexA(_val(l['color']), k)));
  }

  void _wave(Map l, double t) {
    final amp = _frac(l['amplitude'], 0.25) * _h;
    final freq = _num(l['frequency'], 1.5);
    final th = math.max(0.02, _frac(l['thickness'], 0.3)) * _h;
    final col = _val(l['color']);
    final ph = t * _rate(l) * math.pi * 2,
        base = _frac(l['position'], 0.5) * _h;
    final stops = _Stops([
      (0, _hexA(col, 0)),
      (0.5, _hexA(col, 1)),
      (1, _hexA(col, 0)),
    ]);
    for (var x = 0.0; x <= _w; x += 4) {
      final y = base + math.sin(x / _w * freq * math.pi * 2 + ph) * amp;
      _fillRect(x, y - th, 4, th * 2, _linear(0, y - th, 0, y + th, stops));
    }
  }

  void _sweep(Map l, double t) {
    final w = _num(l['width'], 0.25) * _w, col = _val(l['color']);
    final span = _w + w * 2;
    var x = _jsMod(t * _rate(l) * span, span) - w;
    if (_truthy(_val(l['bounce']))) {
      final ph = _jsMod(t * _rate(l), 2);
      x = (ph < 1 ? ph : 2 - ph) * span - w;
    }
    final stops = _Stops([
      (0, _hexA(col, 0)),
      (0.5, _hexA(col, 1)),
      (1, _hexA(col, 0)),
    ]);
    _fillRect(0, 0, _w, _h, _linear(x - w, 0, x + w, 0, stops));
  }

  void _rings(Map l, double t) {
    final raw = _val(l['colors']);
    final cols = raw is List && raw.isNotEmpty ? raw : const ['#fff'];
    final gap = math.max(8.0, _num(l['spacing'], 40));
    final cx = _num(l['x'], 0.5) * _w, cy = _num(l['y'], 0.5) * _h;
    final maxR = math.sqrt(_w * _w + _h * _h);
    final off = _jsMod(t * _rate(l) * gap * 2, gap);
    final lw = gap * math.min(0.9, _num(l['thickness'], 0.5));
    final opacity = _frac(l['opacity'], 1);
    var i = 0;
    for (var r = off; r < maxR; r += gap, i++) {
      _alpha = math.max(0, 1 - r / maxR) * opacity;
      _strokeCircle(cx, cy, r, lw, _color(cols[i % cols.length]) ?? _black);
    }
  }

  void _sparkle(Map l, double t, int idx) {
    final n = _num(l['density'], 40).round(), size = _num(l['size'], 6);
    final col = _val(l['color']);
    final rand = _Rng(1234 + idx * 97);
    final opacity = _frac(l['opacity'], 1), rate = _rate(l);
    for (var i = 0; i < n; i++) {
      final x = rand() * _w, y = rand() * _h, ph = rand(), sp = 0.5 + rand();
      final k = math
          .pow(math.max(0, math.sin((t * rate * sp + ph) * math.pi * 2)), 6)
          .toDouble();
      if (k < 0.01) continue;
      final c = col == 'random'
          ? _hsl((rand() * 360).roundToDouble(), 100, 60)
          : (_color(col) ?? _black);
      _alpha = k * opacity;
      _fillRect(
        x - size,
        y - size,
        size * 2,
        size * 2,
        _radial(x, y, size, _Stops([(0, c), (1, _transparent)])),
      );
    }
  }

  /// JavaScript's `%` (keeps the dividend's sign).
  static double _jsMod(double a, double b) =>
      b == 0 ? double.nan : a.remainder(b);

  /// Always-positive modulo, like `((a % b) + b) % b`.
  static double _mod(double a, double b) {
    final m = a.remainder(b);
    return m < 0 ? m + b : m;
  }
}

typedef _Paint = void Function(double x, double y, _Rgba out);

enum _Blend { normal, screen, add, multiply, overlay }

const _blends = {
  'normal': _Blend.normal,
  'screen': _Blend.screen,
  'add': _Blend.add,
  'multiply': _Blend.multiply,
  'overlay': _Blend.overlay,
};

/// These layers apply their own opacity.
const _selfAlpha = {'rings', 'sparkle', 'ripple', 'stars', 'heartbeat'};

class _Rgba {
  _Rgba(this.r, this.g, this.b, this.a);
  _Rgba.mutable() : r = 0, g = 0, b = 0, a = 0;
  double r, g, b, a;

  void set(_Rgba c) {
    r = c.r;
    g = c.g;
    b = c.b;
    a = c.a;
  }
}

final _black = _Rgba(0, 0, 0, 1);
final _white = _Rgba(255, 255, 255, 1);
final _transparent = _Rgba(0, 0, 0, 0);

/// Gradient color stops, interpolated unpremultiplied like Chrome's canvas.
class _Stops {
  _Stops(List<(double, _Rgba)> stops)
    : _offsets = [for (final s in stops) s.$1.clamp(0.0, 1.0)],
      _colors = [for (final s in stops) s.$2] {
    for (var i = 1; i < _offsets.length; i++) {
      if (_offsets[i] < _offsets[i - 1]) _offsets[i] = _offsets[i - 1];
    }
  }

  final List<double> _offsets;
  final List<_Rgba> _colors;

  void at(double t, _Rgba out) {
    final n = _offsets.length;
    if (n == 0) {
      out.set(_transparent);
      return;
    }
    if (t.isNaN || t <= _offsets.first) {
      out.set(_colors.first);
      return;
    }
    if (t >= _offsets.last) {
      out.set(_colors.last);
      return;
    }
    var i = 1;
    while (_offsets[i] < t) {
      i++;
    }
    while (i + 1 < n && _offsets[i + 1] == _offsets[i] && _offsets[i] == t) {
      i++;
    }
    final o0 = _offsets[i - 1], o1 = _offsets[i];
    final a = _colors[i - 1], b = _colors[i];
    final f = o1 == o0 ? 1.0 : (t - o0) / (o1 - o0);
    out
      ..r = a.r + (b.r - a.r) * f
      ..g = a.g + (b.g - a.g) * f
      ..b = a.b + (b.b - a.b) * f
      ..a = a.a + (b.a - a.a) * f;
  }
}

/// Seeded random so sparkles, stars and rain are stable per layer.
class _Rng {
  _Rng(this._seed);
  int _seed;

  double call() {
    _seed = (_seed * 16807) % 2147483647;
    return (_seed - 1) / 2147483646;
  }
}

class _Ring {
  _Ring(this.color);
  final _Rgba color;
  double r = 0;
}

class _RippleState {
  _RippleState(this.last);
  final rings = <_Ring>[];
  int last;
  int n = 0;
}

final _hexPattern = RegExp(
  r'^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})',
  caseSensitive: false,
);

_Rgba _hex(String s) => _hexOrWhite(s);

/// `#rrggbb` (or white when it is not one), like the runtime's `rgbOf`.
_Rgba _hexOrWhite(Object? v) {
  final m = _hexPattern.firstMatch('$v');
  if (m == null) return _white;
  return _Rgba(
    int.parse(m.group(1)!, radix: 16).toDouble(),
    int.parse(m.group(2)!, radix: 16).toDouble(),
    int.parse(m.group(3)!, radix: 16).toDouble(),
    1,
  );
}

_Rgba _hexA(Object? v, double a) {
  final c = _hexOrWhite(v);
  return _Rgba(c.r, c.g, c.b, a.clamp(0.0, 1.0));
}

_Rgba _hsl(double h, double s, double l) {
  h = ((h % 360) + 360) % 360 / 360;
  s = (s / 100).clamp(0.0, 1.0);
  l = (l / 100).clamp(0.0, 1.0);
  double hue(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  if (s == 0) return _Rgba(l * 255, l * 255, l * 255, 1);
  final q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
  return _Rgba(
    hue(p, q, h + 1 / 3) * 255,
    hue(p, q, h) * 255,
    hue(p, q, h - 1 / 3) * 255,
    1,
  );
}

final _fnColor = RegExp(r'^(rgba?|hsla?)\(([^)]*)\)$', caseSensitive: false);

/// A CSS color as a canvas `fillStyle` accepts it (hex, rgb[a], hsl[a]), or
/// null when it is not one.
_Rgba? _color(Object? v) {
  if (v is! String) return null;
  final s = v.trim().toLowerCase();
  if (s.startsWith('#')) {
    final h = s.substring(1);
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(h)) return null;
    int ch(String x) => int.parse(x.length == 1 ? '$x$x' : x, radix: 16);
    switch (h.length) {
      case 3 || 4:
        return _Rgba(
          ch(h[0]).toDouble(),
          ch(h[1]).toDouble(),
          ch(h[2]).toDouble(),
          h.length == 4 ? ch(h[3]) / 255 : 1,
        );
      case 6 || 8:
        return _Rgba(
          ch(h.substring(0, 2)).toDouble(),
          ch(h.substring(2, 4)).toDouble(),
          ch(h.substring(4, 6)).toDouble(),
          h.length == 8 ? ch(h.substring(6, 8)) / 255 : 1,
        );
    }
    return null;
  }
  if (s == 'white') return _white;
  if (s == 'black') return _black;
  if (s == 'transparent') return _transparent;
  final m = _fnColor.firstMatch(s);
  if (m == null) return null;
  final parts = m
      .group(2)!
      .split(RegExp(r'[\s,/]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length < 3) return null;
  double part(String p, double scale) => p.endsWith('%')
      ? (double.tryParse(p.substring(0, p.length - 1)) ?? 0) / 100 * scale
      : (double.tryParse(p) ?? 0);
  final a = parts.length > 3 ? part(parts[3], 1).clamp(0.0, 1.0) : 1.0;
  if (m.group(1)!.startsWith('rgb')) {
    return _Rgba(
      part(parts[0], 255).clamp(0, 255),
      part(parts[1], 255).clamp(0, 255),
      part(parts[2], 255).clamp(0, 255),
      a,
    );
  }
  final c = _hsl(
    double.tryParse(parts[0].replaceAll('deg', '')) ?? 0,
    double.tryParse(parts[1].replaceAll('%', '')) ?? 0,
    double.tryParse(parts[2].replaceAll('%', '')) ?? 0,
  );
  return _Rgba(c.r, c.g, c.b, a);
}
