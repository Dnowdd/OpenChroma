// Minimal Windows HID access over raw FFI (setupapi / hid / kernel32).
//
// The read/write semantics mirror hidapi's Windows backend (hid_write,
// hid_read_timeout, hid_send_feature_report, ...): short buffers are
// zero-padded to the report length, and a leading report ID of 0 is stripped
// from input reports.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _setupapi = DynamicLibrary.open('setupapi.dll');
final _hid = DynamicLibrary.open('hid.dll');

const _digcfPresent = 0x2;
const _digcfDeviceInterface = 0x10;
const _genericRead = 0x80000000;
const _genericWrite = 0x40000000;
const _fileShareRead = 0x1;
const _fileShareWrite = 0x2;
const _openExisting = 3;
const _fileFlagOverlapped = 0x40000000;
const _waitObject0 = 0;
final _invalidHandle = Pointer<Void>.fromAddress(-1);

// --- kernel32 ---------------------------------------------------------------
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
final _createEvent = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Int32, Int32, Pointer<Utf16>),
      Pointer<Void> Function(Pointer<Void>, int, int, Pointer<Utf16>)
    >('CreateEventW');
final _resetEvent = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'ResetEvent',
    );
final _waitForSingleObject = _kernel32
    .lookupFunction<
      Uint32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)
    >('WaitForSingleObject');
final _writeFile = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Uint8>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Uint8>,
        int,
        Pointer<Uint32>,
        Pointer<Uint8>,
      )
    >('WriteFile');
final _readFile = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Uint8>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Uint8>,
        int,
        Pointer<Uint32>,
        Pointer<Uint8>,
      )
    >('ReadFile');
final _getOverlappedResult = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>, Int32),
      int Function(Pointer<Void>, Pointer<Uint8>, Pointer<Uint32>, int)
    >('GetOverlappedResult');
final _cancelIo = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CancelIo',
    );

// --- setupapi ---------------------------------------------------------------
final _setupDiGetClassDevs = _setupapi
    .lookupFunction<
      Pointer<Void> Function(
        Pointer<Uint8>,
        Pointer<Utf16>,
        Pointer<Void>,
        Uint32,
      ),
      Pointer<Void> Function(Pointer<Uint8>, Pointer<Utf16>, Pointer<Void>, int)
    >('SetupDiGetClassDevsW');
final _setupDiEnumDeviceInterfaces = _setupapi
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Void>,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint8>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Void>,
        Pointer<Uint8>,
        int,
        Pointer<Uint8>,
      )
    >('SetupDiEnumDeviceInterfaces');
final _setupDiGetDeviceInterfaceDetail = _setupapi
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Pointer<Uint8>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Void>,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Uint8>,
        Pointer<Uint8>,
        int,
        Pointer<Uint32>,
        Pointer<Void>,
      )
    >('SetupDiGetDeviceInterfaceDetailW');
final _setupDiDestroyDeviceInfoList = _setupapi
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'SetupDiDestroyDeviceInfoList',
    );

// --- hid --------------------------------------------------------------------
final _hidGetHidGuid = _hid
    .lookupFunction<
      Void Function(Pointer<Uint8>),
      void Function(Pointer<Uint8>)
    >('HidD_GetHidGuid');
final _hidGetAttributes = _hid
    .lookupFunction<
      Uint8 Function(Pointer<Void>, Pointer<Uint8>),
      int Function(Pointer<Void>, Pointer<Uint8>)
    >('HidD_GetAttributes');
final _hidGetPreparsedData = _hid
    .lookupFunction<
      Uint8 Function(Pointer<Void>, Pointer<Pointer<Void>>),
      int Function(Pointer<Void>, Pointer<Pointer<Void>>)
    >('HidD_GetPreparsedData');
final _hidFreePreparsedData = _hid
    .lookupFunction<Uint8 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'HidD_FreePreparsedData',
    );
final _hidPGetCaps = _hid
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Uint16>),
      int Function(Pointer<Void>, Pointer<Uint16>)
    >('HidP_GetCaps');
