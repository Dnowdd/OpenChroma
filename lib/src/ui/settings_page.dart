import 'dart:io';

import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../alerts/alert_service.dart';
import '../audio/audio_service.dart';
import '../engine/engine.dart';
import '../system/launch_settings.dart';
import 'ai_settings.dart';
import 'effects_page.dart';
import 'shell.dart' show Pages;
import 'theme.dart';
import 'widgets.dart';

/// iOS system colors for the settings icons.
abstract final class _Tint {
  static const orange = Color(0xFFFF9F0A);
  static const pink = Color(0xFFFF375F);
  static const blue = Color(0xFF0A84FF);
  static const purple = Color(0xFFBF5AF2);
  static const green = Color(0xFF30D158);
  static const indigo = Color(0xFF5E5CE6);
  static const teal = Color(0xFF40C8E0);
  static const gray = Color(0xFF8E8E93);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.engine,
    required this.ai,
    required this.alerts,
  });
  final Engine engine;
  final AiService ai;
  final AlertService alerts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: Oc.pageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 22),
                    child: Text(
                      'Configurações',
                      style: OcText.pageTitle.copyWith(fontSize: 28),
                    ),
                  ),
                  const SectionLabel('Iluminação'),
                  OcPanel(
                    children: [
                      OcRow(
                        leading: const OcIconTile(
                          Icons.light_mode_rounded,
                          color: _Tint.orange,
                        ),
                        title: 'Brilho',
                        trailing: SizedBox(
                          width: 280,
                          child: OcSlider(
                            value: engine.brightness.toDouble(),
                            min: 0,
                            max: 100,
                            suffix: '%',
                            onChanged: (v) => engine.setBrightness(v.round()),
                          ),
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.graphic_eq_rounded,
                          color: _Tint.pink,
                        ),
                        title: 'Áudio dos efeitos',
                        description: engine.audio.available
                            ? null
                            : 'Indisponível nesta build.',
                        trailing: OcSelect(
                          value: engine.audioSource.name,
                          options: [for (final s in AudioSource.values) s.name],
                          labelOf: (n) => AudioSource.byName(n).label,
                          onChanged: (n) =>
                              engine.setAudioSource(AudioSource.byName(n)),
                          width: 220,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Biblioteca'),
                  OcPanel(
                    children: [
                      OcRow(
                        leading: const OcIconTile(
                          Icons.usb_rounded,
                          color: _Tint.blue,
                        ),
                        title: 'Dispositivos',
                        description: engine.devices.length == 1
                            ? '1 conectado'
                            : '${engine.devices.length} conectados',
                        trailing: OcButton(
                          label: 'Procurar',
                          onPressed: engine.refreshDevices,
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.auto_awesome,
                          color: _Tint.purple,
                        ),
                        title: 'Efeitos',
                        description: '${engine.effects.length} na biblioteca',
                        trailing: OcButton(
                          label: 'Importar',
                          onPressed: () => showImportDialog(context, engine),
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.extension_rounded,
                          color: _Tint.green,
                        ),
                        title: 'Plugins de dispositivos',
                        description:
                            '${engine.plugins.length} carregados. Coloque '
                            'arquivos .js na pasta e reinicie o app.',
                        trailing: OcButton(
                          label: 'Abrir pasta',
                          onPressed: () {
                            Directory(
                              engine.pluginsDir,
                            ).createSync(recursive: true);
                            Process.run('explorer', [engine.pluginsDir]);
                          },
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.folder_rounded,
                          color: _Tint.gray,
                        ),
                        title: 'Pasta de dados',
                        trailing: OcButton(
                          label: 'Abrir',
                          onPressed: () =>
                              Process.run('explorer', [engine.dataDir]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Avisos'),
                  ListenableBuilder(
                    listenable: alerts,
                    builder: (context, _) => OcPanel(
                      children: [
                        OcRow(
                          leading: const OcIconTile(
                            Icons.notifications_active_rounded,
                            color: _Tint.pink,
                          ),
                          title: 'Notificações do Windows',
                          description:
                              'Avisa quando algo esquenta demais, a memória ou '
                              'o disco enchem ou a bomba do water cooler para, '
                              'mesmo com o app na bandeja.',
                          trailing: OcSwitch(
                            value: alerts.notify,
                            onChanged: alerts.setNotify,
                          ),
                        ),
                        OcRow(
                          leading: const OcIconTile(
                            Icons.flash_on_rounded,
                            color: _Tint.orange,
                          ),
                          title: 'Piscar os LEDs em vermelho',
                          description:
                              'Os dispositivos piscam por alguns segundos '
                              'junto com o aviso.',
                          trailing: OcSwitch(
                            value: alerts.flashLeds,
                            onChanged: alerts.setFlashLeds,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Assistente de IA'),
                  AiSettingsPanel(ai: ai),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      'A chave fica só neste PC, criptografada para o seu '
                      'usuário do Windows, e só é enviada ao provedor escolhido.',
                      style: OcText.caption,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionLabel('Inicialização e permissões'),
                  _LaunchPanel(engine: engine),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'OpenChroma $appVersion',
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

/// Shown in Settings; scripts/build-release.ps1 passes the pubspec version.
const appVersion = String.fromEnvironment('OC_VERSION', defaultValue: 'dev');

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
                leading: OcIconTile(
                  elevated
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  color: elevated ? _Tint.green : _Tint.gray,
                ),
                title: 'Modo administrador',
                description: elevated
                    ? 'Ativo. A temperatura da CPU aparece no Monitor.'
                    : 'Desativado. É preciso para ler a temperatura da CPU.',
                trailing: OcButton(
                  label: elevated
                      ? 'Já está ativo'
                      : 'Reiniciar como administrador',
                  icon: elevated
                      ? Icons.check_rounded
                      : Icons.admin_panel_settings_outlined,
                  onPressed: elevated
                      ? null
                      : () => restartAsAdmin(
                          page: Pages.settings,
                          shutdown: widget.engine.shutdown,
                        ),
                ),
              ),
              OcRow(
                leading: const OcIconTile(
                  Icons.admin_panel_settings_rounded,
                  color: _Tint.indigo,
                ),
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
                leading: const OcIconTile(
                  Icons.power_settings_new_rounded,
                  color: _Tint.teal,
                ),
                title: 'Abrir ao ligar o PC',
                description: l.alwaysAdmin
                    ? 'Abre na bandeja, como administrador, ao entrar no '
                          'Windows, sem pedir permissão. Ativar ou desativar '
                          'pede o UAC uma vez.'
                    : 'Abre na bandeja junto com o Windows.',
                trailing: OcSwitch(
                  value: l.startWithWindows,
                  onChanged: enabled ? l.setStartWithWindows : null,
                ),
              ),
              OcRow(
                leading: const OcIconTile(
                  Icons.move_to_inbox_rounded,
                  color: _Tint.blue,
                ),
                title: 'Continuar em segundo plano',
                description:
                    'Ao fechar a janela, o OpenChroma fica na bandeja e '
                    'segue controlando luzes e ventoinhas.',
                trailing: OcSwitch(
                  value: l.runInBackground,
                  onChanged: enabled ? l.setRunInBackground : null,
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
