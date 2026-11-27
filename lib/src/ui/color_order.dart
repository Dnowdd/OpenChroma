import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../i18n/l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Color orders an ARGB header can be set to.
const colorOrders = ['RGB', 'RBG', 'GRB', 'GBR', 'BRG', 'BGR'];

/// The order that fixes what was seen: with the header set to [current],
/// pure red showed as [red] and pure green as [green] ('R', 'G' or 'B').
/// Returns the candidates to try, most likely first (they differ only when
/// three channels are rotated), or an empty list when the answers do not
/// make sense.
List<String> fixColorOrder(String current, String red, String green) {
  if (!colorOrders.contains(current) || red == green) return const [];
  final blue = 'RGB'.split('').firstWhere((c) => c != red && c != green);
  final seen = {'R': red, 'G': green, 'B': blue};
  final inverse = {for (final e in seen.entries) e.value: e.key};
  final a = current.split('').map((c) => seen[c]!).join();
  final b = current.split('').map((c) => inverse[c]!).join();
  return {a, b}.toList();
}

/// Finds an ARGB header's color order with two questions: the header is lit
/// red, then green, and the user says what they see.
Future<void> showColorOrderAssistant(
  BuildContext context, {
  required Engine engine,
  required DeviceInstance device,
  required int zone,
  required String configKey,
  required String header,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _Assistant(
    engine: engine,
    device: device,
    zone: zone,
    configKey: configKey,
    header: header,
  ),
);

class _Assistant extends StatefulWidget {
  const _Assistant({
    required this.engine,
    required this.device,
    required this.zone,
    required this.configKey,
    required this.header,
  });
  final Engine engine;
  final DeviceInstance device;
  final int zone;
  final String configKey;
  final String header;

  @override
  State<_Assistant> createState() => _AssistantState();
}

enum _Step { red, green, confirm, done, failed }

class _AssistantState extends State<_Assistant> {
  _Step _step = _Step.red;
  String? _red;
  List<String> _candidates = const [];
  int _tried = 0;
  String _message = '';

  Engine get _e => widget.engine;

  @override
  void initState() {
    super.initState();
    // A header switched off (or unreadable) gets a known order to test from.
    if (!colorOrders.contains(_current)) _apply('RGB');
    _show(255, 0, 0);
  }

  @override
  void dispose() {
    _e.setTestColor(widget.device, null);
    super.dispose();
  }

  String get _current =>
      '${_e.driverConfigValue(widget.device, widget.configKey)}';

  void _show(int r, int g, int b) =>
      _e.setTestColor(widget.device, widget.zone, r, g, b);

  void _apply(String order) => _e.setDriverConfig(widget.device, {
    widget.configKey: order,
    'calibration_enabled': true,
  });

  void _answer(String? seen) {
    if (seen == null) {
      setState(() {
        _step = _Step.failed;
        _message = l10n.colorOrderNothingLit(widget.header);
      });
      return;
    }
    switch (_step) {
      case _Step.red:
        _red = seen;
        _show(0, 255, 0);
        setState(() => _step = _Step.green);
      case _Step.green:
        if (_red == 'R' && seen == 'G') {
          _done(l10n.colorOrderAlreadyRight(_current));
          return;
        }
        _candidates = fixColorOrder(_current, _red!, seen);
        if (_candidates.isEmpty) {
          setState(() {
            _step = _Step.failed;
            _message = l10n.colorOrderSameColors;
          });
          return;
        }
        _tryNext();
      default:
        break;
    }
  }

  void _tryNext() {
    if (_tried >= _candidates.length) {
      setState(() {
        _step = _Step.failed;
        _message = l10n.colorOrderCouldNotFix;
      });
      return;
    }
    _apply(_candidates[_tried++]);
    _show(0, 0, 255);
    setState(() => _step = _Step.confirm);
  }

  void _done(String text) => setState(() {
    _step = _Step.done;
    _message = text;
  });

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (_step) {
      _Step.red || _Step.green => (
        l10n.colorOrderTitle(widget.header),
        l10n.colorOrderQuestion,
      ),
      _Step.confirm => (
        l10n.colorOrderBlueTitle,
        l10n.colorOrderTesting(_candidates[_tried - 1]),
      ),
      _Step.done => (l10n.colorOrderDoneTitle, _message),
      _Step.failed => (l10n.colorOrderFailedTitle, _message),
    };
    Widget swatch(String label, String value, Color color) => OcButton(
      label: label,
      icon: Icons.circle,
      onPressed: () => _answer(value),
      iconColor: color,
    );
    return AlertDialog(
      title: Text(title, style: OcText.title),
      content: SizedBox(width: 380, child: Text(body, style: OcText.body)),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: switch (_step) {
        _Step.red || _Step.green => [
          OcButton(
            label: l10n.colorOrderNothingLitButton,
            onPressed: () => _answer(null),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              swatch(l10n.colorOrderRed, 'R', const Color(0xFFEF4444)),
              const SizedBox(width: 6),
              swatch(l10n.colorOrderGreen, 'G', const Color(0xFF22C55E)),
              const SizedBox(width: 6),
              swatch(l10n.colorOrderBlue, 'B', const Color(0xFF3B82F6)),
            ],
          ),
        ],
        _Step.confirm => [
          OcButton(label: l10n.colorOrderNo, onPressed: _tryNext),
          OcButton(
            label: l10n.colorOrderYes,
            variant: OcButtonVariant.primary,
            onPressed: () => _done(
              l10n.colorOrderSaved(_candidates[_tried - 1], widget.header),
            ),
          ),
        ],
        _ => [
          const SizedBox.shrink(),
          OcButton(
            label: l10n.colorOrderClose,
            variant: OcButtonVariant.primary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      },
    );
  }
}
