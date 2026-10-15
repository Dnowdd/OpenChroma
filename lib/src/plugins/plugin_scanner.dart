import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'js_transform.dart';
import 'plugin_runtime.dart';

/// Static description of a plugin file, gathered by evaluating its exported
/// metadata functions (Name, VendorId, ProductId, ...) against a stub device.
class PluginInfo {
  PluginInfo({
    required this.path,
    required this.name,
    required this.vendorId,
    required this.productIds,
    required this.type,
    required this.size,
    required this.defaultPosition,
    required this.defaultScale,
    required this.imageUrl,
    required this.deviceType,
    required this.publisher,
    this.error,
  });

  final String path;
  final String name;
  final int? vendorId;
  final List<int> productIds;
  final String type;
  final List<int> size;
  final List<double> defaultPosition;
  final double defaultScale;
  final String imageUrl;
  final String deviceType;
  final String publisher;
  final String? error;

  bool get isHid => type.toLowerCase() == 'hid' || type.isEmpty;

  bool matches(int vid, int pid) =>
      isHid && vendorId == vid && productIds.contains(pid);

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'vendorId': vendorId,
    'productIds': productIds,
    'type': type,
    'size': size,
    'defaultPosition': defaultPosition,
    'defaultScale': defaultScale,
    'imageUrl': imageUrl,
    'deviceType': deviceType,
    'publisher': publisher,
    'error': error,
  };

  static PluginInfo fromJson(Map<String, dynamic> j) => PluginInfo(
    path: j['path'],
    name: j['name'],
    vendorId: j['vendorId'],
    productIds: (j['productIds'] as List).cast<int>(),
    type: j['type'],
    size: (j['size'] as List).cast<int>(),
    defaultPosition: (j['defaultPosition'] as List)
        .map((e) => (e as num).toDouble())
        .toList(),
    defaultScale: (j['defaultScale'] as num).toDouble(),
    imageUrl: j['imageUrl'],
    deviceType: j['deviceType'],
    publisher: j['publisher'],
    error: j['error'],
  );
}

int? _toInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s.startsWith('0x')
        ? int.tryParse(s.substring(2), radix: 16)
        : int.tryParse(s);
  }
  return null;
}

const _metaExpr = '''(function () {
  function t(f) { try { return typeof globalThis[f] === 'function' ? globalThis[f]() : null; } catch (e) { return null; } }
  return { name: t('Name'), vid: t('VendorId'), pids: t('ProductId'), type: t('Type'), size: t('Size'),
           pos: t('DefaultPosition'), scale: t('DefaultScale'), image: t('ImageUrl'),
           deviceType: t('DeviceType'), publisher: t('Publisher') };
})()''';

PluginInfo scanPluginFile(String path) {
  final rt = PluginRuntime((method, args) {
    switch (method) {
      case 'pid':
      case 'vid':
      case 'last_read_size':
        return 0;
      case 'endpoints':
      case 'read':
      case 'get_report':
        return <int>[];
      case 'hid_info':
        return {'writeLength': 0, 'readLength': 0, 'featureLength': 0};
      case 'sysinfo':
        return {'model': '', 'manufacturer': '', 'vendor': '', 'version': ''};
      default:
        return null;
    }
  });
  try {
    rt.eval(transformPlugin(path), name: p.basename(path));
    final m = rt.evalJson(_metaExpr) as Map<String, dynamic>;
    final pidsRaw = m['pids'];
    final pids = <int>[
      for (final v in (pidsRaw is List ? pidsRaw : [pidsRaw]))
        if (_toInt(v) != null) _toInt(v)!,
    ];
    final size = m['size'] is List
        ? (m['size'] as List).map((e) => _toInt(e) ?? 1).toList()
        : [1, 1];
    final pos = m['pos'] is List
        ? (m['pos'] as List).map((e) => (e as num).toDouble()).toList()
        : <double>[];
    return PluginInfo(
      path: path,
      name: (m['name'] ?? p.basenameWithoutExtension(path)).toString(),
      vendorId: _toInt(m['vid']),
      productIds: pids,
      type: (m['type'] ?? 'Hid').toString(),
      size: size.length >= 2 ? size.sublist(0, 2) : [1, 1],
      defaultPosition: pos.length >= 2 ? pos.sublist(0, 2) : [0, 0],
      defaultScale: (m['scale'] as num?)?.toDouble() ?? 8.0,
      imageUrl: (m['image'] ?? '').toString(),
      deviceType: (m['deviceType'] ?? 'other').toString(),
      publisher: (m['publisher'] ?? '').toString(),
    );
  } catch (e) {
    return PluginInfo(
      path: path,
      name: p.basenameWithoutExtension(path),
      vendorId: null,
      productIds: const [],
      type: 'error',
      size: const [1, 1],
      defaultPosition: const [0, 0],
      defaultScale: 8,
      imageUrl: '',
      deviceType: 'other',
      publisher: '',
      error: e.toString(),
    );
  } finally {
    rt.dispose();
  }
}

/// Scans every `.js` plugin under [roots], reusing [cacheFile] entries whose
/// file size and mtime are unchanged. Runs in a background isolate.
Future<List<PluginInfo>> scanPlugins(List<String> roots, String cacheFile) {
  return Isolate.run(() {
    final cache = <String, dynamic>{};
    final f = File(cacheFile);
    if (f.existsSync()) {
      try {
        cache.addAll(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {}
    }
    final out = <PluginInfo>[];
    final newCache = <String, dynamic>{};
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final e in dir.listSync(recursive: true)) {
        final lower = e.path.toLowerCase();
        if (e is! File ||
            !lower.endsWith('.js') ||
            lower.endsWith('.test.js')) {
          continue;
        }
        if (e.path.toLowerCase().contains(
          '${p.separator}tests${p.separator}',
        )) {
          continue;
        }
        final stat = e.statSync();
        final stamp = '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
        final cached = cache[e.path];
        PluginInfo info;
        if (cached is Map && cached['stamp'] == stamp) {
          info = PluginInfo.fromJson(
            (cached['info'] as Map).cast<String, dynamic>(),
          );
        } else {
          info = scanPluginFile(e.path);
        }
        newCache[e.path] = {'stamp': stamp, 'info': info.toJson()};
        out.add(info);
      }
    }
    try {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(newCache));
    } catch (_) {}
    return out;
  });
}
