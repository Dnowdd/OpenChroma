import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../checkup/checkup.dart';
import '../effects/effect_library.dart';
import '../engine/engine.dart';
import '../fans/fan_service.dart';
import '../i18n/l10n.dart';
import '../monitor/system_monitor.dart';
import 'ai_service.dart';

/// One turn of the assistant conversation. A reply may carry an effect the
/// model wrote, ready to apply.
class AssistantTurn {
  AssistantTurn(this.role, this.text, {this.effect, this.error = false});
  final String role;
  final String text;
  final Map<String, dynamic>? effect;
  final bool error;
}

/// The home page assistant: answers questions about this PC with live
/// readings as context, and can write `.ocfx` lighting effects.
class Assistant extends ChangeNotifier {
  Assistant({
    required this.ai,
    required this.engine,
    required this.monitor,
    required this.fans,
  });

  final AiService ai;
  final Engine engine;
  final SystemMonitor monitor;
  final FanService fans;

  final List<AssistantTurn> turns = [];
  bool busy = false;

  void clear() {
    turns.clear();
    notifyListeners();
  }

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || busy) return;
    turns.add(AssistantTurn('user', q));
    busy = true;
    notifyListeners();
    try {
      final reply = await ai.chat(
        system: _systemPrompt(),
        messages: [
          for (final t in turns.where((t) => !t.error))
            AiMessage(t.role, t.text),
        ],
      );
      final (text, effect) = _extractEffect(reply);
      turns.add(AssistantTurn('assistant', text, effect: effect));
    } catch (e) {
      turns.add(AssistantTurn('assistant', '$e', error: true));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Imports an effect the assistant wrote and turns it on.
  EffectInfo applyEffect(Map<String, dynamic> effect) {
    final dir = Directory.systemTemp.createTempSync('openchroma-ai');
    try {
      final file = File(p.join(dir.path, 'effect.ocfx'))
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(effect));
      return engine.importEffect(file.path);
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  static final _block = RegExp(
    r'```(?:ocfx|json)?\s*(\{[\s\S]*?\})\s*```',
    multiLine: true,
  );

  /// Pulls a valid `.ocfx` document out of a reply, if there is one, and
  /// removes the code block from the text shown to the user.
  static (String, Map<String, dynamic>?) _extractEffect(String reply) {
    for (final m in _block.allMatches(reply)) {
      try {
        final doc = jsonDecode(m.group(1)!);
        if (doc is Map<String, dynamic> &&
            doc['openchroma'] == 1 &&
            doc['layers'] is List) {
          final dir = Directory.systemTemp.createTempSync('openchroma-check');
          try {
            final f = File(p.join(dir.path, 'e.ocfx'))
              ..writeAsStringSync(jsonEncode(doc));
            parseOcfx(f.path);
          } finally {
            dir.deleteSync(recursive: true);
          }
          final text = reply.replaceFirst(m.group(0)!, '').trim();
          return (text.isEmpty ? l10n.aiEffectDone : text, doc);
        }
      } catch (_) {}
    }
    return (reply, null);
  }

  String _systemPrompt() {
    final b = StringBuffer()
      ..writeln(
        'You are the assistant of OpenChroma, a Windows app that controls RGB '
        'lighting and fans and monitors the PC. Always answer in '
        '${l10n.localeName == 'pt' ? 'Brazilian Portuguese' : 'English'}, '
        'the language of the app interface, short and direct (at most about 6 '
        'short paragraphs), without heavy markdown. Use the data below, which '
        'are real readings from this PC right now. If a value is not '
        'available, say so instead of making it up. Do not ask the user to '
        'paste data that is already here.',
      )
      ..writeln()
      ..writeln('## PC state')
      ..writeln(describeSystem(monitor.snapshot))
      ..writeln()
      ..writeln('## Lighting')
      ..writeln('Current effect: ${engine.currentEffect?.title ?? 'none'}')
      ..writeln('Brightness: ${engine.brightness}%')
      ..writeln(
        'Available effects: ${engine.effects.map((e) => e.title).join(', ')}',
      )
      ..writeln(
        'Devices: ${engine.devices.values.map((d) => '${d.name} (${d.status})').join(', ').ifEmpty('none detected')}',
      )
      ..writeln()
      ..writeln('## Fans')
      ..writeln(_fans())
      ..writeln()
      ..writeln(_ocfxGuide);
    return b.toString();
  }

  String _fans() {
    final s = fans.snapshot;
    if (s == null || s.fans.isEmpty) return 'No fan readings.';
    return [
      'Profile: ${fans.profile.name}',
      for (final f in s.fans.where(fans.isConnected))
        '${fans.nameOf(f)}: ${f.rpm?.round() ?? '?'} RPM'
            '${f.duty == null ? '' : ', ${f.duty!.round()}%'}',
    ].join('\n');
  }

  static const _ocfxGuide = '''
## Creating effects
If the user asks for a light effect, reply with one short sentence and a
```ocfx block containing JSON in this format (colors as #RRGGBB). Write the
name, description and parameter labels in the language of your reply:
{"openchroma": 1, "name": "Short name", "description": "One sentence.",
 "background": "#000000",
 "params": {"speed": {"label": "Speed", "type": "number", "min": 0, "max": 100, "default": 40},
            "color": {"label": "Color", "type": "color", "default": "#3B82F6"}},
 "layers": [ ... ]}
Layers (drawn bottom to top; "blend": normal|screen|add|multiply|overlay; "opacity" 0..1):
- solid {color}
- gradient {colors:[...], angle, scale, speed}
- spectrum {angle, scale, speed, saturation, lightness}
- pulse {color, min, max, speed}
- wave {color, amplitude, frequency, thickness, position, speed}
- sweep {color, width, speed, bounce}
- rings {colors:[...], spacing, thickness, x, y, speed}
- sparkle {color or "random", density, size, speed}
- plasma {colors:[...], scale, speed}
- fire {colors:[...], height, speed}
- rain {color, density, length, speed}
- stars {color, density, speed}
- noise {colors:[...], scale, speed}
- heartbeat {color, speed}
- strobe {colors:[...], speed}
Values can be "\$name" to use a parameter. Speed goes from 0 to 100.
Audio layers (bars, meter, ripple, flash) only make sense if the user asks for something that reacts to sound.''';
}

/// Plain-text summary of a monitor reading, for model context.
String describeSystem(SystemSnapshot? s) {
  if (s == null) return 'Readings not available yet.';
  String n(double? v, [int d = 0]) => v == null ? '?' : v.toStringAsFixed(d);
  String gb(double bytes) => '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  final lines = <String>[
    'CPU: ${s.cpu.name}, ${s.cpu.cores} cores/${s.cpu.threads} threads, '
        'usage ${n(s.cpu.usage)}%, ${n(s.cpu.clock)} MHz, '
        'temperature ${s.cpu.temp == null ? 'unavailable (${s.cpu.sensor.name})' : '${n(s.cpu.temp)} °C'}, '
        'power ${n(s.cpu.power)} W',
    for (final g in s.gpus)
      'GPU: ${g.name}${g.integrated ? ' (integrated)' : ''}, usage ${n(g.usage)}%, '
          '${n(g.temp)} °C, ${n(g.power)} W, fan ${n(g.fan)}%, '
          'VRAM ${n((g.memUsed ?? 0) / (1 << 20))} of ${n((g.memTotal ?? 0) / (1 << 20))} MB',
    'Memory: ${gb(s.memory.used)} of ${gb(s.memory.total)} in use '
        '(${n(s.memory.percent)}%), commit ${gb(s.memory.committed)} of ${gb(s.memory.commitLimit)}',
    for (final v in s.volumes)
      'Drive ${v.letter}: ${gb(v.free)} free of ${gb(v.total)}',
    for (final d in s.disks)
      if (d.temp != null) 'SSD/HDD ${d.model}: ${n(d.temp)} °C',
    'Uptime ${s.uptime.inHours} h ${s.uptime.inMinutes % 60} min',
    'Top processes by CPU: ${(s.processes.toList()..sort((a, b) => b.cpu.compareTo(a.cpu))).take(6).map((p) => '${p.name} ${p.cpu.toStringAsFixed(1)}%').join(', ')}',
    'Top processes by memory: ${(s.processes.toList()..sort((a, b) => b.memory.compareTo(a.memory))).take(6).map((p) => '${p.name} ${gb(p.memory)}').join(', ')}',
  ];
  return lines.join('\n');
}

