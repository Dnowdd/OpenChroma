import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../effects/effect_library.dart';
import '../engine/engine.dart';
import 'accent.dart';
import 'property_controls.dart';
import 'theme.dart';
import 'widgets.dart';

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
    final list =
        engine.effects.where((e) {
            if (_query.isNotEmpty &&
                !e.title.toLowerCase().contains(_query.toLowerCase())) {
              return false;
            }
            return switch (_filter) {
              'favorites' => engine.isFavorite(e),
              'imported' => e.imported,
              'audio' => e.usesAudio,
              _ => true,
            };
          }).toList()
          // Favorites first, then alphabetical (the library is already sorted).
          ..sort(
            (a, b) =>
                (engine.isFavorite(b) ? 1 : 0) - (engine.isFavorite(a) ? 1 : 0),
          );
    final current = engine.currentEffect;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 20, 20),
                child: Row(
                  children: [
                    OcSegmented<String>(
                      value: _filter,
                      options: const [
                        ('all', 'Todos'),
                        ('favorites', 'Favoritos'),
                        ('audio', 'Com som'),
                        ('imported', 'Importados'),
                      ],
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 260,
                      child: OcSearchField(
                        hint: 'Buscar efeitos',
                        onChanged: (s) => setState(() => _query = s),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OcButton(
                      label: 'Importar',
                      icon: Icons.add_rounded,
                      variant: OcButtonVariant.primary,
                      onPressed: () => showImportDialog(context, engine),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? _empty(context)
                    : LayoutBuilder(
                        builder: (context, box) {
                          // Size cells so the cover is exactly 16:10 (the
                          // effect canvas ratio) with the title below it.
                          const gap = 18.0, minWidth = 220.0;
                          final inner = box.maxWidth - 16 - 20;
                          final cols = ((inner + gap) / (minWidth + gap))
                              .floor()
                              .clamp(1, 8);
                          final cell = (inner - gap * (cols - 1)) / cols;
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 20, 32),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 22,
                                  crossAxisSpacing: gap,
                                  mainAxisExtent: cell / 1.6 + 32,
                                ),
                            itemCount: list.length,
                            itemBuilder: (_, i) => _EffectCard(
                              effect: list[i],
                              thumbnail: engine.thumbnailFor(list[i]),
                              selected: current?.path == list[i].path,
                              favorite: engine.isFavorite(list[i]),
                              onTap: () => engine.selectEffect(list[i]),
                              onFavorite: () => engine.toggleFavorite(list[i]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 20, 24),
            child: _Inspector(engine: engine, effect: current),
          ),
      ],
    );
  }

  Widget _empty(BuildContext context) => switch (_filter) {
    'favorites' when _query.isEmpty => const EmptyState(
      icon: Icons.star_outline_rounded,
      title: 'Nenhum favorito ainda',
      message: 'Passe o mouse sobre um efeito e clique na estrela para guardá-lo aqui.',
    ),
    'imported' when _query.isEmpty => EmptyState(
      icon: Icons.file_upload_outlined,
      title: 'Nenhum efeito importado',
      message: 'Crie um efeito em .ocfx ou traga um arquivo .html.',
      action: OcButton(
        label: 'Importar efeito',
        icon: Icons.add_rounded,
        onPressed: () => showImportDialog(context, widget.engine),
      ),
    ),
    _ => const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Nada encontrado',
      message: 'Tente outro termo de busca.',
    ),
  };
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.effect,
    required this.thumbnail,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });
  final EffectInfo effect;
  final String? thumbnail;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => Hover(
    onTap: onTap,
    builder: (context, h) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.6,
          child: ClipRRect(
            borderRadius: Oc.r12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  scale: h ? 1.04 : 1,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: thumbnail != null
                        ? Image.file(
                            File(thumbnail!),
                            key: ValueKey(thumbnail),
                            fit: BoxFit.cover,
                            cacheWidth: 640,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) =>
                                EffectArtwork(seed: effect.title),
                          )
                        : EffectArtwork(
                            key: const ValueKey('art'),
                            seed: effect.title,
                          ),
                  ),
                ),
                // Selection and hover ring drawn over the cover, so the cover
                // always fills the card edge to edge.
                AnimatedContainer(
                  duration: Oc.fast,
                  decoration: BoxDecoration(
                    borderRadius: Oc.r12,
                    border: Border.all(
                      color: selected
                          ? LiveAccent.of(context)
                          : Colors.white.withValues(alpha: h ? .28 : .06),
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(top: 10, left: 10, child: _LiveChip()),
                if (h || favorite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _FavoriteButton(active: favorite, onTap: onFavorite),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
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
              if (effect.usesAudio)
                const Tooltip(
                  message: 'Reage ao som',
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 15,
                    color: Oc.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: active ? 'Remover dos favoritos' : 'Favoritar',
    child: Hover(
      onTap: onTap,
      builder: (context, h) => AnimatedContainer(
        duration: Oc.fast,
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: h ? .75 : .5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Icon(
          active ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 17,
          color: active ? const Color(0xFFFFD25A) : Colors.white,
        ),
      ),
    ),
  );
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .5),
      borderRadius: Oc.pill,
      border: Border.all(color: Colors.white.withValues(alpha: .14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OcStatusDot(color: LiveAccent.of(context), size: 6),
        const SizedBox(width: 7),
        const Text(
          'Ao vivo',
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

/// Shown until an effect's real cover is rendered: a bright light field
/// whose palette is inferred from the effect name.
class EffectArtwork extends StatelessWidget {
  const EffectArtwork({super.key, required this.seed});
  final String seed;

  static const _palettes = <String, List<Color>>{
    'arctic|ice|frost|snow|indigo|sky': [
      Color(0xFF7DD3FC),
      Color(0xFF818CF8),
      Color(0xFF38BDF8),
    ],
    'water|ocean|oceano|calm|wave|aqua': [
      Color(0xFF2DD4BF),
      Color(0xFF38BDF8),
      Color(0xFF2563EB),
    ],
    'neon|storm|electric': [
      Color(0xFFF0ABFC),
      Color(0xFF22D3EE),
      Color(0xFF8B5CF6),
    ],
    'sunset|fire|brasa|lava|heat': [
      Color(0xFFFDBA74),
      Color(0xFFF43F5E),
      Color(0xFFF97316),
    ],
    'space|dark|matter|galaxy|star|cometa': [
      Color(0xFFA78BFA),
      Color(0xFF6366F1),
      Color(0xFF3B82F6),
    ],
    'aurora|vaga|firefl': [
      Color(0xFF6EE7B7),
      Color(0xFFA78BFA),
      Color(0xFF22D3EE),
    ],
    'rainbow|gradient|tunnel|rgb|spectrum': [
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
      HSVColor.fromAHSV(1, hue, .55, 1).toColor(),
      HSVColor.fromAHSV(1, (hue + 50) % 360, .6, .95).toColor(),
      HSVColor.fromAHSV(1, (hue + 200) % 360, .55, .85).toColor(),
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
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color.lerp(c[2], Colors.black, .55)!),
        blob(c[2], at(1), 1.4),
        blob(c[0], at(4), 1.0),
        blob(c[1], at(7), .9),
      ],
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.engine, required this.effect});
  final Engine engine;
  final EffectInfo effect;

  @override
  Widget build(BuildContext context) {
    final saved = engine.effectSettings(effect);
    final favorite = engine.isFavorite(effect);
    // Only show authors of our own and user-made effects.
    final showAuthor =
        effect.kind == EffectKind.ocfx && effect.author.isNotEmpty;
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Oc.panel,
        borderRadius: Oc.r24,
        border: Border.all(color: Oc.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          AspectRatio(
            aspectRatio: 1.6,
            child: ClipRRect(
              borderRadius: Oc.r12,
              child: LiveCanvas(engine: engine),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        effect.title,
                        style: OcText.title.copyWith(fontSize: 20),
                      ),
                    ),
                    OcIconButton(
                      icon: favorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      tooltip: favorite ? 'Remover dos favoritos' : 'Favoritar',
                      onPressed: () => engine.toggleFavorite(effect),
                    ),
                    if (effect.imported)
                      OcIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Remover efeito importado',
                        onPressed: () => _confirmRemove(context),
                      ),
                  ],
                ),
                if (showAuthor) ...[
                  const SizedBox(height: 2),
                  Text('por ${effect.author}', style: OcText.caption),
                ],
                if (effect.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    displayText(effect.description),
                    style: OcText.secondary,
                  ),
                ],
                const SizedBox(height: 28),
                if (effect.properties.isNotEmpty) ...[
                  SectionLabel(
                    'Ajustes',
                    trailing: OcButton(
                      label: 'Restaurar',
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
                  OcPanel(
                    children: [
                      for (final prop in effect.properties)
                        PropertyControl(
                          label: prop.label,
                          type: prop.type,
                          min: prop.min,
                          max: prop.max,
                          values: prop.values,
                          value: prop.coerce(saved[prop.name]),
                          onChanged: (v) =>
                              engine.setEffectProperty(effect, prop.name, v),
                        ),
                    ],
                  ),
                ] else
                  const Text(
                    'Este efeito não tem ajustes.',
                    style: OcText.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remover "${effect.title}"?', style: OcText.label),
                const SizedBox(height: 8),
                const Text(
                  'O efeito sai da biblioteca. O arquivo original que você importou não é apagado.',
                  style: OcText.secondary,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OcButton(
                      label: 'Cancelar',
                      variant: OcButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    OcButton(
                      label: 'Remover',
                      variant: OcButtonVariant.danger,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) engine.removeEffect(effect);
  }
}

// -------------------------------------------------------------------- import

const _effectTypes = XTypeGroup(
  label: 'Efeitos',
  extensions: ['ocfx', 'json', 'html'],
);

const ocfxTemplate = r'''{
  "openchroma": 1,
  "name": "Meu efeito",
  "description": "Uma frase curta sobre o efeito.",
  "author": "Seu nome",
  "background": "#05060A",
  "params": {
    "speed": { "label": "Velocidade", "type": "number", "min": 0, "max": 100, "default": 40 },
    "color": { "label": "Cor", "type": "color", "default": "#4C8DFF" }
  },
  "layers": [
    { "type": "gradient", "colors": ["#0B1E3D", "#24124D", "#0B1E3D"], "angle": 20, "speed": "$speed" },
    { "type": "wave", "color": "$color", "amplitude": 0.2, "frequency": 1.5, "thickness": 0.25, "speed": "$speed", "blend": "screen" }
  ]
}
''';

Future<void> showImportDialog(BuildContext context, Engine engine) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ImportDialog(engine: engine),
    );

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.engine});
  final Engine engine;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  String? _error;
  String? _saved;

  Future<void> _pick() async {
    final file = await openFile(acceptedTypeGroups: [_effectTypes]);
    if (file == null) return;
    try {
      widget.engine.importEffect(file.path);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Não foi possível importar: $e');
    }
  }

  Future<void> _saveTemplate() async {
    final loc = await getSaveLocation(
      suggestedName: 'meu-efeito.ocfx',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Efeito OpenChroma', extensions: ['ocfx']),
      ],
    );
    if (loc == null) return;
    File(loc.path).writeAsStringSync(ocfxTemplate);
    setState(() => _saved = loc.path);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 460,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Importar efeito', style: OcText.title),
            const SizedBox(height: 8),
            const Text(
              'Traga um efeito .ocfx, o formato do OpenChroma, ou uma página .html que '
              'desenhe num canvas de 320×200.',
              style: OcText.secondary,
            ),
            const SizedBox(height: 20),
            const OcPanel(
              children: [
                _FormatRow(
                  icon: Icons.layers_outlined,
                  title: 'Camadas',
                  text:
                      'gradient, spectrum, wave, pulse, sweep, rings, sparkle e solid, '
                      'empilhadas com blend normal, screen, add, multiply ou overlay.',
                ),
                _FormatRow(
                  icon: Icons.tune_rounded,
                  title: 'Parâmetros',
                  text:
                      r'Declare em "params" e use como "$name" em qualquer camada. '
                      'Eles viram controles no app.',
                ),
              ],
            ),
            if (_saved != null) ...[
              const SizedBox(height: 12),
              Text('Modelo salvo em $_saved', style: OcText.caption),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Oc.danger.withValues(alpha: .06),
                  borderRadius: Oc.r8,
                  border: Border.all(color: Oc.danger.withValues(alpha: .25)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12.5, color: Oc.danger),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                OcButton(
                  label: 'Salvar modelo',
                  icon: Icons.download_rounded,
                  variant: OcButtonVariant.ghost,
                  onPressed: _saveTemplate,
                ),
                const Spacer(),
                OcButton(
                  label: 'Cancelar',
                  variant: OcButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                OcButton(
                  label: 'Escolher arquivo',
                  variant: OcButtonVariant.primary,
                  onPressed: _pick,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => OcRow(
    leading: Icon(icon, size: 18, color: Oc.textSecondary),
    title: title,
    description: text,
  );
}
