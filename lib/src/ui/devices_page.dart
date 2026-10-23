import 'package:flutter/material.dart';

import '../drivers/hardware_mode.dart';
import '../engine/engine.dart';
import '../system/batteries.dart';
import 'color_order.dart';
import 'device_art.dart';
import 'property_controls.dart';
import 'theme.dart';
import 'widgets.dart';

(Color, String) statusStyle(String status) => switch (status) {
  'running' => (Oc.success, 'Conectado'),
  'starting' => (Oc.warning, 'Iniciando'),
  'error' => (Oc.danger, 'Erro'),
  'disabled' => (Oc.textTertiary, 'Desativado'),
  'unsupported' => (Oc.textTertiary, 'Não suportado'),
  _ => (Oc.textTertiary, 'Parado'),
};

String deviceKind(DeviceInstance d) => deviceKindOf(d.type, d.name).label;

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.engine});
  final Engine engine;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  String? _selected;

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
              title: 'Dispositivos',
              subtitle: engine.scanning
                  ? 'Procurando…'
                  : running == 1
                  ? '1 conectado'
                  : '$running conectados',
              actions: [
                OcButton(
                  label: 'Procurar',
                  icon: Icons.refresh_rounded,
                  onPressed: engine.refreshDevices,
                ),
              ],
            ),
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
                                onTap: () => setState(() => _selected = d.key),
                              ),
                            if (engine.otherBatteries.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.fromLTRB(10, 18, 10, 6),
                                child: SectionLabel('Outros sem fio'),
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
                                key: ValueKey(sel.key),
                                engine: engine,
                                device: sel,
                              )
                            : EmptyState(
                                icon: Icons.usb_rounded,
                                title: engine.scanning
                                    ? 'Procurando dispositivos'
                                    : !engine.drivers.available
                                    ? 'Drivers indisponíveis'
                                    : 'Nenhum dispositivo',
                                message: engine.scanning
                                    ? (engine.detectionStep.isEmpty
                                          ? 'Isso leva alguns segundos.'
                                          : '${engine.detectionPercent}% · ${engine.detectionStep}')
                                    : !engine.drivers.available
                                    ? 'Os drivers não foram encontrados nesta instalação. '
                                          'Reinstale o OpenChroma.'
                                    : 'Conecte um dispositivo compatível. Se outro programa de RGB '
                                          'estiver aberto, feche-o antes. Memórias e placas de '
                                          'vídeo precisam do modo administrador e do PawnIO.',
                                action: engine.scanning
                                    ? null
                                    : OcButton(
                                        label: 'Procurar novamente',
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
  const _DeviceDetail({super.key, required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  @override
  State<_DeviceDetail> createState() => _DeviceDetailState();
}

class _DeviceDetailState extends State<_DeviceDetail> {
  String _tab = 'lighting';

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
                      OcBadge(
                        d.device.ledCount == 1
                            ? '1 LED'
                            : '${d.device.ledCount} LEDs',
                      ),
                      if (d.battery != null)
                        OcBadge(
                          d.charging
                              ? 'Carregando · ${d.battery}%'
                              : 'Bateria ${d.battery}%',
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
                label: 'Restaurar padrão',
                icon: Icons.restart_alt_rounded,
                onPressed: () => _confirmReset(context, engine, d),
              ),
              const SizedBox(width: 16),
            ],
            Tooltip(
              message: d.status == 'disabled' ? 'Ativar' : 'Desativar',
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
            value: _tab,
            options: const [('lighting', 'Iluminação'), ('info', 'Detalhes')],
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        const SizedBox(height: 20),
        if (_tab == 'info')
          _InfoTab(device: d)
        else
          _ZonesTab(engine: engine, device: d),
      ],
    );
  }
}

/// Names OpenRGB drivers give their effects, in Portuguese.
const _modeNames = {
  'off': 'Desligado',
  'static': 'Cor fixa',
  'breathing': 'Respirar',
  'blinking': 'Piscar',
  'flashing': 'Piscar',
  'color cycle': 'Ciclo de cores',
  'spectrum cycle': 'Ciclo de cores',
  'rainbow': 'Arco-íris',
  'rainbow wave': 'Onda arco-íris',
  'wave': 'Onda',
  'color wave': 'Onda de cores',
  'reactive': 'Ao digitar',
  'ripple': 'Ondulação',
  'starlight': 'Estrelas',
  'random flicker': 'Cintilar',
  'double flash': 'Flash duplo',
  'spectrum': 'Espectro',
  'custom': 'Personalizado',
  'random': 'Aleatório',
};

/// [name] in Portuguese; a trailing number stays ("Wave 2" -> "Onda 2").
String hardwareModeName(String name) {
  final m = RegExp(r'^(.*?)\s*(\d+)$').firstMatch(name.trim());
  final base = (m?[1] ?? name).trim();
  final known = _modeNames[base.toLowerCase()];
  if (known == null) return name;
  return m == null ? known : '$known ${m[2]}';
}

/// The mode select's entry for "follow the app's effects".
const _appMode = 'openchroma:app';

