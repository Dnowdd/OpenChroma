import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A device's own screen, as its plugin declares it.
class ScreenSpec {
  const ScreenSpec(this.width, this.height, {this.maxFrames = 100});

  static ScreenSpec? fromJson(Object? j) {
    if (j is! Map) return null;
    final w = (j['width'] as num?)?.toInt() ?? 0;
    final h = (j['height'] as num?)?.toInt() ?? 0;
    if (w <= 0 || h <= 0) return null;
    return ScreenSpec(
      w,
      h,
      maxFrames: (j['maxFrames'] as num?)?.toInt() ?? 100,
    );
  }

  final int width;
  final int height;

  /// The most frames the screen keeps (its memory).
  final int maxFrames;
}

/// An image ready for a screen: RGB bytes per frame, row by row, and how
/// long each frame shows.
class ScreenImage {
  const ScreenImage(this.frames, this.delaysMs);
  final List<Uint8List> frames;
  final List<int> delaysMs;
}

/// Reads a PNG, JPEG, GIF or WebP and fits every frame to [spec]: filling
/// the screen (cropping the sides) or showing the whole image on black.
/// Animations longer than the screen keeps lose frames evenly, and the
/// remaining ones show longer, so the timing holds.
Future<ScreenImage> loadScreenImage(
  String path,
  ScreenSpec spec, {
  bool fill = true,
}) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final total = codec.frameCount;
  final keep = total <= spec.maxFrames ? total : spec.maxFrames;
  final frames = <Uint8List>[];
  final delays = <int>[];
  var next = 0.0;
  for (var i = 0; i < total; i++) {
    final info = await codec.getNextFrame();
    final ms = info.duration.inMilliseconds;
    final ok = i >= next.floor() && frames.length < keep;
    if (ok) {
      frames.add(await _fit(info.image, spec, fill));
      delays.add(ms <= 0 ? 100 : ms);
      next += total / keep;
    } else if (delays.isNotEmpty) {
      delays[delays.length - 1] += ms <= 0 ? 100 : ms;
    }
    info.image.dispose();
  }
  codec.dispose();
  return ScreenImage(frames, delays);
}

Future<Uint8List> _fit(ui.Image image, ScreenSpec spec, bool fill) async {
  final w = spec.width.toDouble(), h = spec.height.toDouble();
  final iw = image.width.toDouble(), ih = image.height.toDouble();
  final scale = fill
      ? (w / iw > h / ih ? w / iw : h / ih)
      : (w / iw < h / ih ? w / iw : h / ih);
  final dw = iw * scale, dh = ih * scale;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, iw, ih),
    ui.Rect.fromLTWH((w - dw) / 2, (h - dh) / 2, dw, dh),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final fitted = await recorder.endRecording().toImage(spec.width, spec.height);
  final rgba = (await fitted.toByteData())!.buffer.asUint8List();
  fitted.dispose();
  final rgb = Uint8List(spec.width * spec.height * 3);
  for (var p = 0, q = 0; p < rgba.length; p += 4, q += 3) {
    rgb[q] = rgba[p];
    rgb[q + 1] = rgba[p + 1];
    rgb[q + 2] = rgba[p + 2];
  }
  return rgb;
}
