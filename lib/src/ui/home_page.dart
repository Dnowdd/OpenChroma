import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ai/assistant.dart';
import '../alerts/alert_service.dart';
import '../effects/effect_library.dart';
import '../engine/engine.dart';
import '../fans/fan_service.dart';
import '../monitor/system_monitor.dart';
import 'accent.dart';
import 'device_art.dart';
import 'effects_page.dart' show EffectArtwork;
import 'fan_glyph.dart';
import 'fans_page.dart' show fanSpin;
import 'shell.dart' show Pages;
import 'theme.dart';
import 'widgets.dart';

/// The start page: the light that is on, the PC's vitals, what needs
/// attention, and quick access to everything else.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.engine,
    required this.monitor,
    required this.fans,
    required this.assistant,
    required this.active,
    required this.onNavigate,
  });
  final Engine engine;
  final SystemMonitor monitor;
  final FanService fans;
  final Assistant assistant;
  final bool active;
  final ValueChanged<int> onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.monitor.setActive(this, widget.active);
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    widget.monitor.setActive(this, widget.active);
  }

  @override
  void dispose() {
    widget.monitor.setActive(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.monitor,
    builder: (context, _) {
      final s = widget.monitor.snapshot;
      final alerts = s == null ? <_Alert>[] : _alerts(s, widget.fans);
      return LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1150;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 20, 24),
            children: [
              _Header(snapshot: s, alerts: alerts.length),
              ..._grid(s, alerts, wide: wide),
            ],
          );
        },
      );
    },
  );

  List<Widget> _grid(
    SystemSnapshot? s,
    List<_Alert> alerts, {
    required bool wide,
  }) {
    final go = widget.onNavigate;
    final hero = _LightingHero(
      engine: widget.engine,
      onOpen: () => go(Pages.lighting),
    );
    final profiles = _ProfilesCard(engine: widget.engine);
    final vitals = _vitalTiles(s, () => go(Pages.performance));
    final alertsCard = _AlertsCard(
      alerts: alerts,
      loading: s == null,
      onOpen: () => go(Pages.performance),
    );
    final fans = _FansCard(fans: widget.fans, onOpen: () => go(Pages.fans));
    final reactive = _ReactiveLightCard(engine: widget.engine, snapshot: s);
    final devices = _DevicesCard(
      engine: widget.engine,
      onOpen: () => go(Pages.devices),
    );
    final assistant = _AssistantCard(
      assistant: widget.assistant,
      onOpenSettings: () => go(Pages.settings),
    );

    const gap = 16.0;
    Widget row(double height, List<(int, Widget)> items) => SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(flex: items[i].$1, child: items[i].$2),
          ],
        ],
      ),
    );
    Widget box(double height, Widget child) =>
        SizedBox(height: height, child: child);
    const space = SizedBox(height: gap);

    if (wide) {
      return [
        row(340, [(2, hero), (1, profiles)]),
        space,
        row(176, [for (final v in vitals) (1, v)]),
        space,
        row(268, [(1, alertsCard), (1, fans), (1, reactive)]),
        space,
        row(300, [(2, assistant), (1, devices)]),
      ];
    }
    return [
      box(320, hero),
      space,
      box(250, profiles),
      space,
      row(176, [(1, vitals[0]), (1, vitals[1])]),
      space,
      row(176, [(1, vitals[2]), (1, vitals[3])]),
      space,
      box(268, alertsCard),
      space,
      row(268, [(1, fans), (1, reactive)]),
      space,
      box(300, assistant),
      space,
      box(300, devices),
    ];
  }
}

// ---------------------------------------------------------------- Header

class _Header extends StatelessWidget {
  const _Header({required this.snapshot, required this.alerts});
  final SystemSnapshot? snapshot;
  final int alerts;

