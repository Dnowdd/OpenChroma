import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import 'accent.dart';
import 'property_controls.dart';
import 'theme.dart';
import 'widgets.dart';

/// The frames of a picture or animation, decoded small for previews.
class PreviewFrames {
  PreviewFrames._(this.images, this.delays);

  final List<ui.Image> images;
  final List<int> delays;

  int get length => images.length;

  static Future<PreviewFrames> load(String path, {int maxSide = 480}) async {
    final bytes = await File(path).readAsBytes();
    final probe = await ui.instantiateImageCodec(bytes);
    final first = await probe.getNextFrame();
    final w = first.image.width, h = first.image.height;
    first.image.dispose();
    probe.dispose();
    final scale = math.min(1.0, maxSide / math.max(w, h));
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: (w * scale).round(),
      targetHeight: (h * scale).round(),
    );
    final images = <ui.Image>[];
    final delays = <int>[];
    for (var i = 0; i < codec.frameCount; i++) {
      final f = await codec.getNextFrame();
      images.add(f.image);
      final ms = f.duration.inMilliseconds;
      delays.add(ms <= 0 ? 100 : ms);
    }
    codec.dispose();
    return PreviewFrames._(images, delays);
  }

  void dispose() {
    for (final i in images) {
      i.dispose();
    }
  }
}

/// The screen as it will look: the edited image, looping over the kept
/// frames, with its texts.
class ScreenPreview extends StatefulWidget {
  const ScreenPreview({
    super.key,
    required this.spec,
    required this.frames,
    required this.edit,
    this.readSensor,
  });
  final ScreenSpec spec;
  final PreviewFrames? frames;
  final ScreenEdit edit;

  /// Current live values for the preview (a sample when null or unknown).
  final double? Function(String key)? readSensor;

  @override
  State<ScreenPreview> createState() => _ScreenPreviewState();
}

class _ScreenPreviewState extends State<ScreenPreview> {
  Timer? _timer;
  Timer? _live;
  int _index = 0;

  void _watchLive() {
    final on = widget.edit.sources.isNotEmpty;
    if (on && _live == null) {
      _live = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!on) {
      _live?.cancel();
      _live = null;
    }
  }

  String _value(ScreenText t) {
    final v = widget.readSensor?.call(t.source!);
    if (v != null) return '${v.round()}';
    return '8' * math.min(ScreenSource.byKey(t.source)?.digits ?? 2, 2);
  }

  (int, int) get _range {
    final n = widget.frames?.length ?? 0;
    if (n == 0) return (0, 0);
    final first = widget.edit.first.clamp(0, n - 1);
    final last = widget.edit.last < 0
        ? n - 1
        : widget.edit.last.clamp(first, n - 1);
    return (first, last);
  }

  void _schedule() {
    _timer?.cancel();
    final f = widget.frames;
    if (f == null || f.length < 2) return;
    final (first, last) = _range;
    if (_index < first || _index > last) _index = first;
    _timer = Timer(Duration(milliseconds: f.delays[_index]), () {
      if (!mounted) return;
      setState(() => _index = _index >= last ? first : _index + 1);
      _schedule();
    });
  }

  @override
  void initState() {
    super.initState();
    _schedule();
    _watchLive();
  }

