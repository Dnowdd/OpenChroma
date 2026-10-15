import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';

/// Paints the latest effect frame, rebuilt as a GPU image per frame.
class LiveCanvas extends StatefulWidget {
  const LiveCanvas({super.key, required this.engine});
  final Engine engine;

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
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ImagePainter(_image), size: Size.infinite);
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
      return;
    }
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: img,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
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
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Layout',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Arraste os dispositivos sobre a tela do efeito. Cada ponto é um LED; '
                  'a cor dele é a do efeito naquela posição.',
                  style: TextStyle(color: OcColors.textMuted),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: canvasWidth / canvasHeight,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final k = box.maxWidth / canvasWidth;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: LiveCanvas(engine: engine),
                                ),
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                      () => _selDevice = _selZone = null,
                                    ),
                                  ),
                                ),
                                for (final d in running)
                                  for (final z in d.zones)
                                    _zoneWidget(engine, d, z, k),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 300,
          decoration: const BoxDecoration(
            color: OcColors.sidebar,
            border: Border(left: BorderSide(color: OcColors.border)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'ZONAS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: OcColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                for (final d in running)
                  for (final z in d.zones)
                    ListTile(
                      dense: true,
                      selected: _selDevice == d.key && _selZone == z.key,
                      selectedTileColor: OcColors.surfaceHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: Text(
                        z.key == 'main' ? d.name : z.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${z.positions.length} LEDs · ${z.width}×${z.height}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => setState(() {
                        _selDevice = d.key;
                        _selZone = z.key;
                      }),
                    ),
                if (selDevice != null && _selZone != null) ...[
                  const Divider(height: 32),
                  _ZoneEditor(
                    engine: engine,
                    device: selDevice,
                    zoneKey: _selZone!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _zoneWidget(Engine engine, DeviceInstance d, LedZone z, double k) {
    final item = engine.layoutOf(d, z.key);
    final selected = _selDevice == d.key && _selZone == z.key;
    final w = z.width * item.scale * k, h = z.height * item.scale * k;
    return Positioned(
      left: item.x * k,
      top: item.y * k,
      width: w.clamp(6, 4000),
      height: h.clamp(6, 4000),
      child: GestureDetector(
        onTap: () => setState(() {
          _selDevice = d.key;
          _selZone = z.key;
        }),
        onPanStart: (_) => setState(() {
          _selDevice = d.key;
          _selZone = z.key;
        }),
        onPanUpdate: (u) {
          item.x += u.delta.dx / k;
          item.y += u.delta.dy / k;
          engine.setLayout(d, z.key, item);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
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

class _ZonePainter extends CustomPainter {
  _ZonePainter(this.zone, this.cell, this.selected);
  final LedZone zone;
  final double cell;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(
      r,
      Paint()..color = Colors.black.withValues(alpha: selected ? .25 : .12),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = selected ? OcColors.accent : Colors.white54,
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: .9);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black54;
    final radius = (cell * .18).clamp(1.2, 4.0);
    for (final pos in zone.positions) {
      final c = Offset((pos[0] + .5) * cell, (pos[1] + .5) * cell);
      canvas.drawCircle(c, radius, dot);
      canvas.drawCircle(c, radius, ring);
    }
  }

  @override
  bool shouldRepaint(_ZonePainter old) =>
      old.cell != cell || old.selected != selected || old.zone != zone;
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
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, color: OcColors.textMuted),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            set(v);
            engine.setLayout(device, zoneKey, item);
          },
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.fit_screen, size: 16),
          label: const Text('Cobrir a tela toda'),
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
      ],
    );
  }
}
