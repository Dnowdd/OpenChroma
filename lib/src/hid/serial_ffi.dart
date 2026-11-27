import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'hid_ffi.dart';
import '../system/system_paths.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _createFile = _kernel32
    .lookupFunction<
      Pointer<Void> Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer<Void>,
        Uint32,
        Uint32,
        Pointer<Void>,
      ),
      Pointer<Void> Function(
        Pointer<Utf16>,
        int,
        int,
        Pointer<Void>,
        int,
        int,
        Pointer<Void>,
      )
    >('CreateFileW');
final _closeHandle = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CloseHandle',
    );
final _writeFile = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Void>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Uint8>,
        int,
        Pointer<Uint32>,
        Pointer<Void>,
      )
    >('WriteFile');
final _readFile = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Void>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Uint8>,
        int,
        Pointer<Uint32>,
        Pointer<Void>,
      )
    >('ReadFile');
final _getCommState = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>),
      int Function(Pointer<Void>, Pointer<Uint8>)
    >('GetCommState');
final _setCommState = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>),
      int Function(Pointer<Void>, Pointer<Uint8>)
    >('SetCommState');
final _setCommTimeouts = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>),
      int Function(Pointer<Void>, Pointer<Uint8>)
    >('SetCommTimeouts');
final _purgeComm = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)
    >('PurgeComm');

final _invalid = Pointer<Void>.fromAddress(-1);

/// A USB serial port (COMx), 8N1 without flow control and with DTR and RTS
/// low, as most device apps open them.
class SerialHandle {
  SerialHandle._(this._h);

  final Pointer<Void> _h;
  int _readTimeout = -1;

  static SerialHandle? open(String port, int baud) {
    final name = '\\\\.\\$port'.toNativeUtf16();
    final h = _createFile(name, 0xC0000000, 0, nullptr, 3, 0, nullptr);
    calloc.free(name);
    if (h == _invalid || h == nullptr) return null;
    final dcb = calloc<Uint8>(28);
    try {
      final view = ByteData.sublistView(dcb.asTypedList(28));
      view.setUint32(0, 28, Endian.little);
      _getCommState(h, dcb);
      view
        ..setUint32(0, 28, Endian.little)
        ..setUint32(4, baud, Endian.little)
        ..setUint32(8, 0x11, Endian.little)
        ..setUint8(18, 8)
        ..setUint8(19, 0)
        ..setUint8(20, 0);
      if (_setCommState(h, dcb) == 0) {
        _closeHandle(h);
        return null;
      }
      _purgeComm(h, 0xF);
      return SerialHandle._(h).._timeouts(0);
    } catch (_) {
      _closeHandle(h);
      rethrow;
    } finally {
      calloc.free(dcb);
    }
  }

  void _timeouts(int readMs) {
    if (readMs == _readTimeout) return;
    _readTimeout = readMs;
    final t = calloc<Uint32>(5);
    t[0] = 0xFFFFFFFF;
    t[1] = readMs > 0 ? 0xFFFFFFFF : 0;
    t[2] = readMs;
    t[3] = 0;
    t[4] = 5000;
    _setCommTimeouts(_h, t.cast());
    calloc.free(t);
  }

  int write(List<int> data) {
    if (data.isEmpty) return 0;
    final buf = calloc<Uint8>(data.length);
    buf.asTypedList(data.length).setAll(0, data);
    final n = calloc<Uint32>();
    final ok = _writeFile(_h, buf, data.length, n, nullptr) != 0;
    final written = ok ? n.value : -1;
    calloc.free(buf);
    calloc.free(n);
    return written;
  }

  Uint8List read(int length, int timeoutMs) {
    if (length <= 0) return Uint8List(0);
    _timeouts(timeoutMs < 0 ? 0 : timeoutMs);
    final buf = calloc<Uint8>(length);
    final n = calloc<Uint32>();
    final ok = _readFile(_h, buf, length, n, nullptr) != 0;
    final out = ok
        ? Uint8List.fromList(buf.asTypedList(n.value))
        : Uint8List(0);
    calloc.free(buf);
    calloc.free(n);
    return out;
  }

  void clearReadBuffer() => _purgeComm(_h, 0x8);

  void close() => _closeHandle(_h);
}

/// [serialEnumerate] for [models], as a task for `Isolate.run` that carries
/// nothing else across.
List<HidEndpointInfo> Function() serialEnumerateTask(Set<int> models) =>
    () => serialEnumerate(models);

/// The present USB serial ports of the given VID:PID models, as endpoints
/// whose path is the port name (`COM3`).
List<HidEndpointInfo> serialEnumerate(Set<int> models) {
  final present = <String>{};
  final map = _reg(r'HKLM\HARDWARE\DEVICEMAP\SERIALCOMM', const []);
  for (final m in RegExp(r'REG_SZ\s+(COM\d+)').allMatches(map)) {
    present.add(m.group(1)!);
  }
  if (present.isEmpty) return const [];
  final out = <HidEndpointInfo>[];
  for (final key in models) {
    final vid = (key >> 16).toRadixString(16).padLeft(4, '0').toUpperCase();
    final pid = (key & 0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
    final text = _reg(
      'HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\\VID_$vid&PID_$pid',
      const ['/s', '/v', 'PortName'],
    );
    String? instance;
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.startsWith('HKEY_')) {
        final parts = l.split('\\');
        instance = parts.length >= 2 ? parts[parts.length - 2] : null;
      }
      final m = RegExp(r'PortName\s+REG_SZ\s+(COM\d+)').firstMatch(l);
      if (m == null || !present.contains(m.group(1))) continue;
      out.add(
        HidEndpointInfo(
          path: m.group(1)!,
          vendorId: key >> 16,
          productId: key & 0xFFFF,
          interface: -1,
          usage: 0,
          usagePage: 0,
          collection: 0,
          serial: instance ?? m.group(1)!,
          product: '',
          manufacturer: '',
          inputLength: 0,
          outputLength: 0,
          featureLength: 0,
        ),
      );
    }
  }
  return out;
}

String _reg(String key, List<String> args) {
  try {
    final r = Process.runSync(SystemPaths.tool('reg'), ['query', key, ...args]);
    return r.exitCode == 0 ? '${r.stdout}' : '';
  } catch (_) {
    return '';
  }
}
