import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../ai/assistant.dart';
import '../checkup/checkup.dart';
import '../system/launch_settings.dart';
import 'accent.dart';
import 'theme.dart';
import 'widgets.dart';

/// Checkup: stress tests with result verification, the PC's configuration
/// and plain-rule advice.
class CheckupPage extends StatelessWidget {
  const CheckupPage({
    super.key,
    required this.checkup,
    required this.ai,
    required this.headerActions,
    required this.onRestartAsAdmin,
  });
  final CheckupService checkup;
  final AiService ai;
  final List<Widget> headerActions;
  final VoidCallback onRestartAsAdmin;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: checkup,
    builder: (context, _) {
      final r = checkup.report;
      final advice = r != null && r.finished && !checkup.running
          ? recommendationsFor(r)
          : const <Recommendation>[];
      return ListView(
        children: [
          PageHeader(
            title: 'Desempenho',
            subtitle: checkup.running
                ? 'Checkup em andamento'
                : r == null
                ? 'Teste a estabilidade e a saúde do PC'
                : 'Último checkup ${_when(r.started)}',
            actions: headerActions,
          ),
          Padding(
            padding: Oc.pageInsets,
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1000;
                final system = _SystemCard(report: r?.system);
                final adviceCard = _AdviceCard(
                  advice: advice,
                  hasReport: r != null,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                      checkup: checkup,
                      onRestartAsAdmin: onRestartAsAdmin,
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Row(
                        children: [
                          const Text('Testes', style: OcText.title),
                          const SizedBox(width: 10),
                          OcTag(
                            '${checkup.selected.length} de ${CheckupTest.values.length}',
                          ),
                        ],
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            mainAxisExtent: 150,
                          ),
                      itemCount: CheckupTest.values.length,
                      itemBuilder: (context, i) {
                        final t = CheckupTest.values[i];
                        return _TestTile(
                          test: t,
                          checkup: checkup,
                          result: checkup.running || (r?.finished ?? false)
                              ? r?.tests.where((x) => x.test == t).firstOrNull
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    if (wide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: system),
                            const SizedBox(width: 16),
                            Expanded(child: adviceCard),
                          ],
                        ),
                      )
                    else ...[
                      system,
                      const SizedBox(height: 16),
                      adviceCard,
                    ],
                    const SizedBox(height: 16),
                    _AiCard(ai: ai, report: checkup.running ? null : r),
                  ],
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------- Labels

const _planLabels = {
  CheckupPlan.quick: 'Rápido',
  CheckupPlan.standard: 'Padrão',
  CheckupPlan.long: 'Longo',
};

String _testName(CheckupTest t) => switch (t) {
  CheckupTest.cpuSingle => 'Processador · 1 núcleo',
  CheckupTest.cpuAll => 'Processador · todos',
  CheckupTest.memory => 'Memória RAM',
  CheckupTest.gpu => 'Placa de vídeo',
  CheckupTest.cpuGpu => 'CPU + GPU juntos',
  CheckupTest.disk => 'Armazenamento',
};

IconData _testIcon(CheckupTest t) => switch (t) {
  CheckupTest.cpuSingle => Icons.memory_rounded,
  CheckupTest.cpuAll => Icons.developer_board_rounded,
  CheckupTest.memory => Icons.view_week_rounded,
  CheckupTest.gpu => Icons.videogame_asset_outlined,
  CheckupTest.cpuGpu => Icons.bolt_rounded,
  CheckupTest.disk => Icons.storage_rounded,
};

String _num(double v, [int digits = 0]) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

String _thousands(double v) =>
    v >= 10000 ? '${_num(v / 1000, 1)} mil' : _num(v);

String _duration(num seconds) {
  final s = seconds.round();
  return s < 60 ? '$s s' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _when(DateTime t) {
  final now = DateTime.now();
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days == 0) return 'hoje às $hm';
  if (days == 1) return 'ontem às $hm';
  return 'em ${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} às $hm';
}

String _metric(TestResult r) {
  String? temp(double? v) => v == null ? null : '${v.round()} °C';
  final parts = switch (r.test) {
    CheckupTest.cpuSingle => [
      '${_thousands(r.cpuRate)} pts/s',
      if (r.avgCpuClock != null) '${_num(r.avgCpuClock! / 1000, 2)} GHz',
    ],
    CheckupTest.cpuAll => [
      '${_thousands(r.cpuRate)} pts/s',
      ?temp(r.maxCpuTemp),
      if (r.avgCpuPower != null) '${r.avgCpuPower!.round()} W',
    ],
    CheckupTest.memory => [
      'Lê ${_num(r.memRead, 1)} GB/s',
      'grava ${_num(r.memWrite, 1)}',
    ],
    CheckupTest.gpu => [
      '${_num(r.gpuTflops, 1)} TFLOPS',
      ?temp(r.maxGpuTemp),
      if (r.avgGpuPower != null) '${r.avgGpuPower!.round()} W',
    ],
    CheckupTest.cpuGpu => [
      // Temperatures when known, the scores otherwise.
      if (r.maxCpuTemp != null)
        'CPU ${temp(r.maxCpuTemp)}'
      else
        '${_thousands(r.cpuRate)} pts/s',
      if (r.maxGpuTemp != null)
        'GPU ${temp(r.maxGpuTemp)}'
      else
        '${_num(r.gpuTflops, 1)} TFLOPS',
    ],
    CheckupTest.disk => [
      'Grava ${_num(r.diskWrite / 1000, 1)} GB/s',
      'lê ${_num(r.diskRead / 1000, 1)}',
    ],
  };
  return parts.join(' · ');
}

// ---------------------------------------------------------------- Hero

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.checkup, required this.onRestartAsAdmin});
  final CheckupService checkup;
  final VoidCallback onRestartAsAdmin;

  @override
  Widget build(BuildContext context) {
    final r = checkup.report;
    final running = checkup.running;
    final busy = running || checkup.preparing;
    return OcCard(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 760;
          final left = running
              ? _RunningSummary(checkup: checkup)
              : _IdleSummary(checkup: checkup);
          final chart = SizedBox(
            height: wide ? null : 160,
            child: _TempChart(
              samples: r?.samples ?? const [],
              span: running
                  ? math.max(checkup.plannedSeconds.toDouble(), checkup.elapsed)
                  : null,
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OcCardTitle(
                'Checkup',
                trailing: busy
                    ? null
                    : OcSegmented<CheckupPlan>(
                        value: checkup.plan,
                        options: [
                          for (final e in _planLabels.entries) (e.key, e.value),
                        ],
                        onChanged: checkup.setPlan,
                      ),
              ),
              const SizedBox(height: 18),
              if (wide)
                SizedBox(
                  height: 230,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 340, child: left),
                      const SizedBox(width: 24),
                      Expanded(child: chart),
                    ],
                  ),
                )
              else ...[
                left,
                const SizedBox(height: 16),
                chart,
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  if (running)
                    OcButton(
                      label: 'Cancelar',
                      icon: Icons.stop_rounded,
                      variant: OcButtonVariant.danger,
                      onPressed: checkup.cancel,
                    )
                  else
                    OcButton(
                      label: checkup.preparing
                          ? 'Preparando…'
                          : r == null
                          ? 'Iniciar checkup'
                          : 'Rodar de novo',
                      icon: Icons.play_arrow_rounded,
                      variant: OcButtonVariant.primary,
                      onPressed:
                          busy || checkup.selected.isEmpty || !checkup.available
                          ? null
                          : checkup.start,
                    ),
                  const SizedBox(width: 14),
                  if (!Elevation.isElevated && !running)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 15,
                            color: Oc.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Sem administrador, a temperatura da CPU e a causa das '
                              'telas azuis ficam de fora.',
                              overflow: TextOverflow.ellipsis,
                              style: OcText.caption,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OcButton(
                            label: 'Reiniciar como administrador',
                            variant: OcButtonVariant.ghost,
                            onPressed: onRestartAsAdmin,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

const _display = TextStyle(
  fontFamily: Oc.fontDisplay,
  fontSize: 56,
  fontWeight: FontWeight.w600,
  letterSpacing: -1.8,
  height: 1,
  color: Oc.text,
);

class _IdleSummary extends StatelessWidget {
  const _IdleSummary({required this.checkup});
  final CheckupService checkup;

  @override
  Widget build(BuildContext context) {
    final r = checkup.report;
    final minutes = math.max(1, (checkup.plannedSeconds / 60).round());
    if (r != null && r.finished) {
      final advice = recommendationsFor(r);
      final bad = advice.where((a) => a.severity == Severity.bad).length;
      final warn = advice.where((a) => a.severity == Severity.warning).length;
      final (icon, color, title) = bad > 0
          ? (
              Icons.error_rounded,
              Oc.danger,
              bad == 1 ? '1 problema' : '$bad problemas',
            )
          : warn > 0
          ? (
              Icons.warning_amber_rounded,
              Oc.warning,
              warn == 1 ? '1 aviso' : '$warn avisos',
            )
          : (Icons.check_circle_rounded, Oc.success, 'Tudo certo');
      final errors = r.tests.fold(0, (sum, t) => sum + t.errors);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 34, color: color),
          const SizedBox(height: 14),
          Text(title, style: _display.copyWith(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            [
              errors == 0
                  ? 'Nenhum erro de cálculo'
                  : '$errors erros de cálculo',
              _planLabels[r.plan]!,
            ].join(' · '),
            style: OcText.secondary,
          ),
          const SizedBox(height: 4),
          Text(
            'Próximo: ${_planLabels[checkup.plan]} · ≈ $minutes min',
            style: OcText.caption,
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              '≈ ',
              style: TextStyle(
                fontFamily: Oc.fontDisplay,
                fontSize: 28,
                color: Oc.textSecondary,
              ),
            ),
            Text('$minutes', style: _display),
            const SizedBox(width: 6),
            const Text(
              'min',
              style: TextStyle(
                fontFamily: Oc.fontDisplay,
                fontSize: 20,
                color: Oc.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          checkup.selected.length == 1
              ? '1 teste'
              : '${checkup.selected.length} testes',
          style: OcText.secondary,
        ),
      ],
    );
  }
}

class _RunningSummary extends StatelessWidget {
  const _RunningSummary({required this.checkup});
  final CheckupService checkup;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final r = checkup.report!;
    final i = checkup.currentIndex;
    final current = i == null ? null : r.tests[i];
    final total = r.tests.fold<double>(0, (s, t) => s + t.seconds);
    final done = r.tests.fold<double>(
      0,
      (s, t) =>
          s +
          (t.finished
              ? t.seconds
              : t.status == 'running'
              ? math.min(t.elapsed, t.seconds)
              : 0),
    );
    final progress = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final last = r.samples.lastOrNull;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i == null ? 'Finalizando…' : 'Teste ${i + 1} de ${r.tests.length}',
          style: OcText.caption,
        ),
        const SizedBox(height: 6),
        Text(
          current == null ? '' : _testName(current.test),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _display.copyWith(fontSize: 30, letterSpacing: -.8),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: Oc.pill,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Oc.raised,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).round()}% · ${_duration(math.max(0, total - done))} restantes',
          style: OcText.caption,
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 22,
          runSpacing: 10,
          children: [
            _LiveStat(
              'CPU',
              last?.cpuTemp == null ? '—' : '${last!.cpuTemp!.round()} °C',
            ),
            _LiveStat(
              'Consumo',
              last?.cpuPower == null ? '—' : '${last!.cpuPower!.round()} W',
            ),
            _LiveStat(
              'Clock',
              last?.cpuClock == null
                  ? '—'
                  : '${_num(last!.cpuClock! / 1000, 2)} GHz',
            ),
            _LiveStat(
              'GPU',
              last?.gpuTemp == null ? '—' : '${last!.gpuTemp!.round()} °C',
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: OcText.caption),
      const SizedBox(height: 2),
      Text(value, style: OcText.label.copyWith(fontSize: 15)),
    ],
  );
}

/// CPU and GPU temperatures over the checkup.
class _TempChart extends StatelessWidget {
  const _TempChart({required this.samples, required this.span});
  final List<CheckupSample> samples;

  /// Width of the time axis in seconds; null fits the samples.
  final double? span;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final hasCpu = samples.any((s) => s.cpuTemp != null);
    final hasGpu = samples.any((s) => s.gpuTemp != null);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(color: Oc.raised, borderRadius: Oc.r12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Temperatura', style: OcText.caption),
              const Spacer(),
              if (hasCpu) _Legend(color: accent, label: 'CPU'),
              if (hasCpu && hasGpu) const SizedBox(width: 14),
              if (hasGpu) const _Legend(color: Oc.textSecondary, label: 'GPU'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: samples.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.show_chart_rounded,
                      size: 40,
                      color: Oc.lineStrong,
                    ),
                  )
                : CustomPaint(
                    painter: _ChartPainter(
                      samples: samples,
                      span: span,
                      cpu: accent,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: OcText.caption),
    ],
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.samples, required this.span, required this.cpu});
  final List<CheckupSample> samples;
  final double? span;
  final Color cpu;

