import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _DirectoryNative = Int32 Function(Pointer<Utf16>, Int32);
typedef _Directory = int Function(Pointer<Utf16>, int);

/// Absolute paths of Windows' own programs, so that no PATH or working
/// directory lookup can pick a planted executable (matters most elevated).
class SystemPaths {
  SystemPaths._();

  static final String system32 =
      _directory('OcSystemDirectory') ??
      '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32';

  static final String windows =
      _directory('OcWindowsDirectory') ??
      (Platform.environment['SystemRoot'] ?? r'C:\Windows');

  static final String powershell =
      '$system32\\WindowsPowerShell\\v1.0\\powershell.exe';

  static final String explorer = '$windows\\explorer.exe';

  /// `reg`, `schtasks`, ... -> `<System32>\reg.exe`.
  static String tool(String name) => '$system32\\$name.exe';

  static String? _directory(String symbol) {
    try {
      final fn = DynamicLibrary.executable()
          .lookupFunction<_DirectoryNative, _Directory>(symbol);
      return using((arena) {
        const cap = 520;
        final buf = arena<Uint16>(cap).cast<Utf16>();
        final n = fn(buf, cap);
        return n > 0 ? buf.toDartString(length: n) : null;
      });
    } catch (_) {
      return null;
    }
  }
}
