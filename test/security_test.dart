import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/checkup/minidump.dart';
import 'package:openchroma/src/system/native_security.dart';
import 'package:openchroma/src/system/system_paths.dart';

Uint8List _dump(List<(String, int)> drivers, List<int> stack) {
  final b = Uint8List(0x4000);
  final d = ByteData.sublistView(b);
  b.setAll(0, 'PAGEDU64'.codeUnits);
  d.setUint32(0x38, 0xA, Endian.little);
  const t = 0x2000;
  const driverOff = 0x2100, stride = 0x60;
  d.setUint32(t + 0x28, 0x2800, Endian.little);
  d.setUint32(t + 0x2C, stack.length * 8, Endian.little);
  d.setUint32(t + 0x30, driverOff, Endian.little);
  d.setUint32(t + 0x34, drivers.length, Endian.little);
  d.setUint32(t + 0x38, driverOff + stride * drivers.length, Endian.little);
  for (var i = 0; i < drivers.length; i++) {
    final e = driverOff + i * stride;
    final nameOff = 0x2300 + i * 0x100;
    d.setUint32(e, nameOff, Endian.little);
    d.setUint64(e + 8 + 0x30, drivers[i].$2, Endian.little);
    d.setUint32(e + 8 + 0x40, 0x1000, Endian.little);
    final name = drivers[i].$1;
    d.setUint32(nameOff, name.length, Endian.little);
    for (var c = 0; c < name.length; c++) {
      d.setUint16(nameOff + 4 + c * 2, name.codeUnitAt(c), Endian.little);
    }
  }
  for (var i = 0; i < stack.length; i++) {
    d.setUint64(0x2800 + i * 8, stack[i], Endian.little);
  }
  return b;
}

void main() {
  group('driver names', () {
    test('accepts plain file names', () {
      for (final n in ['nvlddmkm.sys', 'rt640x64.sys', 'a-b_c.1.sys']) {
        expect(NativeSecurity.isSafeDriverName(n), isTrue, reason: n);
      }
    });

    test('rejects anything that could reach a shell or a path', () {
      for (final n in [
        '',
        '..',
        '.hidden',
        '-flag',
        "x';calc;'.sys",
        r'..\evil.sys',
        'a b.sys',
        r'a$(b).sys',
        'a`b`.sys',
        'a' * 65,
        'é.sys',
      ]) {
        expect(NativeSecurity.isSafeDriverName(n), isFalse, reason: n);
      }
    });

    test('a dump with a hostile module name never reports it', () {
      const good = 0xFFFFF80000100000;
      const evil = 0xFFFFF80000200000;
      final bytes = _dump(
        [('good.sys', good), (r"x';calc;'.sys", evil)],
        [good + 0x10, evil + 0x10],
      );
      final dir = Directory.systemTemp.createTempSync('oc-dump-test');
      try {
        final file = File('${dir.path}/a.dmp')..writeAsBytesSync(bytes);
        final dump = KernelDump.read(file);
        expect(dump, isNotNull);
        expect(dump!.stackModules, ['good.sys']);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  test('system tools resolve to absolute System32 paths', () {
    expect(SystemPaths.tool('reg'), endsWith(r'\reg.exe'));
    expect(SystemPaths.tool('reg').toLowerCase(), contains('system32'));
    expect(SystemPaths.powershell, endsWith('powershell.exe'));
    expect(SystemPaths.explorer, endsWith(r'\explorer.exe'));
    if (Platform.isWindows) {
      expect(File(SystemPaths.tool('reg')).existsSync(), isTrue);
    }
  });
}
