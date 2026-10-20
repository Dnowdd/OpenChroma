import 'package:flutter/material.dart';

import '../engine/engine.dart';
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
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OcText.label,
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

/// The device's LED zones; ARGB headers take the number of LEDs plugged in.
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
};

String hardwareModeName(String name) =>
    _modeNames[name.trim().toLowerCase()] ?? name;

/// The mode select's entry for "follow the app's effects".
const _appMode = 'openchroma:app';

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
                    options: [_appMode, for (final m in device.modes) m.$2],
                    labelOf: (v) => v == _appMode
                        ? 'Efeitos do OpenChroma'
                        : hardwareModeName(v),
                    onChanged: (v) =>
                        engine.setDeviceMode(device, v == _appMode ? null : v),
                    width: 240,
                  ),
                ),
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
        if (d.modes.isNotEmpty) info('Modos do hardware', d.modes.join(', ')),
      ],
    );
  }
}
