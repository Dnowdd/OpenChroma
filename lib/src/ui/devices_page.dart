import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../drivers/hardware_mode.dart';
import '../drivers/native_drivers.dart' show DriverZone;
import '../engine/engine.dart';
import '../i18n/l10n.dart';
import '../i18n/terms.dart';
import '../system/batteries.dart';
import 'color_order.dart';
import 'device_art.dart';
import 'plugin_approval.dart';
import 'property_controls.dart';
import 'screen_tab.dart';
import 'theme.dart';
import 'widgets.dart';

(Color, String) statusStyle(String status) => switch (status) {
  'running' => (Oc.success, l10n.devicesStatusConnected),
  'starting' => (Oc.warning, l10n.devicesStatusStarting),
  'error' => (Oc.danger, l10n.devicesStatusError),
  'disabled' => (Oc.textTertiary, l10n.devicesStatusDisabled),
  'unsupported' => (Oc.textTertiary, l10n.devicesStatusUnsupported),
  _ => (Oc.textTertiary, l10n.devicesStatusStopped),
};

String deviceKind(DeviceInstance d) => deviceKindOf(d.type, d.name).label;

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.engine, this.open});
  final Engine engine;

  /// A device to show, on its screen tab when it has one (set from other
  /// pages; cleared once shown).
  final ValueNotifier<String?>? open;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  String? _selected;
  String? _screenFor;

  @override
  void initState() {
    super.initState();
    widget.open?.addListener(_onOpen);
    _onOpen();
  }

  @override
  void dispose() {
    widget.open?.removeListener(_onOpen);
    super.dispose();
  }

  void _onOpen() {
    final key = widget.open?.value;
    if (key == null) return;
    widget.open!.value = null;
    setState(() => _selected = _screenFor = key);
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final devices = engine.devices.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final sel = engine.devices[_selected] ?? devices.firstOrNull;
    final running = devices.where((d) => d.status == 'running').length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: l10n.devicesTitle,
              subtitle: engine.scanning
                  ? l10n.devicesScanning
                  : l10n.devicesConnectedCount(running),
              actions: [
                OcButton(
                  label: l10n.devicesScan,
                  icon: Icons.refresh_rounded,
                  onPressed: engine.refreshDevices,
                ),
              ],
            ),
            PluginApprovalBanner(engine: engine),
            Expanded(
              child: Padding(
                padding: Oc.pageInsets,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (devices.isNotEmpty) ...[
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: Oc.panel,
                          borderRadius: Oc.r24,
                          border: Border.all(color: Oc.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView(
                          padding: const EdgeInsets.all(10),
                          children: [
                            for (final d in devices)
                              _DeviceTile(
                                engine: engine,
                                device: d,
                                selected: d.key == sel?.key,
                                onTap: () => setState(() {
                                  _selected = d.key;
                                  _screenFor = null;
                                }),
                              ),
                            if (engine.otherBatteries.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  18,
                                  10,
                                  6,
                                ),
                                child: SectionLabel(l10n.devicesOtherWireless),
                              ),
                              for (final b in engine.otherBatteries)
                                _BatteryTile(battery: b),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Oc.panel,
                          borderRadius: Oc.r24,
                          border: Border.all(color: Oc.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: sel != null
                            ? _DeviceDetail(
                                key: ValueKey(
                                  '${sel.key}|${_screenFor == sel.key}',
                                ),
                                engine: engine,
                                device: sel,
                                initialTab: _screenFor == sel.key
                                    ? 'screen'
                                    : 'lighting',
                              )
                            : EmptyState(
                                icon: Icons.usb_rounded,
                                title: engine.scanning
                                    ? l10n.devicesScanningTitle
                                    : !engine.drivers.available
                                    ? l10n.devicesDriversUnavailable
                                    : l10n.devicesNone,
                                message: engine.scanning
                                    ? (engine.detectionStep.isEmpty
                                          ? l10n.devicesScanTakesSeconds
                                          : '${engine.detectionPercent}% · ${engine.detectionStep}')
                                    : !engine.drivers.available
                                    ? l10n.devicesDriversMissing
                                    : l10n.devicesNoneHint,
                                action: engine.scanning
                                    ? null
                                    : OcButton(
                                        label: l10n.devicesScanAgain,
                                        icon: Icons.refresh_rounded,
                                        onPressed: engine.refreshDevices,
                                      ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.engine,
    required this.device,
    required this.selected,
    required this.onTap,
  });
  final Engine engine;
  final DeviceInstance device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, label) = statusStyle(device.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Hover(
        onTap: onTap,
        builder: (context, h) => AnimatedContainer(
          duration: Oc.fast,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? Oc.hover : (h ? Oc.raised : Colors.transparent),
            borderRadius: Oc.r12,
          ),
          child: Row(
            children: [
              DeviceArt(engine: engine, device: device, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OcText.label,
                          ),
                        ),
                        if (device.battery case final level?) ...[
                          const SizedBox(width: 8),
                          BatteryLevel(level, charging: device.charging),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        OcStatusDot(color: color, size: 6),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${deviceKind(device)} · $label',
                            overflow: TextOverflow.ellipsis,
                            style: OcText.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small battery icon and percentage, red when low.
class BatteryLevel extends StatelessWidget {
  const BatteryLevel(this.level, {super.key, this.charging = false});
  final int level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final low = level <= 15 && !charging;
    final color = low ? Oc.danger : Oc.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          charging
              ? Icons.battery_charging_full_rounded
              : switch (level) {
                  <= 15 => Icons.battery_1_bar_rounded,
                  <= 50 => Icons.battery_3_bar_rounded,
                  <= 85 => Icons.battery_5_bar_rounded,
                  _ => Icons.battery_full_rounded,
                },
          size: 15,
          color: color,
        ),
        const SizedBox(width: 2),
        Text('$level%', style: OcText.caption.copyWith(color: color)),
      ],
    );
  }
}

/// A device without lighting whose charge Windows reports.
class _BatteryTile extends StatelessWidget {
  const _BatteryTile({required this.battery});
  final WirelessBattery battery;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            battery.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OcText.body,
          ),
        ),
        const SizedBox(width: 8),
        BatteryLevel(battery.level),
      ],
    ),
  );
}