  static const _min = 20.0, _max = 100.0, _left = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t0 = samples.first.t;
    final width = math.max(span ?? (samples.last.t - t0), 10.0);
    final w = size.width - _left, h = size.height;
    Offset at(double t, double v) => Offset(
      _left + (t - t0) / width * w,
      h * (1 - ((v - _min) / (_max - _min)).clamp(0.0, 1.0)),
    );
    final grid = Paint()
      ..color = Oc.line
      ..strokeWidth = 1;
    for (final v in [40.0, 60.0, 80.0, 100.0]) {
      final y = at(t0, v).dy;
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      final tp = TextPainter(
        text: TextSpan(text: '${v.round()}°', style: OcText.caption),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_left - tp.width - 6, y - tp.height / 2));
    }
    void line(
      double? Function(CheckupSample) f,
      Color color, {
      bool fill = false,
    }) {
      final pts = [
        for (final s in samples)
          if (f(s) != null) at(s.t, f(s)!),
      ];
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (fill) {
        final area = Path.from(path)
          ..lineTo(pts.last.dx, h)
          ..lineTo(pts.first.dx, h)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: .22),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }

    line((s) => s.gpuTemp, Oc.textSecondary);
    line((s) => s.cpuTemp, cpu, fill: true);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

// ---------------------------------------------------------------- Tests

