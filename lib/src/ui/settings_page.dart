import 'dart:io';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) {
    final plugins = engine.plugins;
    final hid = plugins.where((p) => p.error == null && p.isHid).length;
    final failed = plugins.where((p) => p.error != null).toList();

    Widget folder(String title, String path) => OcRow(
      title: title,
      description: path,
      trailing: OcIconButton(
        icon: Icons.open_in_new_rounded,
        tooltip: 'Abrir pasta',
        onPressed: Directory(path).existsSync()
            ? () => Process.run('explorer', [path])
            : null,
      ),
    );
    Widget stat(String title, String value) => OcRow(
      title: title,
      trailing: Text(value, style: OcText.mono.copyWith(color: Oc.text)),
    );

    return ListView(
      children: [
        const PageHeader(
          title: 'Configurações',
          subtitle: 'Brilho, fontes de conteúdo e compatibilidade.',
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Geral'),
                  OcPanel(
                    children: [
                      OcRow(
                        title: 'Brilho global',
                        description: 'Aplicado a todos os dispositivos.',
                        stacked: true,
                        trailing: OcSlider(
                          value: engine.brightness.toDouble(),
                          min: 0,
                          max: 100,
                          suffix: '%',
                          onChanged: (v) => engine.setBrightness(v.round()),
                        ),
                      ),
                      OcRow(
                        title: 'Procurar dispositivos',
                        description:
                            'A busca também roda sozinha a cada 5 segundos.',
                        trailing: OcButton(
                          label: 'Procurar agora',
                          icon: Icons.refresh_rounded,
                          onPressed: engine.refreshDevices,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Fontes'),
                  OcPanel(
                    children: [
                      for (final root in engine.paths.pluginRoots)
                        folder('Plugins', root),
                      for (final root in engine.paths.effectRoots)
                        folder('Efeitos', root),
                      folder('Dados do aplicativo', engine.dataDir),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Compatibilidade'),
                  OcPanel(
                    children: [
                      stat('Plugins carregados', '${plugins.length}'),
                      stat('Plugins USB HID', '$hid'),
                      stat('Efeitos', '${engine.effects.length}'),
                      stat(
                        'Placa-mãe',
                        engine.systemInfo['motherboard']?['model'] ?? '—',
                      ),
                      if (failed.isNotEmpty)
                        OcRow(
                          title: 'Plugins com erro',
                          description: failed
                              .map((p) => '${p.name}: ${p.error}')
                              .join('\n'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text(
                      'Esta versão controla dispositivos USB HID. Memórias e placas de vídeo (SMBus), '
                      'ventoinhas, telas LCD e efeitos de tela ou áudio ainda não são suportados.',
                      style: OcText.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