typedef _StringFnNative = Uint8 Function(
  Pointer<Void>,
  Pointer<Uint16>,
  Uint32,
);
typedef _StringFn = int Function(Pointer<Void>, Pointer<Uint16>, int);
final _hidGetSerial = _hid.lookupFunction<_StringFnNative, _StringFn>(
  'HidD_GetSerialNumberString',
);
final _hidGetProduct = _hid.lookupFunction<_StringFnNative, _StringFn>(
  'HidD_GetProductString',
);
final _hidGetManufacturer = _hid.lookupFunction<_StringFnNative, _StringFn>(
  'HidD_GetManufacturerString',
);
typedef _ReportFnNative = Uint8 Function(Pointer<Void>, Pointer<Uint8>, Uint32);
typedef _ReportFn = int Function(Pointer<Void>, Pointer<Uint8>, int);
final _hidSetFeature = _hid.lookupFunction<_ReportFnNative, _ReportFn>(
  'HidD_SetFeature',
);
final _hidGetFeature = _hid.lookupFunction<_ReportFnNative, _ReportFn>(
  'HidD_GetFeature',
);
final _hidGetInputReport = _hid.lookupFunction<_ReportFnNative, _ReportFn>(
  'HidD_GetInputReport',
);
final _hidSetOutputReport = _hid.lookupFunction<_ReportFnNative, _ReportFn>(
  'HidD_SetOutputReport',
);

/// One HID top-level collection, as hidapi's hid_enumerate reports it.
class HidEndpointInfo {
  HidEndpointInfo({
    required this.path,
    required this.vendorId,
    required this.productId,
    required this.interface,
    required this.usage,
    required this.usagePage,
    required this.collection,
    required this.serial,
    required this.product,
    required this.manufacturer,
    required this.inputLength,
    required this.outputLength,
    required this.featureLength,
  });

  final String path;
  final int vendorId;
  final int productId;

  /// USB interface number parsed from `&mi_XX`, or -1 when absent (hidapi).
  final int interface;
  final int usage;
  final int usagePage;

  /// Collection index parsed from `&colXX`, or 0 when absent.
  final int collection;
  final String serial;
  final String product;
  final String manufacturer;
  final int inputLength;
  final int outputLength;
  final int featureLength;

  /// What plugins see of an endpoint.
  Map<String, Object> toPluginEndpoint() => {
    'interface': interface,
    'usagePage': usagePage,
    'usage': usage,
    'collection': collection,
    'inputLength': inputLength,
    'outputLength': outputLength,
    'featureLength': featureLength,
  };

  Map<String, Object> toJson() => {
    'path': path,
    'vendorId': vendorId,
    'productId': productId,
    'interface': interface,
    'usage': usage,
    'usagePage': usagePage,
    'collection': collection,
    'serial': serial,
    'product': product,
    'manufacturer': manufacturer,
    'inputLength': inputLength,
    'outputLength': outputLength,
    'featureLength': featureLength,
  };

  static HidEndpointInfo fromJson(Map<String, dynamic> j) => HidEndpointInfo(
    path: j['path'],
    vendorId: j['vendorId'],
    productId: j['productId'],
    interface: j['interface'],
    usage: j['usage'],
    usagePage: j['usagePage'],
    collection: j['collection'],
    serial: j['serial'],
    product: j['product'],
    manufacturer: j['manufacturer'],
    inputLength: j['inputLength'],
    outputLength: j['outputLength'],
    featureLength: j['featureLength'],
  );
}

String _readHidString(Pointer<Void> h, _StringFn fn) {
  final buf = calloc<Uint16>(256);
  try {
    if (fn(h, buf, 512) == 0) return '';
    return buf.cast<Utf16>().toDartString();
  } finally {
    calloc.free(buf);
  }
}

int _parsePathHex(String lowerPath, String key, int fallback) {
  final m = RegExp('&$key([0-9a-f]{2})').firstMatch(lowerPath);
  return m == null ? fallback : int.parse(m.group(1)!, radix: 16);
}

