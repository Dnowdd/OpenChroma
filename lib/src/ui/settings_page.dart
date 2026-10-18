import 'dart:io';

import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../engine/engine.dart';
import '../system/launch_settings.dart';
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
                        title: 'Áudio',
                        description: engine.audio.available
                            ? 'O que os efeitos com som escutam.'
                            : 'Captura de áudio indisponível nesta build.',
                        trailing: OcSelect(
                          value: engine.audioSource.name,
                          options: [for (final s in AudioSource.values) s.name],
                          labelOf: (n) => AudioSource.byName(n).label,
                          onChanged: (n) =>
                              engine.setAudioSource(AudioSource.byName(n)),
                          width: 200,
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
                  const SectionLabel('Inicialização e permissões'),
                  _LaunchPanel(engine: engine),
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

class _LaunchPanel extends StatefulWidget {
  const _LaunchPanel({required this.engine});
  final Engine engine;

  @override
  State<_LaunchPanel> createState() => _LaunchPanelState();
}

class _LaunchPanelState extends State<_LaunchPanel> {
  final _launch = LaunchSettings();

  @override
  void dispose() {
    _launch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _launch,
    builder: (context, _) {
      final l = _launch;
      final elevated = Elevation.isElevated;
      final enabled = l.loaded && !l.busy;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OcPanel(
            children: [
              OcRow(
                title: 'Modo administrador',
                description: elevated
                    ? 'Ativo. A temperatura da CPU aparece no Monitor.'
                    : 'Desativado. É preciso para ler a temperatura da CPU.',
                trailing: elevated
                    ? const OcBadge('Ativo', dot: Oc.success)
                    : OcButton(
                        label: 'Reiniciar como administrador',
                        icon: Icons.admin_panel_settings_outlined,
                        onPressed: () => restartAsAdmin(
                          page: 4,
                          shutdown: widget.engine.shutdown,
                        ),
                      ),
              ),
              OcRow(
                title: 'Sempre abrir como administrador',
                description:
                    'O Windows pede permissão (UAC) toda vez que o '
                    'OpenChroma abrir.',
                trailing: OcSwitch(
                  value: l.alwaysAdmin,
                  onChanged: enabled ? l.setAlwaysAdmin : null,
                ),
              ),
              OcRow(
                title: 'Abrir ao ligar o PC',
                description: l.alwaysAdmin
                    ? 'Abre como administrador ao entrar no Windows, sem '
                          'pedir permissão. Ativar ou desativar pede o UAC '
                          'uma vez.'
                    : 'Abre junto com o Windows.',
                trailing: OcSwitch(
                  value: l.startWithWindows,
                  onChanged: enabled ? l.setStartWithWindows : null,
                ),
              ),
            ],
          ),
          if (l.error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: Oc.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.error!,
                    style: OcText.secondary.copyWith(color: Oc.warning),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}
