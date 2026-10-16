/// HTML page that renders OpenChroma's declarative `.ocfx` effects.
///
/// The effect definition arrives as `window.__OCFX` and its parameters as
/// globals (injected before load), exactly like HTML effects receive theirs,
/// so both kinds share the same host, controls and capture path.
///
/// Layers are drawn bottom to top each frame from the elapsed time, so the
/// output is deterministic and frame-rate independent.
const ocfxRuntimeHtml = r'''<!doctype html>
<html><head><meta charset="utf-8"><title>ocfx</title></head>
<body style="margin:0;background:#000;overflow:hidden">
<canvas id="exCanvas" width="320" height="200"></canvas>
<script>
(function () {
  var W = 320, H = 200;
  var fx = window.__OCFX || { layers: [] };
  var c = document.getElementById('exCanvas');
  var ctx = c.getContext('2d');
  var t0 = performance.now();

  function val(v) {
    if (typeof v === 'string' && v.charAt(0) === '$') {
      var g = window[v.slice(1)];
      return g === undefined ? (fx.params && fx.params[v.slice(1)] ? fx.params[v.slice(1)]['default'] : 0) : g;
    }
    if (Array.isArray(v)) return v.map(val);
    return v;
  }
  function num(v, d) { var n = Number(val(v)); return isNaN(n) ? d : n; }
  // Fractions are 0..1 literals, or 0..100 when they come from a parameter
  // (sliders) or are written as percentages.
  function frac(v, d) {
    var n = num(v, d);
    return (typeof v === 'string' && v.charAt(0) === '$') || n > 1 ? n / 100 : n;
  }
  function hexA(hex, a) {
    var m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(String(hex)) || [0, 'ff', 'ff', 'ff'];
    return 'rgba(' + parseInt(m[1], 16) + ',' + parseInt(m[2], 16) + ',' + parseInt(m[3], 16) + ',' + a + ')';
  }
  // 0..100 speed -> cycles per second (0 stops, 50 ~ calm, 100 fast)
  function rate(l) { return num(l.speed, 40) / 100 * 0.6; }
  var BLEND = { normal: 'source-over', screen: 'screen', add: 'lighter', multiply: 'multiply', overlay: 'overlay' };

  // Seeded random so sparkles are stable per layer.
  function rng(seed) { return function () { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }

  function loopGradient(l, t, colors) {
    var ang = num(l.angle, 0) * Math.PI / 180;
    var len = (W * Math.abs(Math.cos(ang)) + H * Math.abs(Math.sin(ang))) * Math.max(0.2, num(l.scale, 1));
    var off = (t * rate(l) * len) % len;
    var dx = Math.cos(ang), dy = Math.sin(ang);
    var cx = W / 2 - dx * (len + off), cy = H / 2 - dy * (len + off);
    // Paint three periods so the scroll never shows an edge.
    var g = ctx.createLinearGradient(cx, cy, cx + dx * len * 3, cy + dy * len * 3);
    var n = colors.length;
    for (var p = 0; p < 3; p++) {
      for (var i = 0; i <= n; i++) {
        g.addColorStop(Math.min(1, (p + i / n) / 3), colors[i % n]);
      }
    }
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }

  var draw = {
    solid: function (l) { ctx.fillStyle = val(l.color) || '#fff'; ctx.fillRect(0, 0, W, H); },
    gradient: function (l, t) { loopGradient(l, t, (val(l.colors) || ['#000', '#fff'])); },
    spectrum: function (l, t) {
      var s = num(l.saturation, 100), li = num(l.lightness, 50), cols = [];
      for (var h = 0; h < 360; h += 30) cols.push('hsl(' + h + ',' + s + '%,' + li + '%)');
      loopGradient(l, t, cols);
    },
    pulse: function (l, t) {
      var lo = frac(l.min, 0), hi = frac(l.max, 1);
      var k = lo + (hi - lo) * (0.5 - 0.5 * Math.cos(t * rate(l) * Math.PI * 2));
      ctx.fillStyle = hexA(val(l.color), k);
      ctx.fillRect(0, 0, W, H);
    },
    wave: function (l, t) {
      var amp = num(l.amplitude, 0.25) * H, freq = num(l.frequency, 1.5);
      var th = Math.max(0.02, num(l.thickness, 0.3)) * H, col = val(l.color);
      var ph = t * rate(l) * Math.PI * 2, base = num(l.position, 0.5) * H;
      for (var x = 0; x <= W; x += 4) {
        var y = base + Math.sin(x / W * freq * Math.PI * 2 + ph) * amp;
        var g = ctx.createLinearGradient(0, y - th, 0, y + th);
        g.addColorStop(0, hexA(col, 0)); g.addColorStop(0.5, hexA(col, 1)); g.addColorStop(1, hexA(col, 0));
        ctx.fillStyle = g;
        ctx.fillRect(x, y - th, 4, th * 2);
      }
    },
    sweep: function (l, t) {
      var w = num(l.width, 0.25) * W, col = val(l.color), span = W + w * 2;
      var x = (t * rate(l) * span) % span - w;
      if (val(l.bounce)) { var ph = (t * rate(l)) % 2; x = (ph < 1 ? ph : 2 - ph) * span - w; }
      var g = ctx.createLinearGradient(x - w, 0, x + w, 0);
      g.addColorStop(0, hexA(col, 0)); g.addColorStop(0.5, hexA(col, 1)); g.addColorStop(1, hexA(col, 0));
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, W, H);
    },
    rings: function (l, t) {
      var cols = val(l.colors) || ['#fff'], gap = Math.max(8, num(l.spacing, 40));
      var cx = num(l.x, 0.5) * W, cy = num(l.y, 0.5) * H, maxR = Math.hypot(W, H);
      var off = (t * rate(l) * gap * 2) % gap;
      for (var r = off, i = 0; r < maxR; r += gap, i++) {
        ctx.strokeStyle = cols[i % cols.length];
        ctx.lineWidth = gap * Math.min(0.9, num(l.thickness, 0.5));
        ctx.globalAlpha = Math.max(0, 1 - r / maxR) * frac(l.opacity, 1);
        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
      }
    },
    sparkle: function (l, t, idx) {
      var n = Math.round(num(l.density, 40)), size = num(l.size, 6), col = val(l.color);
      var rand = rng(1234 + idx * 97);
      for (var i = 0; i < n; i++) {
        var x = rand() * W, y = rand() * H, ph = rand(), sp = 0.5 + rand();
        var k = Math.pow(Math.max(0, Math.sin((t * rate(l) * sp + ph) * Math.PI * 2)), 6);
        if (k < 0.01) continue;
        var colr = col === 'random' ? 'hsl(' + Math.round(rand() * 360) + ',100%,60%)' : col;
        var g = ctx.createRadialGradient(x, y, 0, x, y, size);
        g.addColorStop(0, colr); g.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.globalAlpha = k * frac(l.opacity, 1);
        ctx.fillStyle = g;
        ctx.fillRect(x - size, y - size, size * 2, size * 2);
      }
    }
  };

  function frame() {
    var t = (performance.now() - t0) / 1000;
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
    ctx.fillStyle = val(fx.background) || '#000';
    ctx.fillRect(0, 0, W, H);
    var layers = fx.layers || [];
    for (var i = 0; i < layers.length; i++) {
      var l = layers[i], fn = draw[l.type];
      if (!fn || val(l.enabled) === false) continue;
      ctx.save();
      ctx.globalCompositeOperation = BLEND[l.blend] || 'source-over';
      ctx.globalAlpha = l.type === 'rings' || l.type === 'sparkle' ? 1 : frac(l.opacity, 1);
      try { fn(l, t, i); } catch (e) { console.error(e); }
      ctx.restore();
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
</script>
</body></html>
''';