/// Enumerates every present HID collection (equivalent to hid_enumerate(0, 0)).
List<HidEndpointInfo> hidEnumerate() {
  if (!Platform.isWindows) return [];
  final result = <HidEndpointInfo>[];
  final guid = calloc<Uint8>(16);
  final ifData = calloc<Uint8>(32); // SP_DEVICE_INTERFACE_DATA (x64)
  final required = calloc<Uint32>();
  _hidGetHidGuid(guid);
  final devInfo = _setupDiGetClassDevs(
    guid,
    nullptr,
    nullptr,
    _digcfPresent | _digcfDeviceInterface,
  );
  if (devInfo == _invalidHandle) {
    calloc.free(guid);
    calloc.free(ifData);
    calloc.free(required);
    return result;
  }
  try {
    for (var index = 0; ; index++) {
      ifData.cast<Uint32>().value = 32;
      if (_setupDiEnumDeviceInterfaces(devInfo, nullptr, guid, index, ifData) ==
          0) {
        break;
      }
      _setupDiGetDeviceInterfaceDetail(
        devInfo,
        ifData,
        nullptr,
        0,
        required,
        nullptr,
      );
      final size = required.value;
      if (size == 0) continue;
      final detail = calloc<Uint8>(size);
      String path;
      try {
        detail.cast<Uint32>().value = 8; // cbSize of the x64 detail struct
        if (_setupDiGetDeviceInterfaceDetail(
              devInfo,
              ifData,
              detail,
              size,
              nullptr,
              nullptr,
            ) ==
            0) {
          continue;
        }
        path = (detail + 4).cast<Utf16>().toDartString();
      } finally {
        calloc.free(detail);
      }
      final info = _describePath(path);
      if (info != null) result.add(info);
    }
  } finally {
    _setupDiDestroyDeviceInfoList(devInfo);
    calloc.free(guid);
    calloc.free(ifData);
    calloc.free(required);
  }
  return result;
}

HidEndpointInfo? _describePath(String path) {
  final pPath = path.toNativeUtf16();
  // Access 0 lets us query attributes even for keyboards/mice held by Windows.
  final h = _createFile(
    pPath,
    0,
    _fileShareRead | _fileShareWrite,
    nullptr,
    _openExisting,
    0,
    nullptr,
  );
  calloc.free(pPath);
  if (h == _invalidHandle) return null;
  final attrs = calloc<Uint8>(12);
  final caps = calloc<Uint16>(32); // HIDP_CAPS is 64 bytes
  final pp = calloc<Pointer<Void>>();
  try {
    attrs.cast<Uint32>().value = 12;
    if (_hidGetAttributes(h, attrs) == 0) return null;
    final vid = (attrs + 4).cast<Uint16>().value;
    final pid = (attrs + 6).cast<Uint16>().value;
    var usage = 0, usagePage = 0, inLen = 0, outLen = 0, featLen = 0;
    if (_hidGetPreparsedData(h, pp) != 0) {
      // HIDP_STATUS_SUCCESS == 0x00110000
      if (_hidPGetCaps(pp.value, caps) == 0x00110000) {
        usage = caps[0];
        usagePage = caps[1];
        inLen = caps[2];
        outLen = caps[3];
        featLen = caps[4];
      }
      _hidFreePreparsedData(pp.value);
    }
    final lower = path.toLowerCase();
    return HidEndpointInfo(
      path: path,
      vendorId: vid,
      productId: pid,
      interface: _parsePathHex(lower, 'mi_', -1),
      usage: usage,
      usagePage: usagePage,
      collection: _parsePathHex(lower, 'col', 0),
      serial: _readHidString(h, _hidGetSerial),
      product: _readHidString(h, _hidGetProduct),
      manufacturer: _readHidString(h, _hidGetManufacturer),
      inputLength: inLen,
      outputLength: outLen,
      featureLength: featLen,
    );
  } finally {
    calloc.free(attrs);
    calloc.free(caps);
    calloc.free(pp);
    _closeHandle(h);
  }
}

/// An open HID collection with hidapi-like I/O.
class HidHandle {
  HidHandle._(this.info, this._h)
    : _readEvent = _createEvent(nullptr, 1, 0, nullptr),
      _writeEvent = _createEvent(nullptr, 1, 0, nullptr),
      _readOv = calloc<Uint8>(32),
      _writeOv = calloc<Uint8>(32),
      _bytes = calloc<Uint32>(),
      _readBuf = calloc<Uint8>(info.inputLength.clamp(1, 1 << 16)) {
    (_readOv + 24).cast<Pointer<Void>>().value = _readEvent;
    (_writeOv + 24).cast<Pointer<Void>>().value = _writeEvent;
  }

  final HidEndpointInfo info;
  final Pointer<Void> _h;
  final Pointer<Void> _readEvent;
  final Pointer<Void> _writeEvent;
  final Pointer<Uint8> _readOv;
  final Pointer<Uint8> _writeOv;
  final Pointer<Uint32> _bytes;
  final Pointer<Uint8> _readBuf;
  bool _readPending = false;
  bool _closed = false;

  static HidHandle? open(HidEndpointInfo info) {
    final p = info.path.toNativeUtf16();
    final h = _createFile(
      p,
      _genericRead | _genericWrite,
      _fileShareRead | _fileShareWrite,
      nullptr,
      _openExisting,
      _fileFlagOverlapped,
      nullptr,
    );
    calloc.free(p);
    if (h == _invalidHandle) return null;
    return HidHandle._(info, h);
  }

