import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';
import 'widgets.dart';

/// Paints the latest effect frame, rebuilt as a GPU image per frame.
class LiveCanvas extends StatefulWidget {
  const LiveCanvas({super.key, required this.engine, this.opacity = 1});
  final Engine engine;
  final double opacity;

  @override
  State<LiveCanvas> createState() => _LiveCanvasState();
}

class _LiveCanvasState extends State<LiveCanvas> {
  ui.Image? _image;
  bool _decoding = false;

  @override
  void initState() {
    super.initState();
    widget.engine.frameNotifier.addListener(_onFrame);
  }

  void _onFrame() {
    final f = widget.engine.frameNotifier.value;
    if (f == null || _decoding) return;
    _decoding = true;
    final rgba = Uint8List(f.width * f.height * 4);
    for (var i = 0, j = 0; i < f.rgb.length; i += 3, j += 4) {
      rgba[j] = f.rgb[i];
      rgba[j + 1] = f.rgb[i + 1];
      rgba[j + 2] = f.rgb[i + 2];
      rgba[j + 3] = 255;
    }
    ui.decodeImageFromPixels(rgba, f.width, f.height, ui.PixelFormat.rgba8888, (
      img,
    ) {
      _decoding = false;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = img;
      });
    });
  }

  @override
  void dispose() {
    widget.engine.frameNotifier.removeListener(_onFrame);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ImagePainter(_image, widget.opacity),
    size: Size.infinite,
  );
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image, this.opacity);
  final ui.Image? image;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    final img = image;
    if (img == null) return;
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: img,
      fit: BoxFit.fill,
      opacity: opacity,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) =>
      old.image != image || old.opacity != opacity;
}

class LayoutPage extends StatefulWidget {
  const LayoutPage({super.key, required this.engine});
  final Engine engine;

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  String? _selDevice;
  String? _selZone;
  bool _dim = false;

