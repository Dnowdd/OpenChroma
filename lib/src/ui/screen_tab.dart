import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../i18n/l10n.dart';
import 'screen_editor.dart';
import 'theme.dart';
import 'widgets.dart';

XTypeGroup get _imageTypes => XTypeGroup(
  label: l10n.screenImageFiles,
  extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
);

/// What a device's screen shows: the image last sent, animated, with its
/// texts and live values.
class DeviceScreenView extends StatefulWidget {
  const DeviceScreenView({
    super.key,
    required this.engine,
    required this.device,
  });
  final Engine engine;
  final DeviceInstance device;

  @override
  State<DeviceScreenView> createState() => _DeviceScreenViewState();
}

class _DeviceScreenViewState extends State<DeviceScreenView> {
  PreviewFrames? _frames;
  String? _loadedPath;

  void _loadPreview(String? path) {
    final key = path == null
        ? null
        : '$path|${File(path).lastModifiedSync().microsecondsSinceEpoch}';
    if (key == _loadedPath) return;
    _loadedPath = key;
    final old = _frames;
    _frames = null;
    old?.dispose();
    if (path == null) return;
    PreviewFrames.load(path).then((f) {
      if (!mounted || _loadedPath != key) return f.dispose();
      setState(() => _frames = f);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _frames?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.engine,
    builder: (context, _) {
      final engine = widget.engine, device = widget.device;
      final spec = device.screen!;
      final path = engine.screenImagePath(device);
      final edit = engine.screenEdit(device);
      _loadPreview(path);
      if (path == null) {
        return AspectRatio(
          aspectRatio: spec.width / spec.height,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              shape: spec.round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: spec.round ? null : Oc.r12,
              border: Border.all(color: Oc.lineStrong, width: 6),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 32,
              color: Oc.textTertiary,
            ),
          ),
        );
      }
      return ScreenPreview(
        spec: spec,
        frames: _frames,
        edit: edit,
        readSensor: engine.readSensor,
      );
    },
  );
}

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
  Engine get engine => widget.engine;
  DeviceInstance get device => widget.device;

  Future<void> _edit(String path, ScreenEdit? initial) async {
    final edit = await showScreenEditor(
      context,
      spec: device.screen!,
      path: path,
      initial: initial,
      readSensor: engine.readSensor,
    );
    if (edit == null) return;
    await engine.sendToScreen(device, path, edit: edit);
  }

  Future<void> _pick() async {
    final file = await openFile(acceptedTypeGroups: [_imageTypes]);
    if (file != null) await _edit(file.path, null);
  }

  @override
  Widget build(BuildContext context) {
    final path = engine.screenImagePath(device);
    final progress = device.screenProgress;
    final busy = progress != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DeviceScreenView(engine: engine, device: device),
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
              title: l10n.screenImageOrGif,
              description: busy
                  ? l10n.screenSending((progress * 100).round())
                  : device.screenError ?? l10n.screenImageHint,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (path != null) ...[
                    OcButton(
                      label: l10n.screenEdit,
                      icon: Icons.tune_rounded,
                      onPressed: busy
                          ? null
                          : () => _edit(path, engine.screenEdit(device)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OcButton(
                    label: l10n.screenChooseFile,
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
