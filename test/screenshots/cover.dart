import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/ui/accent.dart';
import 'package:openchroma/src/ui/logo.dart';
import 'package:path/path.dart' as p;

import 'scene.dart';

const _mint = Color(0xFF3CFFB4);

class _FixedAccent extends AccentController {
  _FixedAccent(super.engine);

  @override
  Color get value => _mint;
}

Future<void> shootCover(
  WidgetTester tester,
  EffectCovers covers,
  String name,
  Size size, {
  double ratio = pixelRatio,
}) async {
  final aurora = covers.effects.firstWhere(
    (effect) => p.basename(effect.path) == 'aurora.ocfx',
  );
  final image = (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(covers.pngs[aurora.path]!);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }))!;
  final dir = Directory.systemTemp.createTempSync('oc_cover');
  final accent = _FixedAccent(Engine(dataDir: dir.path));
  final key = GlobalKey();
  final blur = size.height * .024;
  tester.view
    ..physicalSize = size * ratio
    ..devicePixelRatio = ratio;

  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: LiveAccent(
          controller: accent,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur,
                    tileMode: TileMode.clamp,
                  ),
                  child: RawImage(
                    image: image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: .95,
                      colors: [Color(0xB3080B14), Color(0x54080B14)],
                    ),
                  ),
                ),
                Center(child: OcLogo(height: size.width * .126)),
              ],
            ),
          ),
        ),
      ),
    );
    await capture(tester, key, name, ratio: ratio);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.reset();
    accent.dispose();
    image.dispose();
    dir.deleteSync(recursive: true);
  }
}
