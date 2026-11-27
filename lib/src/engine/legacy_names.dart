const _legacyNames = {
  'Teclado': 'Keyboard',
  'Barra de luz': 'Light bar',
  'Cor fixa': 'Static',
  'Respirar': 'Breathing',
  'Respirar colorido': 'Color breathing',
  'Desligado': 'Off',
  'Arco-íris': 'Rainbow',
  'Deriva': 'Drift',
  'Ondas': 'Waves',
  'Estrelas': 'Stars',
  'Correnteza': 'Flow',
  'Ao digitar': 'Reactive',
  'Senoide': 'Sine wave',
  'Flores': 'Flowers',
  'Chuva': 'Rain',
  'Neve': 'Snow',
  'Meteoro': 'Meteor',
  'Imagem 1 do teclado': 'Keyboard picture 1',
  'Imagem 2 do teclado': 'Keyboard picture 2',
  'Imagem 3 do teclado': 'Keyboard picture 3',
};

const _legacyValues = {
  'Automático': 'Auto',
  'Ao vivo A': 'Live A',
  'Ao vivo B': 'Live B',
  'Compatível': 'Compatible',
  'Quando o efeito para': 'When the effect stops',
  'Nunca': 'Never',
};

const legacyNamesVersion = 2;

/// Rewrites the Portuguese zone, hardware mode and plugin option names that
/// bundled plugins used before 0.9.0, so saved layouts and modes still match.
/// Returns whether anything changed.
bool migrateLegacyNames(Map<String, dynamic> settings) {
  if ((settings['namesVersion'] as int? ?? 1) >= legacyNamesVersion) {
    return false;
  }
  settings['namesVersion'] = legacyNamesVersion;
  final devices = settings['devices'];
  if (devices is! Map) return true;
  for (final ds in devices.values) {
    if (ds is! Map) continue;
    final layout = ds['layout'];
    if (layout is Map) {
      for (final key in layout.keys.toList()) {
        final renamed = _zoneKey('$key');
        if (renamed != key && !layout.containsKey(renamed)) {
          layout[renamed] = layout.remove(key);
        }
      }
    }
    final mode = ds['hwMode'];
    if (mode is String && _legacyNames.containsKey(mode)) {
      ds['hwMode'] = _legacyNames[mode];
    }
    final options = ds['hwModeOptions'];
    if (options is Map) {
      for (final key in options.keys.toList()) {
        final renamed = _legacyNames['$key'];
        if (renamed != null && !options.containsKey(renamed)) {
          options[renamed] = options.remove(key);
        }
      }
    }
    final props = ds['props'];
    if (props is Map) {
      for (final key in props.keys.toList()) {
        final value = props[key];
        if (value is String && _legacyValues.containsKey(value)) {
          props[key] = _legacyValues[value];
        }
      }
    }
  }
  return true;
}

String _zoneKey(String key) {
  if (!key.startsWith('zone:')) return key;
  final rest = key.substring(5);
  final hash = rest.lastIndexOf('#');
  final name = hash < 0 ? rest : rest.substring(0, hash);
  final suffix = hash < 0 ? '' : rest.substring(hash);
  final renamed = _legacyNames[name];
  return renamed == null ? key : 'zone:$renamed$suffix';
}
