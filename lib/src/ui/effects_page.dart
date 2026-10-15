import 'dart:io';

import 'package:flutter/material.dart';

import '../effects/effect_library.dart';
import '../engine/engine.dart';
import 'property_controls.dart';
import 'theme.dart';

class EffectsPage extends StatefulWidget {
  const EffectsPage({super.key, required this.engine});
  final Engine engine;

  @override
  State<EffectsPage> createState() => _EffectsPageState();
}

class _EffectsPageState extends State<EffectsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final list = engine.effects
        .where(
          (e) =>
              _query.isEmpty ||
              e.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Biblioteca de efeitos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${engine.effects.length}',
                      style: const TextStyle(color: OcColors.textMuted),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar efeito',
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                        onChanged: (s) => setState(() => _query = s),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.15,
                        ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _EffectCard(
                      effect: list[i],
                      selected: engine.currentEffect?.path == list[i].path,
                      onTap: () => engine.selectEffect(list[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (engine.currentEffect != null)
          _EffectPanel(engine: engine, effect: engine.currentEffect!),
      ],
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.effect,
    required this.selected,
    required this.onTap,
  });
  final EffectInfo effect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = effect.thumbnail;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: OcColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? OcColors.accent : OcColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumb != null
                  ? Image.file(File(thumb), fit: BoxFit.cover, cacheWidth: 480)
                  : _Placeholder(seed: effect.title),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effect.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      effect.publisher,
                      effect.source,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OcColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    final h = (seed.hashCode % 360).abs().toDouble();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HSVColor.fromAHSV(1, h, .8, .7).toColor(),
            HSVColor.fromAHSV(1, (h + 70) % 360, .8, .45).toColor(),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, color: Colors.white70, size: 32),
      ),
    );
  }
}

class _EffectPanel extends StatelessWidget {
  const _EffectPanel({required this.engine, required this.effect});
  final Engine engine;
  final EffectInfo effect;

  @override
  Widget build(BuildContext context) {
    final saved = engine.effectSettings(effect);
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: OcColors.sidebar,
        border: Border(left: BorderSide(color: OcColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'EFEITO ATIVO',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: OcColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            effect.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (effect.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              effect.description,
              style: const TextStyle(
                fontSize: 12.5,
                color: OcColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          if (effect.properties.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Este efeito não tem ajustes.',
                style: TextStyle(color: OcColors.textMuted),
              ),
            ),
          for (final prop in effect.properties)
            PropertyControl(
              label: prop.label,
              type: prop.type,
              tooltip: prop.tooltip,
              min: prop.min,
              max: prop.max,
              values: prop.values,
              value: prop.coerce(saved[prop.name]),
              onChanged: (v) => engine.setEffectProperty(effect, prop.name, v),
            ),
          if (effect.properties.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Restaurar padrões'),
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
          ],
        ],
      ),
    );
  }
}
