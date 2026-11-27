import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

enum TaskResult { done, needsAdmin, installNotTrusted, failed }

typedef _NoArgNative = Int32 Function();
typedef _NoArg = int Function();
typedef _StringNative = Int32 Function(Pointer<Utf16>);
typedef _String = int Function(Pointer<Utf16>);
typedef _CompanyNative = Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Int32);
typedef _Company = int Function(Pointer<Utf16>, Pointer<Utf16>, int);

int _callNoArg(String symbol) {
  try {
    return DynamicLibrary.executable().lookupFunction<_NoArgNative, _NoArg>(
      symbol,
    )();
  } catch (_) {
    return -1;
  }
}

int _callString(String symbol, String arg) {
  try {
    final fn = DynamicLibrary.executable()
        .lookupFunction<_StringNative, _String>(symbol);
    return using((arena) => fn(arg.toNativeUtf16(allocator: arena)));
  } catch (_) {
    return -1;
  }
}

TaskResult _taskResult(int code) => switch (code) {
  0 => TaskResult.done,
  1 => TaskResult.needsAdmin,
  2 => TaskResult.installNotTrusted,
  _ => TaskResult.failed,
};

/// Checks done by the runner (windows/runner/security.cpp), looked up with
/// DynamicLibrary.executable().
class NativeSecurity {
  NativeSecurity._();

  static final RegExp _driverName = RegExp(r'^[A-Za-z0-9_.\-]{1,64}$');

  static bool isSafeDriverName(String name) =>
      _driverName.hasMatch(name) &&
      !name.startsWith('.') &&
      !name.startsWith('-');

  /// True when only administrators can change the app's folder, every file
  /// in it and the folders above it, so running it elevated at logon cannot
  /// be hijacked by a program without administrator rights.
  static Future<bool> installIsSecure() =>
      Isolate.run(() => _callNoArg('OcInstallSecure') == 1);

  static Future<bool> startupTaskExists() =>
      Isolate.run(() => _callNoArg('OcStartupTaskExists') == 1);

  static Future<TaskResult> registerStartupTask(String description) =>
      Isolate.run(
        () => _taskResult(_callString('OcStartupTaskRegister', description)),
      );

  static Future<TaskResult> deleteStartupTask() =>
      Isolate.run(() => _taskResult(_callNoArg('OcStartupTaskDelete')));

  /// True when the file is owned by SYSTEM, Administrators or
  /// TrustedInstaller; false when it is not, or when that cannot be told.
  static bool fileOwnerTrusted(String path) =>
      _callString('OcFileOwnerTrusted', path) == 1;

  /// CompanyName in the version resource of System32\drivers\[name]; null
  /// when [name] is not a plain file name or the file has none.
  static String? driverCompany(String name) {
    if (!isSafeDriverName(name)) return null;
    try {
      final fn = DynamicLibrary.executable()
          .lookupFunction<_CompanyNative, _Company>('OcDriverCompany');
      return using((arena) {
        const cap = 512;
        final out = arena<Uint16>(cap).cast<Utf16>();
        final n = fn(name.toNativeUtf16(allocator: arena), out, cap);
        return n > 0 ? out.toDartString(length: n) : null;
      });
    } catch (_) {
      return null;
    }
  }
}
