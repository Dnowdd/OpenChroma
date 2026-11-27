import 'dart:ffi';
import 'dart:io';

typedef _OpenThreadNative = Pointer<Void> Function(Uint32, Int32, Uint32);
typedef _OpenThread = Pointer<Void> Function(int, int, int);
typedef _SetPriorityNative = Int32 Function(Pointer<Void>, Int32);
typedef _SetPriority = int Function(Pointer<Void>, int);
typedef _CloseNative = Int32 Function(Pointer<Void>);
typedef _Close = int Function(Pointer<Void>);

const _threadSetInformation = 0x20;
const _priorityIdle = -15;

int currentThreadId() {
  if (!Platform.isWindows) return 0;
  try {
    return DynamicLibrary.open(
      'kernel32.dll',
    ).lookupFunction<Uint32 Function(), int Function()>('GetCurrentThreadId')();
  } catch (_) {
    return 0;
  }
}

// QuickJS cannot be interrupted or killed: a hung plugin is parked at idle priority.
void deprioritizeThread(int id) {
  if (!Platform.isWindows || id == 0) return;
  try {
    final k = DynamicLibrary.open('kernel32.dll');
    final handle = k.lookupFunction<_OpenThreadNative, _OpenThread>(
      'OpenThread',
    )(_threadSetInformation, 0, id);
    if (handle.address == 0) return;
    k.lookupFunction<_SetPriorityNative, _SetPriority>('SetThreadPriority')(
      handle,
      _priorityIdle,
    );
    k.lookupFunction<_CloseNative, _Close>('CloseHandle')(handle);
  } catch (_) {}
}
