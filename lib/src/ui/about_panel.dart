import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../i18n/l10n.dart';
import '../system/launch_settings.dart';
import '../system/system_paths.dart';
import '../system/update_check.dart';
import 'widgets.dart';

const _issuesUrl = 'https://github.com/Dnowdd/OpenChroma/issues/new/choose';

void openReleasePage(String url) {
  final safe = url.startsWith('$releasesUrl/') || url == releasesUrl;
  Process.run(SystemPaths.explorer, [safe ? url : releasesUrl]);
}

class AboutPanel extends StatelessWidget {
  const AboutPanel({super.key, required this.engine, required this.updates});
  final Engine engine;
  final UpdateChecker updates;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final update = updates.available;
      return OcPanel(
        children: [
          OcRow(
            leading: const OcIconTile(
              Icons.info_outline_rounded,
              color: Color(0xFF8E8E93),
            ),
            title: 'OpenChroma $appVersion',
            description: update != null
                ? l10n.aboutUpdateAvailable(update.version)
                : updates.checking
                ? l10n.aboutChecking
                : appVersion == 'dev'
                ? l10n.aboutDevBuild
                : updates.lastCheck == null
                ? null
                : l10n.aboutUpToDate,
            trailing: update != null
                ? OcButton(
                    label: l10n.aboutDownload,
                    icon: Icons.download_rounded,
                    variant: OcButtonVariant.primary,
                    onPressed: () => openReleasePage(update.url),
                  )
                : OcButton(
                    label: l10n.aboutCheckNow,
                    icon: Icons.refresh_rounded,
                    onPressed: updates.checking || appVersion == 'dev'
                        ? null
                        : updates.check,
                  ),
          ),
          OcRow(
            leading: const OcIconTile(
              Icons.system_update_alt_rounded,
              color: Color(0xFF0A84FF),
            ),
            title: l10n.aboutAutoCheck,
            description: l10n.aboutAutoCheckDescription,
            trailing: OcSwitch(
              value: updates.enabled,
              onChanged: (v) => updates.enabled = v,
            ),
          ),
          OcRow(
            leading: const OcIconTile(
              Icons.bug_report_outlined,
              color: Color(0xFFFF9F0A),
            ),
            title: l10n.aboutReportProblem,
            description: l10n.aboutReportProblemDescription,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OcButton(
                  label: l10n.aboutCopyDiagnostics,
                  icon: Icons.copy_rounded,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: diagnosticsReport(engine)),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text(l10n.aboutDiagnosticsCopied)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                OcButton(
                  label: l10n.aboutOpenIssue,
                  icon: Icons.open_in_new_rounded,
                  onPressed: () =>
                      Process.run(SystemPaths.explorer, [_issuesUrl]),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

String diagnosticsReport(Engine engine) {
  final b = StringBuffer()
    ..writeln('OpenChroma $appVersion')
    ..writeln('Windows: ${Platform.operatingSystemVersion}')
    ..writeln('Administrator: ${Elevation.isElevated}')
    ..writeln('Language: ${l10n.localeName}')
    ..writeln('Drivers loaded: ${engine.drivers.available}');
  if (engine.conflicts.isNotEmpty) {
    b.writeln('Other RGB apps open: ${engine.conflicts.join(', ')}');
  }
  b.writeln('\nDevices (${engine.devices.length}):');
  for (final d in engine.devices.values) {
    final dev = d.device;
    final via = d.plugin != null ? 'plugin ${d.plugin!.name}' : d.source.name;
    b.write('- ${dev.name} [${dev.type}, ${dev.ledCount} LEDs, $via]');
    b.write(' status=${d.status}');
    if (d.error != null) b.write(' error=${d.error}');
    b.writeln();
  }
  final failed = engine.plugins.where((p) => p.error != null);
  if (failed.isNotEmpty) {
    b.writeln('\nPlugin errors:');
    for (final p in failed) {
      b.writeln('- ${p.name}: ${p.error}');
    }
  }
  b.writeln('\nLogs: ${engine.dataDir}\\logs');
  return b.toString();
}
