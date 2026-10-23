import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import '../system/processes.dart';
import 'theme.dart';
import 'widgets.dart';

/// Picks the programs that turn [profile] on while they run.
Future<void> showProfileAppsDialog(
  BuildContext context,
  Engine engine,
  LightProfile profile,
) async {
  final apps = await showDialog<List<String>>(
    context: context,
    builder: (_) => _ProfileAppsDialog(profile: profile),
  );
  if (apps != null) engine.setProfileApps(profile.id, apps);
}

class _ProfileAppsDialog extends StatefulWidget {
  const _ProfileAppsDialog({required this.profile});
  final LightProfile profile;

  @override
  State<_ProfileAppsDialog> createState() => _ProfileAppsDialogState();
}

/// Windows' own hosts and helpers, which are never what the user means.
const _systemApps = {
  'openchroma.exe',
  'msedgewebview2.exe',
  'applicationframehost.exe',
  'textinputhost.exe',
  'shellexperiencehost.exe',
  'searchhost.exe',
  'startmenuexperiencehost.exe',
  'systemsettings.exe',
};

class _ProfileAppsDialogState extends State<_ProfileAppsDialog> {
  late final List<String> _apps = List.of(widget.profile.apps);
  final Future<List<RunningApp>> _open = windowedApps();
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _add(String exe) {
    var e = exe.trim().toLowerCase();
    if (e.isEmpty) return;
    if (!e.endsWith('.exe')) e = '$e.exe';
    if (!_apps.contains(e)) setState(() => _apps.add(e));
  }

  Future<void> _browse() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Programas', extensions: ['exe']),
      ],
    );
    if (file != null) _add(p.basename(file.path));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'Ligar "${widget.profile.name}" com programas',
      style: OcText.title,
    ),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quando um destes programas abrir, o perfil liga sozinho. Quando '
            'fechar, a iluminação de antes volta, a não ser que você tenha '
            'escolhido outra nesse meio-tempo.',
            style: OcText.secondary,
          ),
          const SizedBox(height: 14),
          if (_apps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhum programa ainda.', style: OcText.caption),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in _apps)
                  InputChip(
                    label: Text(a, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _apps.remove(a)),
                    deleteButtonTooltipMessage: 'Remover',
                  ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _typed,
            style: OcText.body,
            decoration: ocFieldDecoration('Nome do programa, ex.: cs2.exe'),
            onSubmitted: (v) {
              _add(v);
              _typed.clear();
            },
          ),
          const SizedBox(height: 18),
          const SectionLabel('Abertos agora'),
          const SizedBox(height: 6),
          SizedBox(
            height: 220,
            child: FutureBuilder<List<RunningApp>>(
              future: _open,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final open = [
                  for (final a in snap.data!)
                    if (!_systemApps.contains(a.exe) && !_apps.contains(a.exe))
                      a,
                ];
                if (open.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum outro programa com janela aberta.',
                      style: OcText.caption,
                    ),
                  );
                }
                return ListView(
                  children: [
                    for (final a in open)
                      Hover(
                        onTap: () => _add(a.exe),
                        builder: (context, h) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: h ? Oc.hover : Colors.transparent,
                            borderRadius: Oc.r8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OcText.body,
                                    ),
                                    Text(a.exe, style: OcText.caption),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: Oc.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      OcButton(
        label: 'Procurar .exe',
        icon: Icons.folder_open_rounded,
        onPressed: _browse,
      ),
      OcButton(label: 'Cancelar', onPressed: () => Navigator.pop(context)),
      OcButton(
        label: 'Salvar',
        variant: OcButtonVariant.primary,
        onPressed: () => Navigator.pop(context, _apps),
      ),
    ],
  );
}
