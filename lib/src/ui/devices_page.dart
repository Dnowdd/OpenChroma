import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import 'device_art.dart';
import 'property_controls.dart';
import 'theme.dart';
import 'widgets.dart';

String _hex4(int v) => v.toRadixString(16).padLeft(4, '0').toUpperCase();

(Color, String) statusStyle(String status) => switch (status) {
  'running' => (Oc.success, 'Conectado'),
  'starting' => (Oc.warning, 'Iniciando'),
  'error' => (Oc.danger, 'Erro'),
  'disabled' => (Oc.textTertiary, 'Desativado'),
  'unsupported' => (Oc.textTertiary, 'Não suportado'),
  _ => (Oc.textTertiary, 'Parado'),
};

String deviceKind(DeviceInstance d) =>
    deviceKindOf(d.plugin.deviceType, d.name).label;

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
                                    ? 'Carregando plugins'
                                    : engine.plugins.isEmpty
                                    ? 'Nenhum driver de dispositivo'
                                    : 'Nenhum dispositivo',
                                message: engine.scanning
                                    ? 'Preparando a compatibilidade com seus dispositivos.'
                                    : engine.plugins.isEmpty
                                    ? 'Não há drivers de iluminação neste PC ainda. '
                                          'Efeitos, ventoinhas e o monitor funcionam '
                                          'normalmente.'
                                    : 'Conecte um dispositivo compatível. Se outro programa de RGB '
                                          'estiver aberto, feche-o antes.',
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
                            '${deviceKind(device)} · $label${device.battery == null ? '' : ' · ${device.battery}%'}',
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
    final hasChannels = d.channelNames.isNotEmpty;
    final tab = !hasChannels && _tab == 'channels' ? 'lighting' : _tab;

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DeviceArt(engine: engine, device: d, size: 84),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            style: OcText.pageTitle.copyWith(fontSize: 24),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              OcBadge(label, dot: color, color: Oc.text),
                              OcBadge(deviceKind(d)),
                              if (d.battery != null)
                                OcBadge(
                                  '${d.batteryState == 2 ? 'Carregando · ' : ''}Bateria ${d.battery}%',
                                  dot: d.battery! <= 15
                                      ? Oc.danger
                                      : Oc.success,
                                  color: Oc.text,
                                ),
                              OcBadge(
                                '${_hex4(d.endpoints.first.vendorId)}:${_hex4(d.endpoints.first.productId)}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OcButton(
                      label: 'Reiniciar',
                      icon: Icons.restart_alt_rounded,
                      onPressed: d.status == 'disabled'
                          ? null
                          : () => engine.restartDevice(d),
                    ),
                    const SizedBox(width: 16),
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
                      border: Border.all(
                        color: Oc.danger.withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: Oc.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            d.error!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Oc.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OcSegmented<String>(
                    value: tab,
                    options: [
                      ('lighting', 'Iluminação'),
                      if (hasChannels) ('channels', 'Canais ARGB'),
                      ('diagnostics', 'Diagnóstico'),
                    ],
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                ),
                const SizedBox(height: 20),
                switch (tab) {
                  'channels' => _ChannelsTab(engine: engine, device: d),
                  'diagnostics' => _DiagnosticsTab(device: d),
                  _ => _LightingTab(engine: engine, device: d),
                },
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LightingTab extends StatelessWidget {
  const _LightingTab({required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final prop in device.properties) {
      (groups[(prop['group'] as String?) ?? 'settings'] ??= []).add(prop);
    }
    if (groups.isEmpty) {
      return const OcPanel(
        children: [
          OcRow(
            title: 'Sem opções',
            description: 'Este dispositivo não expõe configurações.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups.entries) ...[
          SectionLabel(switch (g.key) {
            'lighting' => 'Iluminação',
            'settings' => 'Configurações',
            'mouse_settings' => 'Mouse',
            _ => g.key,
          }),
          OcPanel(
            children: [
              for (final prop in g.value)
                PropertyControl(
                  label: '${prop['label'] ?? prop['property']}',
                  type: '${prop['type'] ?? 'textfield'}',
                  tooltip: '${prop['description'] ?? prop['tooltip'] ?? ''}',
                  min: double.tryParse('${prop['min']}') ?? 0,
                  max: double.tryParse('${prop['max']}') ?? 100,
                  step: double.tryParse('${prop['step']}'),
                  values: ((prop['values'] as List?) ?? [])
                      .map((e) => '$e')
                      .toList(),
                  value: prop['value'],
                  onChanged: (v) => engine.setDeviceProperty(
                    device,
                    '${prop['property']}',
                    v,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ChannelsTab extends StatelessWidget {
  const _ChannelsTab({required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 14, left: 2),
        child: Text(
          'Informe quantos LEDs estão ligados em cada header. Um fan de 120 mm costuma ter '
          'entre 8 e 24 LEDs. Depois posicione cada canal na tela Layout.',
          style: OcText.secondary,
        ),
      ),
      OcPanel(
        children: [
          for (final ch in device.channelNames)
            OcRow(
              leading: const Icon(
                Icons.cable_rounded,
                size: 18,
                color: Oc.textTertiary,
              ),
              title: ch,
              description: () {
                final limit =
                    (device.channel(ch)['limit'] as num?)?.toInt() ?? 0;
                return limit > 0 ? 'Até $limit LEDs' : null;
              }(),
              trailing: OcNumberField(
                value: engine.channelLedCount(device, ch),
                suffix: 'LEDs',
                onSubmitted: (v) => engine.setChannelLedCount(device, ch, v),
              ),
            ),
        ],
      ),
    ],
  );
}

class _DiagnosticsTab extends StatelessWidget {
  const _DiagnosticsTab({required this.device});
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) {
    final e = device.endpoints.first;
    Widget info(String k, String v) => OcRow(
      title: k,
      trailing: SelectableText(v, style: OcText.mono),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcPanel(
          children: [
            info('Plugin', p.basename(device.plugin.path)),
            info(
              'Vendor / Product',
              '0x${_hex4(e.vendorId)} / 0x${_hex4(e.productId)}',
            ),
            if (e.serial.isNotEmpty) info('Número de série', e.serial),
            info('Interfaces HID', '${device.endpoints.length}'),
          ],
        ),
        const SizedBox(height: 24),
        const SectionLabel('Log'),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF070708),
            borderRadius: Oc.r10,
            border: Border.all(color: Oc.line),
          ),
          child: device.logs.isEmpty
              ? const Center(
                  child: Text('Sem mensagens.', style: OcText.caption),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: device.logs.length.clamp(0, 300),
                  itemBuilder: (_, i) {
                    final line = device.logs[device.logs.length - 1 - i];
                    final isError = line.startsWith('ERROR');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: SelectableText(
                        displayText(line.replaceAll(' {"toFile":true}', '')),
                        style: OcText.mono.copyWith(
                          fontSize: 11.5,
                          color: isError ? Oc.danger : Oc.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
