import 'dart:io';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'effects_page.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) {
    final supported = engine.plugins
        .where((p) => p.error == null && p.isHid)
        .length;
    return ListView(
      children: [
        const PageHeader(title: 'Configurações'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OcPanel(
                    children: [
                      OcRow(
                        title: 'Brilho',
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
                        title: 'Dispositivos',
                        description: 'Novos dispositivos aparecem sozinhos.',
                        trailing: OcButton(
                          label: 'Procurar agora',
                          onPressed: engine.refreshDevices,
                        ),
                      ),
                      OcRow(
                        title: 'Efeitos',
                        description:
                            'Adicione efeitos .ocfx ou .html à biblioteca.',
                        trailing: OcButton(
                          label: 'Importar',
                          onPressed: () => showImportDialog(context, engine),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text(
                        'OpenChroma 0.1 · $supported dispositivos compatíveis',
                        style: OcText.caption,
                      ),
                      const Spacer(),
                      OcButton(
                        label: 'Abrir pasta de dados',
                        variant: OcButtonVariant.ghost,
                        onPressed: () =>
                            Process.run('explorer', [engine.dataDir]),
                      ),
                    ],
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
