import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Rebuilds [builder] with the current hover state.
class Hover extends StatefulWidget {
  const Hover({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : widget.cursor,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: widget.builder(context, _hover),
    ),
  );
}

enum OcButtonVariant { primary, secondary, ghost, danger }

class OcButton extends StatelessWidget {
  const OcButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = OcButtonVariant.secondary,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final OcButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Hover(
      onTap: onPressed,
      builder: (context, h) {
        late Color bg, fg, border;
        switch (variant) {
          case OcButtonVariant.primary:
            bg = h ? Colors.white : Oc.text;
            fg = Oc.bg;
            border = Colors.transparent;
          case OcButtonVariant.secondary:
            bg = h ? Oc.hover : Oc.raised;
            fg = Oc.text;
            border = Oc.lineStrong;
          case OcButtonVariant.ghost:
            bg = h ? Oc.hover : Colors.transparent;
            fg = Oc.textSecondary;
            border = Colors.transparent;
          case OcButtonVariant.danger:
            bg = h ? Oc.danger.withValues(alpha: .16) : Oc.raised;
            fg = Oc.danger;
            border = Oc.lineStrong;
        }
        return Opacity(
          opacity: enabled ? 1 : .4,
          child: AnimatedContainer(
            duration: Oc.fast,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: Oc.r6,
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OcIconButton extends StatelessWidget {
  const OcIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 30,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Hover(
      onTap: onPressed,
      builder: (context, h) => AnimatedContainer(
        duration: Oc.fast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: h ? Oc.hover : Colors.transparent,
          borderRadius: Oc.r6,
        ),
        child: Icon(icon, size: 17, color: h ? Oc.text : Oc.textSecondary),
      ),
    ),
  );
}

/// Bordered group whose children are separated by hairlines.
class OcPanel extends StatelessWidget {
  const OcPanel({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Oc.panel,
      borderRadius: Oc.r10,
      border: Border.all(color: Oc.line),
    ),
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(),
          children[i],
        ],
      ],
    ),
  );
}

/// A settings row: title and optional description on the left, control on
/// the right, or the control below when [stacked].
class OcRow extends StatelessWidget {
  const OcRow({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.stacked = false,
    this.leading,
  });
  final String title;
  final String? description;
  final Widget? trailing;
  final Widget? leading;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: OcText.label),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(description!, style: OcText.secondary),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 10), ?trailing],
            )
          : Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(child: text),
                if (trailing != null) ...[const SizedBox(width: 16), trailing!],
              ],
            ),
    );
  }
}

class OcSwitch extends StatelessWidget {
  const OcSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Hover(
    onTap: onChanged == null ? null : () => onChanged!(!value),
    builder: (context, h) => AnimatedContainer(
      duration: Oc.fast,
      width: 34,
      height: 20,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? Oc.text : (h ? Oc.pressed : Oc.hover),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? Oc.text : Oc.lineStrong),
      ),
      child: AnimatedAlign(
        duration: Oc.fast,
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: value ? Oc.bg : Oc.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

class OcSlider extends StatelessWidget {
  const OcSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.integer = true,
    this.suffix = '',
    this.activeColor,
  });
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool integer;
  final String suffix;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max).toDouble();
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(
              context,
            ).copyWith(activeTrackColor: activeColor, thumbColor: activeColor),
            child: Slider(value: v, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            '${integer ? v.round() : v.toStringAsFixed(2)}$suffix',
            textAlign: TextAlign.right,
            style: OcText.mono,
          ),
        ),
      ],
    );
  }
}

