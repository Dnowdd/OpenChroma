import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/engine/legacy_names.dart';

void main() {
  test('renames pre-0.9 plugin names once and keeps everything else', () {
    final settings = <String, dynamic>{
      'devices': {
        'k86': {
          'layout': {
            'zone:Teclado': {'x': 1},
            'zone:Teclado#1': {'x': 2},
            'zone:Mainboard': {'x': 3},
          },
          'hwMode': 'Ondas',
          'hwModeOptions': {
            'Ondas': {'speed': 3},
            'Static': {'speed': 1},
          },
          'props': {'colorMode': 'Ao vivo B', 'other': 'Nunca', 'n': 4},
        },
        'ds4': {
          'layout': {
            'zone:Barra de luz': {'x': 4},
          },
        },
      },
    };
    expect(migrateLegacyNames(settings), isTrue);
    final k86 = settings['devices']['k86'] as Map;
    expect((k86['layout'] as Map).keys, {
      'zone:Keyboard',
      'zone:Keyboard#1',
      'zone:Mainboard',
    });
    expect(k86['layout']['zone:Keyboard'], {'x': 1});
    expect(k86['hwMode'], 'Waves');
    expect((k86['hwModeOptions'] as Map).keys, {'Waves', 'Static'});
    expect(k86['props'], {'colorMode': 'Live B', 'other': 'Never', 'n': 4});
    expect((settings['devices']['ds4']['layout'] as Map).keys, {
      'zone:Light bar',
    });

    k86['hwMode'] = 'Ondas';
    expect(migrateLegacyNames(settings), isFalse);
    expect(k86['hwMode'], 'Ondas');
  });

  test('a fresh settings file is only stamped', () {
    final settings = <String, dynamic>{};
    expect(migrateLegacyNames(settings), isTrue);
    expect(settings, {'namesVersion': legacyNamesVersion});
  });
}
