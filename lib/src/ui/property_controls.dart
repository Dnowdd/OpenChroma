import 'package:flutter/material.dart';

import 'theme.dart';

Color? parseHexColor(Object? v) {
  final s = v?.toString().replaceAll('#', '') ?? '';
  if (s.length < 6) return null;
  final n = int.tryParse(s.substring(0, 6), radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

String toHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

bool _truthy(Object? v) => v == true || v == 'true' || v == '1' || v == 1;

/// Renders one SignalRGB-style control (effect `<meta>` or plugin
/// ControllableParameters entry) and reports edits through [onChanged].
class PropertyControl extends StatelessWidget {
  const PropertyControl({
    super.key,
    required this.label,
    required this.type,
    required this.value,
    required this.onChanged,
    this.tooltip = '',
    this.min = 0,
    this.max = 100,
    this.step,
    this.values = const [],
  });

  final String label;
  final String type;
  final Object? value;
  final ValueChanged<Object> onChanged;
  final String tooltip;
  final double min;
  final double max;
  final double? step;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: OcColors.text),
          ),
        ),
        if (tooltip.isNotEmpty) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltip,
            child: const Icon(
              Icons.info_outline,
              size: 14,
              color: OcColors.textMuted,
            ),
          ),
        ],
      ],
    );

    Widget control;
    switch (type) {
      case 'boolean':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: title),
              Switch(value: _truthy(value), onChanged: (v) => onChanged(v)),
            ],
          ),
        );
      case 'number':
      case 'hue':
      case 'int':
      case 'float':
        final lo = type == 'hue' ? 0.0 : min;
        final hi = type == 'hue' ? 360.0 : (max > lo ? max : lo + 1);
        final v = (num.tryParse('$value') ?? lo).toDouble().clamp(lo, hi);
        final isInt = type != 'float' && (step == null || step! >= 1);
        control = Row(
          children: [
            Expanded(
              child: Slider(
                value: v,
                min: lo,
                max: hi,
                divisions: isInt && hi - lo <= 1000 ? (hi - lo).round() : null,
                activeColor: type == 'hue'
                    ? HSVColor.fromAHSV(1, v % 360, 1, 1).toColor()
                    : null,
                onChanged: (n) => onChanged(isInt ? n.round() : n),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                isInt ? v.round().toString() : v.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: OcColors.textMuted),
              ),
            ),
          ],
        );
      case 'combobox':
        final current = values.contains('$value')
            ? '$value'
            : (values.isEmpty ? null : values.first);
        control = DropdownButtonFormField<String>(
          key: ValueKey('$label=$current'),
          initialValue: current,
          isExpanded: true,
          dropdownColor: OcColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          style: const TextStyle(fontSize: 13, color: OcColors.text),
          items: [
            for (final o in values)
              DropdownMenuItem(
                value: o,
                child: Text(o, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (o) => o == null ? null : onChanged(o),
        );
      case 'color':
        final c = parseHexColor(value) ?? Colors.black;
        control = InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showColorPicker(context, c);
            if (picked != null) onChanged(toHex(picked));
          },
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: OcColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  toHex(c).toUpperCase(),
                  style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
                ),
              ],
            ),
          ),
        );
      default:
        control = TextFormField(
          key: ValueKey('$label=$value'),
          initialValue: '${value ?? ''}',
          style: const TextStyle(fontSize: 13),
          onFieldSubmitted: (s) => onChanged(s),
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 6), control],
      ),
    );
  }
}

/// A compact HSV color picker dialog.
Future<Color?> showColorPicker(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final hex = TextEditingController(
    text: toHex(widget.initial).toUpperCase(),
  );

  static const presets = [
    Color(0xFFFF0000),
    Color(0xFFFF7A00),
    Color(0xFFFFE600),
    Color(0xFF00FF44),
    Color(0xFF00E5FF),
    Color(0xFF0057FF),
    Color(0xFF8B00FF),
    Color(0xFFFF00C8),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  void _set(HSVColor c) {
    setState(() => hsv = c);
    hex.text = toHex(c.toColor()).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = hsv.toColor();
    return AlertDialog(
      backgroundColor: OcColors.surface,
      title: const Text('Cor', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                const h = 160.0;
                void pick(Offset o) => _set(
                  hsv
                      .withSaturation((o.dx / box.maxWidth).clamp(0, 1))
                      .withValue(1 - (o.dy / h).clamp(0, 1)),
                );
                return GestureDetector(
                  onPanDown: (d) => pick(d.localPosition),
                  onPanUpdate: (d) => pick(d.localPosition),
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                        ],
                      ),
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: hsv.saturation * box.maxWidth - 7,
                          top: (1 - hsv.value) * h - 7,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
              ),
              child: Slider(
                value: hsv.hue,
                min: 0,
                max: 360,
                onChanged: (v) => _set(hsv.withHue(v)),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in presets)
                  InkWell(
                    onTap: () => _set(HSVColor.fromColor(c)),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: hex,
                    style: const TextStyle(fontFamily: 'Consolas'),
                    onSubmitted: (s) {
                      final c = parseHexColor(s);
                      if (c != null) {
                        setState(() => hsv = HSVColor.fromColor(c));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