  void _select(DeviceInstance? d, String? zone) => setState(() {
    _selDevice = d?.key;
    _selZone = zone;
  });

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final running = engine.devices.values
        .where((d) => d.status == 'running')
        .toList();
    final selDevice = engine.devices[_selDevice];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Layout',
                subtitle: 'Arraste cada zona sobre o efeito. Cada ponto é um LED e recebe a cor daquele lugar.',
                actions: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Escurecer efeito', style: OcText.secondary),
                      const SizedBox(width: 10),
                      OcSwitch(
                        value: _dim,
                        onChanged: (v) => setState(() => _dim = v),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Oc.panel,
                      borderRadius: Oc.r12,
                      border: Border.all(color: Oc.line),
                    ),
                    child: CustomPaint(
                      painter: const _DotGridPainter(),
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: canvasWidth / canvasHeight,
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final k = box.maxWidth / canvasWidth;
                                return DecoratedBox(
                                  position: DecorationPosition.foreground,
                                  decoration: BoxDecoration(
                                    borderRadius: Oc.r8,
                                    border: Border.all(color: Oc.lineStrong),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: Oc.r8,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: LiveCanvas(
                                            engine: engine,
                                            opacity: _dim ? .35 : 1,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onTap: () => _select(null, null),
                                          ),
                                        ),
                                        for (final d in running)
                                          for (final z in d.zones)
                                            _zone(engine, d, z, k),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              if (running.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.space_dashboard_outlined,
                    title: 'Nada para posicionar',
                    message: 'Os dispositivos conectados aparecem aqui.',
                  ),
                ),
              for (final d in running) ...[
                SectionLabel(d.name),
                OcPanel(
                  children: [
                    for (final z in d.zones)
                      _ZoneTile(
                        // Subdevice names are usually "<Parent> - <Zone>".
                        label: z.key == 'main'
                            ? 'Dispositivo'
                            : z.label.split(' - ').last,
                        detail: '${z.positions.length} LEDs',
                        selected: _selDevice == d.key && _selZone == z.key,
                        onTap: () => _select(d, z.key),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (selDevice != null && _selZone != null)
                _ZoneEditor(
                  engine: engine,
                  device: selDevice,
                  zoneKey: _selZone!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zone(Engine engine, DeviceInstance d, LedZone z, double k) {
    final item = engine.layoutOf(d, z.key);
    final selected = _selDevice == d.key && _selZone == z.key;
    final w = (z.width * item.scale * k).clamp(8.0, 4000.0);
    final h = (z.height * item.scale * k).clamp(8.0, 4000.0);
    return Positioned(
      left: item.x * k,
      top: item.y * k,
      width: w,
      height: h,
      child: GestureDetector(
        onTap: () => _select(d, z.key),
        onPanStart: (_) => _select(d, z.key),
        onPanUpdate: (u) {
          item.x += u.delta.dx / k;
          item.y += u.delta.dy / k;
          engine.setLayout(d, z.key, item);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Tooltip(
            message: z.key == 'main' ? d.name : z.label,
            child: CustomPaint(
              painter: _ZonePainter(z, item.scale * k, selected),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .05);
    const gap = 18.0;
    for (var y = gap; y < size.height; y += gap) {
      for (var x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), .8, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZonePainter extends CustomPainter {
  _ZonePainter(this.zone, this.cell, this.selected);
  final LedZone zone;
  final double cell;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(
      r,
      Paint()..color = Colors.black.withValues(alpha: selected ? .2 : .1),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1
        ..color = Colors.white.withValues(alpha: selected ? .95 : .4),
    );
    final radius = (cell * .16).clamp(1.2, 3.5);
    final fill = Paint()..color = Colors.white.withValues(alpha: .92);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: .55);
    for (final pos in zone.positions) {
      final c = Offset((pos[0] + .5) * cell, (pos[1] + .5) * cell);
      canvas.drawCircle(c, radius, fill);
      canvas.drawCircle(c, radius, ring);
    }
    if (selected) {
      final handle = Paint()..color = Colors.white;
      for (final c in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ]) {
        canvas.drawRect(
          Rect.fromCenter(center: c, width: 5, height: 5),
          handle,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.cell != cell || old.selected != selected || old.zone != zone;
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hover(
    onTap: onTap,
    builder: (context, h) => AnimatedContainer(
      duration: Oc.fast,
      color: selected ? Oc.hover : (h ? Oc.raised : Colors.transparent),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 14,
            color: selected ? Oc.text : Oc.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? Oc.text : Oc.textSecondary,
              ),
            ),
          ),
          Text(detail, style: OcText.caption),
        ],
      ),
    ),
  );
}

class _ZoneEditor extends StatelessWidget {
  const _ZoneEditor({
    required this.engine,
    required this.device,
    required this.zoneKey,
  });
  final Engine engine;
  final DeviceInstance device;
  final String zoneKey;

  @override
  Widget build(BuildContext context) {
    final item = engine.layoutOf(device, zoneKey);
    Widget slider(
      String label,
      double value,
      double min,
      double max,
      void Function(double) set,
    ) => OcRow(
      title: label,
      stacked: true,
      trailing: OcSlider(
        value: value,
        min: min,
        max: max,
        integer: false,
        onChanged: (v) {
          set(v);
          engine.setLayout(device, zoneKey, item);
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Zona selecionada',
          trailing: OcButton(
            label: 'Preencher',
            icon: Icons.fit_screen_rounded,
            variant: OcButtonVariant.ghost,
            onPressed: () {
              final z = device.zones.firstWhere((z) => z.key == zoneKey);
              final s = [
                canvasWidth / z.width,
                canvasHeight / z.height,
              ].reduce((a, b) => a < b ? a : b);
              engine.setLayout(
                device,
                zoneKey,
                LayoutItem(
                  x: (canvasWidth - z.width * s) / 2,
                  y: (canvasHeight - z.height * s) / 2,
                  scale: s,
                ),
              );
            },
          ),
        ),
        OcPanel(
          children: [
            slider('Escala', item.scale, .5, 40, (v) => item.scale = v),
            slider(
              'Posição X',
              item.x,
              -canvasWidth / 2,
              canvasWidth,
              (v) => item.x = v,
            ),
            slider(
              'Posição Y',
              item.y,
              -canvasHeight / 2,
              canvasHeight,
              (v) => item.y = v,
            ),
          ],
        ),
      ],
    );
  }
}
