import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../checkup/checkup.dart';
import '../effects/effect_library.dart';
import '../engine/engine.dart';
import '../fans/fan_service.dart';
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
      final file = File(p.join(dir.path, 'efeito.ocfx'))
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
          return (text.isEmpty ? 'Pronto, fiz o efeito.' : text, doc);
        }
      } catch (_) {}
    }
    return (reply, null);
  }

  String _systemPrompt() {
    final b = StringBuffer()
      ..writeln(
        'Você é o assistente do OpenChroma, um app para Windows que controla '
        'iluminação RGB, ventoinhas e monitora o PC. Responda em português do '
        'Brasil, de forma curta e direta (no máximo uns 6 parágrafos curtos), '
        'sem markdown pesado. Use os dados abaixo, que são leituras reais '
        'deste PC agora. Se um dado não estiver disponível, diga isso em vez '
        'de inventar. Não peça para o usuário colar dados que já estão aqui.',
      )
      ..writeln()
      ..writeln('## Estado do PC')
      ..writeln(describeSystem(monitor.snapshot))
      ..writeln()
      ..writeln('## Iluminação')
      ..writeln('Efeito atual: ${engine.currentEffect?.title ?? 'nenhum'}')
      ..writeln('Brilho: ${engine.brightness}%')
      ..writeln(
        'Efeitos disponíveis: ${engine.effects.map((e) => e.title).join(', ')}',
      )
      ..writeln(
        'Dispositivos: ${engine.devices.values.map((d) => '${d.name} (${d.status})').join(', ').ifEmpty('nenhum detectado')}',
      )
      ..writeln()
      ..writeln('## Ventoinhas')
      ..writeln(_fans())
      ..writeln()
      ..writeln(_ocfxGuide);
    return b.toString();
  }

  String _fans() {
    final s = fans.snapshot;
    if (s == null || s.fans.isEmpty) return 'Sem leitura de ventoinhas.';
    return [
      'Perfil: ${fans.profile.name}',
      for (final f in s.fans.where(fans.isConnected))
        '${fans.nameOf(f)}: ${f.rpm?.round() ?? '?'} RPM'
            '${f.duty == null ? '' : ', ${f.duty!.round()}%'}',
    ].join('\n');
  }

  static const _ocfxGuide = '''
## Criar efeitos
Se o usuário pedir um efeito de luz, responda com uma frase curta e um bloco
```ocfx contendo um JSON neste formato (cores em #RRGGBB):
{"openchroma": 1, "name": "Nome curto", "description": "Uma frase.",
 "background": "#000000",
 "params": {"speed": {"label": "Velocidade", "type": "number", "min": 0, "max": 100, "default": 40},
            "color": {"label": "Cor", "type": "color", "default": "#3B82F6"}},
 "layers": [ ... ]}
Camadas (desenhadas de baixo para cima; "blend": normal|screen|add|multiply|overlay; "opacity" 0..1):
- solid {color}
- gradient {colors:[...], angle, scale, speed}
- spectrum {angle, scale, speed, saturation, lightness}
- pulse {color, min, max, speed}
- wave {color, amplitude, frequency, thickness, position, speed}
- sweep {color, width, speed, bounce}
- rings {colors:[...], spacing, thickness, x, y, speed}
- sparkle {color ou "random", density, size, speed}
- plasma {colors:[...], scale, speed}
- fire {colors:[...], height, speed}
- rain {color, density, length, speed}
- stars {color, density, speed}
- noise {colors:[...], scale, speed}
- heartbeat {color, speed}
- strobe {colors:[...], speed}
Valores podem ser "\$nome" para usar um parâmetro. Velocidade vai de 0 a 100.
Camadas de áudio (bars, meter, ripple, flash) só fazem sentido se o usuário pedir algo que reage ao som.''';
}