  static const _weekdays = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 5
        ? 'Boa noite'
        : now.hour < 12
        ? 'Bom dia'
        : now.hour < 18
        ? 'Boa tarde'
        : 'Boa noite';
    final status = snapshot == null
        ? 'Lendo os sensores…'
        : alerts == 0
        ? 'Tudo certo com o seu PC.'
        : alerts == 1
        ? '1 aviso pede atenção.'
        : '$alerts avisos pedem atenção.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: OcText.pageTitle.copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text(status, style: OcText.secondary.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _Clock(),
              const SizedBox(height: 2),
              Text(
                '${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]}',
                style: OcText.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The time, updated on each minute.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    _timer = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        if (!mounted) return;
        setState(() {});
        _schedule();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return Text(
      '${two(now.hour)}:${two(now.minute)}',
      style: const TextStyle(
        fontFamily: Oc.fontDisplay,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: -.4,
        color: Oc.text,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ---------------------------------------------------------------- Lighting

class _LightingHero extends StatelessWidget {
  const _LightingHero({required this.engine, required this.onOpen});
  final Engine engine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final effect = engine.currentEffect;
    final devices = engine.devices.values
        .where((d) => d.status == 'running')
        .length;
    return ClipRRect(
      borderRadius: Oc.r24,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LiveCanvas(
            engine: engine,
            fallback: effect == null
                ? null
                : _EffectCover(engine: engine, effect: effect),
          ),
          // Keep the text readable over any light.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0, .55, 1],
                colors: [
                  Color(0xE6000000),
                  Color(0x33000000),
                  Color(0x22000000),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 18,
            child: _Glass(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OcStatusDot(color: accent, size: 7),
                  const SizedBox(width: 8),
                  const Text(
                    'Ao vivo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Tooltip(
              message: 'Abrir iluminação',
              child: Hover(
                onTap: onOpen,
                builder: (context, h) => AnimatedContainer(
                  duration: Oc.fast,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: h
                        ? Colors.white
                        : Colors.black.withValues(alpha: .35),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 19,
                    color: h ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        effect?.title ?? 'Nenhum efeito',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Oc.fontDisplay,
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        devices == 1
                            ? 'Em 1 dispositivo'
                            : 'Em $devices dispositivos',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _Glass(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.light_mode_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 190,
                        child: SliderTheme(
                          data: SliderTheme.of(context)
                              .copyWith(inactiveTrackColor: Colors.white24),
                          child: OcSlider(
                            value: engine.brightness.toDouble(),
                            min: 0,
                            max: 100,
                            suffix: '%',
                            activeColor: Colors.white,
                            onChanged: (v) => engine.setBrightness(v.round()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The effect's cover (or generated artwork), dimmed, for when the live
/// light is off.
class _EffectCover extends StatelessWidget {
  const _EffectCover({required this.engine, required this.effect});
  final Engine engine;
  final EffectInfo effect;

  @override
  Widget build(BuildContext context) {
    final path = engine.thumbnailFor(effect);
    return Opacity(
      opacity: .55,
      child: path == null
          ? EffectArtwork(seed: effect.title)
          : Image.file(File(path), fit: BoxFit.cover),
    );
  }
}

/// A translucent dark pill for controls laid over the live light.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.height = 32,
  });
  final Widget child;
  final EdgeInsets padding;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: padding,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: Oc.pill,
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: child,
    ),
  );
}

// ---------------------------------------------------------------- Profiles

class _ProfilesCard extends StatelessWidget {
  const _ProfilesCard({required this.engine});
  final Engine engine;

  static IconData iconOf(String key) => switch (key) {
    'game' => Icons.sports_esports_outlined,
    'work' => Icons.work_outline_rounded,
    'night' => Icons.nightlight_outlined,
    'off' => Icons.power_settings_new_rounded,
    'movie' => Icons.movie_outlined,
    'music' => Icons.music_note_outlined,
    _ => Icons.star_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final profiles = engine.profiles.take(4).toList();
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            'Perfis',
            trailing: Tooltip(
              message:
                  'Clique com o botão direito num perfil para salvar '
                  'nele a iluminação atual',
              child: const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Oc.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 2; r++) ...[
                  if (r > 0) const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < 2; c++) ...[
                          if (c > 0) const SizedBox(width: 10),
                          Expanded(
                            child: r * 2 + c < profiles.length
                                ? _tile(context, profiles[r * 2 + c], accent)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, LightProfile p, Color accent) {
    final on = engine.activeProfile == p.id;
    final fg = on ? onAccent(accent) : Oc.text;
    final detail = p.brightness == 0
        ? 'Luzes apagadas'
        : '${p.effect ?? 'Efeito atual'} · ${p.brightness}%';
    return GestureDetector(
      onSecondaryTapUp: (d) => _menu(context, p, d.globalPosition),
      onLongPressStart: (d) => _menu(context, p, d.globalPosition),
      child: Hover(
        onTap: () => engine.applyProfile(p.id),
        builder: (context, h) => AnimatedContainer(
          duration: Oc.smooth,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: on ? accent : (h ? Oc.hover : Oc.raised),
            borderRadius: Oc.r12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconOf(p.icon), size: 20, color: fg),
              const Spacer(),
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: on ? fg.withValues(alpha: .75) : Oc.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, LightProfile p, Offset at) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: const [
        PopupMenuItem(
          value: 'save',
          child: Text('Salvar a iluminação atual aqui'),
        ),
        PopupMenuItem(value: 'rename', child: Text('Renomear')),
        PopupMenuItem(value: 'reset', child: Text('Restaurar perfis padrão')),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'save':
        engine.saveProfile(p.id);
      case 'rename':
        final name = await _askName(context, p.name);
        if (name != null) engine.renameProfile(p.id, name);
      case 'reset':
        engine.resetProfiles();
    }
  }

  static Future<String?> _askName(BuildContext context, String current) {
    final c = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome do perfil', style: OcText.title),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: c,
            autofocus: true,
            maxLength: 18,
            style: OcText.body,
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          OcButton(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
          OcButton(
            label: 'Salvar',
            variant: OcButtonVariant.primary,
            onPressed: () => Navigator.pop(context, c.text),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Vitals

enum _Level {
  normal('Normal', Oc.success),
  warm('Quente', Oc.warning),
  hot('Muito quente', Oc.danger);

  const _Level(this.label, this.color);
  final String label;
  final Color color;

  static _Level of(double t, double warm, double hot) => t >= hot
      ? _Level.hot
      : t >= warm
      ? _Level.warm
      : _Level.normal;
}

_Level _cpuLevel(double t) => _Level.of(t, cpuLimits.$1, cpuLimits.$2);
_Level _gpuLevel(double t) => _Level.of(t, gpuLimits.$1, gpuLimits.$2);

List<Widget> _vitalTiles(SystemSnapshot? s, VoidCallback onOpen) {
  final cpu = s?.cpu;
  final gpu = s?.gpus.firstOrNull;
  final mem = s?.memory;
  final volume =
      s?.volumes.where((v) => v.letter == 'C').firstOrNull ??
      s?.volumes.firstOrNull;
  return [
    _VitalTile(
      icon: Icons.memory_rounded,
      label: 'CPU',
      value: cpu?.temp != null
          ? _fmt(cpu!.temp!, 0)
          : (cpu?.usage != null ? _fmt(cpu!.usage!, 0) : '—'),
      unit: cpu?.temp != null ? '°C' : '%',
      detail: cpu == null
          ? ''
          : cpu.temp != null
          ? 'Uso ${_fmt(cpu.usage ?? 0, 0)}%'
          : 'Uso · temperatura pede admin',
      percent: cpu?.temp ?? cpu?.usage,
      level: cpu?.temp != null ? _cpuLevel(cpu!.temp!) : null,
      onTap: onOpen,
    ),
    _VitalTile(
      icon: Icons.videogame_asset_outlined,
      label: 'GPU',
      value: gpu?.temp != null ? _fmt(gpu!.temp!, 0) : '—',
      unit: '°C',
      detail: gpu == null
          ? ''
          : [
              if (gpu.usage != null) 'Uso ${_fmt(gpu.usage!, 0)}%',
              if (gpu.power != null) '${_fmt(gpu.power!, 0)} W',
            ].join(' · '),
      percent: gpu?.temp,
      level: gpu?.temp != null ? _gpuLevel(gpu!.temp!) : null,
      onTap: onOpen,
    ),
    _VitalTile(
      icon: Icons.developer_board_outlined,
      label: 'Memória',
      value: mem == null ? '—' : _fmt(mem.percent, 0),
      unit: '%',
      detail: mem == null ? '' : '${_fmtGb(mem.used)} de ${_fmtGb(mem.total)}',
      percent: mem?.percent,
      level: mem == null ? null : (mem.percent >= 90 ? _Level.warm : null),
      onTap: onOpen,
    ),
    _VitalTile(
      icon: Icons.storage_rounded,
      label: 'Armazenamento',
      value: volume == null ? '—' : _fmt(volume.free / _gb, 0),
      unit: 'GB livres',
      detail: volume == null
          ? ''
          : '${volume.letter}: · ${_fmt(volume.percent, 0)}% usado',
      percent: volume?.percent,
      level: volume == null
          ? null
          : (volume.percent >= 90 ? _Level.warm : null),
      onTap: onOpen,
    ),
  ];
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.detail,
    required this.percent,
    required this.level,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String detail;
  final double? percent;

  /// Shown as a colored dot with its label; null when there is nothing to
  /// flag.
  final _Level? level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return OcCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Oc.raised,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: Oc.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: OcText.secondary.copyWith(color: Oc.text),
                ),
              ),
              if (level != null)
                Tooltip(
                  message: level!.label,
                  child: OcStatusDot(color: level!.color, size: 8),
                ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: Oc.fontDisplay,
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.2,
                  height: 1,
                  color: Oc.text,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  unit,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Oc.fontDisplay,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Oc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Meter(
            percent: percent ?? 0,
            color: level != null && level != _Level.normal
                ? level!.color
                : accent,
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OcText.caption,
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: Oc.pill,
    child: SizedBox(
      height: 5,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Oc.raised)),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            widthFactor: (percent / 100).clamp(0, 1),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: Oc.pill),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- Alerts

class _Alert {
  const _Alert(this.icon, this.title, this.detail, this.color);
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
}

List<_Alert> _alerts(SystemSnapshot s, FanService fans) => [
  for (final a in evaluateAlerts(s, fans: fans))
    _Alert(
      switch (a.kind) {
        'memory' => Icons.developer_board_outlined,
        'disk' => Icons.storage_rounded,
        'fan' => Icons.water_drop_outlined,
        _ => Icons.thermostat_rounded,
      },
      a.title,
      a.detail,
      a.level == AlertLevel.critical ? Oc.danger : Oc.warning,
    ),
];

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.alerts,
    required this.loading,
    required this.onOpen,
  });
  final List<_Alert> alerts;
  final bool loading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => OcCard(
    onTap: onOpen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcCardTitle(
          'Avisos',
          trailing: alerts.isEmpty ? null : OcTag('${alerts.length}'),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: loading
              ? const SizedBox.shrink()
              : alerts.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 38,
                      color: Oc.success,
                    ),
                    SizedBox(height: 10),
                    Text('Tudo certo', style: OcText.label),
                  ],
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = alerts[i];
                    return Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: a.color.withValues(alpha: .14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(a.icon, size: 18, color: a.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OcText.label,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OcText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Fans

class _FansCard extends StatelessWidget {
  const _FansCard({required this.fans, required this.onOpen});
  final FanService fans;
  final VoidCallback onOpen;

  static const _modes = [
    (FanProfile.silent, 'Silencioso'),
    (FanProfile.balanced, 'Equilibrado'),
    (FanProfile.turbo, 'Turbo'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return ListenableBuilder(
      listenable: fans,
      builder: (context, _) {
        final connected = [
          for (final f in fans.snapshot?.fans ?? const <FanReading>[])
            if (fans.isConnected(f)) f,
        ];
        final rpms = [for (final f in connected) f.rpm ?? 0];
        final fastest = rpms.isEmpty ? null : rpms.reduce(math.max);
        return OcCard(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OcCardTitle('Ventoinhas'),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    FanGlyph(color: accent, size: 104, speed: fanSpin(fastest)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _modes.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            _ModeButton(
                              label: _modes[i].$2,
                              selected: fans.profile == _modes[i].$1,
                              onTap: () => fans.setProfile(_modes[i].$1),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (connected.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  [
                    connected.length == 1
                        ? '1 ventoinha'
                        : '${connected.length} ventoinhas',
                    if (fastest != null && fastest > 0)
                      'até ${fastest.round()} RPM',
                  ].join(' · '),
                  style: OcText.caption,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return Hover(
      onTap: onTap,
      builder: (context, h) => AnimatedContainer(
        duration: Oc.smooth,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? accent : (h ? Oc.hover : Oc.raised),
          borderRadius: Oc.pill,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? onAccent(accent) : Oc.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Reactive

class _ReactiveLightCard extends StatelessWidget {
  const _ReactiveLightCard({required this.engine, required this.snapshot});
  final Engine engine;
  final SystemSnapshot? snapshot;

  static const _lo = Engine.reactiveLow;
  static const _hi = Engine.reactiveHigh;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final gpu = engine.reactiveSource == ReactiveSource.gpu;
    final temp = gpu
        ? (s?.gpus.where((g) => !g.integrated).firstOrNull ??
                  s?.gpus.firstOrNull)
              ?.temp
        : s?.cpu.temp;
    final t = temp == null
        ? null
        : ((temp - _lo) / (_hi - _lo)).clamp(0.0, 1.0);
    final missing = engine.reactive && s != null && temp == null;
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            'Luz reativa',
            trailing: OcSwitch(
              value: engine.reactive,
              onChanged: (v) => engine.setReactive(v),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            missing
                ? (gpu
                      ? 'Sem leitura da GPU neste PC.'
                      : 'A temperatura da CPU precisa do modo administrador.')
                : engine.reactive
                ? 'Os LEDs mostram a temperatura no lugar do efeito.'
                : 'A cor dos LEDs segue a temperatura.',
            style: OcText.secondary.copyWith(
              color: missing ? Oc.warning : null,
            ),
          ),
          const Spacer(),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 11,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: Oc.pill,
                        gradient: LinearGradient(colors: Engine.reactiveScale),
                      ),
                    ),
                  ),
                  if (t != null)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      left: t * (c.maxWidth - 30),
                      top: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: engine.reactive
                              ? Engine.reactiveColorFor(temp!)
                              : Oc.text,
                          border: Border.all(color: Oc.panel, width: 4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${_lo.round()} °C', style: OcText.caption),
              const Spacer(),
              if (temp != null)
                Text(
                  '${gpu ? 'GPU' : 'CPU'} ${_fmt(temp, 0)} °C',
                  style: OcText.caption.copyWith(color: Oc.text),
                ),
              const Spacer(),
              Text('${_hi.round()} °C', style: OcText.caption),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OcSegmented<ReactiveSource>(
              value: engine.reactiveSource,
              options: const [
                (ReactiveSource.cpu, 'CPU'),
                (ReactiveSource.gpu, 'GPU'),
              ],
              onChanged: (v) => engine.setReactive(engine.reactive, source: v),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Devices

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.engine, required this.onOpen});
  final Engine engine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final devices = engine.devices.values.toList();
    return OcCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcCardTitle(
            'Dispositivos',
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Oc.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Text(
                      engine.scanning ? 'Procurando…' : 'Nenhum dispositivo',
                      style: OcText.secondary,
                    ),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = devices[i];
                      final (label, color) = switch (d.status) {
                        'running' => ('Conectado', Oc.success),
                        'starting' => ('Iniciando', Oc.warning),
                        _ => ('Com problema', Oc.danger),
                      };
                      return Row(
                        children: [
                          DeviceArt(engine: engine, device: d, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: OcText.label,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    OcStatusDot(color: color, size: 6),
                                    const SizedBox(width: 6),
                                    Text(label, style: OcText.caption),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Assistant

class _AssistantCard extends StatefulWidget {
  const _AssistantCard({required this.assistant, required this.onOpenSettings});
  final Assistant assistant;
  final VoidCallback onOpenSettings;

  @override
  State<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends State<_AssistantCard> {
  final _input = TextEditingController();

  static const _suggestions = [
    'Por que meu PC tá lento?',
    'O que tá esquentando a GPU?',
    'Cria um efeito azul calmo',
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    widget.assistant.ask(q);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.assistant, widget.assistant.ai]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final a = widget.assistant;
    final ready = a.ai.ready;
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      HSVColor.fromColor(accent)
                          .withHue((HSVColor.fromColor(accent).hue + 60) % 360)
                          .toColor(),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: onAccent(accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OcCardTitle(
                  'Assistente',
                  trailing: a.turns.isEmpty
                      ? (ready ? OcTag(a.ai.current.model) : null)
                      : OcIconButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Nova conversa',
                          onPressed: a.clear,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _body(a, ready, accent)),
          if (ready) ...[
            if (a.turns.isEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _suggestions)
                    Hover(
                      onTap: () => _send(s),
                      builder: (context, h) => AnimatedContainer(
                        duration: Oc.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: h ? Oc.hover : Oc.raised,
                          borderRadius: Oc.pill,
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Oc.text,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _composer(a, accent),
          ],
        ],
      ),
    );
  }

  Widget _body(Assistant a, bool ready, Color accent) {
    if (!ready) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Conecte uma IA para perguntar sobre o seu PC.',
            style: OcText.title.copyWith(fontSize: 20, color: Oc.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use sua chave da Anthropic, da OpenAI ou de um serviço '
            'compatível.',
            style: OcText.secondary,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OcButton(
              label: 'Configurar IA',
              icon: Icons.key_rounded,
              variant: OcButtonVariant.primary,
              onPressed: widget.onOpenSettings,
            ),
          ),
        ],
      );
    }
    if (a.turns.isEmpty) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          'Pergunte qualquer coisa sobre o seu PC.',
          style: OcText.title.copyWith(fontSize: 22, color: Oc.textSecondary),
        ),
      );
    }
    return ListView(
      reverse: true,
      children: [
        if (a.busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Bubble(text: 'Pensando…', mine: false, accent: accent),
            ),
          ),
        for (final t in a.turns.reversed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: t.role == 'user'
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _Bubble(
                text: t.text,
                mine: t.role == 'user',
                error: t.error,
                accent: accent,
                action: t.effect == null
                    ? null
                    : OcButton(
                        label: 'Aplicar efeito',
                        icon: Icons.auto_awesome,
                        variant: OcButtonVariant.primary,
                        onPressed: () => _apply(t.effect!),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _composer(Assistant a, Color accent) => Container(
    height: 48,
    padding: const EdgeInsets.only(left: 18, right: 5),
    decoration: BoxDecoration(
      color: Oc.raised,
      borderRadius: Oc.pill,
      border: Border.all(color: Oc.line),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            enabled: !a.busy,
            onSubmitted: (_) => _send(),
            style: const TextStyle(fontSize: 13.5, color: Oc.text),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Pergunte algo…',
              hintStyle: TextStyle(fontSize: 13.5, color: Oc.textTertiary),
            ),
          ),
        ),
        Hover(
          onTap: a.busy ? null : _send,
          builder: (context, h) => Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: h && !a.busy ? Colors.white : accent,
            ),
            child: a.busy
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onAccent(accent),
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    size: 19,
                    color: h ? Oc.bg : onAccent(accent),
                  ),
          ),
        ),
      ],
    ),
  );

  void _apply(Map<String, dynamic> effect) {
    try {
      final e = widget.assistant.applyEffect(effect);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('"${e.title}" está ligado.')));
    } on FormatException catch (e) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    required this.accent,
    this.error = false,
    this.action,
  });
  final String text;
  final bool mine;
  final bool error;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 520),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: mine
          ? accent
          : (error ? Oc.danger.withValues(alpha: .12) : Oc.raised),
      borderRadius: Oc.r12,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: mine ? onAccent(accent) : (error ? Oc.danger : Oc.text),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ],
    ),
  );
}

// ---------------------------------------------------------------- Format

const _gb = 1024.0 * 1024 * 1024;

String _fmt(double v, int decimals) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

String _fmtGb(double bytes) => '${_fmt(bytes / _gb, 1)} GB';
