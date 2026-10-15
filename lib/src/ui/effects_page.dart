import 'dart:io';

import 'package:flutter/material.dart';

import '../effects/effect_library.dart';
import '../engine/engine.dart';
import 'property_controls.dart';
import 'theme.dart';
import 'widgets.dart';

String effectCategory(EffectInfo e) => switch (e.source) {
  'Built-in' => 'Integrado',
  'Marketplace cache' => 'Baixado',
  _ => 'Meus efeitos',
};

class EffectsPage extends StatefulWidget {
  const EffectsPage({super.key, required this.engine});
  final Engine engine;

  @override
  State<EffectsPage> createState() => _EffectsPageState();
}

class _EffectsPageState extends State<EffectsPage> {
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final list = engine.effects.where((e) {
      if (_query.isNotEmpty &&
          !e.title.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return _filter == 'all' || effectCategory(e) == _filter;
    }).toList();
    final current = engine.currentEffect;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Efeitos',
                subtitle:
                    '${engine.effects.length} efeitos disponíveis. O escolhido é aplicado em todos os dispositivos.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                child: Row(
                  children: [
                    OcSegmented<String>(
                      value: _filter,
                      options: const [
                        ('all', 'Todos'),
                        ('Integrado', 'Integrados'),
                        ('Baixado', 'Baixados'),
                        ('Meus efeitos', 'Meus'),
                      ],
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 240,
                      child: OcSearchField(
                        hint: 'Buscar efeitos',
                        onChanged: (s) => setState(() => _query = s),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nenhum efeito encontrado',
                        message: 'Tente outro termo ou mude o filtro.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 20,
                              childAspectRatio: 1.22,
                            ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _EffectCard(
                          effect: list[i],
                          thumbnail: engine.thumbnailFor(list[i]),
                          selected: current?.path == list[i].path,
                          onTap: () => engine.selectEffect(list[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (current != null) ...[
          const VerticalDivider(width: 1),
          _Inspector(engine: engine, effect: current),
        ],
      ],
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.effect,
    required this.thumbnail,
    required this.selected,
    required this.onTap,
  });
  final EffectInfo effect;
  final String? thumbnail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hover(
    onTap: onTap,
    builder: (context, h) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: Oc.fast,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: Oc.r12,
              border: Border.all(
                color: selected
                    ? Oc.text
                    : (h ? Oc.lineStrong : Colors.transparent),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: Oc.r8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    scale: h ? 1.03 : 1,
                    child: thumbnail != null
                        ? Image.file(
                            File(thumbnail!),
                            fit: BoxFit.cover,
                            cacheWidth: 520,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) =>
                                EffectArtwork(seed: effect.title),
                          )
                        : EffectArtwork(seed: effect.title),
                  ),
                  if (selected)
                    const Positioned(top: 8, left: 8, child: _LiveChip()),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  effect.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OcText.label,
                ),
              ),
              Text(effectCategory(effect), style: OcText.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .62),
      borderRadius: Oc.r6,
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OcStatusDot(color: Oc.success, size: 6),
        SizedBox(width: 6),
        Text(
          'Ativo',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

/// Artwork for effects that have no preview yet: a soft light field whose
/// palette is inferred from the effect name.
class EffectArtwork extends StatelessWidget {
  const EffectArtwork({super.key, required this.seed});
  final String seed;

  static const _palettes = <String, List<Color>>{
    'arctic|ice|frost|snow|indigo|sky': [
      Color(0xFF7DD3FC),
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
    ],
    'water|ocean|calm|wave|aqua': [
      Color(0xFF2DD4BF),
      Color(0xFF0EA5E9),
      Color(0xFF1E3A8A),
    ],
    'neon|storm|electric': [
      Color(0xFFF0ABFC),
      Color(0xFF22D3EE),
      Color(0xFF7C3AED),
    ],
    'sunset|fire|lava|heat': [
      Color(0xFFFB923C),
      Color(0xFFF43F5E),
      Color(0xFF7C2D12),
    ],
    'space|dark|matter|galaxy|star': [
      Color(0xFF8B5CF6),
      Color(0xFF1E1B4B),
      Color(0xFF3B82F6),
    ],
    'bio|hazard|toxic|matrix': [
      Color(0xFFA3E635),
      Color(0xFF16A34A),
      Color(0xFF052E16),
    ],
    'audio|spectrum|visual|scope|log|bar': [
      Color(0xFF34D399),
      Color(0xFFFBBF24),
      Color(0xFFF43F5E),
    ],
    'rainbow|gradient|tunnel|rgb': [
      Color(0xFFF43F5E),
      Color(0xFF22C55E),
      Color(0xFF3B82F6),
    ],
  };

  List<Color> _palette() {
    final name = seed.toLowerCase();
    for (final e in _palettes.entries) {
      if (e.key.split('|').any(name.contains)) return e.value;
    }
    final hash = seed.codeUnits.fold<int>(
      7,
      (h, c) => (h * 31 + c) & 0x7fffffff,
    );
    final hue = (hash % 360).toDouble();
    return [
      HSVColor.fromAHSV(1, hue, .6, .95).toColor(),
      HSVColor.fromAHSV(1, (hue + 50) % 360, .7, .8).toColor(),
      HSVColor.fromAHSV(1, (hue + 200) % 360, .6, .5).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = _palette();
    final hash = seed.codeUnits.fold<int>(3, (h, x) => (h * 17 + x) & 0xffff);
    Alignment at(int shift) => Alignment(
      ((hash >> shift) % 200) / 100 - 1,
      ((hash >> (shift + 3)) % 200) / 100 - 1,
    );
    Widget blob(Color color, Alignment a, double r) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: a,
            radius: r,
            colors: [color.withValues(alpha: .85), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF07070A)),
        blob(c[2], at(1), 1.3),
        blob(c[0], at(4), .9),
        blob(c[1], at(7), .8),
        // A faint scanline texture keeps the gradient from looking flat.
        const Positioned.fill(child: CustomPaint(painter: _LinesPainter())),
      ],
    );
  }
}

class _LinesPainter extends CustomPainter {
  const _LinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: .18);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.engine, required this.effect});
  final Engine engine;
  final EffectInfo effect;

  @override
  Widget build(BuildContext context) {
    final saved = engine.effectSettings(effect);
    return SizedBox(
      width: 340,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('EM EXECUÇÃO', style: OcText.overline),
              ),
              OcBadge(effectCategory(effect)),
            ],
          ),
          const SizedBox(height: 10),
          Text(effect.title, style: OcText.title),
          if (effect.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(displayText(effect.description), style: OcText.secondary),
          ],
          const SizedBox(height: 24),
          SectionLabel(
            'Ajustes',
            trailing: effect.properties.isEmpty
                ? null
                : OcButton(
                    label: 'Restaurar',
                    icon: Icons.restart_alt_rounded,
                    variant: OcButtonVariant.ghost,
                    onPressed: () {
                      for (final prop in effect.properties) {
                        engine.setEffectProperty(
                          effect,
                          prop.name,
                          prop.coerce(null),
                        );
                      }
                    },
                  ),
          ),
          if (effect.properties.isEmpty)
            const OcPanel(
              children: [
                OcRow(
                  title: 'Sem ajustes',
                  description: 'Este efeito não tem opções configuráveis.',
                ),
              ],
            )
          else
            OcPanel(
              children: [
                for (final prop in effect.properties)
                  PropertyControl(
                    label: prop.label,
                    type: prop.type,
                    tooltip: prop.tooltip,
                    min: prop.min,
                    max: prop.max,
                    values: prop.values,
                    value: prop.coerce(saved[prop.name]),
                    onChanged: (v) =>
                        engine.setEffectProperty(effect, prop.name, v),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
