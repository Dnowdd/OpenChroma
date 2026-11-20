import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'accent.dart';
import 'device_art.dart';
import 'theme.dart';
import 'widgets.dart';

/// The overall brightness slider. Hovering it (or clicking its icon) opens
/// a panel with each device's own brightness.
class BrightnessControl extends StatefulWidget {
  const BrightnessControl({
    super.key,
    required this.engine,
    this.width = 210,
    this.onDark = false,
  });
  final Engine engine;
  final double width;

  /// Drawn over the live light (white controls) instead of on a panel.
  final bool onDark;

  @override
  State<BrightnessControl> createState() => _BrightnessControlState();
}

class _BrightnessControlState extends State<BrightnessControl> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _pill = GlobalKey();
  Timer? _close;
  bool _overPanel = false, _overPill = false, _pressing = false;

  /// Opens upwards when there is more room above the slider, and the room
  /// the panel gets on that side.
  bool _above = false;
  double _room = 400;

  void _open() {
    _close?.cancel();
    if (_portal.isShowing) return;
    final box = _pill.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(context).height;
    if (box != null && box.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      final below = screen - top - box.size.height - 18;
      final above = top - 18;
      _above = below < 360 && above > below;
      _room = math.max(160, _above ? above : below);
    }
    setState(_portal.show);
  }

  void _scheduleClose() {
    _close?.cancel();
    _close = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _overPanel || _overPill || _pressing) return;
      setState(_portal.hide);
    });
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final color = widget.onDark ? Colors.white : Oc.textSecondary;
    return CompositedTransformTarget(
      key: _pill,
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: _above ? Alignment.topRight : Alignment.bottomRight,
          followerAnchor: _above ? Alignment.bottomRight : Alignment.topRight,
          offset: Offset(6, _above ? -10 : 10),
          child: Align(
            alignment: _above ? Alignment.bottomRight : Alignment.topRight,
            child: MouseRegion(
              onEnter: (_) {
                _overPanel = true;
                _open();
              },
              onExit: (_) {
                _overPanel = false;
                _scheduleClose();
              },
              child: Listener(
                onPointerDown: (_) => _pressing = true,
                onPointerUp: (_) {
                  _pressing = false;
                  _scheduleClose();
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: _room),
                  child: BrightnessPanel(engine: engine),
                ),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          onEnter: (_) {
            _overPill = true;
            _open();
          },
          onExit: (_) {
            _overPill = false;
            _scheduleClose();
          },
          child: ListenableBuilder(
            listenable: engine,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Brilho de cada dispositivo',
                  child: InkResponse(
                    radius: 16,
                    onTap: () =>
                        _portal.isShowing ? setState(_portal.hide) : _open(),
                    child: Icon(
                      engine.brightness == 0
                          ? Icons.light_mode_outlined
                          : Icons.light_mode_rounded,
                      size: 16,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: widget.width,
                  child: widget.onDark
                      ? SliderTheme(
                          data: SliderTheme.of(context)
                              .copyWith(inactiveTrackColor: Colors.white24),
                          child: _master(engine, Colors.white),
                        )
                      : _master(engine, LiveAccent.of(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _master(Engine engine, Color color) => OcSlider(
    value: engine.brightness.toDouble(),
    min: 0,
    max: 100,
    suffix: '%',
    activeColor: color,
    onChanged: (v) => engine.setBrightness(v.round()),
  );
}

/// Overall brightness and each device's own: LEDs and screens.
class BrightnessPanel extends StatelessWidget {
  const BrightnessPanel({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final accent = LiveAccent.of(context);
      final running = engine.devices.values
          .where((d) => d.status == 'running')
          .toList();
      final leds = running.where((d) => d.device.ledCount > 0).toList();
      final screens = running.where(engine.hasScreenBrightness).toList();
      return Material(
        color: Oc.panel,
        elevation: 12,
        shadowColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: Oc.r12,
          side: BorderSide(color: Oc.line),
        ),
        child: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Brilho', style: OcText.label),
                const SizedBox(height: 10),
                _row(
                  leading: Icon(Icons.tune_rounded, size: 18, color: accent),
                  label: 'Tudo',
                  value: engine.brightness,
                  color: accent,
                  onChanged: engine.setBrightness,
                ),
                if (leds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const SectionLabel('Luzes'),
                  for (final d in leds)
                    _row(
                      leading: DeviceArt(engine: engine, device: d, size: 26),
                      label: d.name,
                      value: engine.deviceBrightness(d),
                      color: accent,
                      onChanged: (v) => engine.setDeviceBrightness(d, v),
                    ),
                ],
                if (screens.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const SectionLabel('Telas'),
                  for (final d in screens)
                    _row(
                      leading: const Icon(
                        Icons.monitor_rounded,
                        size: 18,
                        color: Oc.textSecondary,
                      ),
                      label: d.name,
                      value: engine.screenBrightness(d),
                      min: 1,
                      color: accent,
                      onChanged: (v) => engine.setScreenBrightness(d, v),
                    ),
                ],
                if (leds.isEmpty && screens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Nenhum dispositivo conectado.',
                      style: OcText.caption,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '"Tudo" vale para todos os dispositivos, por cima do brilho '
                  'de cada um. Em 0%, o efeito pausa e nada é enviado.',
                  style: OcText.caption,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _row({
    required Widget leading,
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
    double min = 0,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 28, child: Center(child: leading)),
        const SizedBox(width: 10),
        SizedBox(
          width: 104,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OcText.body,
          ),
        ),
        Expanded(
          child: OcSlider(
            value: value.toDouble(),
            min: min,
            max: 100,
            suffix: '%',
            activeColor: color,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    ),
  );
}

/// Pauses the effect where it is, or lets it go on.
class PauseButton extends StatelessWidget {
  const PauseButton({super.key, required this.engine, this.onDark = false});
  final Engine engine;
  final bool onDark;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final paused = engine.paused;
      final dark = engine.brightness == 0;
      final tip = dark
          ? 'Pausado: o brilho está em 0%'
          : paused
          ? 'Continuar o efeito'
          : 'Pausar o efeito';
      final color = onDark ? Colors.white : Oc.textSecondary;
      return Tooltip(
        message: tip,
        child: Hover(
          onTap: dark ? null : () => engine.setPaused(!paused),
          builder: (context, h) => AnimatedContainer(
            duration: Oc.fast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: h && !dark
                  ? (onDark ? Colors.white24 : Oc.hover)
                  : Colors.transparent,
            ),
            child: Icon(
              paused || dark ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 20,
              color: dark ? color.withValues(alpha: .4) : color,
            ),
          ),
        ),
      );
    },
  );
}
