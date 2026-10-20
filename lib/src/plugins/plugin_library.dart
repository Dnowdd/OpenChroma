import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'js_runtime.dart';

/// A device model a plugin drives.
class PluginDevice {
  const PluginDevice(this.vid, this.pid, this.name);
  final int vid;
  final int pid;
  final String name;

  int get key => vid << 16 | pid;
}

/// What a plugin file declares, read without opening any device.
class PluginInfo {
  PluginInfo({
    required this.path,
    required this.name,
    required this.vendor,
    required this.type,
    required this.devices,
    required this.settings,
    required this.bundled,
    this.error,
  });

  final String path;
  final String name;
  final String vendor;
  final String type;
  final List<PluginDevice> devices;

  /// Setting definitions: name -> {label, type, default, min, max, values}.
  final Map<String, Map<String, dynamic>> settings;

  /// Ships with the app (else the user added it).
  final bool bundled;
  final String? error;

  String get id => p.basenameWithoutExtension(path).toLowerCase();
}

int? _int(Object? v) => switch (v) {
  int i => i,
  double d => d.toInt(),
  String s when s.toLowerCase().startsWith('0x') => int.tryParse(
    s.substring(2),
    radix: 16,
  ),
  String s => int.tryParse(s),
  _ => null,
};

/// Reads one plugin file's description.
PluginInfo readPlugin(String path, {required bool bundled}) {
  final rt = JsRuntime((method, args) => null);
  try {
    rt.eval(File(path).readAsStringSync(), name: p.basename(path));
    if (rt.eval('__oc.defined()') != true) {
      throw PluginError('o arquivo não chama plugin({...})');
    }
    final d = rt.evalJson('JSON.parse(__oc.describe())') as Map;
    final devices = <PluginDevice>[
      for (final e in d['devices'] as List? ?? [])
        if (e is Map && _int(e['vid']) != null && _int(e['pid']) != null)
          PluginDevice(
            _int(e['vid'])!,
            _int(e['pid'])!,
            '${e['name'] ?? d['name'] ?? ''}',
          ),
    ];
    if (devices.isEmpty) throw PluginError('nenhum dispositivo em "devices"');
    return PluginInfo(
      path: path,
      name: '${d['name'] ?? p.basenameWithoutExtension(path)}',
      vendor: '${d['vendor'] ?? ''}',
      type: '${d['type'] ?? 'other'}',
      devices: devices,
      settings: {
        for (final e in (d['settings'] as Map? ?? {}).entries)
          if (e.value is Map)
            '${e.key}': (e.value as Map).cast<String, dynamic>(),
      },
      bundled: bundled,
    );
  } catch (e) {
    return PluginInfo(
      path: path,
      name: p.basenameWithoutExtension(path),
      vendor: '',
      type: 'other',
      devices: const [],
      settings: const {},
      bundled: bundled,
      error: '$e',
    );
  } finally {
    rt.dispose();
  }
}

/// Reads every plugin: the bundled ones in [bundledDir], then the user's in
/// [userDir], which replace bundled ones with the same file name.
Future<List<PluginInfo>> loadPlugins({
  required String bundledDir,
  required String userDir,
}) => Isolate.run(() {
  final byId = <String, PluginInfo>{};
  for (final (dir, bundled) in [(bundledDir, true), (userDir, false)]) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d.listSync().whereType<File>()) {
      if (!f.path.toLowerCase().endsWith('.js')) continue;
      final info = readPlugin(f.path, bundled: bundled);
      byId[info.id] = info;
    }
  }
  return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
});
