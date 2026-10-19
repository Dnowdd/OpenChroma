import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../i18n/pt_br.dart';

/// One adjustable effect parameter (an HTML effect `<meta property=...>` or
/// an `.ocfx` `params` entry).
class EffectProperty {
  EffectProperty(this.attrs);
  final Map<String, String> attrs;

  String get name => attrs['property']!;
  String get label => attrs['label'] ?? name;
  String get type => attrs['type'] ?? 'textfield';
  String get tooltip => attrs['tooltip'] ?? '';
  String get defaultValue => attrs['default'] ?? '';
  double get min => double.tryParse(attrs['min'] ?? '') ?? 0;
  double get max => double.tryParse(attrs['max'] ?? '') ?? 100;
  List<String> get values =>
      (attrs['values'] ?? '').split(',').where((s) => s.isNotEmpty).toList();

  /// The JS value the effect sees as the global `name`.
  Object coerce(Object? v) {
    final s = v ?? defaultValue;
    switch (type) {
      case 'boolean':
        return s == true || s == 'true' || s == '1' || s == 1;
      case 'number':
        return s is num ? s : (double.tryParse(s.toString()) ?? min);
      case 'hue':
        return s is num ? s : (double.tryParse(s.toString()) ?? 0);
      default:
        return s.toString();
    }
  }
}

enum EffectKind { html, ocfx }

class EffectInfo {
  EffectInfo({
    required this.path,
    required this.title,
    required this.description,
    required this.author,
    required this.properties,
    required this.thumbnail,
    required this.kind,
    required this.imported,
    this.usesAudio = false,
    this.definition,
  });

  final String path;
  final String title;
  final String description;
  final String author;
  final List<EffectProperty> properties;

  /// A preview image shipped next to the effect, if any.
  final String? thumbnail;
  final EffectKind kind;

  /// Added by the user through "Importar" (can be removed).
  final bool imported;

  /// Reacts to sound, so audio capture runs while it is active.
  final bool usesAudio;

  /// Parsed `.ocfx` document, for [EffectKind.ocfx].
  final Map<String, dynamic>? definition;

  String get id => p.normalize(path).toLowerCase();
}

// ------------------------------------------------------------------ curation
/// Effects that need inputs this app does not capture (system audio, screen)
/// would just sit black, so they are left out of the library.
final _unsupportedInputs = RegExp(r'engine\.(audio|zone|vision)');

/// Effects that technically run but read poorly on LEDs (e.g. thousands of
/// random dots, which turn into flicker).
const _hidden = {'biohazard'};

// --------------------------------------------------------------------- HTML
final _metaTag = RegExp(
  r'<meta\b([^>]*?)/?>',
  caseSensitive: false,
  dotAll: true,
);
final _attr = RegExp(r'''([A-Za-z_:][\w:.-]*)\s*=\s*("([^"]*)"|'([^']*)')''');
final _title = RegExp(r'<title>([^<]*)</title>', caseSensitive: false);

Map<String, String> _parseAttrs(String s) => {
  for (final m in _attr.allMatches(s))
    m.group(1)!.toLowerCase(): m.group(3) ?? m.group(4) ?? '',
};

/// Parses an HTML effect. Returns null when it cannot be read or needs
/// unsupported inputs (unless [force]).
EffectInfo? parseHtmlEffect(
  String path, {
  bool imported = false,
  bool force = false,
}) {
  String html;
  try {
    html = File(path).readAsStringSync();
  } catch (_) {
    return null;
  }
  if (!force && _unsupportedInputs.hasMatch(html)) return null;
  // Only the <head> carries metadata; ignore commented-out metas.
  final headEnd = html.toLowerCase().indexOf('</head>');
  var head = headEnd > 0 ? html.substring(0, headEnd) : html;
  head = head.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  var description = '', author = '';
  final props = <EffectProperty>[];
  for (final m in _metaTag.allMatches(head)) {
    final a = _parseAttrs(m.group(1)!);
    if (a.containsKey('property')) {
      if (hiddenParameters.contains((a['label'] ?? '').toLowerCase())) continue;
      props.add(EffectProperty(a));
    } else if (a.containsKey('description')) {
      description = a['description']!;
    } else if (a.containsKey('publisher')) {
      author = a['publisher']!;
    }
  }
  final dir = p.dirname(path);
  final base = p.basenameWithoutExtension(path).toLowerCase();
  String? thumb;
  try {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final n = p.basename(f.path).toLowerCase();
      if (n == '$base.png' || n == '$base.jpg') thumb = f.path;
    }
  } catch (_) {}
  final rawTitle = _title.firstMatch(head)?.group(1)?.trim();
  final original = (rawTitle == null || rawTitle.isEmpty)
      ? p.basenameWithoutExtension(path)
      : rawTitle;
  final key = original.toLowerCase();
  return EffectInfo(
    path: path,
    title: effectTitles[key] ?? original,
    description: effectDescriptions[key] ?? _firstSentence(description),
    author: author,
    properties: props,
    thumbnail: thumb,
    kind: EffectKind.html,
    imported: imported,
    usesAudio: html.contains('engine.audio'),
  );
}

