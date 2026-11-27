import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fans/fan_service.dart';
import '../i18n/l10n.dart';
import 'accent.dart';
import 'fan_glyph.dart';
import 'theme.dart';
import 'widgets.dart';
import '../system/system_paths.dart';

/// Fan control: motherboard headers (Super I/O through PawnIO) and GPU
/// coolers (NvAPI), each left to the BIOS / driver, on the shared profile
/// curve or at a fixed speed.
class FansPage extends StatefulWidget {
  const FansPage({
    super.key,
    required this.fans,
    required this.active,
    required this.onRestartAsAdmin,
  });
  final FanService fans;

  /// On screen: the curve shows live temperatures.
  final bool active;
  final VoidCallback onRestartAsAdmin;

  @override
  State<FansPage> createState() => _FansPageState();
}

/// Turns per second for the glyph at [rpm].
double fanSpin(double? rpm) =>
    rpm == null ? .15 : (rpm / 1400).clamp(0, 2.4).toDouble();

class _FansPageState extends State<FansPage> {
  String? _selected;
  bool _showEmpty = false;

  @override
  void initState() {
    super.initState();
    widget.fans.monitor.setActive(this, widget.active);
  }

  @override
  void didUpdateWidget(FansPage old) {
    super.didUpdateWidget(old);
    widget.fans.monitor.setActive(this, widget.active);
  }

  @override
  void dispose() {
    widget.fans.monitor.setActive(this, false);
    super.dispose();
  }

  static List<(FanProfile, String)> get _profiles => [
    (FanProfile.silent, l10n.fansProfileSilent),
    (FanProfile.balanced, l10n.fansProfileBalanced),
    (FanProfile.turbo, l10n.fansProfileTurbo),
    (FanProfile.custom, l10n.fansProfileCustom),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.fans,
    builder: (context, _) {
      final fans = widget.fans;
      final s = fans.snapshot;
      final all = s?.fans ?? const <FanReading>[];
      final connected = all.where(fans.isConnected).toList();
      final empty = all.where((f) => !fans.isConnected(f)).toList();
      final shown = [...connected, if (_showEmpty) ...empty];
      final selected =
          all.where((f) => f.id == _selected).firstOrNull ??
          connected.firstOrNull ??
          all.firstOrNull;
      return LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1100;
          final curveCard = _CurveCard(fans: fans, fan: selected);
          final fanCard = _FanCard(
            key: ValueKey(selected?.id),
            fans: fans,
            fan: selected,
          );
          final notice = _notice(s);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 18, 4, 22),
                        child: Row(
                          children: [
                            Text(
                              l10n.fansTitle,
                              style: OcText.pageTitle.copyWith(fontSize: 28),
                            ),
                            const Spacer(),
                            OcSegmented<FanProfile>(
                              value: fans.profile,
                              options: _profiles,
                              onChanged: fans.setProfile,
                            ),
                          ],
                        ),
                      ),
                      if (notice != null) ...[
                        notice,
                        const SizedBox(height: 16),
                      ],
                      if (fans.askPump) ...[
                        _PumpQuestion(
                          fans: fans,
                          // Fastest first: pumps usually spin faster than
                          // fans, so it is the likely answer.
                          candidates: [
                            for (final f in connected)
                              if (!f.gpu) f,
                          ]..sort((a, b) => (b.rpm ?? 0).compareTo(a.rpm ?? 0)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (wide)
                        SizedBox(
                          height: 420,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: curveCard),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: fanCard),
                            ],
                          ),
                        )
                      else ...[
                        SizedBox(height: 360, child: curveCard),
                        const SizedBox(height: 16),
                        SizedBox(height: 420, child: fanCard),
                      ],
                      if (all.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 14),
                          child: Row(
                            children: [
                              Text(l10n.fansConnected, style: OcText.title),
                              const SizedBox(width: 10),
                              OcTag('${connected.length}'),
                              const Spacer(),
                              if (empty.isNotEmpty)
                                OcButton(
                                  label: _showEmpty
                                      ? l10n.fansHideEmpty
                                      : l10n.fansShowEmpty(empty.length),
                                  variant: OcButtonVariant.ghost,
                                  onPressed: () =>
                                      setState(() => _showEmpty = !_showEmpty),
                                ),
                            ],
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: .78,
                              ),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => _FanTile(
                            fans: fans,
                            fan: shown[i],
                            selected: shown[i].id == selected?.id,
                            onTap: () =>
                                setState(() => _selected = shown[i].id),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  Widget? _notice(FanSnapshot? s) {
    if (s == null) return null;
    if (s.conflict.isNotEmpty) {
      return _Notice(
        color: Oc.warning,
        icon: Icons.error_outline_rounded,
        title: l10n.fansConflictTitle(s.conflict),
        text: ' ${l10n.fansConflictText}',
      );
    }
    return switch (s.superIo) {
      SuperIoStatus.needsAdmin => _Notice(
        color: Oc.textSecondary,
        icon: Icons.shield_outlined,
        title: l10n.fansAdminTitle,
        text: ' ${l10n.fansAdminText}',
        action: OcButton(
          label: l10n.fansRestartAsAdmin,
          icon: Icons.admin_panel_settings_outlined,
          variant: OcButtonVariant.primary,
          onPressed: widget.onRestartAsAdmin,
        ),
      ),
      SuperIoStatus.noDriver => _Notice(
        color: Oc.textSecondary,
        icon: Icons.download_rounded,
        title: l10n.fansInstallPawnIoTitle,
        text: ' ${l10n.fansInstallPawnIoText}',
        action: OcButton(
          label: l10n.fansDownload,
          icon: Icons.open_in_new_rounded,
          onPressed: () =>
              Process.run(SystemPaths.explorer, ['https://pawnio.eu']),
        ),
      ),
      SuperIoStatus.busy => _Notice(
        color: Oc.warning,
        icon: Icons.hourglass_empty_rounded,
        title: l10n.fansBusyTitle,
        text: ' ${l10n.fansBusyText}',
      ),
      _ => null,
    };
  }
}

