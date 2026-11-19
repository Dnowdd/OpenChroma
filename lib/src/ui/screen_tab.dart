import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'screen_editor.dart';
import 'theme.dart';
import 'widgets.dart';

const _imageTypes = XTypeGroup(
  label: 'Imagens e GIFs',
  extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
);

/// A device's own screen: what it shows, and editing and sending a new
/// image or GIF.
class ScreenTab extends StatefulWidget {
  const ScreenTab({super.key, required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  @override
  State<ScreenTab> createState() => _ScreenTabState();
}

class _ScreenTabState extends State<ScreenTab> {
  PreviewFrames? _frames;
  String? _loadedPath;

  Engine get engine => widget.engine;
  DeviceInstance get device => widget.device;

  void _loadPreview(String? path) {
    if (path == _loadedPath) return;
    _loadedPath = path;
    final old = _frames;
    _frames = null;
    old?.dispose();
    if (path == null) return;
    PreviewFrames.load(path).then((f) {
      if (!mounted || _loadedPath != path) return f.dispose();
      setState(() => _frames = f);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _frames?.dispose();
    super.dispose();
  }

  Future<void> _edit(String path, ScreenEdit? initial) async {
    final edit = await showScreenEditor(
      context,
      spec: device.screen!,
      path: path,
      initial: initial,
    );
    if (edit == null) return;
    if (await engine.sendToScreen(device, path, edit: edit)) {
      _loadedPath = null;
      _loadPreview(engine.screenImagePath(device));
    }
  }

  Future<void> _pick() async {
    final file = await openFile(acceptedTypeGroups: const [_imageTypes]);
    if (file != null) await _edit(file.path, null);
  }

  @override
  Widget build(BuildContext context) {
    final spec = device.screen!;
    final path = engine.screenImagePath(device);
    _loadPreview(path);
    final progress = device.screenProgress;
    final busy = progress != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: path == null
                ? AspectRatio(
                    aspectRatio: spec.width / spec.height,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: spec.round
                            ? BoxShape.circle
                            : BoxShape.rectangle,
                        borderRadius: spec.round ? null : Oc.r12,
                        border: Border.all(color: Oc.lineStrong, width: 6),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: Oc.textTertiary,
                      ),
                    ),
                  )
                : ScreenPreview(
                    spec: spec,
                    frames: _frames,
                    edit: engine.screenEdit(device),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        OcPanel(
          children: [
            OcRow(
              leading: const Icon(
                Icons.wallpaper_rounded,
                size: 18,
                color: Oc.textTertiary,
              ),
              title: 'Imagem ou GIF',
              description: busy
                  ? 'Enviando… ${(progress * 100).round()}%'
                  : device.screenError ??
                        'Recorte, escolha o trecho e escreva por cima antes de '
                            'enviar. A tela guarda o que receber, mesmo com o '
                            'app fechado.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (path != null) ...[
                    OcButton(
                      label: 'Editar',
                      icon: Icons.tune_rounded,
                      onPressed: busy
                          ? null
                          : () => _edit(path, engine.screenEdit(device)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OcButton(
                    label: 'Escolher arquivo',
                    icon: Icons.folder_open_rounded,
                    onPressed: busy ? null : _pick,
                  ),
                ],
              ),
            ),
            if (busy)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: ClipRRect(
                  borderRadius: Oc.pill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Oc.hover,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