class _DeviceDetail extends StatefulWidget {
  const _DeviceDetail({
    super.key,
    required this.engine,
    required this.device,
    this.initialTab = 'lighting',
  });
  final String initialTab;
  final Engine engine;
  final DeviceInstance device;

  @override
  State<_DeviceDetail> createState() => _DeviceDetailState();
}

class _DeviceDetailState extends State<_DeviceDetail> {
  late String _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final d = widget.device;
    final (color, label) = statusStyle(d.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Row(
          children: [
            DeviceArt(engine: engine, device: d, size: 84),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: OcText.pageTitle.copyWith(fontSize: 24)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OcBadge(label, dot: color, color: Oc.text),
                      OcBadge(deviceKind(d)),
                      OcBadge(l10n.devicesLedCount(d.device.ledCount)),
                      if (d.battery != null)
                        OcBadge(
                          d.charging
                              ? l10n.devicesCharging(d.battery!)
                              : l10n.devicesBattery(d.battery!),
                          dot: d.battery! <= 15 && !d.charging
                              ? Oc.danger
                              : Oc.success,
                          color: Oc.text,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (engine.isCustomized(d)) ...[
              OcButton(
                label: l10n.devicesRestoreDefaults,
                icon: Icons.restart_alt_rounded,
                onPressed: () => _confirmReset(context, engine, d),
              ),
              const SizedBox(width: 16),
            ],
            Tooltip(
              message: d.status == 'disabled'
                  ? l10n.devicesEnable
                  : l10n.devicesDisable,
              child: OcSwitch(
                value: d.status != 'disabled',
                onChanged: (v) => engine.setDeviceEnabled(d, v),
              ),
            ),
          ],
        ),
        if (d.error != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Oc.danger.withValues(alpha: .06),
              borderRadius: Oc.r12,
              border: Border.all(color: Oc.danger.withValues(alpha: .25)),
            ),
            child: SelectableText(
              d.error!,
              style: const TextStyle(fontSize: 12.5, color: Oc.danger),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: OcSegmented<String>(
            value: _tab == 'screen' && d.screen == null ? 'lighting' : _tab,
            options: [
              ('lighting', l10n.devicesTabLighting),
              if (d.screen != null) ('screen', l10n.devicesTabScreen),
              ('info', l10n.devicesTabDetails),
            ],
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        const SizedBox(height: 20),
        if (_tab == 'info')
          _InfoTab(device: d)
        else if (_tab == 'screen' && d.screen != null)
          ScreenTab(engine: engine, device: d)
        else
          _ZonesTab(engine: engine, device: d),
      ],
    );
  }
}

String? _modeName(String name) => switch (name) {
  'off' => l10n.devicesOff,
  'static' => l10n.devicesModeStatic,
  'breathing' => l10n.devicesModeBreathing,
  'blinking' => l10n.devicesModeBlinking,
  'flashing' => l10n.devicesModeFlashing,
  'color cycle' => l10n.devicesModeColorCycle,
  'spectrum cycle' => l10n.devicesModeSpectrumCycle,
  'rainbow' => l10n.devicesModeRainbow,
  'rainbow wave' => l10n.devicesModeRainbowWave,
  'wave' => l10n.devicesModeWave,
  'color wave' => l10n.devicesModeColorWave,
  'reactive' => l10n.devicesModeReactive,
  'ripple' => l10n.devicesModeRipple,
  'starlight' => l10n.devicesModeStarlight,
  'random flicker' => l10n.devicesModeRandomFlicker,
  'double flash' => l10n.devicesModeDoubleFlash,
  'spectrum' => l10n.devicesModeSpectrum,
  'custom' => l10n.devicesModeCustom,
  'random' => l10n.devicesModeRandom,
  _ => null,
};

/// [name] in the UI language; a trailing number stays ("Wave 2" -> "Onda 2").
String hardwareModeName(String name) {
  final m = RegExp(r'^(.*?)\s*(\d+)$').firstMatch(name.trim());
  final base = (m?[1] ?? name).trim();
  final known = _modeName(base.toLowerCase());
  if (known == null) return localizeTerm(name);
  return m == null ? known : '$known ${m[2]}';
}

/// The mode select's entry for "follow the app's effects".
const _appMode = 'openchroma:app';

String? _directionName(int direction) => switch (direction) {
  ModeDirection.left => l10n.devicesDirLeft,
  ModeDirection.right => l10n.devicesDirRight,
  ModeDirection.up => l10n.devicesDirUp,
  ModeDirection.down => l10n.devicesDirDown,
  ModeDirection.horizontal => l10n.devicesDirHorizontal,
  ModeDirection.vertical => l10n.devicesDirVertical,
  ModeDirection.upLeft => l10n.devicesDirUpLeft,
  ModeDirection.upRight => l10n.devicesDirUpRight,
  ModeDirection.downLeft => l10n.devicesDirDownLeft,
  ModeDirection.downRight => l10n.devicesDirDownRight,
  _ => null,
};

/// Rows for what the running hardware effect lets the user adjust.
List<Widget> _modeOptions(
  Engine engine,
  DeviceInstance device,
  HardwareMode mode,
) {
  final o = engine.modeOptions(device, mode);
  void set(String key, Object? value) =>
      engine.setModeOption(device, key, value);
  final colors = (o['colors'] as List?)?.cast<int>() ?? const <int>[];
  final random = o['random'] == true;
  return [
    if (mode.speed case final r?)
      OcRow(
        title: l10n.devicesSpeed,
        stacked: true,
        trailing: _ModeSlider(
          value: r.fraction(o['speed'] as int),
          onDone: (t) => set('speed', r.at(t)),
        ),
      ),
    if (mode.brightness case final r?)
      OcRow(
        title: l10n.devicesBrightness,
        stacked: true,
        trailing: _ModeSlider(
          value: r.fraction(o['brightness'] as int),
          onDone: (t) => set('brightness', r.at(t)),
        ),
      ),
    if (mode.directions.length > 1)
      OcRow(
        title: l10n.devicesDirection,
        trailing: OcSelect(
          value: '${o['direction']}',
          options: [for (final d in mode.directions) '$d'],
          labelOf: (v) => _directionName(int.parse(v)) ?? v,
          onChanged: (v) => set('direction', int.parse(v)),
          width: 200,
        ),
      ),
    if (mode.random)
      OcRow(
        title: l10n.devicesRandomColors,
        trailing: OcSwitch(value: random, onChanged: (v) => set('random', v)),
      ),
    if (mode.hasColors && !random)
      OcRow(
        title: colors.length == 1 ? l10n.devicesColor : l10n.devicesColors,
        trailing: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (i, c) in colors.indexed)
              ColorField(
                color: Color(0xFF000000 | c),
                onChanged: (picked) => set('colors', [
                  for (final (j, old) in colors.indexed)
                    j == i ? picked.toARGB32() & 0xFFFFFF : old,
                ]),
              ),
            if (mode.colorsMax > mode.colorsMin) ...[
              OcIconButton(
                icon: Icons.remove,
                tooltip: l10n.devicesRemoveColor,
                onPressed: colors.length > mode.colorsMin
                    ? () => set('colors', colors.sublist(0, colors.length - 1))
                    : null,
              ),
              OcIconButton(
                icon: Icons.add,
                tooltip: l10n.devicesAddColor,
                onPressed: colors.length < mode.colorsMax
                    ? () => set('colors', [
                        ...colors,
                        colors.lastOrNull ?? 0xFFFFFF,
                      ])
                    : null,
              ),
            ],
          ],
        ),
      ),
    if (mode.ledColor)
      OcRow(
        title: l10n.devicesColor,
        trailing: ColorField(
          color: Color(0xFF000000 | (o['ledColor'] as int)),
          onChanged: (c) => set('ledColor', c.toARGB32() & 0xFFFFFF),
        ),
      ),
  ];
}

