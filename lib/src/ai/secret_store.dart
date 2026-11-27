import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Encrypts small secrets (API keys) with the Windows Data Protection API, so
/// they are stored on disk readable only by the same Windows user. Elsewhere
/// (tests, other platforms) values pass through base64 only.
class SecretStore {
  static final _crypt32 = Platform.isWindows
      ? DynamicLibrary.open('crypt32.dll')
      : null;
  static final _kernel32 = Platform.isWindows
      ? DynamicLibrary.open('kernel32.dll')
      : null;

  // CryptProtectData / CryptUnprotectData share this signature.
  static final _protect = _crypt32
      ?.lookupFunction<
        Int32 Function(
          Pointer<_Blob>,
          Pointer<Utf16>,
          Pointer<_Blob>,
          Pointer<Void>,
          Pointer<Void>,
          Uint32,
          Pointer<_Blob>,
        ),
        int Function(
          Pointer<_Blob>,
          Pointer<Utf16>,
          Pointer<_Blob>,
          Pointer<Void>,
          Pointer<Void>,
          int,
          Pointer<_Blob>,
        )
      >('CryptProtectData');
  static final _unprotect = _crypt32
      ?.lookupFunction<
        Int32 Function(
          Pointer<_Blob>,
          Pointer<Pointer<Utf16>>,
          Pointer<_Blob>,
          Pointer<Void>,
          Pointer<Void>,
          Uint32,
          Pointer<_Blob>,
        ),
        int Function(
          Pointer<_Blob>,
          Pointer<Pointer<Utf16>>,
          Pointer<_Blob>,
          Pointer<Void>,
          Pointer<Void>,
          int,
          Pointer<_Blob>,
        )
      >('CryptUnprotectData');
  static final _localFree = _kernel32
      ?.lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('LocalFree');

  // CRYPTPROTECT_UI_FORBIDDEN
  static const _flags = 0x1;

  /// Returns [plain] encrypted for this Windows user, base64-encoded.
  static String seal(String plain) {
    if (plain.isEmpty) return '';
    final data = Uint8List.fromList(utf8.encode(plain));
    final out = _run(_protect, data);
    return out == null ? '' : base64Encode(out);
  }

  /// Reverses [seal]; returns an empty string when it cannot be read (for
  /// example, the settings were copied from another user or PC).
  static String open(String sealed) {
    if (sealed.isEmpty) return '';
    try {
      if (sealed.startsWith('plain:')) {
        return utf8.decode(base64Decode(sealed.substring(6)));
      }
      final out = _run(
        _unprotect == null
            ? null
            : (a, b, c, d, e, f, g) => _unprotect!(a, nullptr, c, d, e, f, g),
        base64Decode(sealed),
      );
      return out == null ? '' : utf8.decode(out);
    } catch (_) {
      return '';
    }
  }

  static Uint8List? _run(
    int Function(
      Pointer<_Blob>,
      Pointer<Utf16>,
      Pointer<_Blob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_Blob>,
    )?
    fn,
    Uint8List data,
  ) {
    if (fn == null || _localFree == null) return null;
    return using((arena) {
      final input = arena<_Blob>();
      final buf = arena<Uint8>(data.length);
      buf.asTypedList(data.length).setAll(0, data);
      input.ref
        ..cbData = data.length
        ..pbData = buf;
      final output = arena<_Blob>();
      if (fn(input, nullptr, nullptr, nullptr, nullptr, _flags, output) == 0) {
        return null;
      }
      final result = Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
      _localFree!(output.ref.pbData.cast());
      return result;
    });
  }
}

final class _Blob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}
