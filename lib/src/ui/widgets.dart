import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accent.dart';
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
    final accent = LiveAccent.of(context);
    return Hover(
      onTap: onPressed,
      builder: (context, h) {
        late Color bg, fg, border;
        switch (variant) {
          case OcButtonVariant.primary:
            bg = h ? Color.lerp(accent, Colors.white, .2)! : accent;
            fg = onAccent(accent);
            border = Colors.transparent;
          case OcButtonVariant.secondary:
            bg = h ? Oc.pressed : Oc.hover;
            fg = Oc.text;
            border = Colors.transparent;
          case OcButtonVariant.ghost:
            bg = h ? Oc.hover : Colors.transparent;
            fg = Oc.textSecondary;
            border = Colors.transparent;
          case OcButtonVariant.danger:
            bg = Oc.danger.withValues(alpha: h ? .2 : .1);
            fg = Oc.danger;
            border = Colors.transparent;
        }
        return Opacity(
          opacity: enabled ? 1 : .4,
          child: AnimatedContainer(
            duration: Oc.fast,
            height: Oc.control,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: Oc.pill,
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
                    fontWeight: FontWeight.w600,
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
    this.size = 34,
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
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: h ? Oc.text : Oc.textSecondary),
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
      borderRadius: Oc.r12,
      border: Border.all(color: Oc.line),
    ),
    clipBehavior: Clip.antiAlias,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    return Opacity(
      opacity: onChanged == null ? .45 : 1,
      child: Hover(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        builder: (context, h) => AnimatedContainer(
          duration: Oc.smooth,
          curve: Curves.easeOutCubic,
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? accent : (h ? Oc.pressed : Oc.hover),
            borderRadius: Oc.pill,
          ),
          child: AnimatedAlign(
            duration: Oc.smooth,
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: value ? onAccent(accent) : Oc.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor ?? LiveAccent.of(context),
              thumbColor: activeColor ?? LiveAccent.of(context),
            ),
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
    this.labelOf,
  });
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final double width;

  /// Display text for an option; the option itself is what [onChanged] gets.
  final String Function(String option)? labelOf;

  String _label(String o) => labelOf?.call(o) ?? o;

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
              Expanded(child: Text(_label(o), overflow: TextOverflow.ellipsis)),
              if (o == value) const Icon(Icons.check, size: 15, color: Oc.text),
            ],
          ),
        ),
    ],
    child: Hover(
      builder: (context, h) => AnimatedContainer(
        duration: Oc.fast,
        width: width,
        height: Oc.control,
        padding: const EdgeInsets.only(left: 14, right: 10),
        decoration: BoxDecoration(
          color: h ? Oc.pressed : Oc.hover,
          borderRadius: Oc.pill,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? '' : _label(value!),
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
    height: Oc.control,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Oc.panel,
      borderRadius: Oc.pill,
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: v == value ? Oc.pressed : Colors.transparent,
                borderRadius: Oc.pill,
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
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(color: Oc.raised, borderRadius: Oc.pill),
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
    height: Oc.control,
    child: TextField(
      onChanged: onChanged,
      // Fill the control height like the buttons next to it.
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.center,
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
  fillColor: Oc.hover,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
  enabledBorder: const OutlineInputBorder(
    borderRadius: Oc.pill,
    borderSide: BorderSide(color: Colors.transparent),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: Oc.pill,
    borderSide: BorderSide(color: Oc.lineStrong),
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
    padding: Oc.headerInsets,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: OcText.pageTitle.copyWith(fontSize: 28)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: OcText.secondary.copyWith(fontSize: 13.5),
                ),
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
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Oc.raised,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: Oc.textSecondary),
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

/// The redesign's surface: a large rounded card. With [onTap] it lifts its
/// border on hover.
class OcCard extends StatelessWidget {
  const OcCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(22),
    this.color,
    this.borderColor,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  /// Overrides the hairline border, e.g. to mark a selected card.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Hover(
    onTap: onTap,
    builder: (context, h) => AnimatedContainer(
      duration: Oc.smooth,
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (h && onTap != null ? Oc.raised : Oc.panel),
        borderRadius: Oc.r24,
        border: Border.all(
          color: borderColor ?? (h && onTap != null ? Oc.lineStrong : Oc.line),
        ),
      ),
      child: child,
    ),
  );
}

/// Card heading: title on the left, optional controls on the right.
class OcCardTitle extends StatelessWidget {
  const OcCardTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: OcText.title.copyWith(fontSize: 16),
        ),
      ),
      ?trailing,
    ],
  );
}

/// A tiny tag such as "Em breve".
class OcTag extends StatelessWidget {
  const OcTag(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: const BoxDecoration(color: Oc.raised, borderRadius: Oc.pill),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Oc.textSecondary,
      ),
    ),
  );
}

/// An iOS-style settings icon: a white glyph on a small colored square.
class OcIconTile extends StatelessWidget {
  const OcIconTile(this.icon, {super.key, required this.color, this.size = 30});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(icon, size: size * .58, color: Colors.white),
  );
}

/// An [IndexedStack] that also pauses the animations (tickers and the
/// decor clock) of the children it hides; the plain one keeps them running
/// and asking for frames.
class PageStack extends StatelessWidget {
  const PageStack({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: index,
    children: [
      for (var i = 0; i < children.length; i++)
        TickerMode(enabled: i == index, child: children[i]),
    ],
  );
}
