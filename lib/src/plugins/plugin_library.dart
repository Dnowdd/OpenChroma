import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show Locale;

import 'package:path/path.dart' as p;

import '../i18n/l10n.dart';
import 'js_runtime.dart';
import 'plugin_trust.dart';
import 'thread_priority.dart';

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
    this.serialBaud,
    this.stamp = 0,
    this.sha256 = '',
    this.source = '',
    this.overrides = const [],
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

  /// Baud rate when the devices are serial ports instead of HID.
  final int? serialBaud;

  /// Hash of the file's source, to tell when it changed.
  final int stamp;

  /// SHA-256 and text of what was read; the plugin runs from this text,
  /// never from a second read of the file.
  final String sha256;
  final String source;

  /// Bundled plugins this user plugin takes devices or the file name from.
  final List<String> overrides;
  final String? error;

  String get id => p.basenameWithoutExtension(path).toLowerCase();

  PluginInfo withOverrides(List<String> names) => PluginInfo(
    path: path,
    name: name,
    vendor: vendor,
    type: type,
    devices: devices,
    settings: settings,
    bundled: bundled,
    serialBaud: serialBaud,
    stamp: stamp,
    sha256: sha256,
    source: source,
    overrides: names,
    error: error,
  );
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
PluginInfo readPlugin(String path, {required bool bundled}) =>
    readPluginFile(PluginFile.read(path), bundled: bundled);

/// Runs [file] in a throwaway QuickJS context to read what it declares. Only
/// for bundled or approved files.
PluginInfo readPluginFile(PluginFile file, {required bool bundled}) {
  if (file.error != null) return _failed(file, bundled, file.error!);
  final rt = JsRuntime((method, args) => null);
  try {
    rt.eval(file.source, name: file.name);
    if (rt.eval('__oc.defined()') != true) {
      throw PluginError(l10n.pluginsNoDefinition);
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
    if (devices.isEmpty) throw PluginError(l10n.pluginsNoDevices);
    return PluginInfo(
      path: file.path,
      name: '${d['name'] ?? p.basenameWithoutExtension(file.name)}',
      vendor: '${d['vendor'] ?? ''}',
      type: '${d['type'] ?? 'other'}',
      devices: devices,
      settings: {
        for (final e in (d['settings'] as Map? ?? {}).entries)
          if (e.value is Map)
            '${e.key}': (e.value as Map).cast<String, dynamic>(),
      },
      bundled: bundled,
      serialBaud: d['serial'] is Map
          ? _int((d['serial'] as Map)['baud'])
          : null,
      stamp: file.source.hashCode,
      sha256: file.sha256,
      source: file.source,
    );
  } catch (e) {
    return _failed(file, bundled, '$e');
  } finally {
    rt.dispose();
  }
}

PluginInfo _failed(PluginFile file, bool bundled, String error) => PluginInfo(
  path: file.path,
  name: p.basenameWithoutExtension(file.name),
  vendor: '',
  type: 'other',
  devices: const [],
  settings: const {},
  bundled: bundled,
  stamp: file.source.hashCode,
  sha256: file.sha256,
  error: error,
);

const pluginLoadTimeout = Duration(seconds: 3);
const _bundledLoadTimeout = Duration(seconds: 20);

final _hung = <String>{};

class _ProbeArgs {
  _ProbeArgs(this.out, this.files, this.bundled, this.language);
  final SendPort out;
  final List<PluginFile> files;
  final bool bundled;
  final String language;
}

void _probeMain(_ProbeArgs a) {
  l10n = lookupAppLocalizations(Locale(a.language));
  a.out.send({'t': 'thread', 'id': currentThreadId()});
  a.out.send({
    't': 'result',
    'infos': [for (final f in a.files) readPluginFile(f, bundled: a.bundled)],
  });
}

/// QuickJS cannot be interrupted: a plugin that never returns costs one
/// idle-priority thread until the app exits, and is reported as an error
/// instead of stalling the others.
Future<List<PluginInfo>> _readIsolated(
  List<PluginFile> files, {
  required bool bundled,
  required String language,
  required Duration timeout,
}) async {
  final skipped = files.where((f) => _hung.contains(f.sha256)).toList();
  final todo = files.where((f) => !skipped.contains(f)).toList();
  final out = <PluginInfo>[
    for (final f in skipped) _failed(f, bundled, l10n.pluginTrustTimedOut),
  ];
  if (todo.isEmpty) return out;

  final port = ReceivePort();
  final done = Completer<List<PluginInfo>>();
  int? thread;
  final sub = port.listen((m) {
    if (done.isCompleted) return;
    if (m is Map && m['t'] == 'thread') {
      thread = m['id'] as int;
    } else if (m is Map && m['t'] == 'result') {
      done.complete((m['infos'] as List).cast<PluginInfo>());
    } else if (m is List) {
      done.complete([for (final f in todo) _failed(f, bundled, '${m.first}')]);
    } else if (m == null) {
      done.complete([
        for (final f in todo) _failed(f, bundled, l10n.pluginTrustLoadFailed),
      ]);
    }
  });
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn(
      _probeMain,
      _ProbeArgs(port.sendPort, todo, bundled, language),
      onError: port.sendPort,
      onExit: port.sendPort,
    );
    out.addAll(await done.future.timeout(timeout));
  } on TimeoutException {
    for (final f in todo) {
      _hung.add(f.sha256);
      out.add(_failed(f, bundled, l10n.pluginTrustTimedOut));
    }
    if (thread != null) deprioritizeThread(thread!);
    isolate?.kill(priority: Isolate.immediate);
  } finally {
    await sub.cancel();
    port.close();
  }
  return out;
}

