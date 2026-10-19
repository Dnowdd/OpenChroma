import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final _importDefault = RegExp(
  r'''^[ \t]*import\s+([A-Za-z_$][\w$]*)\s+from\s+["']([^"']+)["'];?''',
  multiLine: true,
);
final _importNamed = RegExp(
  r'''^[ \t]*import\s*\{([^}]*)\}\s*from\s*["']([^"']+)["'];?''',
  multiLine: true,
);
final _importStar = RegExp(
  r'''^[ \t]*import\s*\*\s*as\s+([A-Za-z_$][\w$]*)\s+from\s*["']([^"']+)["'];?''',
  multiLine: true,
);
final _exportList = RegExp(r'^[ \t]*export\s*\{([^}]*)\};?', multiLine: true);
final _exportDefaultDecl = RegExp(
  r'^([ \t]*)export\s+default\s+(?=((async\s+)?function|class)\s+([A-Za-z_$][\w$]*))',
  multiLine: true,
);
final _exportDefault = RegExp(r'^([ \t]*)export\s+default\s+', multiLine: true);
final _exportDecl = RegExp(
  r'^([ \t]*)export\s+(?:(?:async\s+)?function\s*\*?\s*|class\s+|(?:const|let|var)\s+)([A-Za-z_$][\w$]*)',
  multiLine: true,
);
final _exportPrefix = RegExp(
  r'^([ \t]*)export\s+(?=(async\s+)?function|class|const|let|var)',
  multiLine: true,
);

class _Module {
  _Module(this.body, this.exports, this.defaultName);
  final String body;
  final Set<String> exports;
  final String? defaultName;
}

/// Turns a SignalRGB ES-module plugin into a classic script for QuickJS'
/// global scope. Exported functions become globals the host calls by name;
/// `@SignalRGB/*` imports resolve to the prelude's module shims, and each
/// relative import is evaluated once in its own function scope and bound to
/// the imported names.
String transformPlugin(String filePath) {
  final deps = StringBuffer();
  final ids = <String, String>{};
  final m = _transform(p.normalize(p.absolute(filePath)), deps, ids);
  return '$deps\n${m.body}\n${_declareGlobals(m.body)}';
}

final _globalComment = RegExp(r'/\*\s*global\s+([^*]*)\*/');
final _identifier = RegExp(r'^[A-Za-z_$][\w$]*');

/// Plugins list the properties they read as globals in a `/* global */`
/// lint comment, and some add a property only for certain models (e.g. DPI
/// settings on mice) yet read it everywhere. Declaring the listed names
/// keeps those reads from throwing a ReferenceError on the other models.
String _declareGlobals(String body) {
  final names = <String>{
    for (final m in _globalComment.allMatches(body))
      for (final part in m.group(1)!.split(RegExp(r'[\s,]+')))
        ?_identifier.firstMatch(part)?.group(0),
  };
  if (names.isEmpty) return '';
  // The leading semicolon ends whatever statement the plugin left open.
  return ';${jsonEncode(names.toList())}.forEach(function (n) '
      '{ if (!(n in globalThis)) globalThis[n] = undefined; });';
}

_Module _transform(String abs, StringBuffer deps, Map<String, String> ids) {
  var src = File(abs).readAsStringSync();
  if (src.startsWith('﻿')) src = src.substring(1);

  // Returns the expression that yields the imported module object.
  String moduleExpr(String spec) {
    if (!spec.startsWith('.')) return '__oc.module(${_q(spec)})';
    var dep = p.normalize(p.join(p.dirname(abs), spec));
    if (!dep.toLowerCase().endsWith('.js') && File('$dep.js').existsSync()) {
      dep = '$dep.js';
    }
    final key = dep.toLowerCase();
    final existing = ids[key];
    if (existing != null) return existing;
    final id = '__mod${ids.length}';
    ids[key] = id;
    if (!File(dep).existsSync()) {
      deps.writeln('var $id = {};');
      return id;
    }
    final m = _transform(dep, deps, ids);
    final exported = [
      for (final n in m.exports)
        "$n: typeof $n === 'undefined' ? undefined : $n",
      if (m.defaultName != null) 'default: ${m.defaultName}',
    ].join(', ');
    deps.writeln(
      'var $id = (function () {\n${m.body}\nreturn { $exported };\n})();',
    );
    return id;
  }

  src = src.replaceAllMapped(
    _importStar,
    (m) => 'var ${m.group(1)} = ${moduleExpr(m.group(2)!)};',
  );
  src = src.replaceAllMapped(_importNamed, (m) {
    final names = m
        .group(1)!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceAll(RegExp(r'\s+as\s+'), ': '))
        .join(', ');
    return 'var {$names} = ${moduleExpr(m.group(2)!)};';
  });
  src = src.replaceAllMapped(_importDefault, (m) {
    final spec = m.group(2)!;
    final expr = moduleExpr(spec);
    // Shim modules are the default export themselves.
    return spec.startsWith('.')
        ? 'var ${m.group(1)} = $expr.default;'
        : 'var ${m.group(1)} = $expr;';
  });

  final exports = <String>{};
  String? defaultName;
  for (final m in _exportDecl.allMatches(src)) {
    exports.add(m.group(2)!);
  }
  src = src.replaceAllMapped(_exportList, (m) {
    for (final part in m.group(1)!.split(',')) {
      final name = part.trim().split(RegExp(r'\s+as\s+')).first.trim();
      if (name.isNotEmpty) exports.add(name);
    }
    return '';
  });
  src = src.replaceAllMapped(_exportDefaultDecl, (m) {
    defaultName = m.group(4);
    return m.group(1)!;
  });
  if (_exportDefault.hasMatch(src)) {
    defaultName = '__default';
    src = src.replaceAllMapped(
      _exportDefault,
      (m) => '${m.group(1)}var __default = ',
    );
  }
  src = src.replaceAllMapped(_exportPrefix, (m) => m.group(1)!);
  return _Module(src, exports, defaultName);
}

String _q(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
