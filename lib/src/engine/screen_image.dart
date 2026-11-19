import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A device's own screen, as its plugin declares it.
class ScreenSpec {
  const ScreenSpec(
    this.width,
    this.height, {
    this.maxFrames = 100,
    this.round = false,
  });

  static ScreenSpec? fromJson(Object? j) {
    if (j is! Map) return null;
    final w = (j['width'] as num?)?.toInt() ?? 0;
    final h = (j['height'] as num?)?.toInt() ?? 0;
    if (w <= 0 || h <= 0) return null;
    return ScreenSpec(
      w,
      h,
      maxFrames: (j['maxFrames'] as num?)?.toInt() ?? 100,
      round: j['round'] == true,
    );
  }

  final int width;
  final int height;

  /// The most frames the screen keeps (its memory).
  final int maxFrames;

  /// The screen is a circle inscribed in [width] x [height].
  final bool round;
}

/// A text drawn over the image, placed and sized relative to the screen.
class ScreenText {
  const ScreenText({
    this.text = 'Texto',
    this.x = .5,
    this.y = .5,
    this.size = .1,
    this.color = 0xFFFFFFFF,
    this.bold = true,
  });

  factory ScreenText.fromJson(Map j) => ScreenText(
    text: '${j['text'] ?? ''}',
    x: (j['x'] as num?)?.toDouble() ?? .5,
    y: (j['y'] as num?)?.toDouble() ?? .5,
    size: (j['size'] as num?)?.toDouble() ?? .1,
    color: (j['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
    bold: j['bold'] != false,
  );

  final String text;

  /// Center of the text, 0..1 across and down the screen.
  final double x, y;

  /// Font size as a fraction of the screen height.
  final double size;
  final int color;
  final bool bold;

  ScreenText copyWith({
    String? text,
    double? x,
    double? y,
    double? size,
    int? color,
    bool? bold,
  }) => ScreenText(
    text: text ?? this.text,
    x: x ?? this.x,
    y: y ?? this.y,
    size: size ?? this.size,
    color: color ?? this.color,
    bold: bold ?? this.bold,
  );

  Map<String, Object> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'size': size,
    'color': color,
    'bold': bold,
  };

  ui.TextStyle uiStyle(double screenHeight) => ui.TextStyle(
    color: ui.Color(color),
    fontSize: size * screenHeight,
    fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
    shadows: const [ui.Shadow(color: ui.Color(0xAA000000), blurRadius: 4)],
  );
}

/// How an image is laid on a screen before it is sent.
///
/// [zoom] 1 fills the screen (cropping the sides); [pan] moves the image by
/// a fraction of the screen size. [first]..[last] are the frames kept (last
/// -1 means the end).
class ScreenEdit {
  const ScreenEdit({
    this.zoom = 1,
    this.panX = 0,
    this.panY = 0,
    this.first = 0,
    this.last = -1,
    this.background = 0xFF000000,
    this.texts = const [],
  });

  factory ScreenEdit.fromJson(Object? j) {
    if (j is! Map) return const ScreenEdit();
    return ScreenEdit(
      zoom: (j['zoom'] as num?)?.toDouble() ?? 1,
      panX: (j['panX'] as num?)?.toDouble() ?? 0,
      panY: (j['panY'] as num?)?.toDouble() ?? 0,
      first: (j['first'] as num?)?.toInt() ?? 0,
      last: (j['last'] as num?)?.toInt() ?? -1,
      background: (j['background'] as num?)?.toInt() ?? 0xFF000000,
      texts: [
        for (final t in (j['texts'] as List? ?? const []))
          if (t is Map) ScreenText.fromJson(t),
      ],
    );
  }

  final double zoom, panX, panY;
  final int first, last;
  final int background;
  final List<ScreenText> texts;

  ScreenEdit copyWith({
    double? zoom,
    double? panX,
    double? panY,
    int? first,
    int? last,
    int? background,
    List<ScreenText>? texts,
  }) => ScreenEdit(
    zoom: zoom ?? this.zoom,
    panX: panX ?? this.panX,
    panY: panY ?? this.panY,
    first: first ?? this.first,
    last: last ?? this.last,
    background: background ?? this.background,
    texts: texts ?? this.texts,
  );

  Map<String, Object> toJson() => {
    'zoom': zoom,
    'panX': panX,
    'panY': panY,
    'first': first,
    'last': last,
    'background': background,
    'texts': [for (final t in texts) t.toJson()],
  };