class _TestTile extends StatelessWidget {
  const _TestTile({
    required this.test,
    required this.checkup,
    required this.result,
  });
  final CheckupTest test;
  final CheckupService checkup;

  /// The test's result in the running or last checkup.
  final TestResult? result;

  @override
  Widget build(BuildContext context) {
    final accent = LiveAccent.of(context);
    final idle = !checkup.running && !checkup.preparing;
    final on = checkup.selected.contains(test);
    final r = result;
    final caption =
        r != null && r.finished && (r.status == 'done' || r.status == 'aborted')
        ? _metric(r)
        : r?.error.isNotEmpty ?? false
        ? r!.error
        : test == CheckupTest.disk
        ? '${_num(checkup.plan.diskMb / 1024, checkup.plan.diskMb < 1024 ? 1 : 0)} GB'
        : _duration(checkup.plan.seconds(test));
    return Opacity(
      opacity: idle && !on ? .55 : 1,
      child: OcCard(
        padding: const EdgeInsets.all(18),
        onTap: idle ? () => checkup.toggle(test) : null,
        borderColor: idle && on ? accent.withValues(alpha: .55) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Oc.raised,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _testIcon(test),
                    size: 17,
                    color: Oc.textSecondary,
                  ),
                ),
                const Spacer(),
                _status(accent, idle, on, r),
              ],
            ),
            const Spacer(),
            Text(
              _testName(test),
              overflow: TextOverflow.ellipsis,
              style: OcText.label,
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OcText.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(Color accent, bool idle, bool on, TestResult? r) {
    if (r == null || (idle && !r.finished)) {
      return Icon(
        on ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 20,
        color: on ? accent : Oc.textTertiary,
      );
    }
    if (r.status == 'running') {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: r.seconds > 0 ? (r.elapsed / r.seconds).clamp(0.0, 1.0) : null,
          strokeWidth: 2.4,
          backgroundColor: Oc.raised,
          color: accent,
        ),
      );
    }
    final (label, color) = switch (r.status) {
      'pending' => ('Na fila', Oc.textTertiary),
      'done' when r.errors == 0 => ('Estável', Oc.success),
      'done' => (r.errors == 1 ? '1 erro' : '${r.errors} erros', Oc.danger),
      'aborted' => ('Interrompido', Oc.danger),
      'failed' => ('Não rodou', Oc.warning),
      _ => ('Cancelado', Oc.textTertiary),
    };
    return _Chip(label: label, color: color);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: Oc.pill,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

