import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../fans/fan_service.dart';
import '../i18n/l10n.dart';
import 'native_security.dart';
import 'system_paths.dart';

typedef _RunElevatedNative = Int32 Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Int32,
);
typedef _RunElevated = int Function(Pointer<Utf16>, Pointer<Utf16>, int);

/// Administrator rights, through the runner's windows/runner/elevation.cpp.
class Elevation {
  static final bool _native = () {
    try {
      return DynamicLibrary.executable()
              .lookupFunction<Int32 Function(), int Function()>(
                'OcIsElevated',
              )() ==
          1;
    } catch (_) {
      return false;
    }
  }();

  @visibleForTesting
  static bool? debugOverride;

  static bool get isElevated => debugOverride ?? _native;

  /// Starts this app again elevated with [args]; true when it launched.
  static bool relaunch(List<String> args) {
    try {
      final run = DynamicLibrary.executable()
          .lookupFunction<_RunElevatedNative, _RunElevated>('OcRunElevated');
      return using((arena) {
        final params = args.map((a) => '"$a"').join(' ');
        return run(nullptr, params.toNativeUtf16(allocator: arena), 0) == 0;
      });
    } catch (_) {
      return false;
    }
  }
}

/// Restarts the app elevated, reopening [page]. Shuts the current instance
/// down (so plugins apply their shutdown colors) only once the new one
/// launched; does nothing when the UAC prompt is declined.
Future<void> restartAsAdmin({
  required int page,
  required Future<void> Function() shutdown,
}) async {
  // --replace: the new instance starts even though this one still runs.
  if (!Elevation.relaunch(['--page=$page', '--replace'])) return;
  // The new instance saves the fans' firmware settings when it takes them
  // over; hand them back first so it does not save ours.
  FanService.releaseAll();
  await shutdown();
  try {
    DynamicLibrary.executable()
        .lookupFunction<Void Function(), void Function()>('OcTrayRemoveIcon')();
  } catch (_) {}
  exit(0);
}

/// Why changing "start with Windows" cannot be done right now.
enum StartupBlock { needsAdmin, installNotTrusted }

/// "Always run as administrator", "start with Windows" and "keep running in
/// the background", stored where Windows (or the runner) reads them, so they
/// also apply to a packaged exe:
/// - always admin: the RUNASADMIN compatibility flag for this exe (HKCU),
///   which makes every launch ask for elevation;
/// - start with Windows: a value under HKCU\...\Run, or, when it should
///   start elevated, a logon task with the highest run level (the Run key
///   cannot start elevated programs, and the task does so without a prompt).
///   Both pass --hidden, so the app starts in the tray. The task is only
///   created or removed by an elevated app, and only when no program
///   without administrator rights can change the install (a per-user
///   install could be replaced to get administrator rights at logon);
/// - background: RunInBackground under HKCU\Software\OpenChroma, read by
///   windows/runner/tray.cpp when the window closes.
class LaunchSettings extends ChangeNotifier {
  LaunchSettings() {
    load();
  }

  static LaunchSettings Function() create = LaunchSettings.new;

  static const _layersKey =
      r'HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _name = 'OpenChroma';
  static const _appKey = r'HKCU\Software\OpenChroma';

  final String exe = Platform.resolvedExecutable;

  bool alwaysAdmin = false;
  bool startWithWindows = false;

  /// Closing the window leaves the app in the tray.
  bool runInBackground = true;
  bool _task = false;
  bool installSecure = true;
  bool busy = false;
  bool loaded = false;

  /// What went wrong in the last change, for the UI.
  String? error;

  Future<void> load() async {
    final layers = await Process.run(SystemPaths.tool('reg'), [
      'query',
      _layersKey,
      '/v',
      exe,
    ]);
    alwaysAdmin =
        layers.exitCode == 0 && '${layers.stdout}'.contains('RUNASADMIN');
    final run = await Process.run(SystemPaths.tool('reg'), [
      'query',
      _runKey,
      '/v',
      _name,
    ]);
    _task = await NativeSecurity.startupTaskExists();
    installSecure = await NativeSecurity.installIsSecure();
    startWithWindows = run.exitCode == 0 || _task;
    final bg = await Process.run(SystemPaths.tool('reg'), [
      'query',
      _appKey,
      '/v',
      'RunInBackground',
    ]);
    // Missing means the default: on.
    runInBackground =
        bg.exitCode != 0 ||
        !RegExp(r'REG_DWORD\s+0x0\b').hasMatch('${bg.stdout}');
    loaded = true;
    notifyListeners();
  }