  /// The zoom that shows a [iw] x [ih] image whole on [spec].
  static double fitZoom(ScreenSpec spec, double iw, double ih) {
    final cover = math.max(spec.width / iw, spec.height / ih);
    final contain = math.min(spec.width / iw, spec.height / ih);
    return contain / cover;
  }

  /// Where a [iw] x [ih] image lands on a [w] x [h] screen.
  ui.Rect imageRect(double w, double h, double iw, double ih) {
    final scale = math.max(w / iw, h / ih) * zoom;
    final dw = iw * scale, dh = ih * scale;
    return ui.Rect.fromLTWH(
      (w - dw) / 2 + panX * w,
      (h - dh) / 2 + panY * h,
      dw,
      dh,
    );
  }

  /// Draws one frame of the edited screen at [w] x [h].
  void paint(ui.Canvas canvas, double w, double h, ui.Image? image) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..color = ui.Color(background),
    );
    if (image != null) {
      final iw = image.width.toDouble(), ih = image.height.toDouble();
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, iw, ih),
        imageRect(w, h, iw, ih),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    }
    for (final t in texts) {
      if (t.text.trim().isEmpty) continue;
      final b =
          ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
            ..pushStyle(t.uiStyle(h))
            ..addText(t.text);
      final para = b.build()..layout(ui.ParagraphConstraints(width: w * 2));
      canvas.drawParagraph(
        para,
        ui.Offset(t.x * w - w, t.y * h - para.height / 2),
      );
    }
  }
}

/// An image ready for a screen: RGB bytes per frame, row by row, and how
/// long each frame shows.
class ScreenImage {
  const ScreenImage(this.frames, this.delaysMs);
  final List<Uint8List> frames;
  final List<int> delaysMs;
}

/// Frame count and duration of the picture or animation at [path].
Future<({int frames, int ms, int width, int height})> probeScreenImage(
  String path,
) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final first = await codec.getNextFrame();
  final w = first.image.width, h = first.image.height;
  var ms = first.duration.inMilliseconds;
  first.image.dispose();
  for (var i = 1; i < codec.frameCount; i++) {
    final f = await codec.getNextFrame();
    ms += f.duration.inMilliseconds;
    f.image.dispose();
  }
  final n = codec.frameCount;
  codec.dispose();
  return (frames: n, ms: ms, width: w, height: h);
}

/// Reads a PNG, JPEG, GIF or WebP and renders the frames [edit] keeps at the
/// screen's size. Animations longer than the screen keeps lose frames
/// evenly, and the remaining ones show longer, so the timing holds.
Future<ScreenImage> loadScreenImage(
  String path,
  ScreenSpec spec, {
  ScreenEdit edit = const ScreenEdit(),
}) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final count = codec.frameCount;
  final first = edit.first.clamp(0, count - 1);
  final last = edit.last < 0 ? count - 1 : edit.last.clamp(first, count - 1);
  final total = last - first + 1;
  final keep = total <= spec.maxFrames ? total : spec.maxFrames;
  final frames = <Uint8List>[];
  final delays = <int>[];
  var next = 0.0;
  for (var i = 0; i <= last; i++) {
    final info = await codec.getNextFrame();
    final ms = info.duration.inMilliseconds <= 0
        ? 100
        : info.duration.inMilliseconds;
    if (i >= first) {
      final k = i - first;
      if (k >= next.floor() && frames.length < keep) {
        frames.add(await _render(info.image, spec, edit));
        delays.add(ms);
        next += total / keep;
      } else if (delays.isNotEmpty) {
        delays[delays.length - 1] += ms;
      }
    }
    info.image.dispose();
  }
  codec.dispose();
  return ScreenImage(frames, delays);
}

Future<Uint8List> _render(
  ui.Image image,
  ScreenSpec spec,
  ScreenEdit edit,
) async {
  final recorder = ui.PictureRecorder();
  edit.paint(
    ui.Canvas(recorder),
    spec.width.toDouble(),
    spec.height.toDouble(),
    image,
  );
  final out = await recorder.endRecording().toImage(spec.width, spec.height);
  final rgba = (await out.toByteData())!.buffer.asUint8List();
  out.dispose();
  final rgb = Uint8List(spec.width * spec.height * 3);
  for (var p = 0, q = 0; p < rgba.length; p += 4, q += 3) {
    rgb[q] = rgba[p];
    rgb[q + 1] = rgba[p + 1];
    rgb[q + 2] = rgba[p + 2];
  }
  return rgb;
}