/// Asked once: nothing tells a water cooling pump from a fan, and a pump
/// must never slow down or stop.
class _PumpQuestion extends StatelessWidget {
  const _PumpQuestion({required this.fans, required this.candidates});
  final FanService fans;
  final List<FanReading> candidates;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
    decoration: BoxDecoration(
      color: Oc.panel,
      borderRadius: Oc.r12,
      border: Border.all(color: Oc.line),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.water_drop_outlined,
          size: 17,
          color: Oc.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: l10n.fansPumpQuestionTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Oc.text,
                  ),
                ),
                TextSpan(text: ' ${l10n.fansPumpQuestionText}'),
              ],
            ),
            style: const TextStyle(fontSize: 12.5, color: Oc.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in candidates)
              OcButton(
                label: fans.nameOf(f),
                icon: Icons.water_drop_outlined,
                // Only a hint: fast fans exist too, so the user decides.
                variant: f == candidates.first && (f.rpm ?? 0) >= 2200
                    ? OcButtonVariant.primary
                    : OcButtonVariant.secondary,
                onPressed: () => fans.answerPump(f.id),
              ),
            OcButton(
              label: l10n.fansPumpNone,
              variant: OcButtonVariant.ghost,
              onPressed: () => fans.answerPump(null),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(18, action == null ? 12 : 8, 8, 8),
    constraints: const BoxConstraints(minHeight: 52),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: Oc.r12,
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: text),
              ],
            ),
            style: TextStyle(fontSize: 12.5, color: color),
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    ),
  );
}

// ---------------------------------------------------------------- Curve

