import 'dart:io';
import 'dart:typed_data';

/// What a Windows kernel minidump (PAGEDU64 / triage format) says about a
/// blue screen: its bug check, where it happened and which drivers' code
/// was on the crashing thread's stack.
class KernelDump {
  KernelDump({
    required this.path,
    required this.time,
    required this.code,
    required this.params,
    required this.faultModule,
    required this.stackModules,
  });

  final String path;
  final DateTime time;
  final int code;
  final List<int> params;

  /// Driver holding the faulting instruction, for bug checks that report it.
  final String? faultModule;

  /// Drivers with return addresses on the stack, most frequent first.
  final List<String> stackModules;

  String get codeHex => '0x${code.toRadixString(16).toUpperCase()}';

  /// Bug checks raised by code touching memory it should not: the drivers
  /// on their stacks are the suspects.
  bool get isDriverFault => const {
    0xA,
    0xD1,
    0x50,
    0x3B,
    0x1E,
    0x7E,
    0x8E,
    0xC4,
    0x139,
  }.contains(code);

  /// Parses [file]; null when it is not a kernel minidump this reads.
  static KernelDump? read(File file) {
    final Uint8List b;
    try {
      b = file.readAsBytesSync();
    } catch (_) {
      return null;
    }
    if (b.length < 0x2100 ||
        String.fromCharCodes(b.sublist(0, 8)) != 'PAGEDU64') {
      return null;
    }
    final d = ByteData.sublistView(b);
    int u32(int o) => o + 4 <= b.length ? d.getUint32(o, Endian.little) : 0;
    int u64(int o) => o + 8 <= b.length ? d.getUint64(o, Endian.little) : 0;

    final code = u32(0x38);
    final params = [for (var i = 0; i < 4; i++) u64(0x40 + 8 * i)];
    // TRIAGE_DUMP64 right after the 0x2000-byte header.
    const t = 0x2000;
    final stackOff = u32(t + 0x28), stackSize = u32(t + 0x2C);
    final driverOff = u32(t + 0x30), driverCount = u32(t + 0x34);
    final poolOff = u32(t + 0x38);

    final drivers = <(int, int, String)>[];
    if (driverCount > 0 && driverCount < 4096 && poolOff > driverOff) {
      final stride = (poolOff - driverOff) ~/ driverCount;
      for (var i = 0; i < driverCount; i++) {
        final e = driverOff + i * stride;
        final nameOff = u32(e);
        final ldr = e + 8;
        final base = u64(ldr + 0x30);
        final size = u32(ldr + 0x40);
        final len = u32(nameOff);
        if (len == 0 || len > 260 || nameOff + 4 + len * 2 > b.length) continue;
        final name = String.fromCharCodes(
          Uint16List.sublistView(
            Uint8List.fromList(b.sublist(nameOff + 4, nameOff + 4 + len * 2)),
          ),
        );
        drivers.add((base, size, name.split('\\').last.toLowerCase()));
      }
    }
    String? moduleAt(int addr) {
      for (final (base, size, name) in drivers) {
        if (addr >= base && addr < base + size) return name;
      }
      return null;
    }

    final counts = <String, int>{};
    if (stackOff > 0 && stackSize > 0 && stackOff + stackSize <= b.length) {
      for (var o = stackOff; o + 8 <= stackOff + stackSize; o += 8) {
        final v = u64(o);
        // Kernel addresses: the top 17 bits set.
        if ((v >> 47) & 0x1FFFF != 0x1FFFF) continue;
        final m = moduleAt(v);
        if (m != null) counts[m] = (counts[m] ?? 0) + 1;
      }
    }
    final stack = counts.keys.toList()
      ..sort((a, c) => counts[c]!.compareTo(counts[a]!));
    final dump = KernelDump(
      path: file.path,
      time: file.lastModifiedSync(),
      code: code,
      params: params,
      faultModule: null,
      stackModules: stack,
    );
    return dump.isDriverFault
        ? KernelDump(
            path: dump.path,
            time: dump.time,
            code: code,
            params: params,
            faultModule: moduleAt(params[3]),
            stackModules: stack,
          )
        : dump;
  }
}

/// Windows' own drivers: never the suspect by themselves.
const microsoftDrivers = {
  'ntoskrnl.exe',
  'hal.dll',
  'ci.dll',
  'fltmgr.sys',
  'ndis.sys',
  'tcpip.sys',
  'netio.sys',
  'storport.sys',
  'stornvme.sys',
  'classpnp.sys',
  'disk.sys',
  'volmgr.sys',
  'partmgr.sys',
  'ntfs.sys',
  'fwpkclnt.sys',
  'wdf01000.sys',
  'acpi.sys',
  'pci.sys',
  'dxgkrnl.sys',
  'dxgmms2.sys',
  'win32k.sys',
  'win32kbase.sys',
  'win32kfull.sys',
  'afd.sys',
  'usbxhci.sys',
  'ucx01000.sys',
  'usbhub3.sys',
  'hidclass.sys',
  'hidparse.sys',
  'ksecdd.sys',
  'cng.sys',
  'msrpc.sys',
  'clfs.sys',
  'tm.sys',
  'wof.sys',
  'fileinfo.sys',
  'wcifs.sys',
  'cldflt.sys',
  'volsnap.sys',
  'rdyboost.sys',
  'mup.sys',
  'vmbus.sys',
  'winhvr.sys',
  'werkernel.sys',
  'pdc.sys',
  'mssecflt.sys',
  'wdfilter.sys',
  'intelppm.sys',
  'amdppm.sys',
  'kbdclass.sys',
  'mouclass.sys',
  'hidusb.sys',
  'watchdog.sys',
  'wpprecorder.sys',
  'wdiwifi.sys',
  'usbport.sys',
  'usbccgp.sys',
  'ks.sys',
  'portcls.sys',
  'hdaudbus.sys',
  'storahci.sys',
  'iorate.sys',
  'bindflt.sys',
  'npfs.sys',
  'msfs.sys',
  'netbt.sys',
  'http.sys',
  'srv2.sys',
  'mrxsmb.sys',
  'rdbss.sys',
  'luafv.sys',
  'bam.sys',
  'ahcache.sys',
  'cimfs.sys',
};
