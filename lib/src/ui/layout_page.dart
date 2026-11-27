import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../i18n/l10n.dart';
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
  final _sidebar = ScrollController();
  String? _selDevice;
  String? _selZone;
  bool _dim = false;
  bool _preview = false;
  var _undo = <(String, String), (LedZone, LayoutItem, LayoutItem)>{};

  void _select(DeviceInstance? device, LedZone? zone, {bool identify = false}) {
    final engine = widget.engine;
    engine.stopIdentifyingZone();
    if (identify && device != null && zone != null) {
      engine.identifyZone(device, zone);
    }
    if (!_preview &&
        zone != null &&
        (_selDevice != device?.key || _selZone != zone.key) &&
        _sidebar.hasClients) {
      _sidebar.jumpTo(0);
    }
    setState(() {
      _selDevice = device?.key;
      _selZone = zone?.key;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      widget.engine.stopIdentifyingZone();
    }
  }

  @override
  void dispose() {
    widget.engine.stopIdentifyingZone();
    _sidebar.dispose();
    super.dispose();
  }

  bool _samePosition(LayoutItem a, LayoutItem b) =>
      a.x == b.x &&
      a.y == b.y &&
      a.scale == b.scale &&
      a.turns == b.turns &&
      a.flipX == b.flipX &&
      a.flipY == b.flipY;

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
    final proposal = preview
        ? suggestLayout(running, currentLayout: engine.layoutOf)
        : null;
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
                      Text(l10n.layoutPreview, style: OcText.label),
                      OcButton(
                        label: l10n.layoutApply,
                        variant: OcButtonVariant.primary,
                        onPressed: () => _apply(running, proposal!),
                      ),
                      OcButton(
                        label: l10n.layoutCancel,
                        variant: OcButtonVariant.ghost,
                        onPressed: () => setState(() => _preview = false),
                      ),
                    ] else ...[
                      if (canArrange)
                        OcButton(
                          label: l10n.layoutAutoArrange,
                          icon: Icons.auto_awesome_rounded,
                          onPressed: () {
                            engine.stopIdentifyingZone();
                            setState(() => _preview = true);
                          },
                        ),
                      if (undoable.isNotEmpty)
                        OcButton(
                          label: l10n.layoutUndo,
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
                        Text(l10n.layoutHint, style: OcText.secondary),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.layoutDimEffect, style: OcText.secondary),
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
            controller: _sidebar,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            children: [
              if (running.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: EmptyState(
                    icon: Icons.space_dashboard_outlined,
                    title: l10n.layoutNothingTitle,
                    message: l10n.layoutNothingMessage,
                  ),
                ),
              if (!preview &&
                  selDevice != null &&
                  selDevice.status == 'running' &&
                  selDevice.zones.any((zone) => zone.key == _selZone)) ...[
                _ZoneEditor(
                  engine: engine,
                  device: selDevice,
                  zoneKey: _selZone!,
                ),
                const SizedBox(height: 20),
              ],
              for (final d in running) ...[
                SectionLabel(d.name),
                OcPanel(
                  children: [
                    for (final z in d.zones)
                      _ZoneTile(
                        // Subdevice names are usually "<Parent> - <Zone>".
                        label: z.key == 'main'
                            ? l10n.layoutDevice
                            : z.label.split(' - ').last,
                        detail: l10n.devicesLedCount(z.positions.length),
                        selected: _selDevice == d.key && _selZone == z.key,
                        onTap: () => _select(d, z, identify: !preview),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
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
    final (width, height) = item.sizeOf(z);
    final w = (width * item.scale * k).clamp(0.0, 4000.0);
    final h = (height * item.scale * k).clamp(0.0, 4000.0);
    return Positioned(
      key: ValueKey((d.key, z.key)),
      left: item.x * k,
      top: item.y * k,
      width: math.max(8, w),
      height: math.max(8, h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(d, z, identify: editing),
        onPanStart: editing ? (_) => _select(d, z) : null,
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
                painter: _ZonePainter(z, item, item.scale * k, selected),
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
  _ZonePainter(this.zone, this.item, this.cell, this.selected);
  final LedZone zone;
  final LayoutItem item;
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
      final (x, y) = item.pointOf(zone, pos[0] + .5, pos[1] + .5);
      final c = Offset(x * cell, y * cell);
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
      old.cell != cell ||
      old.selected != selected ||
      old.zone != zone ||
      old.item.turns != item.turns ||
      old.item.flipX != item.flipX ||
      old.item.flipY != item.flipY;
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
    final zone = device.zones.firstWhere((z) => z.key == zoneKey);
    final (width, height) = item.sizeOf(zone);
    void save() => engine.setLayout(device, zoneKey, item);
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
          save();
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l10n.layoutSelectedZone,
          trailing: OcButton(
            label: l10n.layoutFill,
            icon: Icons.fit_screen_rounded,
            variant: OcButtonVariant.ghost,
            onPressed: () {
              final scale = math.min(
                60.0,
                math.min(canvasWidth / width, canvasHeight / height),
              );
              item
                ..x = (canvasWidth - width * scale) / 2
                ..y = (canvasHeight - height * scale) / 2
                ..scale = scale;
              save();
            },
          ),
        ),
        if (device.activeMode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.layoutSwitchToApp, style: OcText.secondary),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OcButton(
              label: l10n.layoutRotate,
              icon: Icons.rotate_right_rounded,
              onPressed: () {
                final (oldWidth, oldHeight) = item.sizeOf(zone);
                final (flipX, flipY) = (item.flipX, item.flipY);
                item
                  ..turns = (item.turns + 1) % 4
                  ..flipX = flipY
                  ..flipY = flipX
                  ..x += (oldWidth - oldHeight) * item.scale / 2
                  ..y += (oldHeight - oldWidth) * item.scale / 2;
                save();
              },
            ),
            OcButton(
              label: l10n.layoutFlipHorizontal,
              icon: Icons.swap_horiz_rounded,
              variant: item.flipX
                  ? OcButtonVariant.primary
                  : OcButtonVariant.secondary,
              onPressed: () {
                item.flipX = !item.flipX;
                save();
              },
            ),
            OcButton(
              label: l10n.layoutFlipVertical,
              icon: Icons.swap_vert_rounded,
              variant: item.flipY
                  ? OcButtonVariant.primary
                  : OcButtonVariant.secondary,
              onPressed: () {
                item.flipY = !item.flipY;
                save();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        OcPanel(
          children: [
            slider(
              l10n.layoutScale,
              item.scale,
              math.min(.5, item.scale),
              math.max(40, item.scale),
              (v) => item.scale = v,
            ),
            slider(
              l10n.layoutPositionX,
              item.x,
              -canvasWidth / 2,
              canvasWidth,
              (v) => item.x = v,
            ),
            slider(
              l10n.layoutPositionY,
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
