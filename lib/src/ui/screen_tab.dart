import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';
import 'widgets.dart';

const _imageTypes = XTypeGroup(
  label: 'Imagens e GIFs',
  extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
);

/// A device's own screen: what it shows and sending it a new image or GIF.
class ScreenTab extends StatelessWidget {
  const ScreenTab({super.key, required this.engine, required this.device});
  final Engine engine;
  final DeviceInstance device;

  Future<void> _pick() async {
    final file = await openFile(acceptedTypeGroups: const [_imageTypes]);
    if (file != null) await engine.sendToScreen(device, file.path);
  }

  @override
  Widget build(BuildContext context) {
    final spec = device.screen!;
    final path = engine.screenImagePath(device);
    final progress = device.screenProgress;
    final busy = progress != null;
    final fill = engine.screenFill(device);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AspectRatio(
              aspectRatio: spec.width / spec.height,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: Oc.r12,
                  border: Border.all(color: Oc.lineStrong, width: 6),
                ),
                clipBehavior: Clip.antiAlias,
                child: path == null
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: Oc.textTertiary,
                        ),
                      )
                    : Image.file(
                        File(path),
                        // A new file at the same path must show again.
                        key: ValueKey('$path${File(path).lastModifiedSync()}'),
                        fit: fill ? BoxFit.cover : BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
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
                        'A tela guarda o que receber, mesmo com o app fechado. '
                            'GIFs com mais de ${spec.maxFrames} quadros são '
                            'reduzidos; cada quadro leva alguns segundos.',
              trailing: OcButton(
                label: 'Escolher arquivo',
                icon: Icons.folder_open_rounded,
                onPressed: busy ? null : _pick,
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
            OcRow(
              title: 'Ajuste',
              description: fill
                  ? 'Preenche a tela; as bordas da imagem podem ficar de fora.'
                  : 'Mostra a imagem inteira, com faixas pretas se precisar.',
              trailing: OcSegmented<bool>(
                value: fill,
                options: const [(true, 'Preencher'), (false, 'Inteira')],
                onChanged: busy
                    ? (_) {}
                    : (v) => engine.setScreenFill(device, v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
