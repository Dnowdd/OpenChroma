import 'dart:convert';

import 'package:flutter_js/quickjs/quickjs_runtime2.dart';

import 'prelude.dart';

typedef HostHandler = Object? Function(String method, List<dynamic> args);

class PluginError implements Exception {
  PluginError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One QuickJS context hosting one plugin instance (SignalRGB keeps module
/// state per device, so every device gets its own runtime).
class PluginRuntime {
  PluginRuntime(HostHandler host) {
    _js.onMessage('h', (dynamic args) {
      final list = args as List;
      return host(list.first as String, list.sublist(1));
    });
    eval(pluginPrelude, name: 'prelude.js');
  }

  final QuickJsRuntime2 _js = QuickJsRuntime2();

  /// Evaluates [code] in global scope; throws [PluginError] on JS exceptions.
  Object? eval(String code, {String name = '<eval>'}) {
    final r = _js.evaluate(code, name: name);
    if (r.isError) throw PluginError(r.stringResult);
    return r.rawResult;
  }

  /// Evaluates [expression] and returns it decoded from JSON.
  dynamic evalJson(String expression) {
    final raw = eval('JSON.stringify($expression)');
    if (raw == null || raw == 'undefined') return null;
    return jsonDecode(raw as String);
  }

  bool hasFunction(String name) =>
      eval("typeof globalThis['$name'] === 'function'") == true;

  /// Calls a global plugin function with JSON-encodable arguments.
  dynamic call(String name, [List<Object?> args = const []]) {
    return evalJson('$name(${args.map(jsonEncode).join(',')})');
  }

  dynamic callIfPresent(String name, [List<Object?> args = const []]) =>
      hasFunction(name) ? call(name, args) : null;

  void dispose() {
    try {
      _js.dispose();
    } catch (_) {}
  }
}