  /// A logon task for the elevated start exists.
  bool get hasStartupTask => _task;

  /// What stops the next change of "start with Windows" (turning it off when
  /// it is on, on when it is off); null when it can be done.
  StartupBlock? get startupBlock =>
      _blockFor(enable: !startWithWindows, admin: alwaysAdmin);

  /// An elevated start is set up although the install can be changed
  /// without administrator rights.
  bool get startupTaskUntrusted => _task && !installSecure;

  StartupBlock? _blockFor({required bool enable, required bool admin}) {
    if (enable && admin) {
      if (!installSecure) return StartupBlock.installNotTrusted;
      if (!Elevation.isElevated) return StartupBlock.needsAdmin;
    } else if (_task && !Elevation.isElevated) {
      return StartupBlock.needsAdmin;
    }
    return null;
  }

  String _blockMessage(StartupBlock block) => switch (block) {
    StartupBlock.needsAdmin => l10n.securityErrorNeedsAdmin,
    StartupBlock.installNotTrusted => l10n.securityErrorInstallNotTrusted,
  };

  Future<void> setAlwaysAdmin(bool value) => _change(() async {
    if (startWithWindows) {
      final block = _blockFor(enable: true, admin: value);
      if (block != null) {
        error = _blockMessage(block);
        return;
      }
    }
    final r = value
        ? await Process.run(SystemPaths.tool('reg'), [
            'add',
            _layersKey,
            '/v',
            exe,
            '/t',
            'REG_SZ',
            '/d',
            '~ RUNASADMIN',
            '/f',
          ])
        : await Process.run(SystemPaths.tool('reg'), [
            'delete',
            _layersKey,
            '/v',
            exe,
            '/f',
          ]);
    if (r.exitCode != 0) {
      error = l10n.systemErrorWindowsSetting;
      return;
    }
    // Startup must follow: only the task can start the app elevated.
    if (startWithWindows) await _applyStartup(true, admin: value);
  });

  Future<void> setRunInBackground(bool value) => _change(() async {
    final r = await Process.run(SystemPaths.tool('reg'), [
      'add',
      _appKey,
      '/v',
      'RunInBackground',
      '/t',
      'REG_DWORD',
      '/d',
      value ? '1' : '0',
      '/f',
    ]);
    if (r.exitCode != 0) error = l10n.systemErrorSaveSetting;
  });

  Future<void> setStartWithWindows(bool value) =>
      _change(() => _applyStartup(value, admin: alwaysAdmin));

  Future<void> _change(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = '$e';
    }
    await load();
    busy = false;
    notifyListeners();
  }

  Future<void> _applyStartup(bool enable, {required bool admin}) async {
    final wantTask = enable && admin;
    final wantRun = enable && !admin;

    final block = _blockFor(enable: enable, admin: admin);
    if (block != null) {
      error = _blockMessage(block);
      return;
    }
    if (wantTask) {
      final result = await NativeSecurity.registerStartupTask(
        l10n.systemTaskDescription,
      );
      if (result != TaskResult.done) {
        error = switch (result) {
          TaskResult.needsAdmin => l10n.securityErrorNeedsAdmin,
          TaskResult.installNotTrusted => l10n.securityErrorInstallNotTrusted,
          _ => l10n.securityErrorTaskNotCreated,
        };
        return;
      }
    } else if (_task) {
      final result = await NativeSecurity.deleteStartupTask();
      if (result != TaskResult.done) {
        error = result == TaskResult.needsAdmin
            ? l10n.securityErrorNeedsAdmin
            : l10n.securityErrorTaskNotRemoved;
        return;
      }
    }
    if (wantRun) {
      final r = await Process.run(SystemPaths.tool('reg'), [
        'add',
        _runKey,
        '/v',
        _name,
        '/t',
        'REG_SZ',
        '/d',
        '"$exe" --hidden',
        '/f',
      ]);
      if (r.exitCode != 0) {
        error = l10n.systemErrorEnableStartup;
      }
    } else {
      await Process.run(SystemPaths.tool('reg'), [
        'delete',
        _runKey,
        '/v',
        _name,
        '/f',
      ]);
    }
  }
}
