import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../fans/fan_service.dart';

typedef _RunElevatedNative = Int32 Function(
  Pointer<Utf16>,
  Pointer<Utf16>,
  Int32,
);
typedef _RunElevated = int Function(Pointer<Utf16>, Pointer<Utf16>, int);

/// Administrator rights, through the runner's windows/runner/elevation.cpp.
class Elevation {
  static final bool isElevated = () {
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

  /// Runs [file] elevated (UAC prompt) and waits for it on a background
  /// isolate. Returns its exit code, or -1 when the prompt was declined.
  static Future<int> run(String file, String params) =>
      Isolate.run(() => _run(file, params, true));

  /// Starts this app again elevated with [args]; true when it launched.
  static bool relaunch(List<String> args) =>
      _run(null, args.map((a) => '"$a"').join(' '), false) == 0;

  static int _run(String? file, String params, bool wait) {
    try {
      final run = DynamicLibrary.executable()
          .lookupFunction<_RunElevatedNative, _RunElevated>('OcRunElevated');
      return using((arena) {
        final f = file == null
            ? nullptr.cast<Utf16>()
            : file.toNativeUtf16(allocator: arena);
        return run(f, params.toNativeUtf16(allocator: arena), wait ? 1 : 0);
      });
    } catch (_) {
      return -1;
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

/// "Always run as administrator", "start with Windows" and "keep running in
/// the background", stored where Windows (or the runner) reads them, so they
/// also apply to a packaged exe:
/// - always admin: the RUNASADMIN compatibility flag for this exe (HKCU),
///   which makes every launch ask for elevation;
/// - start with Windows: a value under HKCU\...\Run, or, when it should
///   start elevated, a logon task with the highest run level (the Run key
///   cannot start elevated programs, and the task does so without a prompt).
///   Both pass --hidden, so the app starts in the tray;
/// - background: RunInBackground under HKCU\Software\OpenChroma, read by
///   windows/runner/tray.cpp when the window closes.
class LaunchSettings extends ChangeNotifier {
  LaunchSettings() {
    load();
  }

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
  bool busy = false;
  bool loaded = false;

  /// What went wrong in the last change, for the UI.
  String? error;

  Future<void> load() async {
    final layers = await Process.run('reg', ['query', _layersKey, '/v', exe]);
    alwaysAdmin =
        layers.exitCode == 0 && '${layers.stdout}'.contains('RUNASADMIN');
    final run = await Process.run('reg', ['query', _runKey, '/v', _name]);
    final task = await Process.run('schtasks', ['/Query', '/TN', _name]);
    _task = task.exitCode == 0;
    startWithWindows = run.exitCode == 0 || _task;
    final bg = await Process.run('reg', [
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

  Future<void> setAlwaysAdmin(bool value) => _change(() async {
    final r = value
        ? await Process.run('reg', [
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
        : await Process.run('reg', ['delete', _layersKey, '/v', exe, '/f']);
    if (r.exitCode != 0) {
      error = 'Não foi possível alterar a configuração do Windows.';
      return;
    }
    // Startup must follow: only the task can start the app elevated.
    if (startWithWindows) await _applyStartup(true, admin: value);
  });

  Future<void> setRunInBackground(bool value) => _change(() async {
    final r = await Process.run('reg', [
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
    if (r.exitCode != 0) error = 'Não foi possível salvar a configuração.';
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

    // Change the task first: it needs the UAC prompt, and when that is
    // declined startup stays as it was.
    if (wantTask && !await _createTask()) return;
    if (!wantTask && _task && !await _deleteTask()) return;
    if (wantRun) {
      final r = await Process.run('reg', [
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
        error = 'Não foi possível ativar a inicialização com o Windows.';
      }
    } else {
      await Process.run('reg', ['delete', _runKey, '/v', _name, '/f']);
    }
  }

  Future<bool> _createTask() async {
    final user =
        '${Platform.environment['USERDOMAIN']}\\${Platform.environment['USERNAME']}';
    final xml = File('${Directory.systemTemp.path}\\openchroma_task.xml');
    // schtasks expects the XML in UTF-16 with a BOM.
    final text = _taskXml(exe: exe, user: user);
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in text.codeUnits) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }
    await xml.writeAsBytes(bytes);
    try {
      final args = ['/Create', '/TN', _name, '/XML', xml.path, '/F'];
      final ok = await _schtasks(args);
      if (!ok) {
        error =
            'A tarefa de inicialização não foi criada. '
            'É preciso aceitar a permissão do Windows.';
      }
      return ok;
    } finally {
      if (await xml.exists()) await xml.delete();
    }
  }

  Future<bool> _deleteTask() async {
    final ok = await _schtasks(['/Delete', '/TN', _name, '/F']);
    if (!ok) {
      error =
          'A tarefa de inicialização não foi removida. '
          'É preciso aceitar a permissão do Windows.';
    }
    return ok;
  }

  /// Runs schtasks directly when already elevated, otherwise through UAC.
  Future<bool> _schtasks(List<String> args) async {
    if (Elevation.isElevated) {
      return (await Process.run('schtasks', args)).exitCode == 0;
    }
    final params = args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
    return await Elevation.run('schtasks.exe', params) == 0;
  }

  static String _taskXml({required String exe, required String user}) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final dir = File(exe).parent.path;
    return '''<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Abre o OpenChroma como administrador ao entrar no Windows.</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>${esc(user)}</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>${esc(user)}</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>${esc(exe)}</Command>
      <Arguments>--hidden</Arguments>
      <WorkingDirectory>${esc(dir)}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
''';
  }
}
