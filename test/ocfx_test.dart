import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/effects/effect_library.dart';
import 'package:openchroma/src/i18n/l10n.dart';
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

  group('translations', () {
    tearDown(() => l10n = lookupAppLocalizations(const Locale('en')));

    File write(String name, Map<String, dynamic> doc) =>
        File('${Directory.systemTemp.path}/$name.ocfx')
          ..writeAsStringSync(jsonEncode(doc));

    final doc = {
      'openchroma': 1,
      'name': 'Waves',
      'description': 'Blue waves.',
      'params': {
        'speed': {'label': 'Speed', 'type': 'number'},
        'mode': {
          'label': 'Mode',
          'type': 'combobox',
          'values': ['fast', 'slow'],
        },
      },
      'i18n': {
        'pt-BR': {
          'name': 'Ondas',
          'description': 'Ondas azuis.',
          'params': {
            'speed': 'Velocidade',
            'mode': {
              'label': 'Modo',
              'options': {'fast': 'Rápido'},
            },
          },
        },
      },
      'layers': [
        {'type': 'solid', 'color': '#ffffff'},
      ],
    };

    test('English is the default', () {
      final e = parseOcfx(write('i18n-en', doc).path);
      expect(e.title, 'Waves');
      expect(e.description, 'Blue waves.');
      expect(e.properties.first.label, 'Speed');
      expect(e.properties.last.optionLabel('fast'), 'fast');
      expect(e.allTitles, {'Waves', 'Ondas'});
    });

    test('the matching locale overrides the texts', () {
      final e = parseOcfx(write('i18n-pt', doc).path);
      l10n = lookupAppLocalizations(const Locale('pt'));
      expect(e.title, 'Ondas');
      expect(e.baseTitle, 'Waves');
      expect(e.description, 'Ondas azuis.');
      expect(e.properties.first.label, 'Velocidade');
      expect(e.properties.last.label, 'Modo');
      expect(e.properties.last.optionLabel('fast'), 'Rápido');
      expect(e.properties.last.optionLabel('slow'), 'slow');
    });

    test('files without translations show their own text', () {
      final e = parseOcfx(
        write('i18n-none', {
          'openchroma': 1,
          'name': 'Pôr do Sol',
          'params': {
            'speed': {'label': 'Rapidez', 'type': 'number'},
          },
          'layers': [
            {'type': 'solid', 'color': '#ffffff'},
          ],
        }).path,
      );
      for (final code in ['en', 'pt']) {
        l10n = lookupAppLocalizations(Locale(code));
        expect(e.title, 'Pôr do Sol');
        expect(e.properties.single.label, 'Rapidez');
      }
    });

    test('bundled effects are translated to Portuguese', () {
      l10n = lookupAppLocalizations(const Locale('pt'));
      final e = parseOcfx('assets/effects/aurora.ocfx');
      expect(e.properties.first.label, 'Velocidade');
      for (final f in bundled) {
        final e = parseOcfx(f.path);
        expect(e.translations['pt']?.name, isNotNull, reason: e.baseTitle);
        expect(
          e.properties.every((p) => p.translations['pt']?.label != null),
          isTrue,
          reason: e.baseTitle,
        );
      }
    });

    test('English parameter names are translated only in Portuguese', () {
      final p = EffectProperty({'property': 'speed', 'label': 'Speed'});
      expect(p.label, 'Speed');
      l10n = lookupAppLocalizations(const Locale('pt'));
      expect(p.label, 'Velocidade');
    });

    test('rejects a malformed i18n block', () {
      final bad = write('i18n-bad', {...doc, 'i18n': 'pt'});
      expect(() => parseOcfx(bad.path), throwsFormatException);
    });
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

  test('huge or non-finite counts cannot stall a frame', () {
    final r = OcfxRenderer({
      'layers': [
        {'type': 'rain', 'density': 1e12},
        {'type': 'stars', 'density': 'Infinity'},
        {'type': 'sparkle', 'density': double.nan},
        {'type': 'rings', 'spacing': double.infinity},
        {'type': 'bars', 'count': 1e9},
      ],
    });
    final watch = Stopwatch()..start();
    r.render(1);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
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
