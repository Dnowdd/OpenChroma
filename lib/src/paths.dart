import 'dart:io';

import 'package:path/path.dart' as p;

String get _localAppData => Platform.environment['LOCALAPPDATA'] ?? '';
String get _appData => Platform.environment['APPDATA'] ?? '';

/// Locations of an existing SignalRGB installation, whose plugins, effects
/// and components OpenChroma reuses as-is.
class SignalRgbPaths {
  SignalRgbPaths._(this.installDir, this.userDir, this.effectCacheDir);

  /// `...\VortxEngine\app-x.y.z\Signal-x64`, or null when not installed.
  final String? installDir;

  /// The user's WhirlwindFX folder (custom plugins/effects).
  final String userDir;

  /// Marketplace effects SignalRGB downloaded (`cache\effects\<id>\effect.html`).
  final String effectCacheDir;

  static SignalRgbPaths detect() {
    String? install;
    final root = Directory(p.join(_localAppData, 'VortxEngine'));
    if (root.existsSync()) {
      final apps =
          root
              .listSync()
              .whereType<Directory>()
              .where((d) => p.basename(d.path).startsWith('app-'))
              .where(
                (d) => Directory(p.join(d.path, 'Signal-x64')).existsSync(),
              )
              .toList()
            ..sort(
              (a, b) => _compareVersions(
                p.basename(a.path).substring(4),
                p.basename(b.path).substring(4),
              ),
            );
      if (apps.isNotEmpty) install = p.join(apps.last.path, 'Signal-x64');
    }
    return SignalRgbPaths._(
      install,
      _registryUserDir() ??
          p.join(
            Platform.environment['USERPROFILE'] ?? '',
            'Documents',
            'WhirlwindFX',
          ),
      p.join(_localAppData, 'WhirlwindFX', 'SignalRgb', 'cache', 'effects'),
    );
  }

  List<String> get pluginRoots => [
    if (installDir != null) p.join(installDir!, 'Plugins'),
    p.join(userDir, 'Plugins'),
  ];

  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 4; i++) {
      final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static String? _registryUserDir() {
    try {
      final r = Process.runSync('reg', [
        'query',
        r'HKCU\Software\WhirlwindFX\SignalRgb',
        '/v',
        'UserDirectory',
      ]);
      final m = RegExp(r'UserDirectory\s+REG_SZ\s+(.+)')
          .firstMatch(r.stdout as String);
      final dir = m?.group(1)?.trim();
      return dir == null ? null : p.normalize(dir);
    } catch (_) {
      return null;
    }
  }
}

/// OpenChroma's own data folder (%APPDATA%\OpenChroma).
String openChromaDataDir() {
  final dir = p.join(_appData, 'OpenChroma');
  Directory(dir).createSync(recursive: true);
  return dir;
}

/// Motherboard / BIOS strings for the plugins' `systeminfo` module, read from
/// the registry copy of SMBIOS data (same values WMI Win32_BaseBoard reports).
Map<String, Map<String, String>> readSystemInfo() {
  String value(String name) {
    try {
      final r = Process.runSync('reg', [
        'query',
        r'HKLM\HARDWARE\DESCRIPTION\System\BIOS',
        '/v',
        name,
      ]);
      final m = RegExp('$name\\s+REG_SZ\\s+(.+)')
          .firstMatch(r.stdout as String);
      return m?.group(1)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  return {
    'motherboard': {
      'manufacturer': value('BaseBoardManufacturer'),
      'model': value('BaseBoardProduct'),
    },
    'bios': {'vendor': value('BIOSVendor'), 'version': value('BIOSVersion')},
  };
}