  @override
  void didUpdateWidget(ScreenPreview old) {
    super.didUpdateWidget(old);
    _watchLive();
    if (old.frames != widget.frames ||
        old.edit.first != widget.edit.first ||
        old.edit.last != widget.edit.last) {
      _index = _range.$1;
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _live?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.frames;
    final image = f == null || f.length == 0
        ? null
        : f.images[_index.clamp(0, f.length - 1)];
    final spec = widget.spec;
    return AspectRatio(
      aspectRatio: spec.width / spec.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: spec.round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: spec.round ? null : Oc.r12,
          border: Border.all(color: Oc.lineStrong, width: 6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipPath(
            clipper: _ScreenClip(spec.round),
            child: CustomPaint(
              painter: _EditPainter(widget.edit, image, _value),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenClip extends CustomClipper<Path> {
  const _ScreenClip(this.round);
  final bool round;

  @override
  Path getClip(Size size) {
    final r = Offset.zero & size;
    return round
        ? (Path()..addOval(r))
        : (Path()
            ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(14))));
  }

  @override
  bool shouldReclip(_ScreenClip old) => old.round != round;
}

class _EditPainter extends CustomPainter {
  const _EditPainter(this.edit, this.image, this.liveValue);
  final ScreenEdit edit;
  final ui.Image? image;
  final String Function(ScreenText t) liveValue;

  @override
  void paint(Canvas canvas, Size size) =>
      edit.paint(canvas, size.width, size.height, image, liveValue: liveValue);

  @override
  bool shouldRepaint(_EditPainter old) => true;
}

/// Opens the editor for the image at [path]; the edit to send, or null.
Future<ScreenEdit?> showScreenEditor(
  BuildContext context, {
  required ScreenSpec spec,
  required String path,
  ScreenEdit? initial,
  double? Function(String key)? readSensor,
}) => showDialog<ScreenEdit>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ScreenEditor(
    spec: spec,
    path: path,
    initial: initial,
    readSensor: readSensor,
  ),
);

class _ScreenEditor extends StatefulWidget {
  const _ScreenEditor({
    required this.spec,
    required this.path,
    this.initial,
    this.readSensor,
  });
  final ScreenSpec spec;
  final String path;
  final ScreenEdit? initial;
  final double? Function(String key)? readSensor;

  @override
  State<_ScreenEditor> createState() => _ScreenEditorState();
}

class _ScreenEditorState extends State<_ScreenEditor> {
  PreviewFrames? _frames;
  String? _error;
  late ScreenEdit _edit = widget.initial ?? const ScreenEdit();
  int? _selected;
  final _fields = <TextEditingController>[];
  final _canvasFocus = FocusNode();
  _DragMode? _mode;
  Offset _dragAt = Offset.zero;
  double _resizeSize = 0, _resizeDist = 1;
  bool _guideX = false, _guideY = false;
  MouseCursor _cursor = SystemMouseCursors.grab;

  double get _fitZoom {
    final f = _frames;
    if (f == null || f.length == 0) return 1;
    return ScreenEdit.fitZoom(
      widget.spec,
      f.images.first.width.toDouble(),
      f.images.first.height.toDouble(),
    );
  }

  @override
  void initState() {
    super.initState();
    for (final t in _edit.texts) {
      _fields.add(TextEditingController(text: t.text));
    }
    PreviewFrames.load(widget.path).then(
      (f) {
        if (!mounted) return f.dispose();
        setState(() => _frames = f);
      },
      onError: (_) {
        if (mounted) {
          setState(() => _error = 'Não foi possível abrir a imagem.');
        }
      },
    );
  }

  @override
  void dispose() {
    _frames?.dispose();
    _canvasFocus.dispose();
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _setText(int i, ScreenText t) {
    final list = [..._edit.texts]..[i] = t;
    setState(() => _edit = _edit.copyWith(texts: list));
  }

  void _addText() {
    final list = [..._edit.texts, const ScreenText()];
    _fields.add(TextEditingController(text: list.last.text));
    setState(() {
      _edit = _edit.copyWith(texts: list);
      _selected = list.length - 1;
    });
  }

  void _removeText(int i) {
    final list = [..._edit.texts]..removeAt(i);
    _fields.removeAt(i).dispose();
    setState(() {
      _edit = _edit.copyWith(texts: list);
      _selected = null;
    });
  }

  static const _inset = 12.0;
  static const _handle = 7.0;

  double _sizeLimit(ScreenText t) => t.live ? maxLiveSize : maxTextSize;

  ScreenText? get _current {
    final i = _selected;
    return i != null && i < _edit.texts.length ? _edit.texts[i] : null;
  }

  Rect _rectOf(int i, double side) {
    final inner = side - _inset * 2;
    return ScreenEdit.textRect(
      _edit.texts[i],
      inner,
      inner,
    ).shift(const Offset(_inset, _inset)).inflate(6);
  }

  Offset _centerOf(ScreenText t, double side) {
    final inner = side - _inset * 2;
    return Offset(_inset + t.x * inner, _inset + t.y * inner);
  }

  int? _hit(Offset p, double side) {
    for (var i = _edit.texts.length - 1; i >= 0; i--) {
      if (_rectOf(i, side).contains(p)) return i;
    }
    return null;
  }

  bool _onHandle(Offset p, double side) =>
      _current != null &&
      (p - _rectOf(_selected!, side).bottomRight).distance <= _handle + 5;

  void _select(int? i) {
    _canvasFocus.requestFocus();
    setState(() => _selected = i);
  }

  void _pointerDown(Offset p, double side) {
    if (_onHandle(p, side)) {
      final t = _current!;
      _canvasFocus.requestFocus();
      _mode = _DragMode.resize;
      _resizeSize = t.size;
      _resizeDist = math.max((p - _centerOf(t, side)).distance, 1);
      return;
    }
    final hit = _hit(p, side);
    _select(hit);
    if (hit != null) {
      final t = _edit.texts[hit];
      _mode = _DragMode.move;
      _dragAt = Offset(t.x, t.y);
    } else {
      _mode = _DragMode.pan;
    }
  }

  void _drag(DragUpdateDetails d, double side) {
    final inner = side - _inset * 2;
    final dx = d.delta.dx / inner, dy = d.delta.dy / inner;
    final t = _current;
    switch (_mode) {
      case _DragMode.move when t != null:
        _dragAt += Offset(dx, dy);
        var x = _dragAt.dx.clamp(0.0, 1.0), y = _dragAt.dy.clamp(0.0, 1.0);
        _guideX = (x - .5).abs() < .015;
        _guideY = (y - .5).abs() < .015;
        if (_guideX) x = .5;
        if (_guideY) y = .5;
        _setText(_selected!, t.copyWith(x: x, y: y));
      case _DragMode.resize when t != null:
        final dist = (d.localPosition - _centerOf(t, side)).distance;
        _setText(
          _selected!,
          t.copyWith(
            size: (_resizeSize * dist / _resizeDist).clamp(
              minTextSize,
              _sizeLimit(t),
            ),
          ),
        );
      case _DragMode.pan:
        setState(
          () => _edit = _edit.copyWith(
            panX: (_edit.panX + dx).clamp(-1.0, 1.0),
            panY: (_edit.panY + dy).clamp(-1.0, 1.0),
          ),
        );
      default:
    }
  }

  void _dragEnd() {
    _mode = null;
    if (_guideX || _guideY) setState(() => _guideX = _guideY = false);
  }

  void _scroll(PointerScrollEvent e, double side) {
    final factor = e.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
    final t = _current;
    if (t != null && _rectOf(_selected!, side).contains(e.localPosition)) {
      _setText(
        _selected!,
        t.copyWith(size: (t.size * factor).clamp(minTextSize, _sizeLimit(t))),
      );
    } else {
      _zoomBy(factor);
    }
  }

  void _hover(Offset p, double side) {
    final cursor = _onHandle(p, side)
        ? SystemMouseCursors.resizeUpLeftDownRight
        : _hit(p, side) != null
        ? SystemMouseCursors.move
        : SystemMouseCursors.grab;
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    final t = _current;
    if (t == null || e is KeyUpEvent) return KeyEventResult.ignored;
    final i = _selected!;
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (k == LogicalKeyboardKey.escape) {
      setState(() => _selected = null);
    } else if (k == LogicalKeyboardKey.delete ||
        k == LogicalKeyboardKey.backspace) {
      _removeText(i);
    } else if (keys.isControlPressed && k == LogicalKeyboardKey.keyD) {
      if (e is KeyDownEvent) _duplicate(i);
    } else {
      final step = (keys.isShiftPressed ? 10 : 1) / widget.spec.width;
      final d = switch (k) {
        LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
        LogicalKeyboardKey.arrowRight => Offset(step, 0),
        LogicalKeyboardKey.arrowUp => Offset(0, -step),
        LogicalKeyboardKey.arrowDown => Offset(0, step),
        _ => null,
      };
      if (d == null) return KeyEventResult.ignored;
      _setText(
        i,
        t.copyWith(
          x: (t.x + d.dx).clamp(0.0, 1.0),
          y: (t.y + d.dy).clamp(0.0, 1.0),
        ),
      );
    }
    return KeyEventResult.handled;
  }

  void _duplicate(int i) {
    final t = _edit.texts[i];
    final copy = t.copyWith(
      x: (t.x + .04).clamp(0.0, 1.0),
      y: (t.y + .04).clamp(0.0, 1.0),
    );
    final list = [..._edit.texts, copy];
    _fields.add(TextEditingController(text: copy.text));
    setState(() {
      _edit = _edit.copyWith(texts: list);
      _selected = list.length - 1;
    });
  }

  void _zoomBy(double factor) => setState(
    () => _edit = _edit.copyWith(
      zoom: (_edit.zoom * factor).clamp(math.min(_fitZoom, 1.0), 4.0),
    ),
  );

  String _seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    final spec = widget.spec;
    return Dialog(
      backgroundColor: Oc.panel,
      insetPadding: const EdgeInsets.all(24),
      shape: const RoundedRectangleBorder(borderRadius: Oc.r12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Editar imagem da tela', style: OcText.title),
              const SizedBox(height: 4),
              Text(
                _selected == null
                    ? 'Clique num texto para selecioná-lo. Arraste a imagem para posicionar e use a roda do mouse para o zoom.'
                    : 'Arraste para mover e puxe o canto (ou use a roda do mouse sobre o texto) para mudar o tamanho. '
                          'Setas ajustam a posição, Delete remove, Ctrl+D duplica e Esc solta a seleção.',
                style: OcText.secondary,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: _error != null
                            ? Text(_error!, style: OcText.secondary)
                            : f == null
                            ? const CircularProgressIndicator()
                            : LayoutBuilder(
                                builder: (context, box) {
                                  final side = math.min(
                                    box.maxWidth,
                                    box.maxHeight,
                                  );
                                  final sel = _current == null
                                      ? null
                                      : _rectOf(_selected!, side);
                                  return SizedBox.square(
                                    dimension: side,
                                    child: Focus(
                                      focusNode: _canvasFocus,
                                      onKeyEvent: _key,
                                      child: Listener(
                                        onPointerDown: (e) =>
                                            _pointerDown(e.localPosition, side),
                                        onPointerSignal: (e) {
                                          if (e is PointerScrollEvent) {
                                            _scroll(e, side);
                                          }
                                        },
                                        child: GestureDetector(
                                          onPanUpdate: (d) => _drag(d, side),
                                          onPanEnd: (_) => _dragEnd(),
                                          onPanCancel: _dragEnd,
                                          child: MouseRegion(
                                            cursor: _cursor,
                                            onHover: (e) =>
                                                _hover(e.localPosition, side),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ScreenPreview(
                                                  spec: spec,
                                                  frames: f,
                                                  edit: _edit,
                                                  readSensor: widget.readSensor,
                                                ),
                                                IgnorePointer(
                                                  child: CustomPaint(
                                                    painter: _SelectionPainter(
                                                      boxes: [
                                                        for (
                                                          var i = 0;
                                                          i <
                                                              _edit
                                                                  .texts
                                                                  .length;
                                                          i++
                                                        )
                                                          if (i != _selected)
                                                            _rectOf(i, side),
                                                      ],
                                                      selected: sel,
                                                      handle: _handle,
                                                      color: LiveAccent.of(
                                                        context,
                                                      ),
                                                      guideX: _guideX,
                                                      guideY: _guideY,
                                                      inset: _inset,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 360,
                      child: f == null ? const SizedBox() : _controls(f),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OcButton(
                    label: 'Cancelar',
                    variant: OcButtonVariant.ghost,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  OcButton(
                    label: 'Enviar para a tela',
                    icon: Icons.upload_rounded,
                    variant: OcButtonVariant.primary,
                    onPressed:
                        f == null ||
                            _edit.sources.length > widget.spec.liveValues
                        ? null
                        : () => Navigator.pop(context, _edit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(PreviewFrames f) {
    final n = f.length;
    final first = _edit.first.clamp(0, n - 1);
    final last = _edit.last < 0 ? n - 1 : _edit.last.clamp(first, n - 1);
    final kept = last - first + 1;
    var ms = 0;
    for (var i = first; i <= last; i++) {
      ms += f.delays[i];
    }
    return ListView(
      children: [
        const SectionLabel('Enquadramento'),
        Row(
          children: [
            OcButton(
              label: 'Preencher',
              icon: Icons.crop_free_rounded,
              onPressed: () => setState(
                () => _edit = _edit.copyWith(zoom: 1, panX: 0, panY: 0),
              ),
            ),
            const SizedBox(width: 8),
            OcButton(
              label: 'Inteira',
              icon: Icons.fit_screen_rounded,
              onPressed: () => setState(
                () => _edit = _edit.copyWith(zoom: _fitZoom, panX: 0, panY: 0),
              ),
            ),
            const Spacer(),
            Tooltip(
              message: 'Cor do fundo',
              child: InkWell(
                borderRadius: Oc.pill,
                onTap: () async {
                  final c = await showColorPicker(
                    context,
                    Color(_edit.background),
                  );
                  if (c != null) {
                    setState(
                      () => _edit = _edit.copyWith(background: c.toARGB32()),
                    );
                  }
                },
                child: _Swatch(Color(_edit.background)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Zoom', style: OcText.caption),
        OcSlider(
          value: _edit.zoom,
          min: math.min(_fitZoom, 1.0),
          max: 4,
          integer: false,
          suffix: 'x',
          onChanged: (v) => setState(() => _edit = _edit.copyWith(zoom: v)),
        ),
        if (n > 1) ...[
          const SizedBox(height: 12),
          const SectionLabel('Trecho do GIF'),
          RangeSlider(
            values: RangeValues(first.toDouble(), last.toDouble()),
            min: 0,
            max: (n - 1).toDouble(),
            divisions: n - 1,
            activeColor: LiveAccent.of(context),
            onChanged: (r) => setState(
              () => _edit = _edit.copyWith(
                first: r.start.round(),
                last: r.end.round() >= n - 1 ? -1 : r.end.round(),
              ),
            ),
          ),
          Text(
            'Quadros ${first + 1} a ${last + 1} de $n · ${_seconds(ms)}'
            '${kept > widget.spec.maxFrames ? ' · será reduzido a ${widget.spec.maxFrames} quadros' : ''}',
            style: OcText.caption,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: SectionLabel('Textos')),
            OcButton(
              label: 'Adicionar',
              icon: Icons.add_rounded,
              onPressed: _addText,
            ),
          ],
        ),
        if (widget.spec.liveValues > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Valores ao vivo: ${_edit.sources.length} de '
              '${widget.spec.liveValues}. A tela atualiza a cada segundo '
              'enquanto o app estiver aberto.',
              style: _edit.sources.length > widget.spec.liveValues
                  ? OcText.caption.copyWith(color: Oc.danger)
                  : OcText.caption,
            ),
          ),
        const SizedBox(height: 8),
        for (var i = 0; i < _edit.texts.length; i++) _textCard(i),
      ],
    );
  }

  Widget _textCard(int i) {
    final t = _edit.texts[i];
    final selected = _selected == i;
    return GestureDetector(
      onTap: () => _select(selected ? null : i),
      child: AnimatedContainer(
        duration: Oc.fast,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: Oc.raised,
          borderRadius: Oc.r8,
          border: Border.all(
            color: selected ? LiveAccent.of(context) : Oc.line,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: t.live
                      ? Text(
                          ScreenSource.byKey(t.source)?.label ?? '',
                          style: OcText.body,
                        )
                      : TextField(
                          controller: _fields[i],
                          style: OcText.body,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Texto',
                          ),
                          onTap: () => setState(() => _selected = i),
                          onChanged: (v) => _setText(i, t.copyWith(text: v)),
                        ),
                ),
                OcIconButton(
                  icon: t.bold
                      ? Icons.format_bold_rounded
                      : Icons.text_fields_rounded,
                  tooltip: t.bold ? 'Negrito' : 'Normal',
                  onPressed: () => _setText(i, t.copyWith(bold: !t.bold)),
                ),
                Tooltip(
                  message: 'Cor do texto',
                  child: InkWell(
                    borderRadius: Oc.pill,
                    onTap: () async {
                      final c = await showColorPicker(context, Color(t.color));
                      if (c != null) {
                        _setText(
                          i,
                          _edit.texts[i].copyWith(color: c.toARGB32()),
                        );
                      }
                    },
                    child: _Swatch(Color(t.color)),
                  ),
                ),
                OcIconButton(
                  icon: Icons.copy_rounded,
                  tooltip: 'Duplicar',
                  onPressed: () => _duplicate(i),
                ),
                OcIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remover',
                  onPressed: () => _removeText(i),
                ),
              ],
            ),
            if (widget.spec.liveValues > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.live
                            ? 'Ao vivo · coloque a unidade '
                                  '(${ScreenSource.byKey(t.source)?.unit}) '
                                  'num texto fixo'
                            : 'Mostrar',
                        style: OcText.caption,
                      ),
                    ),
                    OcSelect(
                      width: 190,
                      value: t.source ?? '',
                      options: [
                        '',
                        for (final src in ScreenSource.all) src.key,
                      ],
                      labelOf: (k) => k.isEmpty
                          ? 'Texto fixo'
                          : ScreenSource.byKey(k)!.label,
                      onChanged: (k) => _setText(
                        i,
                        t.copyWith(
                          source: () => k.isEmpty ? null : k,
                          size: k.isEmpty
                              ? t.size
                              : math.min(t.size, maxLiveSize),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            OcSlider(
              value: t.size * 100,
              min: 3,
              max: _sizeLimit(t) * 100,
              suffix: '%',
              onChanged: (v) => _setText(i, t.copyWith(size: v / 100)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DragMode { pan, move, resize }

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({
    required this.boxes,
    required this.selected,
    required this.handle,
    required this.color,
    required this.guideX,
    required this.guideY,
    required this.inset,
  });
  final List<Rect> boxes;
  final Rect? selected;
  final double handle;
  final Color color;
  final bool guideX, guideY;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = color.withValues(alpha: .8)
      ..strokeWidth = 1;
    if (guideX) {
      canvas.drawLine(
        Offset(size.width / 2, inset),
        Offset(size.width / 2, size.height - inset),
        guide,
      );
    }
    if (guideY) {
      canvas.drawLine(
        Offset(inset, size.height / 2),
        Offset(size.width - inset, size.height / 2),
        guide,
      );
    }
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x40FFFFFF);
    for (final b in boxes) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, const Radius.circular(4)),
        faint,
      );
    }
    final s = selected;
    if (s == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(s, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
    canvas.drawCircle(s.bottomRight, handle, Paint()..color = color);
    canvas.drawCircle(
      s.bottomRight,
      handle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => true;
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Oc.lineStrong, width: 2),
    ),
  );
}
