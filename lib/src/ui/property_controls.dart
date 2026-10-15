import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'widgets.dart';

Color? parseHexColor(Object? v) {
  final s = v?.toString().replaceAll('#', '').trim() ?? '';
  if (s.length < 6) return null;
  final n = int.tryParse(s.substring(0, 6), radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

String toHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Third-party plugin/effect text can name the app it was written for; show
/// ours instead.
String displayText(String s) => s
    .replaceAll(RegExp('signal ?rgb', caseSensitive: false), 'OpenChroma')
    .replaceAll(RegExp('whirlwind ?fx', caseSensitive: false), 'OpenChroma');

bool _truthy(Object? v) => v == true || v == 'true' || v == '1' || v == 1;

/// One effect `<meta>` / plugin parameter, rendered as a settings row.
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
    final description = tooltip.isEmpty ? null : displayText(tooltip);
    final label = displayText(this.label);
    switch (type) {
      case 'boolean':
        return OcRow(
          title: label,
          description: description,
          trailing: OcSwitch(value: _truthy(value), onChanged: onChanged),
        );
      case 'combobox':
        final current = values.contains('$value')
            ? '$value'
            : (values.isEmpty ? null : values.first);
        return OcRow(
          title: label,
          description: description,
          trailing: OcSelect(
            value: current,
            options: values,
            onChanged: onChanged,
            width: 168,
          ),
        );
      case 'color':
        return OcRow(
          title: label,
          description: description,
          trailing: ColorField(
            color: parseHexColor(value) ?? Colors.black,
            onChanged: (c) => onChanged(toHex(c)),
          ),
        );
      case 'number':
      case 'hue':
      case 'int':
      case 'float':
        final hue = type == 'hue';
        final lo = hue ? 0.0 : min;
        final hi = hue ? 360.0 : (max > lo ? max : lo + 1);
        final v = (num.tryParse('$value') ?? lo).toDouble();
        final integer = type != 'float' && (step == null || step! >= 1);
        return OcRow(
          title: label,
          description: description,
          stacked: true,
          trailing: OcSlider(
            value: v,
            min: lo,
            max: hi,
            integer: integer,
            suffix: hue ? '°' : '',
            activeColor: hue
                ? HSVColor.fromAHSV(1, v.clamp(0, 360) % 360, .8, 1).toColor()
                : null,
            onChanged: (n) => onChanged(integer ? n.round() : n),
          ),
        );
      default:
        return OcRow(
          title: label,
          description: description,
          stacked: true,
          trailing: TextFormField(
            key: ValueKey('$label=$value'),
            initialValue: '${value ?? ''}',
            style: const TextStyle(fontSize: 12.5, color: Oc.text),
            decoration: ocFieldDecoration(''),
            onFieldSubmitted: onChanged,
          ),
        );
    }
  }
}

/// Swatch + hex value; opens the picker on click.
class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) => Hover(
    onTap: () async {
      final picked = await showColorPicker(context, color);
      if (picked != null) onChanged(picked);
    },
    builder: (context, h) => AnimatedContainer(
      duration: Oc.fast,
      width: 120,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: h ? Oc.hover : Oc.raised,
        borderRadius: Oc.r6,
        border: Border.all(color: Oc.lineStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            toHex(color).toUpperCase(),
            style: const TextStyle(
              fontFamily: Oc.mono,
              fontSize: 12,
              color: Oc.text,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<Color?> showColorPicker(BuildContext context, Color initial) =>
    showDialog<Color>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ColorPickerDialog(initial: initial),
    );

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor hsv = HSVColor.fromColor(widget.initial);
  late final hex = TextEditingController(
    text: toHex(widget.initial).substring(1).toUpperCase(),
  );

  static const presets = [
    Color(0xFFFFFFFF),
    Color(0xFFFF2D2D),
    Color(0xFFFF7A1A),
    Color(0xFFFFD60A),
    Color(0xFF32D74B),
    Color(0xFF00C7BE),
    Color(0xFF0A84FF),
    Color(0xFF5E5CE6),
    Color(0xFFBF5AF2),
    Color(0xFFFF375F),
    Color(0xFF000000),
  ];

  void _set(HSVColor c) {
    setState(() => hsv = c);
    hex.text = toHex(c.toColor()).substring(1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = hsv.toColor();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Cor', style: OcText.label),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  const h = 168.0;
                  void pick(Offset o) => _set(
                    hsv
                        .withSaturation((o.dx / box.maxWidth).clamp(0, 1))
                        .withValue(1 - (o.dy / h).clamp(0, 1)),
                  );
                  return MouseRegion(
                    cursor: SystemMouseCursors.precise,
                    child: GestureDetector(
                      onPanDown: (d) => pick(d.localPosition),
                      onPanUpdate: (d) => pick(d.localPosition),
                      child: ClipRRect(
                        borderRadius: Oc.r8,
                        child: SizedBox(
                          height: h,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white,
                                        HSVColor.fromAHSV(
                                          1,
                                          hsv.hue,
                                          1,
                                          1,
                                        ).toColor(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: hsv.saturation * box.maxWidth - 8,
                                top: (1 - hsv.value) * h - 8,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _HueBar(hue: hsv.hue, onChanged: (v) => _set(hsv.withHue(v))),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in presets)
                    Hover(
                      onTap: () => _set(HSVColor.fromColor(c)),
                      builder: (context, h) => Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(5),
                          ),
                          border: Border.all(
                            color: h
                                ? Colors.white70
                                : Colors.white.withValues(alpha: .12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: Oc.r6,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: TextField(
                        controller: hex,
                        style: const TextStyle(
                          fontFamily: Oc.mono,
                          fontSize: 12.5,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[0-9a-fA-F]'),
                          ),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: ocFieldDecoration(
                          '',
                        ).copyWith(prefixText: '#', prefixStyle: OcText.mono),
                        onChanged: (s) {
                          final c = parseHexColor(s);
                          if (c != null) {
                            setState(() => hsv = HSVColor.fromColor(c));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OcButton(
                    label: 'Cancelar',
                    variant: OcButtonVariant.ghost,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  OcButton(
                    label: 'Aplicar',
                    variant: OcButtonVariant.primary,
                    onPressed: () => Navigator.pop(context, color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});
  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      void pick(double x) => onChanged((x / box.maxWidth).clamp(0, 1) * 359.9);
      return GestureDetector(
        onPanDown: (d) => pick(d.localPosition.dx),
        onPanUpdate: (d) => pick(d.localPosition.dx),
        child: SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      colors: [
                        for (var h = 0; h <= 360; h += 60)
                          HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: hue / 360 * box.maxWidth - 7,
                top: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
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
  );
}
