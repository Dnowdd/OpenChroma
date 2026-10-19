import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/paths.dart';
import 'package:openchroma/src/plugins/plugin_scanner.dart';

/// Scans every installed SignalRGB plugin. It needs QuickJS, which only
/// loads next to a Windows build, so it runs when OC_PLUGIN_TEST=1.
void main() {
  final install = SignalRgbPaths.detect().installDir;
  final enabled = Platform.environment['OC_PLUGIN_TEST'] == '1';

  test(
    'scans installed plugins without errors',
    () {
      final root = '$install${Platform.pathSeparator}Plugins';
      final files = Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.js') && !f.path.endsWith('.test.js'))
          .toList();
      final infos = files.map((f) => scanPluginFile(f.path)).toList();
      final errors = infos.where((i) => i.error != null).toList();
      expect(errors, isEmpty, reason: errors.map((e) => e.path).join('\n'));
    },
    skip: !enabled
        ? 'set OC_PLUGIN_TEST=1 (needs the QuickJS DLL)'
        : install == null
        ? 'SignalRGB is not installed'
        : false,
  );
}
