import 'package:flutter/material.dart';

import '../effects/effect_host.dart';
import '../engine/engine.dart';
import 'devices_page.dart';
import 'effects_page.dart';
import 'layout_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.engine});
  final Engine engine;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _page = 0;

  static const _nav = [
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Efeitos'),
    (Icons.devices_other_outlined, Icons.devices_other, 'Dispositivos'),
    (Icons.dashboard_customize_outlined, Icons.dashboard_customize, 'Layout'),
    (Icons.settings_outlined, Icons.settings, 'Configurações'),
  ];

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 248,
            color: OcColors.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Logo(),
                const SizedBox(height: 8),
                for (var i = 0; i < _nav.length; i++)
                  _NavItem(
                    icon: _page == i ? _nav[i].$2 : _nav[i].$1,
                    label: _nav[i].$3,
                    selected: _page == i,
                    badge: i == 1
                        ? engine.devices.values
                              .where((d) => d.status == 'running')
                              .length
                        : null,
                    onTap: () => setState(() => _page = i),
                  ),
                const Spacer(),
                _NowPlaying(engine: engine),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: engine,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (engine.conflicts.isNotEmpty)
                    _ConflictBanner(names: engine.conflicts),
                  Expanded(
                    child: IndexedStack(
                      index: _page,
                      children: [
                        EffectsPage(engine: engine),
                        DevicesPage(engine: engine),
                        LayoutPage(engine: engine),
                        SettingsPage(engine: engine),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    color: OcColors.warn.withValues(alpha: .14),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: OcColors.warn, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${names.join(', ')} está aberto e também controla os LEDs; '
            'os dois programas vão disputar as cores e elas vão piscar. '
            'Feche-o (inclusive na bandeja do sistema) para usar o OpenChroma.',
            style: const TextStyle(color: OcColors.warn, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: OcColors.accentGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.blur_on, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 10),
        const Text(
          'OpenChroma',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: Material(
      color: selected ? OcColors.surfaceHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? OcColors.accent : OcColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? OcColors.text : OcColors.textMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (badge != null && badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: OcColors.accent.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 11,
                      color: OcColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sidebar card with the running effect. It hosts the WebView2 that renders
/// the effect, so it must stay mounted and visible.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: OcColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: OcColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: EffectPreview(engine: engine),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: engine,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                engine.currentEffect?.title ?? 'Nenhum efeito',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.brightness_6,
                    size: 16,
                    color: OcColors.textMuted,
                  ),
                  Expanded(
                    child: Slider(
                      value: engine.brightness.toDouble(),
                      min: 0,
                      max: 100,
                      onChanged: (v) => engine.setBrightness(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${engine.brightness}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: OcColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
