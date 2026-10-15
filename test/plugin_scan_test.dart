import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/plugins/plugin_scanner.dart';

void main() {
  final root = '${Platform.environment['LOCALAPPDATA']}/VortxEngine/app-2.5.80/Signal-x64/Plugins';

  test('scans SignalRGB plugins', () {
    final files = Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.js') && !f.path.endsWith('.test.js')).toList();
    final infos = files.map((f) => scanPluginFile(f.path)).toList();
    final errors = infos.where((i) => i.error != null).toList();
    final hid = infos.where((i) => i.error == null && i.isHid && i.vendorId != null).toList();
    print('total=${infos.length} errors=${errors.length} hid=${hid.length}');
    final types = <String, int>{};
    for (final i in infos) { types[i.type] = (types[i.type] ?? 0) + 1; }
    print(types);
    for (final e in errors.take(25)) { print('ERR ${e.path.substring(root.length)}: ${e.error!.split('\n').first}'); }
    for (final pair in [[0x048d, 0x5702], [0x3151, 0x4015], [0x046d, 0xc08f], [0x054c, 0x09cc]]) {
      print('${pair[0].toRadixString(16)}:${pair[1].toRadixString(16)} -> ${hid.where((i) => i.matches(pair[0], pair[1])).map((i) => i.name).toList()}');
    }
  });
}