/// A 0-100% slider that applies its value when the drag ends: each change
/// is a command to the device, which some store in their memory.
class _ModeSlider extends StatefulWidget {
  const _ModeSlider({required this.value, required this.onDone});
  final double value;
  final ValueChanged<double> onDone;

  @override
  State<_ModeSlider> createState() => _ModeSliderState();
}

class _ModeSliderState extends State<_ModeSlider> {
  double? _drag;

  @override
  Widget build(BuildContext context) => OcSlider(
    value: (_drag ?? widget.value) * 100,
    min: 0,
    max: 100,
    suffix: '%',
    onChanged: (v) => setState(() => _drag = v / 100),
    onChangeEnd: (v) {
      setState(() => _drag = null);
      widget.onDone(v / 100);
    },
  );
}

/// The device's LED zones; ARGB headers take the number of LEDs plugged in.
class _ZonesTab extends StatelessWidget {
  const _ZonesTab({required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) {
    final zones = device.device.zones;
    final resizable = device.resizableZones.isNotEmpty;
    final settings = device.plugin?.settings ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (device.modes.isNotEmpty || settings.isNotEmpty) ...[
          OcPanel(
            children: [
              if (device.modes.isNotEmpty)
                OcRow(
                  leading: const Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: Oc.textTertiary,
                  ),
                  title: l10n.devicesLighting,
                  description: device.activeMode == null
                      ? l10n.devicesFollowsApp
                      : l10n.devicesRunsItself,
                  trailing: OcSelect(
                    value: device.activeMode ?? _appMode,
                    options: [_appMode, for (final m in device.modes) m.name],
                    labelOf: (v) => v == _appMode
                        ? l10n.devicesAppEffects
                        : hardwareModeName(v),
                    onChanged: (v) =>
                        engine.setDeviceMode(device, v == _appMode ? null : v),
                    width: 240,
                  ),
                ),
              if (engine.activeHardwareMode(device) case final mode?
                  when mode.adjustable)
                ..._modeOptions(engine, device, mode),
              for (final e in settings.entries)
                PropertyControl(
                  label: '${e.value['label'] ?? e.key}',
                  type: '${e.value['type'] ?? 'number'}',
                  tooltip: '${e.value['description'] ?? ''}',
                  min: (e.value['min'] as num?)?.toDouble() ?? 0,
                  max: (e.value['max'] as num?)?.toDouble() ?? 100,
                  step: (e.value['step'] as num?)?.toDouble(),
                  values: [
                    for (final v in e.value['values'] as List? ?? []) '$v',
                  ],
                  value: engine.pluginSetting(device, e.key),
                  onChanged: (v) => engine.setPluginSetting(device, e.key, v),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (device.device.configSchema.isNotEmpty) ...[
          _DriverOptions(engine: engine, device: device),
          const SizedBox(height: 20),
        ],
        if (device.resizableZones.any((z) => z.$2.count == 0))
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Oc.warning.withValues(alpha: .08),
              borderRadius: Oc.r12,
              border: Border.all(color: Oc.warning.withValues(alpha: .25)),
            ),
            child: Text(
              l10n.devicesZonesWithoutLeds(
                device.resizableZones
                    .where((z) => z.$2.count == 0)
                    .map((z) => z.$2.name)
                    .join(', '),
              ),
              style: const TextStyle(fontSize: 12.5, color: Oc.warning),
            ),
          ),
        if (resizable)
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 2),
            child: Text(l10n.devicesArgbHint, style: OcText.secondary),
          ),
        OcPanel(
          children: [
            for (var i = 0; i < zones.length; i++)
              OcRow(
                leading: Icon(
                  zones[i].isMatrix
                      ? Icons.grid_view_rounded
                      : zones[i].resizable
                      ? Icons.cable_rounded
                      : Icons.linear_scale_rounded,
                  size: 18,
                  color: Oc.textTertiary,
                ),
                title: zones[i].name.isEmpty
                    ? l10n.devicesZoneN(i + 1)
                    : zones[i].name,
                description: zones[i].resizable
                    ? l10n.devicesUpToLeds(zones[i].max)
                    : zones[i].isMatrix
                    ? l10n.devicesMatrix(zones[i].width, zones[i].height)
                    : null,
                trailing: zones[i].resizable
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OcButton(
                            label: l10n.devicesCountLeds,
                            icon: Icons.auto_fix_high_rounded,
                            variant: OcButtonVariant.ghost,
                            onPressed: () => showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => _LedCounter(
                                engine: engine,
                                device: device,
                                zone: i,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OcNumberField(
                            value: zones[i].count,
                            suffix: 'LEDs',
                            onSubmitted: (v) =>
                                engine.setZoneLedCount(device, i, v),
                          ),
                        ],
                      )
                    : Text(
                        l10n.devicesLedCount(zones[i].count),
                        style: OcText.secondary,
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Finds how many LEDs hang off an ARGB connector: the first N light up
/// green while the user moves N until the last fan is fully lit.
class _LedCounter extends StatefulWidget {
  const _LedCounter({
    required this.engine,
    required this.device,
    required this.zone,
  });
  final Engine engine;
  final DeviceInstance device;
  final int zone;

  @override
  State<_LedCounter> createState() => _LedCounterState();
}

class _LedCounterState extends State<_LedCounter> {
  late final DriverZone _info = widget.device.device.zones[widget.zone];
  late final int _original = _info.count;
  late final int _max = math.min(_info.max, 300);
  late int _count = _original > 0 ? _original : 10;

  @override
  void initState() {
    super.initState();
    widget.engine.setZoneLedCount(widget.device, widget.zone, _info.max);
    _show();
  }

  void _show() => widget.engine.setTestColor(
    widget.device,
    widget.zone,
    0,
    255,
    90,
    _count,
  );

  void _set(int v) {
    setState(() => _count = v.clamp(1, _max));
    _show();
  }

  void _finish(int? count) {
    widget.engine
      ..setTestColor(widget.device, null)
      ..setZoneLedCount(widget.device, widget.zone, count ?? _original);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Oc.panel,
    shape: const RoundedRectangleBorder(borderRadius: Oc.r12),
    child: SizedBox(
      width: 460,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.devicesCountLedsTitle(_info.name), style: OcText.title),
            const SizedBox(height: 6),
            Text(l10n.devicesCountLedsHint, style: OcText.secondary),
            const SizedBox(height: 20),
            Row(
              children: [
                OcIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.devicesOneLess,
                  onPressed: _count > 1 ? () => _set(_count - 1) : null,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.devicesLedCount(_count),
                      style: OcText.title.copyWith(
                        fontSize: 22,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                OcIconButton(
                  icon: Icons.add_rounded,
                  tooltip: l10n.devicesOneMore,
                  onPressed: _count < _max ? () => _set(_count + 1) : null,
                ),
              ],
            ),
            OcSlider(
              value: _count.toDouble(),
              min: 1,
              max: _max.toDouble(),
              onChanged: (v) => _set(v.round()),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OcButton(
                  label: l10n.devicesCancel,
                  variant: OcButtonVariant.ghost,
                  onPressed: () => _finish(null),
                ),
                const SizedBox(width: 8),
                OcButton(
                  label: l10n.devicesUseLeds(_count),
                  icon: Icons.check_rounded,
                  variant: OcButtonVariant.primary,
                  onPressed: () => _finish(_count),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.device});
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) {
    final d = device.device;
    Widget info(String k, String v) => OcRow(
      title: k,
      trailing: Flexible(
        child: SelectableText(v, style: OcText.mono, textAlign: TextAlign.end),
      ),
    );
    return OcPanel(
      children: [
        if (d.vendor.isNotEmpty) info(l10n.devicesInfoVendor, d.vendor),
        if (d.description.isNotEmpty)
          info(l10n.devicesInfoDescription, d.description),
        if (d.version.isNotEmpty) info(l10n.devicesInfoVersion, d.version),
        if (d.serial.isNotEmpty) info(l10n.devicesInfoSerial, d.serial),
        info(
          l10n.devicesInfoDriver,
          device.plugin == null
              ? l10n.devicesDriverBuiltIn
              : device.plugin!.bundled
              ? l10n.devicesDriverPluginBundled(device.plugin!.name)
              : l10n.devicesDriverPluginUser(device.plugin!.name),
        ),
        info(l10n.devicesInfoConnection, d.location),
        info(l10n.devicesInfoZones, '${d.zones.length}'),
        if (device.modes.isNotEmpty)
          info(
            l10n.devicesInfoHardwareModes,
            device.modes.map((m) => hardwareModeName(m.name)).join(', '),
          ),
      ],
    );
  }
}

/// Options a built-in driver offers for this device, such as the color
/// order of each ARGB header.
class _DriverOptions extends StatelessWidget {
  const _DriverOptions({required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  static String _title(String key, Map entry) {
    final title = '${entry['title'] ?? key}';
    final order = RegExp(r'^(.*) Color Order$').firstMatch(title);
    if (order != null) {
      final what = order
          .group(1)!
          .replaceAll('LED_C(x)', l10n.devicesBoardLedC);
      return l10n.devicesColorOrderOption(what);
    }
    final gen2 = RegExp(r'^(.*) Gen2').firstMatch(title);
    if (gen2 != null && key.startsWith('gen2_')) {
      return l10n.devicesDetectGen2(gen2.group(1)!);
    }
    return switch (title) {
      'Persist Lighting on Exit' => l10n.devicesPersistLighting,
      _ => title,
    };
  }

  static String? _description(String key, Map entry) {
    if (key.startsWith('calibration_') && key != 'calibration_enabled') {
      return l10n.devicesCalibrationHint;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final schema = device.device.configSchema;
    // The override is switched on with any order the user picks; on its
    // own it changes nothing, so it is not shown.
    final keys = schema.keys.where((k) => k != 'calibration_enabled').toList()
      ..sort(
        (a, b) => ((schema[a] as Map)['order'] as num? ?? 0).compareTo(
          (schema[b] as Map)['order'] as num? ?? 0,
        ),
      );
    // Picking an order only takes effect with the override on.
    final hasOverride = schema.containsKey('calibration_enabled');
    void set(String key, Object? value) => engine.setDriverConfig(device, {
      key: value,
      if (hasOverride &&
          key.startsWith('calibration_') &&
          key != 'calibration_enabled')
        'calibration_enabled': true,
    });
    return OcPanel(
      children: [
        for (final key in keys)
          () {
            final entry = schema[key] as Map;
            final value = engine.driverConfigValue(device, key);
            final type = '${entry['type'] ?? ''}';
            final options = [
              for (final o in entry['enum'] as List? ?? [])
                if ('$o' != 'INVALID') '$o',
            ];
            Widget? control;
            if (type == 'bool') {
              control = OcSwitch(
                value: value == true,
                onChanged: (v) => set(key, v),
              );
            } else if (options.isNotEmpty) {
              final current = '$value';
              control = OcSelect(
                value: options.contains(current) ? current : options.first,
                options: options,
                labelOf: (o) => o == 'OFF' ? l10n.devicesOff : o,
                onChanged: (o) => set(key, o),
                width: 160,
              );
            } else if (type == 'integer') {
              control = OcNumberField(
                value: (value as num?)?.toInt() ?? 0,
                onSubmitted: (v) => set(key, v),
              );
            }
            // Orders of a header with LEDs get the assistant.
            final header = RegExp(r'^(.*) Color Order$')
                .firstMatch('${entry['title'] ?? ''}')
                ?.group(1);
            final zone = header == null
                ? -1
                : device.device.zones.indexWhere(
                    (z) => z.name == header && z.count > 0,
                  );
            return OcRow(
              title: _title(key, entry),
              description: _description(key, entry),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (zone >= 0) ...[
                    OcButton(
                      label: l10n.devicesDetect,
                      icon: Icons.auto_fix_high_rounded,
                      onPressed: () => showColorOrderAssistant(
                        context,
                        engine: engine,
                        device: device,
                        zone: zone,
                        configKey: key,
                        header: header!,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ?control,
                ],
              ),
            );
          }(),
      ],
    );
  }
}

Future<void> _confirmReset(
  BuildContext context,
  Engine engine,
  DeviceInstance d,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.devicesResetTitle, style: OcText.title),
      content: SizedBox(
        width: 380,
        child: Text(l10n.devicesResetBody, style: OcText.body),
      ),
      actions: [
        OcButton(
          label: l10n.devicesCancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        OcButton(
          label: l10n.devicesRestore,
          variant: OcButtonVariant.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  if (ok == true) engine.resetDevice(d);
}
