import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../i18n/l10n.dart';
import '../plugins/plugin_trust.dart';
import '../system/launch_settings.dart' show Elevation;
import 'theme.dart';
import 'widgets.dart';

class PluginApprovalBanner extends StatelessWidget {
  const PluginApprovalBanner({super.key, required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final pending = engine.pluginsPending;
      if (pending == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          decoration: BoxDecoration(
            color: Oc.warning.withValues(alpha: .08),
            borderRadius: Oc.r12,
            border: Border.all(color: Oc.warning.withValues(alpha: .22)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 17, color: Oc.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.pluginTrustBanner(pending),
                  style: const TextStyle(fontSize: 12.5, color: Oc.warning),
                ),
              ),
              OcButton(
                label: l10n.pluginTrustReview,
                onPressed: () => showPluginApproval(context, engine),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showPluginApproval(BuildContext context, Engine engine) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ApprovalDialog(engine: engine),
    );

class _ApprovalDialog extends StatelessWidget {
  const _ApprovalDialog({required this.engine});
  final Engine engine;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(l10n.pluginTrustTitle, style: OcText.title),
    content: SizedBox(
      width: 560,
      child: ListenableBuilder(
        listenable: engine,
        builder: (context, _) {
          const order = {
            PluginTrust.pending: 0,
            PluginTrust.approved: 1,
            PluginTrust.denied: 2,
          };
          final plugins = [...engine.userPlugins]
            ..sort((a, b) => order[a.trust]!.compareTo(order[b.trust]!));
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Oc.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        Elevation.isElevated
                            ? '${l10n.pluginTrustIntro} ${l10n.pluginTrustElevated}'
                            : l10n.pluginTrustIntro,
                        style: OcText.body,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (plugins.isEmpty)
                  Text(l10n.pluginTrustEmpty, style: OcText.caption),
                for (final u in plugins)
                  _PluginCard(
                    plugin: u,
                    onApprove: () => engine.approvePlugin(u),
                    onDeny: () => engine.denyPlugin(u),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      OcButton(
        label: l10n.pluginTrustClose,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}

String _stamp(DateTime t) {
  String two(int v) => '$v'.padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.plugin,
    required this.onApprove,
    required this.onDeny,
  });
  final UserPlugin plugin;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final f = plugin.file;
    final (color, label) = switch (plugin.trust) {
      PluginTrust.approved => (Oc.success, l10n.pluginTrustApproved),
      PluginTrust.denied => (Oc.textTertiary, l10n.pluginTrustDenied),
      _ => (Oc.warning, l10n.pluginTrustPending),
    };
    final modified = _stamp(f.modified.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Oc.raised,
        borderRadius: Oc.r8,
        border: Border.all(color: Oc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.name,
                  style: OcText.title.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OcBadge(label, color: color, dot: color),
            ],
          ),
          const SizedBox(height: 8),
          if (f.error != null)
            Text(
              f.error!,
              style: const TextStyle(fontSize: 12.5, color: Oc.danger),
            )
          else ...[
            _Fact(l10n.pluginTrustPath, f.path),
            _Fact(
              l10n.pluginTrustSize,
              '${(f.size / 1024).toStringAsFixed(1)} KB',
            ),
            _Fact(l10n.pluginTrustModified, modified),
            _Fact(l10n.pluginTrustHash, f.shortHash, tooltip: f.sha256),
          ],
          if (plugin.changed && plugin.trust == PluginTrust.pending)
            _Note(l10n.pluginTrustChanged),
          if (plugin.replacesBundled) _Note(l10n.pluginTrustReplaces),
          if (plugin.overrides.isNotEmpty && !plugin.replacesBundled)
            _Note(l10n.pluginTrustOverrides(plugin.overrides.join(', '))),
          if (f.error == null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (plugin.trust != PluginTrust.denied)
                  OcButton(
                    label: plugin.trust == PluginTrust.approved
                        ? l10n.pluginTrustRevoke
                        : l10n.pluginTrustDeny,
                    variant: OcButtonVariant.ghost,
                    onPressed: onDeny,
                  ),
                if (plugin.trust != PluginTrust.approved) ...[
                  const SizedBox(width: 8),
                  OcButton(
                    label: l10n.pluginTrustApprove,
                    variant: OcButtonVariant.primary,
                    onPressed: onApprove,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.tooltip});
  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final text = SelectableText(
      value,
      style: tooltip == null ? OcText.secondary : OcText.mono,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 78, child: Text(label, style: OcText.caption)),
          Expanded(
            child: tooltip == null
                ? text
                : Tooltip(message: tooltip!, child: text),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: Oc.warning),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Oc.warning),
          ),
        ),
      ],
    ),
  );
}