/// Plain-text summary of a checkup, for the AI analysis.
String describeCheckup(CheckupReport r) {
  final s = r.system;
  String n(double? v, [int d = 0]) => v == null ? '?' : v.toStringAsFixed(d);
  final b = StringBuffer()
    ..writeln(
      'Checkup from ${r.started.toIso8601String()} (plan ${r.plan.name})',
    )
    ..writeln('Motherboard: ${s.board}, BIOS ${s.bios}')
    ..writeln('CPU: ${s.cpuName} (AVX2: ${s.avx2}); GPU: ${s.gpuName}')
    ..writeln(
      'Memory: ${n(s.memTotal / (1 << 30), 1)} GB, ${s.modules.length} of ${s.slots} slots: '
      '${s.modules.map((m) => '${m.maker} ${m.part} ${m.megabytes} MB ${m.configured}/${m.speed} MT/s channel ${m.channel ?? '?'}').join('; ')}',
    )
    ..writeln(
      'System drive: ${n((s.driveFree ?? 0) / (1 << 30))} GB free of ${n((s.driveTotal ?? 0) / (1 << 30))} GB',
    )
    ..writeln(
      'At idle: CPU ${n(s.idleCpuTemp)} °C, usage ${n(s.idleCpuUsage)}%; startup apps: ${s.startupApps ?? '?'}',
    )
    ..writeln(
      'Recent blue screens: ${s.blueScreens.length} (${s.blueScreens.take(10).map((x) => '${x.code} on ${x.time.toIso8601String().substring(0, 10)}').join(', ')})',
    )
    ..writeln(
      'Suspect drivers in the blue screens: ${s.suspects.isEmpty ? 'none identified' : s.suspects.entries.map((e) => '${e.key} (${e.value}x)').join(', ')}',
    );
  if (r.abortReason != null) b.writeln('Aborted: ${r.abortReason}');
  for (final t in r.tests) {
    b.writeln(
      'Test ${t.test.id}: ${t.status}, errors ${t.errors}, '
      'CPU max ${n(t.maxCpuTemp)} °C at ${n(t.avgCpuClock)} MHz and ${n(t.avgCpuPower)} W, '
      'GPU max ${n(t.maxGpuTemp)} °C at ${n(t.avgGpuPower)} W'
      '${t.memWrite > 0 ? ', memory ${n(t.memWrite, 1)}/${n(t.memRead, 1)} GB/s' : ''}'
      '${t.gpuTflops > 0 ? ', ${n(t.gpuTflops, 1)} TFLOPS' : ''}'
      '${t.diskWrite > 0 ? ', disk ${n(t.diskWrite)}/${n(t.diskRead)} MB/s' : ''}'
      '${t.error.isEmpty ? '' : ', ${t.error}'}',
    );
  }
  b.writeln('App recommendations:');
  for (final rec in recommendationsFor(r)) {
    b.writeln('- [${rec.severity.name}] ${rec.title}: ${rec.detail}');
  }
  return b.toString();
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