  Pointer<Uint8> _padded(List<int> data, int length) {
    final buf = calloc<Uint8>(length);
    for (var i = 0; i < data.length && i < length; i++) {
      buf[i] = data[i] & 0xff;
    }
    return buf;
  }

  /// hid_write: pads to the output report length; returns bytes written or -1.
  int write(List<int> data) {
    final length = info.outputLength > data.length
        ? info.outputLength
        : data.length;
    final buf = _padded(data, length);
    try {
      _resetEvent(_writeEvent);
      final ok = _writeFile(_h, buf, length, nullptr, _writeOv);
      if (ok == 0) {
        if (_waitForSingleObject(_writeEvent, 1000) != _waitObject0) {
          // The buffer is freed below: wait for the cancelled write to let
          // go of it first.
          _cancelIo(_h);
          _getOverlappedResult(_h, _writeOv, _bytes, 1);
          return -1;
        }
      }
      if (_getOverlappedResult(_h, _writeOv, _bytes, 0) == 0) return -1;
      return _bytes.value;
    } finally {
      calloc.free(buf);
    }
  }

  /// hid_read_timeout: returns the report (report ID 0 stripped), or an empty
  /// list on timeout / error. [timeoutMs] < 0 blocks.
  Uint8List read(int maxLength, int timeoutMs) {
    if (info.inputLength == 0) return Uint8List(0);
    if (!_readPending) {
      _resetEvent(_readEvent);
      final ok = _readFile(_h, _readBuf, info.inputLength, nullptr, _readOv);
      _readPending = true;
      if (ok != 0) {
        // Completed synchronously; the result is collected below.
      }
    }
    final wait = _waitForSingleObject(
      _readEvent,
      timeoutMs < 0 ? 0xFFFFFFFF : timeoutMs,
    );
    if (wait != _waitObject0) return Uint8List(0);
    _readPending = false;
    if (_getOverlappedResult(_h, _readOv, _bytes, 1) == 0) return Uint8List(0);
    var n = _bytes.value;
    var start = 0;
    if (n > 0 && _readBuf[0] == 0) {
      start = 1;
      n -= 1;
    }
    final copy = n < maxLength ? n : maxLength;
    return Uint8List.fromList(
      _readBuf.asTypedList(start + copy).sublist(start),
    );
  }

  /// Drops any queued input reports.
  void clearReadBuffer() {
    while (read(info.inputLength, 0).isNotEmpty) {}
  }

  /// hid_send_feature_report.
  int sendFeature(List<int> data) {
    final length = info.featureLength > data.length
        ? info.featureLength
        : data.length;
    final buf = _padded(data, length);
    try {
      return _hidSetFeature(_h, buf, length) != 0 ? data.length : -1;
    } finally {
      calloc.free(buf);
    }
  }

  /// hid_get_feature_report: data[0] is the report ID.
  Uint8List getFeature(List<int> data, int length) =>
      _getReport(_hidGetFeature, data, length, info.featureLength);

  /// hid_get_input_report.
  Uint8List getInputReport(List<int> data, int length) =>
      _getReport(_hidGetInputReport, data, length, info.inputLength);

  /// HidD_SetOutputReport (control-pipe output report).
  int setOutputReport(List<int> data) {
    final length = info.outputLength > data.length
        ? info.outputLength
        : data.length;
    final buf = _padded(data, length);
    try {
      return _hidSetOutputReport(_h, buf, length) != 0 ? data.length : -1;
    } finally {
      calloc.free(buf);
    }
  }

  Uint8List _getReport(
    _ReportFn fn,
    List<int> data,
    int length,
    int reportLen,
  ) {
    final size = reportLen > length ? reportLen : length;
    final buf = _padded(data, size);
    try {
      if (fn(_h, buf, size) == 0) return Uint8List(0);
      return Uint8List.fromList(buf.asTypedList(length));
    } finally {
      calloc.free(buf);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_readPending) {
      // Let the cancelled read finish before its buffer is freed.
      _cancelIo(_h);
      _getOverlappedResult(_h, _readOv, _bytes, 1);
    }
    _closeHandle(_h);
    _closeHandle(_readEvent);
    _closeHandle(_writeEvent);
    calloc.free(_readOv);
    calloc.free(_writeOv);
    calloc.free(_bytes);
    calloc.free(_readBuf);
  }
}