/// Reads every plugin: [bundled] come from the app's own assets and [user]
/// are the files the user approved. Each user plugin runs in its own
/// isolate with a [timeout]. A user plugin replaces the bundled one with
/// the same file name, and lists in [PluginInfo.overrides] the bundled
/// plugins it replaces or shares devices with.
Future<List<PluginInfo>> loadPlugins({
  required List<PluginFile> bundled,
  required List<PluginFile> user,
  String language = 'en',
  Duration timeout = pluginLoadTimeout,
}) async {
  final fromAssets = await _readIsolated(
    bundled,
    bundled: true,
    language: language,
    timeout: _bundledLoadTimeout,
  );
  final fromUser = [
    for (final list in await Future.wait([
      for (final f in user)
        _readIsolated(
          [f],
          bundled: false,
          language: language,
          timeout: timeout,
        ),
    ]))
      ...list,
  ];

  final replacedIds = {
    for (final u in fromUser)
      if (u.error == null) u.id,
  };
  final result = [
    for (final b in fromAssets)
      if (!replacedIds.contains(b.id)) b,
  ];
  for (final u in fromUser) {
    if (u.error != null) {
      result.add(u);
      continue;
    }
    final userKeys = {for (final d in u.devices) d.key};
    final names = {
      for (final b in fromAssets)
        if (b.id == u.id || b.devices.any((d) => userKeys.contains(d.key)))
          b.name,
    };
    result.add(u.withOverrides(names.toList()..sort()));
  }
  return result..sort((a, b) => a.name.compareTo(b.name));
}

class PluginScan {
  PluginScan(this.plugins, this.userPlugins, this.approvalsChanged);
  final List<PluginInfo> plugins;
  final List<UserPlugin> userPlugins;
  final bool approvalsChanged;
}

/// Looks at the .js files in [userDir], settles [approvals] against them
/// and loads the bundled plugins plus the user plugins that are approved.
/// Files that are not approved are listed but never evaluated.
Future<PluginScan> readAllPlugins({
  required String userDir,
  required List<PluginFile> bundled,
  required PluginApprovals approvals,
  required bool elevated,
  String language = 'en',
  Duration timeout = pluginLoadTimeout,
}) async {
  final files = await scanPluginFiles(userDir, language: language);
  final changed = approvals.sync(files, elevated: elevated);
  final loaded = await loadPlugins(
    bundled: bundled,
    user: [
      for (final f in files)
        if (approvals.trustOf(f) == PluginTrust.approved) f,
    ],
    language: language,
    timeout: timeout,
  );
  final bundledIds = {
    for (final b in bundled) p.basenameWithoutExtension(b.name).toLowerCase(),
  };
  final users = [
    for (final f in files)
      UserPlugin(
        file: f,
        trust: approvals.trustOf(f),
        changed: approvals.changedSinceApproval(f),
        replacesBundled: bundledIds.contains(
          p.basenameWithoutExtension(f.name).toLowerCase(),
        ),
        overrides:
            loaded.where((i) => i.path == f.path).firstOrNull?.overrides ??
            const [],
      ),
  ];
  return PluginScan(loaded, users, changed);
}
