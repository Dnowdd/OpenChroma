import 'dart:convert';
import 'dart:io';

import 'system_paths.dart';

/// Executable names (lowercase, e.g. `cs2.exe`) of every running process.
Future<Set<String>> runningProcesses() async {
  final r = await Process.run(SystemPaths.tool('tasklist'), [
    '/fo',
    'csv',
    '/nh',
  ]);
  return {
    for (final line in (r.stdout as String).split('\n'))
      if (line.startsWith('"'))
        line.substring(1, line.indexOf('"', 1)).toLowerCase(),
  };
}

/// A program with a window open: its executable and window title.
typedef RunningApp = ({String exe, String title});

/// Programs that have a window open now, for picking one; sorted by title.
Future<List<RunningApp>> windowedApps() async {
  try {
    final r = await Process.run(SystemPaths.powershell, [
      '-NoProfile',
      '-Command',
      r'[Console]::OutputEncoding = [Text.Encoding]::UTF8; '
          r'Get-Process | Where-Object { $_.MainWindowTitle } | '
          r'ForEach-Object { "$($_.ProcessName)`t$($_.MainWindowTitle)" }',
    ], stdoutEncoding: utf8);
    final seen = <String>{};
    final apps = <RunningApp>[];
    for (final line in const LineSplitter().convert(r.stdout as String)) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      final exe = '${line.substring(0, tab).trim().toLowerCase()}.exe';
      if (!seen.add(exe)) continue;
      apps.add((exe: exe, title: line.substring(tab + 1).trim()));
    }
    apps.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return apps;
  } catch (_) {
    return const [];
  }
}