const _directionNames = {
  ModeDirection.left: 'Para a esquerda',
  ModeDirection.right: 'Para a direita',
  ModeDirection.up: 'Para cima',
  ModeDirection.down: 'Para baixo',
  ModeDirection.horizontal: 'Horizontal',
  ModeDirection.vertical: 'Vertical',
  ModeDirection.upLeft: 'Para cima e à esquerda',
  ModeDirection.upRight: 'Para cima e à direita',
  ModeDirection.downLeft: 'Para baixo e à esquerda',
  ModeDirection.downRight: 'Para baixo e à direita',
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
        title: 'Velocidade',
        stacked: true,
        trailing: _ModeSlider(
          value: r.fraction(o['speed'] as int),
          onDone: (t) => set('speed', r.at(t)),
        ),
      ),
    if (mode.brightness case final r?)
      OcRow(
        title: 'Brilho',
        stacked: true,
        trailing: _ModeSlider(
          value: r.fraction(o['brightness'] as int),
          onDone: (t) => set('brightness', r.at(t)),
        ),
      ),
    if (mode.directions.length > 1)
      OcRow(
        title: 'Direção',
        trailing: OcSelect(
          value: '${o['direction']}',
          options: [for (final d in mode.directions) '$d'],
          labelOf: (v) => _directionNames[int.parse(v)] ?? v,
          onChanged: (v) => set('direction', int.parse(v)),
          width: 200,
        ),
      ),
    if (mode.random)
      OcRow(
        title: 'Cores aleatórias',
        trailing: OcSwitch(value: random, onChanged: (v) => set('random', v)),
      ),
    if (mode.hasColors && !random)
      OcRow(
        title: colors.length == 1 ? 'Cor' : 'Cores',
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
                tooltip: 'Uma cor a menos',
                onPressed: colors.length > mode.colorsMin
                    ? () => set('colors', colors.sublist(0, colors.length - 1))
                    : null,
              ),
              OcIconButton(
                icon: Icons.add,
                tooltip: 'Mais uma cor',
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
        title: 'Cor',
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
                  title: 'Iluminação',
                  description: device.activeMode == null
                      ? 'Segue os efeitos do OpenChroma.'
                      : 'O próprio dispositivo faz o efeito.',
                  trailing: OcSelect(
                    value: device.activeMode ?? _appMode,
                    options: [_appMode, for (final m in device.modes) m.name],
                    labelOf: (v) => v == _appMode
                        ? 'Efeitos do OpenChroma'
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
              '${device.resizableZones.where((z) => z.$2.count == 0).map((z) => z.$2.name).join(', ')} '
              'sem LEDs: o que estiver ligado nesses conectores não segue os '
              'efeitos e fica no efeito anterior. Informe a quantidade abaixo.',
              style: const TextStyle(fontSize: 12.5, color: Oc.warning),
            ),
          ),
        if (resizable)
          const Padding(
            padding: EdgeInsets.only(bottom: 14, left: 2),
            child: Text(
              'Nos conectores ARGB, informe quantos LEDs estão ligados. Uma '
              'ventoinha de 120 mm costuma ter entre 8 e 24. Depois posicione '
              'cada zona em Iluminação › Layout.',
              style: OcText.secondary,
            ),
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
                title: zones[i].name.isEmpty ? 'Zona ${i + 1}' : zones[i].name,
                description: zones[i].resizable
                    ? 'Até ${zones[i].max} LEDs'
                    : zones[i].isMatrix
                    ? 'Matriz ${zones[i].width} × ${zones[i].height}'
                    : null,
                trailing: zones[i].resizable
                    ? OcNumberField(
                        value: zones[i].count,
                        suffix: 'LEDs',
                        onSubmitted: (v) =>
                            engine.setZoneLedCount(device, i, v),
                      )
                    : Text(
                        zones[i].count == 1
                            ? '1 LED'
                            : '${zones[i].count} LEDs',
                        style: OcText.secondary,
                      ),
              ),
          ],
        ),
      ],
    );
  }
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
        if (d.vendor.isNotEmpty) info('Fabricante', d.vendor),
        if (d.description.isNotEmpty) info('Descrição', d.description),
        if (d.version.isNotEmpty) info('Versão', d.version),
        if (d.serial.isNotEmpty) info('Número de série', d.serial),
        info(
          'Driver',
          device.plugin == null
              ? 'OpenRGB (incluído)'
              : '${device.plugin!.name} · plugin '
                    '${device.plugin!.bundled ? 'incluído' : 'seu'}',
        ),
        info('Conexão', d.location),
        info('Zonas', '${d.zones.length}'),
        if (device.modes.isNotEmpty)
          info(
            'Modos do hardware',
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
      final what = order.group(1)!.replaceAll('LED_C(x)', 'LED_C da placa');
      return 'Ordem das cores · $what';
    }
    final gen2 = RegExp(r'^(.*) Gen2').firstMatch(title);
    if (gen2 != null && key.startsWith('gen2_')) {
      return 'Detectar ARGB Gen2 · ${gen2.group(1)}';
    }
    return switch (title) {
      'Persist Lighting on Exit' => 'Gravar a iluminação ao fechar',
      _ => title,
    };
  }

  static String? _description(String key, Map entry) {
    if (key.startsWith('calibration_') && key != 'calibration_enabled') {
      return 'Se a cor sair trocada (ex.: verde no lugar de azul), use '
          '"Descobrir": duas perguntas e o app acha a ordem certa.';
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
                labelOf: (o) => o == 'OFF' ? 'Desligado' : o,
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
                      label: 'Descobrir',
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
      title: const Text('Restaurar padrão?', style: OcText.title),
      content: const SizedBox(
        width: 380,
        child: Text(
          'Volta as opções do dispositivo (como a ordem das cores) ao que ele '
          'tinha quando foi detectado pela primeira vez, faz ele seguir os '
          'efeitos do OpenChroma e devolve a posição dele no layout. A '
          'quantidade de LEDs dos conectores continua.',
          style: OcText.body,
        ),
      ),
      actions: [
        OcButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context, false),
        ),
        OcButton(
          label: 'Restaurar',
          variant: OcButtonVariant.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  if (ok == true) engine.resetDevice(d);
}
