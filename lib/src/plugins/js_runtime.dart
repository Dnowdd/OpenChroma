import 'dart:convert';

import 'package:flutter_js/quickjs/quickjs_runtime2.dart';

import 'plugin_api.dart';

typedef HostHandler = Object? Function(String method, List<dynamic> args);

class PluginError implements Exception {
  PluginError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One QuickJS context running one plugin file for one device.
class JsRuntime {
  JsRuntime(HostHandler host) {
    _js.onMessage('h', (dynamic args) {
      final list = args as List;
      return host(list.first as String, list.sublist(1));
    });
    eval(pluginApiJs, name: 'openchroma-api.js');
  }

  final QuickJsRuntime2 _js = QuickJsRuntime2();

  /// Evaluates [code] in global scope; throws [PluginError] on JS errors.
  Object? eval(String code, {String name = '<eval>'}) {
    final r = _js.evaluate(code, name: name);
    if (r.isError) throw PluginError(r.stringResult);
    return r.rawResult;
  }

  /// Evaluates [expression] and decodes its JSON result.
  dynamic evalJson(String expression) {
    final raw = eval('JSON.stringify($expression)');
    if (raw == null || raw == 'undefined') return null;
    return jsonDecode(raw as String);
  }

  void dispose() {
    try {
      _js.dispose();
    } catch (_) {}
  }
}