String _firstSentence(String s) {
  final i = s.indexOf(RegExp(r'[.!?](\s|$)'));
  return (i > 0 ? s.substring(0, i + 1) : s).trim();
}

// --------------------------------------------------------------------- OCFX
const ocfxLayerTypes = {
  'solid',
  'gradient',
  'spectrum',
  'pulse',
  'wave',
  'sweep',
  'rings',
  'sparkle',
  'plasma',
  'noise',
  'fire',
  'rain',
  'stars',
  'heartbeat',
  'strobe',
  // Audio-reactive
  'bars',
  'meter',
  'ripple',
  'flash',
};
const _audioLayerTypes = {'bars', 'meter', 'ripple', 'flash'};
const _paramTypes = {'number', 'color', 'boolean', 'combobox', 'hue'};

/// Parses and validates an `.ocfx` effect. Throws [FormatException] with a
/// user-facing message when the document is invalid.
EffectInfo parseOcfx(String path, {bool imported = false}) {
  Object? doc;
  try {
    doc = jsonDecode(File(path).readAsStringSync());
  } on FormatException catch (e) {
    throw FormatException('O arquivo não é um JSON válido (${e.message}).');
  }
  if (doc is! Map<String, dynamic>) {
    throw const FormatException('O arquivo precisa ser um objeto JSON.');
  }
  if (doc['openchroma'] != 1) {
    throw const FormatException('Falta o campo "openchroma": 1.');
  }
  final name = doc['name'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('Falta o campo "name".');
  }
  final layers = doc['layers'];
  if (layers is! List || layers.isEmpty) {
    throw const FormatException(
      'O efeito precisa de pelo menos uma camada em "layers".',
    );
  }
  for (var i = 0; i < layers.length; i++) {
    final l = layers[i];
    if (l is! Map || !ocfxLayerTypes.contains(l['type'])) {
      throw FormatException(
        'Camada ${i + 1}: "type" deve ser um destes: ${ocfxLayerTypes.join(', ')}.',
      );
    }
  }
  final props = <EffectProperty>[];
  final params = doc['params'];
  if (params != null && params is! Map) {
    throw const FormatException('"params" precisa ser um objeto.');
  }
  (params as Map? ?? {}).forEach((key, value) {
    if (value is! Map || !_paramTypes.contains(value['type'])) {
      throw FormatException(
        'Parâmetro "$key": "type" deve ser ${_paramTypes.join(', ')}.',
      );
    }
    props.add(
      EffectProperty({
        'property': '$key',
        'label': '${value['label'] ?? key}',
        'type': '${value['type']}',
        if (value['min'] != null) 'min': '${value['min']}',
        if (value['max'] != null) 'max': '${value['max']}',
        if (value['default'] != null) 'default': '${value['default']}',
        if (value['values'] is List)
          'values': (value['values'] as List).join(','),
        if (value['description'] != null) 'tooltip': '${value['description']}',
      }),
    );
  });
  return EffectInfo(
    path: path,
    title: name.trim(),
    description: '${doc['description'] ?? ''}',
    author: '${doc['author'] ?? ''}',
    properties: props,
    thumbnail: null,
    kind: EffectKind.ocfx,
    imported: imported,
    // Audio layers, or any value bound to an audio signal ("@bass", ...).
    usesAudio:
        layers.any((l) => _audioLayerTypes.contains((l as Map)['type'])) ||
        jsonEncode(layers).contains('"@'),
    definition: doc,
  );
}

/// Builds the library: HTML effects from [htmlRoots], `.ocfx` effects from
/// [bundledDir], and anything the user imported into [importedDir].
List<EffectInfo> scanEffects({
  required List<String> htmlRoots,
  required String bundledDir,
  required String importedDir,
}) {
  final out = <EffectInfo>[];
  final seen = <String>{};

  void add(EffectInfo? e) {
    if (e == null || _hidden.contains(e.title.toLowerCase())) return;
    if (!seen.add(e.title.toLowerCase())) return;
    out.add(e);
  }

  Iterable<File> files(String dir, {bool recursive = true}) {
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    return d.listSync(recursive: recursive).whereType<File>();
  }

  // User imports win over bundled/third-party effects with the same name.
  for (final f in files(importedDir, recursive: false)) {
    final lower = f.path.toLowerCase();
    if (lower.endsWith('.ocfx') || lower.endsWith('.json')) {
      try {
        add(parseOcfx(f.path, imported: true));
      } on FormatException {
        // Invalid imports are rejected at import time; skip stale ones.
      }
    } else if (lower.endsWith('.html')) {
      add(parseHtmlEffect(f.path, imported: true, force: true));
    }
  }
  for (final f in files(bundledDir, recursive: false)) {
    if (f.path.toLowerCase().endsWith('.ocfx')) {
      try {
        add(parseOcfx(f.path));
      } on FormatException {
        // Bundled effects are validated in tests.
      }
    }
  }
  for (final root in htmlRoots) {
    for (final f in files(root)) {
      if (f.path.toLowerCase().endsWith('.html')) add(parseHtmlEffect(f.path));
    }
  }
  out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return out;
}