/// Plain-text summary of a monitor reading, for model context.
String describeSystem(SystemSnapshot? s) {
  if (s == null) return 'Leituras ainda não disponíveis.';
  String n(double? v, [int d = 0]) => v == null ? '?' : v.toStringAsFixed(d);
  String gb(double bytes) => '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  final lines = <String>[
    'CPU: ${s.cpu.name}, ${s.cpu.cores} núcleos/${s.cpu.threads} threads, '
        'uso ${n(s.cpu.usage)}%, ${n(s.cpu.clock)} MHz, '
        'temperatura ${s.cpu.temp == null ? 'indisponível (${s.cpu.sensor.name})' : '${n(s.cpu.temp)} °C'}, '
        'potência ${n(s.cpu.power)} W',
    for (final g in s.gpus)
      'GPU: ${g.name}${g.integrated ? ' (integrada)' : ''}, uso ${n(g.usage)}%, '
          '${n(g.temp)} °C, ${n(g.power)} W, ventoinha ${n(g.fan)}%, '
          'VRAM ${n((g.memUsed ?? 0) / (1 << 20))} de ${n((g.memTotal ?? 0) / (1 << 20))} MB',
    'Memória: ${gb(s.memory.used)} de ${gb(s.memory.total)} em uso '
        '(${n(s.memory.percent)}%), commit ${gb(s.memory.committed)} de ${gb(s.memory.commitLimit)}',
    for (final v in s.volumes)
      'Disco ${v.letter}: ${gb(v.free)} livres de ${gb(v.total)}',
    for (final d in s.disks)
      if (d.temp != null) 'SSD/HD ${d.model}: ${n(d.temp)} °C',
    'Ligado há ${s.uptime.inHours} h ${s.uptime.inMinutes % 60} min',
    'Processos que mais usam CPU: ${(s.processes.toList()..sort((a, b) => b.cpu.compareTo(a.cpu))).take(6).map((p) => '${p.name} ${p.cpu.toStringAsFixed(1)}%').join(', ')}',
    'Processos que mais usam memória: ${(s.processes.toList()..sort((a, b) => b.memory.compareTo(a.memory))).take(6).map((p) => '${p.name} ${gb(p.memory)}').join(', ')}',
  ];
  return lines.join('\n');
}

/// Plain-text summary of a checkup, for the AI analysis.
String describeCheckup(CheckupReport r) {
  final s = r.system;
  String n(double? v, [int d = 0]) => v == null ? '?' : v.toStringAsFixed(d);
  final b = StringBuffer()
    ..writeln(
      'Diagnóstico de ${r.started.toIso8601String()} (plano ${r.plan.name})',
    )
    ..writeln('Placa-mãe: ${s.board}, BIOS ${s.bios}')
    ..writeln('CPU: ${s.cpuName} (AVX2: ${s.avx2}); GPU: ${s.gpuName}')
    ..writeln(
      'Memória: ${n(s.memTotal / (1 << 30), 1)} GB, ${s.modules.length} de ${s.slots} slots: '
      '${s.modules.map((m) => '${m.maker} ${m.part} ${m.megabytes} MB ${m.configured}/${m.speed} MT/s canal ${m.channel ?? '?'}').join('; ')}',
    )
    ..writeln(
      'Disco do sistema: ${n((s.driveFree ?? 0) / (1 << 30))} GB livres de ${n((s.driveTotal ?? 0) / (1 << 30))} GB',
    )
    ..writeln(
      'Em repouso: CPU ${n(s.idleCpuTemp)} °C, uso ${n(s.idleCpuUsage)}%; apps na inicialização: ${s.startupApps ?? '?'}',
    )
    ..writeln(
      'Telas azuis recentes: ${s.blueScreens.length} (${s.blueScreens.take(10).map((x) => '${x.code} em ${x.time.toIso8601String().substring(0, 10)}').join(', ')})',
    )
    ..writeln(
      'Drivers suspeitos nas telas azuis: ${s.suspects.isEmpty ? 'nenhum identificado' : s.suspects.entries.map((e) => '${e.key} (${e.value}x)').join(', ')}',
    );
  if (r.abortReason != null) b.writeln('Interrompido: ${r.abortReason}');
  for (final t in r.tests) {
    b.writeln(
      'Teste ${t.test.id}: ${t.status}, erros ${t.errors}, '
      'CPU máx ${n(t.maxCpuTemp)} °C a ${n(t.avgCpuClock)} MHz e ${n(t.avgCpuPower)} W, '
      'GPU máx ${n(t.maxGpuTemp)} °C a ${n(t.avgGpuPower)} W'
      '${t.memWrite > 0 ? ', memória ${n(t.memWrite, 1)}/${n(t.memRead, 1)} GB/s' : ''}'
      '${t.gpuTflops > 0 ? ', ${n(t.gpuTflops, 1)} TFLOPS' : ''}'
      '${t.diskWrite > 0 ? ', disco ${n(t.diskWrite)}/${n(t.diskRead)} MB/s' : ''}'
      '${t.error.isEmpty ? '' : ', ${t.error}'}',
    );
  }
  b.writeln('Recomendações do app:');
  for (final rec in recommendationsFor(r)) {
    b.writeln('- [${rec.severity.name}] ${rec.title}: ${rec.detail}');
  }
  return b.toString();
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