// ---------------------------------------------------------------- System

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.report});
  final SystemReport? report;

  @override
  Widget build(BuildContext context) {
    final s = report;
    if (s == null) {
      return const OcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OcCardTitle('Sistema'),
            SizedBox(height: 40),
            Center(
              child: Text(
                'Aparece depois do primeiro checkup',
                style: OcText.caption,
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      );
    }
    final mods = s.modules;
    final totalGb = mods.fold<int>(0, (sum, m) => sum + m.megabytes) / 1024;
    final m = mods.firstOrNull;
    final suspect =
        (s.suspects.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .firstOrNull;
    final usedPct = s.memTotal > 0 ? s.memUsed / s.memTotal : 0.0;
    final freePct = (s.driveTotal ?? 0) > 0
        ? s.driveFree! / s.driveTotal!
        : 1.0;
    return OcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OcCardTitle('Sistema'),
          const SizedBox(height: 10),
          if (s.board.isNotEmpty)
            _InfoRow(
              icon: Icons.developer_board_outlined,
              label: 'Placa-mãe',
              value: [
                s.board,
                if (s.bios.isNotEmpty) 'BIOS ${s.bios}',
              ].join(' · '),
            ),
          if (s.cpuName.isNotEmpty)
            _InfoRow(
              icon: Icons.memory_rounded,
              label: 'Processador',
              value: s.cpuName,
            ),
          if (s.gpuName.isNotEmpty)
            _InfoRow(
              icon: Icons.videogame_asset_outlined,
              label: 'Placa de vídeo',
              value: s.gpuName,
            ),
          if (m != null)
            _InfoRow(
              icon: Icons.view_week_outlined,
              label: 'Memória',
              value: [
                '${_num(totalGb)} GB',
                mods.length == 1 ? '1 pente' : '${mods.length} pentes',
                if (m.type.isNotEmpty) '${m.type}-${m.configured}',
                if (s.slots > 0) '${s.slots} slots',
              ].join(' · '),
              severity: mods.length == 1 ? Severity.warning : null,
            ),
          if (s.memTotal > 0)
            _InfoRow(
              icon: Icons.pie_chart_outline_rounded,
              label: 'Memória em uso',
              value:
                  '${_num(s.memUsed / 1073741824, 1)} de ${_num(s.memTotal / 1073741824, 1)} GB',
              severity: usedPct > .85 ? Severity.warning : null,
            ),
          if (s.driveFree != null)
            _InfoRow(
              icon: Icons.storage_rounded,
              label: 'Disco do sistema',
              value:
                  '${_num(s.driveFree! / 1073741824)} GB livres de ${_num(s.driveTotal! / 1073741824)} GB',
              severity: freePct < .1 ? Severity.warning : null,
            ),
          _InfoRow(
            icon: Icons.report_gmailerrorred_rounded,
            label: 'Telas azuis · 30 dias',
            value: s.blueScreens.isEmpty
                ? 'Nenhuma'
                : [
                    '${s.blueScreens.length}',
                    if (suspect != null) suspect.key,
                  ].join(' · '),
            severity: s.blueScreens.isEmpty ? Severity.good : Severity.bad,
          ),
          if (s.startupApps != null)
            _InfoRow(
              icon: Icons.rocket_launch_outlined,
              label: 'Abrem com o Windows',
              value: s.startupApps == 1
                  ? '1 programa'
                  : '${s.startupApps} programas',
              severity: s.startupApps! > 12 ? Severity.info : null,
            ),
          if (s.idleCpuTemp != null)
            _InfoRow(
              icon: Icons.thermostat_rounded,
              label: 'CPU em repouso',
              value:
                  '${s.idleCpuTemp!.round()} °C · ${(s.idleCpuUsage ?? 0).round()}% de uso',
            ),
        ],
      ),
    );
  }
}

