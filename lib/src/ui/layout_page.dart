import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'accent.dart';
import 'auto_layout.dart';
import 'theme.dart';
import 'widgets.dart';

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
  bool _preview = false;
  var _undo = <(String, String), (LedZone, LayoutItem, LayoutItem)>{};

  void _select(DeviceInstance? d, String? zone) => setState(() {
    _selDevice = d?.key;
    _selZone = zone;
  });

  bool _samePosition(LayoutItem a, LayoutItem b) =>
      a.x == b.x && a.y == b.y && a.scale == b.scale;

  void _apply(
    List<DeviceInstance> devices,
    Map<(String, String), LayoutItem> proposal,
  ) {
    final engine = widget.engine;
    final undo = <(String, String), (LedZone, LayoutItem, LayoutItem)>{};
    for (final device in devices) {
      for (final zone in device.zones) {
        final key = (device.key, zone.key);
        final proposed = proposal[key];
        if (proposed == null) continue;
        final previous = engine.layoutOf(device, zone.key);
        if (!_samePosition(previous, proposed)) {
          undo[key] = (zone, previous, proposed);
        }
      }
    }
    setState(() {
      _preview = false;
      if (undo.isNotEmpty) _undo = undo;
    });
    engine.setLayouts({
      for (final entry in undo.entries) entry.key: entry.value.$3,
    });
  }

  Map<(String, String), LayoutItem> _undoable(Engine engine) {
    final placements = <(String, String), LayoutItem>{};
    for (final MapEntry(key: (deviceKey, zoneKey), value: (zone, old, applied))
        in _undo.entries) {
      final device = engine.devices[deviceKey];
      final current = device?.zones.where((z) => z.key == zoneKey).firstOrNull;
      if (device != null &&
          current != null &&
          current.width == zone.width &&
          current.height == zone.height &&
          _samePosition(engine.layoutOf(device, zoneKey), applied)) {
        placements[(deviceKey, zoneKey)] = old;
      }
    }
    return placements;
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final running = engine.devices.values
        .where((d) => d.status == 'running')
        .toList();
    final selDevice = engine.devices[_selDevice];
    final canArrange = running.any(
      (device) => device.zones.any(
        (zone) =>
            zone.width > 0 && zone.height > 0 && zone.positions.isNotEmpty,
      ),
    );
    final preview = _preview && canArrange;
    final proposal = preview ? suggestLayout(running) : null;
    final undoable = _undoable(engine);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 20, 18),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (preview) ...[
                      const Text('Preview', style: OcText.label),
                      OcButton(
                        label: 'Apply',
                        variant: OcButtonVariant.primary,
                        onPressed: () => _apply(running, proposal!),
                      ),
                      OcButton(
                        label: 'Cancel',
                        variant: OcButtonVariant.ghost,
                        onPressed: () => setState(() => _preview = false),
                      ),
                    ] else ...[
                      if (canArrange)
                        OcButton(
                          label: 'Auto Arrange',
                          icon: Icons.auto_awesome_rounded,
                          onPressed: () => setState(() => _preview = true),
                        ),
                      if (undoable.isNotEmpty)
                        OcButton(
                          label: 'Undo',
                          icon: Icons.undo_rounded,
                          variant: OcButtonVariant.ghost,
                          onPressed: () {
                            final placements = _undoable(engine);
                            setState(
                              () => placements.keys.forEach(_undo.remove),
                            );
                            engine.setLayouts(placements);
                          },
                        ),
                      if (canArrange)
                        const Text(
                          'Drag zones to move them.',
                          style: OcText.secondary,
                        ),
                    ],
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
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Oc.panel,
                      borderRadius: Oc.r24,
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
                                    borderRadius: Oc.r10,
                                    border: Border.all(color: Oc.lineStrong),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: Oc.r10,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: AnimatedOpacity(
                                            duration: Oc.smooth,
                                            opacity: _dim ? .35 : 1,
                                            child: LiveCanvas(engine: engine),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onTap: () => _select(null, null),
                                          ),
                                        ),
                                        for (final d in running)
                                          for (final z in d.zones)
                                            _zone(engine, d, z, k, proposal),
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
        Container(
          width: 330,
          margin: const EdgeInsets.fromLTRB(0, 0, 20, 24),
          decoration: BoxDecoration(
            color: Oc.panel,
            borderRadius: Oc.r24,
            border: Border.all(color: Oc.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
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
              if (!preview &&
                  selDevice != null &&
                  selDevice.zones.any((zone) => zone.key == _selZone))
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

  Widget _zone(
    Engine engine,
    DeviceInstance d,
    LedZone z,
    double k,
    Map<(String, String), LayoutItem>? proposal,
  ) {
    final item = proposal?[(d.key, z.key)] ?? engine.layoutOf(d, z.key);
    final editing = proposal == null;
    final selected = _selDevice == d.key && _selZone == z.key;
    final w = (z.width * item.scale * k).clamp(0.0, 4000.0);
    final h = (z.height * item.scale * k).clamp(0.0, 4000.0);
    return Positioned(
      left: item.x * k,
      top: item.y * k,
      width: math.max(8, w),
      height: math.max(8, h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(d, z.key),
        onPanStart: editing ? (_) => _select(d, z.key) : null,
        onPanUpdate: editing
            ? (u) {
                item.x += u.delta.dx / k;
                item.y += u.delta.dy / k;
                engine.setLayout(d, z.key, item);
              }
            : null,
        child: MouseRegion(
          cursor: editing ? SystemMouseCursors.grab : SystemMouseCursors.click,
          child: Tooltip(
            message: z.key == 'main' ? d.name : z.label,
            child: Align(
              alignment: Alignment.topLeft,
              child: CustomPaint(
                size: Size(w, h),
                painter: _ZonePainter(z, item.scale * k, selected),
              ),
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
            slider(
              'Escala',
              item.scale,
              math.min(.5, item.scale),
              math.max(40, item.scale),
              (v) => item.scale = v,
            ),
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
