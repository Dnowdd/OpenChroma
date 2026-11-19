import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

  void _drag(Offset delta, Size size) {
    final dx = delta.dx / size.width, dy = delta.dy / size.height;
    final i = _selected;
    if (i != null && i < _edit.texts.length) {
      final t = _edit.texts[i];
      _setText(
        i,
        t.copyWith(
          x: (t.x + dx).clamp(0.0, 1.0),
          y: (t.y + dy).clamp(0.0, 1.0),
        ),
      );
    } else {
      setState(
        () => _edit = _edit.copyWith(
          panX: (_edit.panX + dx).clamp(-1.0, 1.0),
          panY: (_edit.panY + dy).clamp(-1.0, 1.0),
        ),
      );
    }
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
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Editar imagem da tela', style: OcText.title),
              const SizedBox(height: 4),
              Text(
                _selected == null
                    ? 'Arraste a imagem para posicionar e use a roda do mouse para o zoom.'
                    : 'Arraste para mover o texto selecionado. Clique nele de novo na lista para voltar a mover a imagem.',
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
                                  return SizedBox.square(
                                    dimension: side,
                                    child: Listener(
                                      onPointerSignal: (e) {
                                        if (e is PointerScrollEvent) {
                                          _zoomBy(
                                            e.scrollDelta.dy < 0
                                                ? 1.1
                                                : 1 / 1.1,
                                          );
                                        }
                                      },
                                      child: GestureDetector(
                                        onPanUpdate: (d) => _drag(
                                          d.delta,
                                          Size.square(side - 24),
                                        ),
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.move,
                                          child: ScreenPreview(
                                            spec: spec,
                                            frames: f,
                                            edit: _edit,
                                            readSensor: widget.readSensor,
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
                      width: 340,
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
      onTap: () => setState(() => _selected = selected ? null : i),
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
                          size: k.isEmpty ? t.size : math.min(t.size, .18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            OcSlider(
              value: t.size * 100,
              min: 3,
              max: t.live ? 18 : 30,
              suffix: '%',
              onChanged: (v) => _setText(i, t.copyWith(size: v / 100)),
            ),
          ],
        ),
      ),
    );
  }
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