Color _severityColor(Severity? s) => switch (s) {
  Severity.good => Oc.success,
  Severity.info => Oc.textSecondary,
  Severity.warning => Oc.warning,
  Severity.bad => Oc.danger,
  null => Colors.transparent,
};

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.severity,
  });
  final IconData icon;
  final String label;
  final String value;
  final Severity? severity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, size: 17, color: Oc.textTertiary),
        const SizedBox(width: 12),
        SizedBox(width: 150, child: Text(label, style: OcText.secondary)),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: OcText.label,
          ),
        ),
        const SizedBox(width: 10),
        OcStatusDot(color: _severityColor(severity), size: 7),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Advice

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice, required this.hasReport});
  final List<Recommendation> advice;
  final bool hasReport;

  @override
  Widget build(BuildContext context) => OcCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OcCardTitle('Recomendações'),
        const SizedBox(height: 10),
        if (advice.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                hasReport
                    ? 'Termine um checkup para ver as recomendações'
                    : 'Aparece depois do primeiro checkup',
                style: OcText.caption,
              ),
            ),
          )
        else
          for (final a in advice) _AdviceRow(advice: a),
      ],
    ),
  );
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({required this.advice});
  final Recommendation advice;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(advice.severity);
    final icon = switch (advice.severity) {
      Severity.good => Icons.check_circle_rounded,
      Severity.info => Icons.info_outline_rounded,
      Severity.warning => Icons.warning_amber_rounded,
      Severity.bad => Icons.error_rounded,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advice.title, style: OcText.label),
                const SizedBox(height: 3),
                Text(advice.detail, style: OcText.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCard extends StatefulWidget {
  const _AiCard({required this.ai, required this.report});
  final AiService ai;
  final CheckupReport? report;

  @override
  State<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends State<_AiCard> {
  String? _answer;
  String? _error;
  bool _busy = false;
  DateTime? _analyzed;

  Future<void> _analyze() async {
    final r = widget.report;
    if (r == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final answer = await widget.ai.chat(
        system:
            'Você é um técnico de hardware experiente analisando o checkup de '
            'um PC com Windows feito pelo app OpenChroma. Responda em '
            'português do Brasil, em texto simples (sem tabelas), com: um '
            'veredito de uma linha; os problemas reais em ordem de '
            'importância, cada um com a causa provável e o que fazer; e o que '
            'está bom. Seja específico com os números do relatório e não '
            'invente dados que não estão nele. No máximo 250 palavras.',
        messages: [AiMessage('user', describeCheckup(r))],
      );
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _analyzed = r.started;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ai,
    builder: (context, _) {
      final accent = LiveAccent.of(context);
      final ready = widget.ai.ready;
      final r = widget.report;
      final stale = _answer != null && _analyzed != r?.started;
      return OcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 19,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Análise com IA', style: OcText.label),
                      const SizedBox(height: 3),
                      Text(
                        !ready
                            ? 'Conecte uma IA em Configurações para usar.'
                            : r == null || !r.finished
                            ? 'Rode um checkup para analisar os resultados.'
                            : 'Explica os resultados e sugere ajustes para o '
                                  'seu PC.',
                        style: OcText.secondary,
                      ),
                    ],
                  ),
                ),
                OcButton(
                  label: _answer == null || stale
                      ? 'Analisar'
                      : 'Analisar de novo',
                  icon: Icons.auto_awesome,
                  variant: OcButtonVariant.primary,
                  onPressed: ready && r != null && r.finished && !_busy
                      ? _analyze
                      : null,
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(
                minHeight: 2,
                color: accent,
                backgroundColor: Oc.line,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: OcText.secondary.copyWith(color: Oc.danger)),
            ],
            if (_answer != null && !_busy) ...[
              const SizedBox(height: 18),
              SelectableText(
                _answer!,
                style: OcText.body.copyWith(height: 1.55),
              ),
            ],
          ],
        ),
      );
    },
  );
}