/// A dropdown that looks like a field.
class OcSelect extends StatelessWidget {
  const OcSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 200,
  });
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '',
    position: PopupMenuPosition.under,
    constraints: BoxConstraints(minWidth: width, maxWidth: width + 80),
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final o in options)
        PopupMenuItem(
          value: o,
          height: 34,
          child: Row(
            children: [
              Expanded(child: Text(o, overflow: TextOverflow.ellipsis)),
              if (o == value) const Icon(Icons.check, size: 15, color: Oc.text),
            ],
          ),
        ),
    ],
    child: Hover(
      builder: (context, h) => AnimatedContainer(
        duration: Oc.fast,
        width: width,
        height: 30,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: h ? Oc.hover : Oc.raised,
          borderRadius: Oc.r6,
          border: Border.all(color: Oc.lineStrong),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: Oc.text),
              ),
            ),
            const Icon(Icons.unfold_more, size: 15, color: Oc.textTertiary),
          ],
        ),
      ),
    ),
  );
}

class OcSegmented<T> extends StatelessWidget {
  const OcSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: Oc.panel,
      borderRadius: Oc.r8,
      border: Border.all(color: Oc.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (v, label) in options)
          Hover(
            onTap: () => onChanged(v),
            builder: (context, h) => AnimatedContainer(
              duration: Oc.fast,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: v == value ? Oc.hover : Colors.transparent,
                borderRadius: Oc.r6,
                border: Border.all(
                  color: v == value ? Oc.lineStrong : Colors.transparent,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: v == value || h ? Oc.text : Oc.textSecondary,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class OcStatusDot extends StatelessWidget {
  const OcStatusDot({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .45), blurRadius: 6),
      ],
    ),
  );
}

class OcBadge extends StatelessWidget {
  const OcBadge(
    this.text, {
    super.key,
    this.color = Oc.textSecondary,
    this.dot,
  });
  final String text;
  final Color color;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Oc.raised,
      borderRadius: Oc.r6,
      border: Border.all(color: Oc.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != null) ...[
          OcStatusDot(color: dot!, size: 6),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class OcSearchField extends StatelessWidget {
  const OcSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Buscar',
  });
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 30,
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12.5, color: Oc.text),
      decoration: _fieldDecoration(hint).copyWith(
        prefixIcon: const Icon(Icons.search, size: 16, color: Oc.textTertiary),
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
      ),
    ),
  );
}

/// A compact numeric field that commits on Enter or focus loss.
class OcNumberField extends StatefulWidget {
  const OcNumberField({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.suffix,
    this.width = 96,
  });
  final int value;
  final ValueChanged<int> onSubmitted;
  final String? suffix;
  final double width;

  @override
  State<OcNumberField> createState() => _OcNumberFieldState();
}

class _OcNumberFieldState extends State<OcNumberField> {
  late final _c = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(OcNumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _c.text = '${widget.value}';
    }
  }

  void _commit() {
    final v = int.tryParse(_c.text);
    if (v != null && v != widget.value) widget.onSubmitted(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: 30,
    child: TextField(
      controller: _c,
      focusNode: _focus,
      textAlign: TextAlign.right,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontFamily: Oc.mono,
        fontSize: 12.5,
        color: Oc.text,
      ),
      onSubmitted: (_) => _commit(),
      decoration: _fieldDecoration('')
          .copyWith(suffixText: widget.suffix, suffixStyle: OcText.caption),
    ),
  );
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 12.5, color: Oc.textTertiary),
  isDense: true,
  filled: true,
  fillColor: Oc.raised,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  enabledBorder: const OutlineInputBorder(
    borderRadius: Oc.r6,
    borderSide: BorderSide(color: Oc.lineStrong),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: Oc.r6,
    borderSide: BorderSide(color: Oc.textSecondary),
  ),
);

InputDecoration ocFieldDecoration(String hint) => _fieldDecoration(hint);

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: OcText.pageTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: OcText.secondary),
              ],
            ],
          ),
        ),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ],
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10, top: 4),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: OcText.overline)),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Oc.raised,
              borderRadius: Oc.r10,
              border: Border.all(color: Oc.line),
            ),
            child: Icon(icon, size: 20, color: Oc.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(title, style: OcText.label),
          const SizedBox(height: 6),
          Text(message, style: OcText.secondary, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
