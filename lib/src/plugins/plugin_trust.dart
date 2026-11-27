import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Locale;

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../i18n/l10n.dart';

const maxPluginBytes = 1024 * 1024;

enum PluginTrust { bundled, approved, pending, denied }

class PluginFile {
  const PluginFile({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.sha256,
    required this.source,
    this.error,
  });

  final String name;
  final String path;
  final int size;
  final DateTime modified;
  final String sha256;
  final String source;
  final String? error;

  String get key => name.toLowerCase();
  String get shortHash => sha256.length < 12 ? sha256 : sha256.substring(0, 12);

  static PluginFile read(String path) {
    final file = File(path);
    final stat = file.statSync();
    final name = p.basename(path);
    if (stat.size > maxPluginBytes) {
      return PluginFile(
        name: name,
        path: path,
        size: stat.size,
        modified: stat.modified,
        sha256: '',
        source: '',
        error: l10n.pluginTrustTooLarge,
      );
    }
    final bytes = file.readAsBytesSync();
    return PluginFile(
      name: name,
      path: path,
      size: bytes.length,
      modified: stat.modified,
      sha256: crypto.sha256.convert(bytes).toString(),
      source: utf8.decode(bytes, allowMalformed: true),
    );
  }

  static PluginFile bundled(String name, String source) {
    final bytes = utf8.encode(source);
    return PluginFile(
      name: name,
      path: 'assets/plugins/$name',
      size: bytes.length,
      modified: DateTime.fromMillisecondsSinceEpoch(0),
      sha256: crypto.sha256.convert(bytes).toString(),
      source: source,
    );
  }
}

List<PluginFile> scanPluginFilesSync(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return [];
  final files = <PluginFile>[];
  for (final f in d.listSync(followLinks: false).whereType<File>()) {
    if (!f.path.toLowerCase().endsWith('.js')) continue;
    try {
      files.add(PluginFile.read(f.path));
    } catch (_) {}
  }
  files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return files;
}

Future<List<PluginFile>> scanPluginFiles(
  String dir, {
  String language = 'en',
}) => Isolate.run(() {
  l10n = lookupAppLocalizations(Locale(language));
  return scanPluginFilesSync(dir);
});

class PluginApprovals {
  PluginApprovals({Map<String, String>? approved, Map<String, String>? denied})
    : approved = {...?approved},
      denied = {...?denied};

  factory PluginApprovals.fromJson(Object? json) {
    Map<String, String> strings(Object? m) => m is Map
        ? {
            for (final e in m.entries)
              if (e.value is String)
                '${e.key}'.toLowerCase(): e.value as String,
          }
        : {};
    final map = json is Map ? json : const {};
    return PluginApprovals(
      approved: strings(map['approved']),
      denied: strings(map['denied']),
    );
  }

  final Map<String, String> approved;
  final Map<String, String> denied;

  Map<String, Object> toJson() => {'approved': approved, 'denied': denied};

  PluginTrust trustOf(PluginFile f) {
    if (f.error != null) return PluginTrust.pending;
    if (approved[f.key] == f.sha256) return PluginTrust.approved;
    if (denied[f.key] == f.sha256) return PluginTrust.denied;
    return PluginTrust.pending;
  }

  bool changedSinceApproval(PluginFile f) =>
      approved.containsKey(f.key) && approved[f.key] != f.sha256;

  // Elevated: an approval is bound to the exact hash. Not elevated, a file
  // approved once follows its edits so hot reload keeps working.
  bool sync(Iterable<PluginFile> files, {required bool elevated}) {
    var changed = false;
    for (final f in files) {
      if (f.error != null) continue;
      if (approved[f.key] == f.sha256) continue;
      if (denied[f.key] == f.sha256) continue;
      if (!elevated && approved.containsKey(f.key)) {
        approved[f.key] = f.sha256;
        denied.remove(f.key);
        changed = true;
      } else if (denied.remove(f.key) != null) {
        changed = true;
      }
    }
    return changed;
  }

  void approve(PluginFile f) {
    approved[f.key] = f.sha256;
    denied.remove(f.key);
  }

  void deny(PluginFile f) {
    denied[f.key] = f.sha256;
    approved.remove(f.key);
  }
}

class UserPlugin {
  const UserPlugin({
    required this.file,
    required this.trust,
    required this.changed,
    required this.replacesBundled,
    required this.overrides,
  });

  final PluginFile file;
  final PluginTrust trust;
  final bool changed;

  final bool replacesBundled;

  final List<String> overrides;
}