class _CurveCard extends StatelessWidget {
  const _CurveCard({required this.fans, required this.fan});
  final FanService fans;
  final FanReading? fan;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final f = fan;
    final source = f == null ? TempSource.cpu : fans.sourceOf(f);
    final temp = fans.temperature(source);
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            l10n.fansCurveTitle,
            trailing: f == null
                ? null
                : Tooltip(
                    message:
                        source == TempSource.cpu &&
                            temp == null &&
                            !(fans.snapshot?.elevated ?? false)
                        ? l10n.fansCpuTempNeedsAdmin
                        : '',
                    child: OcSegmented<TempSource>(
                      value: source,
                      options: const [
                        (TempSource.cpu, 'CPU'),
                        (TempSource.gpu, 'GPU'),
                      ],
                      onChanged: (v) => fans.setSource(f.id, v),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _CurveEditor(
              curve: fans.curve,
              temp: temp,
              label: source == TempSource.cpu ? 'CPU' : 'GPU',
              color: accent,
              onEditStart: fans.beginCustomEdit,
              onMove: fans.moveCustomPoint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The curve chart; dragging a point edits the custom curve (starting it
/// from the current profile).
class _CurveEditor extends StatefulWidget {
  const _CurveEditor({
    required this.curve,
    required this.temp,
    required this.label,
    required this.color,
    required this.onEditStart,
    required this.onMove,
  });
  final FanCurve curve;
  final double? temp;
  final String label;
  final Color color;
  final VoidCallback onEditStart;
  final void Function(int index, double t, double s) onMove;

  @override
  State<_CurveEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends State<_CurveEditor> {
  int? _hover;
  int? _drag;

  int? _hit(Offset pos, Size size) {
    int? best;
    var bestD = 18.0;
    for (var i = 0; i < widget.curve.length; i++) {
      final (t, s) = widget.curve[i];
      final d = (_CurvePainter.at(size, t, s) - pos).distance;
      if (d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final size = c.biggest;
      return MouseRegion(
        cursor: _drag != null
            ? SystemMouseCursors.grabbing
            : _hover != null
            ? SystemMouseCursors.grab
            : MouseCursor.defer,
        onHover: (e) {
          final h = _hit(e.localPosition, size);
          if (h != _hover) setState(() => _hover = h);
        },
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (e) {
            final i = _hit(e.localPosition, size);
            if (i == null) return;
            widget.onEditStart();
            setState(() => _drag = i);
          },
          onPanUpdate: (e) {
            final i = _drag;
            if (i == null) return;
            final (t, s) = _CurvePainter.valueAt(size, e.localPosition);
            widget.onMove(i, t, s);
          },
          onPanEnd: (_) => setState(() => _drag = null),
          onPanCancel: () => setState(() => _drag = null),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.temp ?? -1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              size: size,
              painter: _CurvePainter(
                curve: widget.curve,
                temp: widget.temp == null ? null : t,
                label: widget.temp == null ? null : widget.label,
                color: widget.color,
                active: _drag ?? _hover,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.curve,
    required this.temp,
    required this.label,
    required this.color,
    required this.active,
  });
  final FanCurve curve;
  final double? temp;
  final String? label;
  final Color color;

  /// Point under the pointer or being dragged.
  final int? active;

  static const _tMin = 20.0, _tMax = 100.0;
  static const _left = 40.0, _bottom = 26.0;

  static Offset at(Size size, double t, double s) {
    final w = size.width - _left;
    final h = size.height - _bottom;
    return Offset(_left + (t - _tMin) / (_tMax - _tMin) * w, h * (1 - s / 100));
  }

  static (double, double) valueAt(Size size, Offset o) {
    final w = size.width - _left;
    final h = size.height - _bottom;
    return (_tMin + (o.dx - _left) / w * (_tMax - _tMin), (1 - o.dy / h) * 100);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _bottom;
    void text(String s, Offset o, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: OcText.caption),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right
          ? o.dx - tp.width
          : align == TextAlign.center
          ? o.dx - tp.width / 2
          : o.dx;
      tp.paint(canvas, Offset(dx, o.dy - tp.height / 2));
    }

    final grid = Paint()
      ..color = Oc.line
      ..strokeWidth = 1;
    for (var s = 0; s <= 100; s += 25) {
      final y = at(size, _tMin, s.toDouble()).dy;
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      text('$s%', Offset(_left - 10, y), align: TextAlign.right);
    }
    for (var t = 20; t <= 100; t += 20) {
      final x = at(size, t.toDouble(), 0).dx;
      text('$t °C', Offset(x, h + 16), align: TextAlign.center);
    }

    final points = [for (final (t, s) in curve) at(size, t, s)];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final hot = i == active;
      if (hot) {
        canvas.drawCircle(p, 13, Paint()..color = color.withValues(alpha: .2));
      }
      canvas.drawCircle(p, 7, Paint()..color = hot ? color : Oc.panel);
      canvas.drawCircle(
        p,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
      if (hot) {
        final (t, s) = curve[i];
        text(
          '${t.round()} °C · ${s.round()}%',
          p + const Offset(0, -22),
          align: TextAlign.center,
        );
      }
    }

    final t = temp;
    if (t != null) {
      final clamped = t.clamp(_tMin, _tMax).toDouble();
      final p = at(size, clamped, FanService.speedAt(curve, clamped));
      final dash = Paint()
        ..color = Oc.textTertiary
        ..strokeWidth = 1;
      for (var y = 0.0; y < h; y += 6) {
        canvas.drawLine(
          Offset(p.dx, y),
          Offset(p.dx, math.min(y + 3, h)),
          dash,
        );
      }
      canvas.drawCircle(p, 9, Paint()..color = color.withValues(alpha: .25));
      canvas.drawCircle(p, 5, Paint()..color = Oc.text);
      final tp = TextPainter(
        text: TextSpan(
          text: '$label ${t.round()} °C',
          style: const TextStyle(
            fontFamily: Oc.font,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Oc.bg,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            p.dx.clamp(
              _left + tp.width / 2 + 10,
              size.width - tp.width / 2 - 10,
            ),
            10,
          ),
          width: tp.width + 18,
          height: 22,
        ),
        const Radius.circular(11),
      );
      canvas.drawRRect(box, Paint()..color = Oc.text);
      tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) => true;
}

// ---------------------------------------------------------------- Fan

/// The selected fan: live speed, rename, mode and its options.
class _FanCard extends StatefulWidget {
  const _FanCard({super.key, required this.fans, required this.fan});
  final FanService fans;
  final FanReading? fan;

  @override
  State<_FanCard> createState() => _FanCardState();
}

class _FanCardState extends State<_FanCard> {
  bool _editing = false;
  final _name = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit(FanReading f) {
    _name.text = widget.fans.nameOf(f);
    _name.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _name.text.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _commit() {
    final f = widget.fan;
    if (f != null) widget.fans.rename(f.id, _name.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final fans = widget.fans;
    final f = widget.fan;
    if (f == null) {
      return OcCard(
        child: Center(
          child: Text(
            fans.snapshot == null ? l10n.fansSearching : l10n.fansNone,
            style: OcText.secondary,
          ),
        ),
      );
    }
    final cfg = fans.settingsOf(f.id);
    final blocked = fans.blockedReason(f);
    final duty = f.duty ?? (f.controlled ? fans.targetOf(f) : null);
    final noTemp =
        cfg.mode == FanMode.curve && fans.temperature(fans.sourceOf(f)) == null;
    final status = [
      if (f.rpm != null) '${f.rpm!.round()} RPM',
      blocked ??
          (noTemp
              ? (f.gpu ? l10n.fansNoTempDriver : l10n.fansNoTempBios)
              : switch (cfg.mode) {
                  FanMode.auto => f.gpu ? 'Driver' : 'BIOS',
                  FanMode.curve => l10n.fansModeCurve,
                  FanMode.fixed => l10n.fansModeFixed,
                }),
    ].join(' · ');
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: _editing
                      ? TextField(
                          controller: _name,
                          focusNode: _focus,
                          style: OcText.title.copyWith(fontSize: 16),
                          decoration: ocFieldDecoration(fans.defaultName(f)),
                          onSubmitted: (_) => _commit(),
                        )
                      : Hover(
                          onTap: () => _startEdit(f),
                          cursor: SystemMouseCursors.text,
                          builder: (context, h) => Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fans.nameOf(f),
                                  overflow: TextOverflow.ellipsis,
                                  style: OcText.title.copyWith(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedOpacity(
                                duration: Oc.fast,
                                opacity: h ? 1 : .45,
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: Oc.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            f.gpu ? f.device : l10n.fansMotherboardDevice(f.device),
            overflow: TextOverflow.ellipsis,
            style: OcText.caption,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            duty == null
                                ? l10n.fansModeAuto
                                : '${duty.round()}',
                            style: TextStyle(
                              fontFamily: Oc.fontDisplay,
                              fontSize: duty == null ? 44 : 56,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.8,
                              height: 1,
                              color: Oc.text,
                            ),
                          ),
                          if (duty != null) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '%',
                              style: TextStyle(
                                fontFamily: Oc.fontDisplay,
                                fontSize: 20,
                                color: Oc.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(status, style: OcText.secondary),
                    ],
                  ),
                ),
                FanGlyph(color: accent, size: 130, speed: fanSpin(f.rpm)),
              ],
            ),
          ),
          Tooltip(
            message: blocked ?? '',
            child: Opacity(
              opacity: blocked == null ? 1 : .45,
              child: IgnorePointer(
                ignoring: blocked != null,
                child: Row(
                  children: [
                    OcSegmented<FanMode>(
                      value: cfg.mode,
                      options: [
                        (FanMode.auto, l10n.fansModeAuto),
                        (FanMode.curve, l10n.fansModeCurve),
                        (FanMode.fixed, l10n.fansModeFixed),
                      ],
                      onChanged: (m) => fans.setMode(f.id, m),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: cfg.mode == FanMode.fixed && blocked == null
                ? OcSlider(
                    value: math.max(
                      cfg.fixed,
                      cfg.pump ? FanService.pumpMinimum : 0,
                    ),
                    min: cfg.pump ? FanService.pumpMinimum : 0,
                    max: 100,
                    suffix: '%',
                    onChanged: (v) => fans.setFixed(f.id, v),
                  )
                : _SwitchRow(
                    label: l10n.fansStopWhenCold,
                    value: cfg.zeroRpm && !cfg.pump,
                    onChanged: cfg.mode == FanMode.curve && !cfg.pump
                        ? (v) => fans.setZeroRpm(f.id, v)
                        : null,
                  ),
          ),
          const Divider(),
          _SwitchRow(
            label: l10n.fansPumpToggle,
            value: cfg.pump,
            onChanged: (v) => fans.setPump(f.id, v),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: OcText.label.copyWith(
              color: onChanged == null ? Oc.textTertiary : null,
            ),
          ),
        ),
        OcSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _FanTile extends StatelessWidget {
  const _FanTile({
    required this.fans,
    required this.fan,
    required this.selected,
    required this.onTap,
  });
  final FanService fans;
  final FanReading fan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final cfg = fans.settingsOf(fan.id);
    final duty = fan.duty;
    final rpm = fan.rpm;
    return OcCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      borderColor: selected ? accent.withValues(alpha: .7) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fans.nameOf(fan),
                  overflow: TextOverflow.ellipsis,
                  style: OcText.label,
                ),
              ),
              if (cfg.pump)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.water_drop_outlined,
                    size: 14,
                    color: Oc.textTertiary,
                  ),
                ),
              const SizedBox(width: 6),
              Text(switch (cfg.mode) {
                FanMode.auto => l10n.fansModeAuto,
                FanMode.curve => l10n.fansModeCurve,
                FanMode.fixed => l10n.fansModeFixed,
              }, style: OcText.caption),
            ],
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) => FanGlyph(
                  color: accent,
                  size: math.min(c.maxWidth, c.maxHeight) * .86,
                  speed: fanSpin(rpm),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                duty == null ? l10n.fansModeAuto : '${duty.round()}',
                style: OcText.pageTitle.copyWith(fontSize: 24),
              ),
              if (duty != null) ...[
                const SizedBox(width: 3),
                const Text('%', style: OcText.caption),
              ],
              const Spacer(),
              Text(
                rpm == null ? '— RPM' : '${rpm.round()} RPM',
                style: OcText.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
