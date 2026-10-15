import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) {
    final plugins = engine.plugins;
    final hid = plugins.where((p) => p.error == null && p.isHid).length;
    final failed = plugins.where((p) => p.error != null).toList();
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(k, style: const TextStyle(color: OcColors.textMuted)),
          ),
          Expanded(child: SelectableText(v)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const Text(
          'Configurações',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fontes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                row(
                  'Instalação do SignalRGB',
                  engine.paths.installDir ?? 'não encontrada',
                ),
                row('Pasta do usuário', engine.paths.userDir),
                row('Cache de efeitos', engine.paths.effectCacheDir),
                row('Dados do OpenChroma', engine.dataDir),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compatibilidade',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                row('Plugins carregados', '${plugins.length}'),
                row('Plugins HID suportados', '$hid'),
                row('Efeitos', '${engine.effects.length}'),
                row(
                  'Placa-mãe',
                  engine.systemInfo['motherboard']?['model'] ?? '',
                ),
                if (failed.isNotEmpty)
                  row(
                    'Plugins com erro',
                    failed.map((p) => '${p.name}: ${p.error}').join('\n'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Esta versão controla dispositivos USB HID. SMBus (RAM/GPU), controle de fans, '
                  'telas LCD e captura de tela/áudio ainda não estão implementados.',
                  style: TextStyle(color: OcColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Procurar dispositivos agora'),
            onPressed: engine.refreshDevices,
          ),
        ),
      ],
    );
  }
}
