import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/effects/effect_library.dart';
import 'package:openchroma/src/effects/ocfx_player.dart';
import 'package:openchroma/src/effects/ocfx_renderer.dart';

void main() {
  final bundled = Directory('assets/effects')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ocfx'))
      .toList();

  test('bundled effects exist', () => expect(bundled, isNotEmpty));

  for (final f in bundled) {
    test('${f.uri.pathSegments.last} is a valid effect', () {
      final e = parseOcfx(f.path);
      expect(e.title, isNotEmpty);
      expect(e.description, isNotEmpty);
      final params = e.properties.map((p) => p.name).toSet();
      // Every "$name" reference must point at a declared parameter.
      final refs = RegExp(r'"\$(\w+)"')
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(1));
      expect(refs.where((r) => !params.contains(r)), isEmpty);
    });
  }

  test('audio effects are detected as audio-reactive', () {
    for (final name in [
      'spectrum',
      'neon-equalizer',
      'bass-pulse',
      'beat',
      'sound-wave',
      'volume-meter',
    ]) {
      expect(
        parseOcfx('assets/effects/$name.ocfx').usesAudio,
        isTrue,
        reason: name,
      );
    }
    expect(parseOcfx('assets/effects/aurora.ocfx').usesAudio, isFalse);
  });

  test('rejects documents without layers', () {
    final tmp = File('${Directory.systemTemp.path}/bad.ocfx')
      ..writeAsStringSync('{"openchroma": 1, "name": "x", "layers": []}');
    expect(() => parseOcfx(tmp.path), throwsFormatException);
  });

  Map<String, Object> defaults(EffectInfo e) => {
    for (final p in e.properties) p.name: p.coerce(null),
  };

  test('every bundled effect renders lit frames of the right size', () {
    for (final f in bundled) {
      final e = parseOcfx(f.path);
      final r = OcfxRenderer(e.definition!)..params = defaults(e);
      var lit = 0;
      for (var t = 0.0; t < 3; t += 0.25) {
        r.audio = demoAudio(t);
        final rgb = r.render(t);
        expect(rgb.length, 160 * 100 * 3, reason: e.title);
        lit = rgb.fold(lit, (m, v) => v > m ? v : m);
      }
      expect(lit, greaterThan(40), reason: e.title);
    }
  });

  test('frames depend only on the time', () {
    final e = parseOcfx('assets/effects/aurora.ocfx');
    final a = OcfxRenderer(e.definition!)..params = defaults(e);
    final b = OcfxRenderer(e.definition!)..params = defaults(e);
    a.render(0.4);
    expect(a.render(1.3), b.render(1.3));
  });

  test('a solid layer fills the canvas with its color', () {
    final r = OcfxRenderer(
      {
        'layers': [
          {'type': 'solid', 'color': r'$color'},
        ],
      },
      width: 4,
      height: 2,
    )..params = {'color': '#3200ff'};
    final rgb = r.render(0);
    for (var i = 0; i < rgb.length; i += 3) {
      expect([rgb[i], rgb[i + 1], rgb[i + 2]], [0x32, 0x00, 0xff]);
    }
  });

  test('covers render as PNG', () async {
    final e = parseOcfx('assets/effects/rainbow.ocfx');
    final png = await renderOcfxCover(e, defaults(e));
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
  });
}
