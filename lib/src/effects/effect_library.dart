import 'dart:io';

import 'package:path/path.dart' as p;

/// One `<meta property=...>` control declared by a SignalRGB effect.
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

class EffectInfo {
  EffectInfo({
    required this.path,
    required this.title,
    required this.description,
    required this.publisher,
    required this.properties,
    required this.thumbnail,
    required this.source,
  });

  final String path;
  final String title;
  final String description;
  final String publisher;
  final List<EffectProperty> properties;
  final String? thumbnail;

  /// 'Built-in', 'User' or 'Marketplace cache'.
  final String source;

  String get id => p.normalize(path).toLowerCase();
}

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

EffectInfo? parseEffect(String path, String source) {
  String html;
  try {
    html = File(path).readAsStringSync();
  } catch (_) {
    return null;
  }
  // Only the <head> carries metadata; ignore commented-out metas.
  final headEnd = html.toLowerCase().indexOf('</head>');
  var head = headEnd > 0 ? html.substring(0, headEnd) : html;
  head = head.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  var description = '', publisher = '';
  final props = <EffectProperty>[];
  for (final m in _metaTag.allMatches(head)) {
    final a = _parseAttrs(m.group(1)!);
    if (a.containsKey('property')) {
      props.add(EffectProperty(a));
    } else if (a.containsKey('description')) {
      description = a['description']!;
    } else if (a.containsKey('publisher')) {
      publisher = a['publisher']!;
    }
  }
  final dir = p.dirname(path);
  final base = p.basenameWithoutExtension(path).toLowerCase();
  String? thumb;
  try {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      final n = p.basename(f.path).toLowerCase();
      if (n == '$base.png' || n == '$base.jpg' || n == '$base.gif') {
        thumb = f.path;
      }
    }
  } catch (_) {}
  final title = _title.firstMatch(head)?.group(1)?.trim();
  return EffectInfo(
    path: path,
    title: (title == null || title.isEmpty)
        ? p.basenameWithoutExtension(path)
        : title,
    description: description,
    publisher: publisher,
    properties: props,
    thumbnail: thumb,
    source: source,
  );
}

List<EffectInfo> scanEffects(List<String> roots) {
  final out = <EffectInfo>[];
  final seen = <String>{};
  for (var i = 0; i < roots.length; i++) {
    final dir = Directory(roots[i]);
    if (!dir.existsSync()) continue;
    final source = i == 0
        ? 'Built-in'
        : (i == roots.length - 1 ? 'Marketplace cache' : 'User');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.toLowerCase().endsWith('.html')) continue;
      final e = parseEffect(f.path, source);
      if (e == null || !seen.add(e.title.toLowerCase())) continue;
      out.add(e);
    }
  }
  out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return out;
}
