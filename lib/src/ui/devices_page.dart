import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import 'property_controls.dart';
import 'theme.dart';

String _hex4(int v) => v.toRadixString(16).padLeft(4, '0').toUpperCase();

(Color, String) statusStyle(String status) => switch (status) {
  'running' => (OcColors.ok, 'Ativo'),
  'starting' => (OcColors.warn, 'Iniciando'),
  'error' => (OcColors.error, 'Erro'),
  'disabled' => (OcColors.textMuted, 'Desativado'),
  'unsupported' => (OcColors.textMuted, 'Não suportado'),
  _ => (OcColors.textMuted, 'Parado'),
};

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 320,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: OcColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
                child: Row(
                  children: [
                    const Text(
                      'Dispositivos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Procurar dispositivos',
                      icon: const Icon(Icons.refresh),
                      onPressed: engine.refreshDevices,
                    ),
                  ],
                ),
              ),
              if (engine.scanning)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Carregando plugins…',
                    style: TextStyle(color: OcColors.textMuted),
                  ),
                ),
              if (!engine.scanning && devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhum dispositivo compatível encontrado. Feche o SignalRGB se ele estiver aberto, '
                    'porque os dois disputam os mesmos dispositivos.',
                    style: TextStyle(color: OcColors.textMuted, height: 1.4),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (final d in devices)
                      _DeviceTile(
                        device: d,
                        selected: d.key == sel?.key,
                        onTap: () => setState(() => _selected = d.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sel == null
              ? const SizedBox()
              : _DeviceDetail(
                  key: ValueKey(sel.key),
                  engine: engine,
                  device: sel,
                ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });
  final DeviceInstance device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, label) = statusStyle(device.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? OcColors.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _DeviceImage(url: device.imageUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: OcColors.textMuted,
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
      ),
    );
  }
}

class _DeviceImage extends StatelessWidget {
  const _DeviceImage({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.memory,
      color: OcColors.textMuted,
      size: size * .55,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class _DeviceDetail extends StatelessWidget {
  const _DeviceDetail({super.key, required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final first = d.endpoints.first;
    final (color, label) = statusStyle(d.status);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final prop in d.properties) {
      (groups[(prop['group'] as String?) ?? 'settings'] ??= []).add(prop);
    }
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DeviceImage(url: d.imageUrl, size: 96),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'VID ${_hex4(first.vendorId)} · PID ${_hex4(first.productId)}'
                    '${first.serial.isNotEmpty ? ' · S/N ${first.serial}' : ''}',
                    style: const TextStyle(
                      color: OcColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plugin: ${p.basename(d.plugin.path)}  (${d.plugin.publisher})',
                    style: const TextStyle(
                      color: OcColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Chip(
                        avatar: CircleAvatar(backgroundColor: color, radius: 5),
                        label: Text(label),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reiniciar'),
                        onPressed: d.status == 'disabled'
                            ? null
                            : () => engine.restartDevice(d),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Ativado',
                        style: const TextStyle(color: OcColors.textMuted),
                      ),
                      Switch(
                        value: d.status != 'disabled',
                        onChanged: (v) => engine.setDeviceEnabled(d, v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (d.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OcColors.error.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              d.error!,
              style: const TextStyle(color: OcColors.error),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (d.channelNames.isNotEmpty) ...[
          const _Section('Canais ARGB'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Informe quantos LEDs estão ligados em cada header. '
                    'Depois posicione cada canal na tela Layout.',
                    style: TextStyle(color: OcColors.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  for (final ch in d.channelNames)
                    _ChannelRow(engine: engine, device: d, channel: ch),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        for (final g in groups.entries) ...[
          _Section(
            g.key == 'lighting'
                ? 'Iluminação'
                : (g.key == 'settings' ? 'Configurações' : g.key),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final prop in g.value)
                    PropertyControl(
                      label: '${prop['label'] ?? prop['property']}',
                      type: '${prop['type'] ?? 'textfield'}',
                      tooltip:
                          '${prop['description'] ?? prop['tooltip'] ?? ''}',
                      min: double.tryParse('${prop['min']}') ?? 0,
                      max: double.tryParse('${prop['max']}') ?? 100,
                      step: double.tryParse('${prop['step']}'),
                      values: ((prop['values'] as List?) ?? [])
                          .map((e) => '$e')
                          .toList(),
                      value: prop['value'],
                      onChanged: (v) =>
                          engine.setDeviceProperty(d, '${prop['property']}', v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        const _Section('Log do plugin'),
        Container(
          height: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF09090C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OcColors.border),
          ),
          child: ListView(
            reverse: true,
            children: [
              for (final line in d.logs.reversed.take(200))
                SelectableText(
                  line,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 11.5,
                    color: OcColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.engine,
    required this.device,
    required this.channel,
  });
  final Engine engine;
  final DeviceInstance device;
  final String channel;

  @override
  Widget build(BuildContext context) {
    final limit = (device.channel(channel)['limit'] as num?)?.toInt() ?? 0;
    final count = engine.channelLedCount(device, channel);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.cable, size: 18, color: OcColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(channel)),
          if (limit > 0)
            Text(
              'máx. $limit  ',
              style: const TextStyle(fontSize: 12, color: OcColors.textMuted),
            ),
          SizedBox(
            width: 90,
            child: TextFormField(
              key: ValueKey('$channel=$count'),
              initialValue: '$count',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'LEDs'),
              onFieldSubmitted: (s) => engine.setChannelLedCount(
                device,
                channel,
                int.tryParse(s) ?? 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        color: OcColors.textMuted,
      ),
    ),
  );
}
