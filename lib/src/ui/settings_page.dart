import 'dart:io';

import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../alerts/alert_service.dart';
import '../audio/audio_service.dart';
import '../engine/engine.dart';
import '../i18n/l10n.dart';
import '../system/launch_settings.dart';
import '../system/update_check.dart';
import 'about_panel.dart';
import 'ai_settings.dart';
import 'plugin_approval.dart';
import 'effects_page.dart';
import 'shell.dart' show Pages;
import 'theme.dart';
import 'widgets.dart';
import '../system/system_paths.dart';

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
    required this.language,
    required this.updates,
  });
  final Engine engine;
  final AiService ai;
  final AlertService alerts;
  final LanguageController language;
  final UpdateChecker updates;

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
                      l10n.settingsTitle,
                      style: OcText.pageTitle.copyWith(fontSize: 28),
                    ),
                  ),
                  SectionLabel(l10n.settingsGeneral),
                  OcPanel(
                    children: [
                      OcRow(
                        leading: const OcIconTile(
                          Icons.translate_rounded,
                          color: _Tint.blue,
                        ),
                        title: l10n.settingsLanguage,
                        trailing: OcSelect(
                          value: language.language.name,
                          options: [for (final l in AppLanguage.values) l.name],
                          labelOf: (n) => AppLanguage.values.byName(n).label,
                          onChanged: (n) =>
                              language.language = AppLanguage.values.byName(n),
                          width: 220,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SectionLabel(l10n.settingsLighting),
                  OcPanel(
                    children: [
                      OcRow(
                        leading: const OcIconTile(
                          Icons.light_mode_rounded,
                          color: _Tint.orange,
                        ),
                        title: l10n.settingsBrightness,
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
                        title: l10n.settingsEffectAudio,
                        description: engine.audio.available
                            ? null
                            : l10n.settingsAudioUnavailable,
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
                  SectionLabel(l10n.settingsLibrary),
                  OcPanel(
                    children: [
                      OcRow(
                        leading: const OcIconTile(
                          Icons.usb_rounded,
                          color: _Tint.blue,
                        ),
                        title: l10n.settingsDevices,
                        description: l10n.settingsDevicesConnected(
                          engine.devices.length,
                        ),
                        trailing: OcButton(
                          label: l10n.settingsScan,
                          onPressed: engine.refreshDevices,
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.auto_awesome,
                          color: _Tint.purple,
                        ),
                        title: l10n.settingsEffects,
                        description: l10n.settingsEffectsInLibrary(
                          engine.effects.length,
                        ),
                        trailing: OcButton(
                          label: l10n.settingsImport,
                          onPressed: () => showImportDialog(context, engine),
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.extension_rounded,
                          color: _Tint.green,
                        ),
                        title: l10n.settingsPlugins,
                        description: _pluginsSummary(engine),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OcIconButton(
                              icon: Icons.refresh_rounded,
                              tooltip: l10n.settingsReloadPlugins,
                              onPressed: engine.reloadPlugins,
                            ),
                            const SizedBox(width: 6),
                            OcButton(
                              label: l10n.settingsManagePlugins,
                              onPressed: () =>
                                  showPluginApproval(context, engine),
                            ),
                            const SizedBox(width: 6),
                            OcButton(
                              label: l10n.settingsOpenFolder,
                              onPressed: () {
                                Directory(engine.pluginsDir)
                                    .createSync(recursive: true);
                                Process.run(SystemPaths.explorer, [
                                  engine.pluginsDir,
                                ]);
                              },
                            ),
                          ],
                        ),
                      ),
                      OcRow(
                        leading: const OcIconTile(
                          Icons.folder_rounded,
                          color: _Tint.gray,
                        ),
                        title: l10n.settingsDataFolder,
                        trailing: OcButton(
                          label: l10n.settingsOpen,
                          onPressed: () => Process.run(SystemPaths.explorer, [
                            engine.dataDir,
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SectionLabel(l10n.settingsAlerts),
                  ListenableBuilder(
                    listenable: alerts,
                    builder: (context, _) => OcPanel(
                      children: [
                        OcRow(
                          leading: const OcIconTile(
                            Icons.notifications_active_rounded,
                            color: _Tint.pink,
                          ),
                          title: l10n.settingsWindowsNotifications,
                          description:
                              l10n.settingsWindowsNotificationsDescription,
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
                          title: l10n.settingsFlashLeds,
                          description: l10n.settingsFlashLedsDescription,
                          trailing: OcSwitch(
                            value: alerts.flashLeds,
                            onChanged: alerts.setFlashLeds,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SectionLabel(l10n.settingsAiAssistant),
                  AiSettingsPanel(ai: ai),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(l10n.settingsAiKeyNote, style: OcText.caption),
                  ),
                  const SizedBox(height: 28),
                  SectionLabel(l10n.settingsStartup),
                  _LaunchPanel(engine: engine),
                  const SizedBox(height: 28),
                  SectionLabel(l10n.aboutSection),
                  AboutPanel(engine: engine, updates: updates),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// How many plugins loaded, and which ones failed and why.
String _pluginsSummary(Engine engine) {
  final failed = engine.plugins.where((p) => p.error != null).toList();
  final ok = engine.plugins.length - failed.length;
  return [
    l10n.settingsPluginsLoaded(ok),
    for (final p in failed) '${p.name}: ${p.error}',
  ].join('\n');
}

class _LaunchPanel extends StatefulWidget {
  const _LaunchPanel({required this.engine});
  final Engine engine;

  @override
  State<_LaunchPanel> createState() => _LaunchPanelState();
}

class _LaunchPanelState extends State<_LaunchPanel> {
  final _launch = LaunchSettings.create();

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
      final block = l.loaded ? l.startupBlock : null;
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
                title: l10n.settingsAdminMode,
                description: elevated
                    ? l10n.settingsAdminActive
                    : l10n.settingsAdminInactive,
                trailing: OcButton(
                  label: elevated
                      ? l10n.settingsAdminAlreadyActive
                      : l10n.settingsRestartAsAdmin,
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
                title: l10n.settingsAlwaysAdmin,
                description: l10n.settingsAlwaysAdminDescription,
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
                title: l10n.settingsStartWithWindows,
                description: switch (block) {
                  StartupBlock.installNotTrusted =>
                    l10n.securityStartupInstallUnsafe,
                  StartupBlock.needsAdmin => l10n.securityStartupNeedsAdmin,
                  null =>
                    l.startupTaskUntrusted
                        ? l10n.securityStartupInstallUnsafeRemove
                        : l.alwaysAdmin
                        ? l10n.securityStartupAdminDescription
                        : l10n.settingsStartWithWindowsDescription,
                },
                trailing: block == StartupBlock.needsAdmin
                    ? OcButton(
                        label: l10n.settingsRestartAsAdmin,
                        icon: Icons.admin_panel_settings_outlined,
                        onPressed: () => restartAsAdmin(
                          page: Pages.settings,
                          shutdown: widget.engine.shutdown,
                        ),
                      )
                    : OcSwitch(
                        value: l.startWithWindows,
                        onChanged: enabled && block == null
                            ? l.setStartWithWindows
                            : null,
                      ),
              ),
              OcRow(
                leading: const OcIconTile(
                  Icons.move_to_inbox_rounded,
                  color: _Tint.blue,
                ),
                title: l10n.settingsRunInBackground,
                description: l10n.settingsRunInBackgroundDescription,
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
