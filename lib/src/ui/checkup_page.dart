import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import '../ai/assistant.dart';
import '../checkup/checkup.dart';
import '../i18n/l10n.dart';
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
            title: l10n.perfTitle,
            subtitle: checkup.running
                ? l10n.checkupSubtitleRunning
                : r == null
                ? l10n.checkupSubtitleEmpty
                : l10n.checkupSubtitleLast(_when(r.started)),
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
                          Text(l10n.checkupTests, style: OcText.title),
                          const SizedBox(width: 10),
                          OcTag(
                            l10n.checkupSelectedCount(
                              checkup.selected.length,
                              CheckupTest.values.length,
                            ),
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

String _planLabel(CheckupPlan p) => switch (p) {
  CheckupPlan.quick => l10n.checkupPlanQuick,
  CheckupPlan.standard => l10n.checkupPlanStandard,
  CheckupPlan.long => l10n.checkupPlanLong,
};

String _testName(CheckupTest t) => switch (t) {
  CheckupTest.cpuSingle => l10n.checkupTestCpuSingle,
  CheckupTest.cpuAll => l10n.checkupTestCpuAll,
  CheckupTest.memory => l10n.checkupTestMemory,
  CheckupTest.gpu => l10n.checkupTestGpu,
  CheckupTest.cpuGpu => l10n.checkupTestCpuGpu,
  CheckupTest.disk => l10n.checkupTestDisk,
};

IconData _testIcon(CheckupTest t) => switch (t) {
  CheckupTest.cpuSingle => Icons.memory_rounded,
  CheckupTest.cpuAll => Icons.developer_board_rounded,
  CheckupTest.memory => Icons.view_week_rounded,
  CheckupTest.gpu => Icons.videogame_asset_outlined,
  CheckupTest.cpuGpu => Icons.bolt_rounded,
  CheckupTest.disk => Icons.storage_rounded,
};

String _num(double v, [int digits = 0]) {
  final text = v.toStringAsFixed(digits);
  return l10n.localeName == 'pt' ? text.replaceAll('.', ',') : text;
}

String _thousands(double v) =>
    v >= 10000 ? l10n.checkupThousands(_num(v / 1000, 1)) : _num(v);

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
  if (days == 0) return l10n.checkupWhenToday(hm);
  if (days == 1) return l10n.checkupWhenYesterday(hm);
  final day = t.day.toString().padLeft(2, '0');
  final month = t.month.toString().padLeft(2, '0');
  final date = l10n.localeName == 'pt' ? '$day/$month' : '$month/$day';
  return l10n.checkupWhenDate(date, hm);
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
      l10n.checkupMemoryMetricRead(_num(r.memRead, 1)),
      l10n.checkupMemoryMetricWrite(_num(r.memWrite, 1)),
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
      l10n.checkupDiskMetricWrite(_num(r.diskWrite / 1000, 1)),
      l10n.checkupDiskMetricRead(_num(r.diskRead / 1000, 1)),
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
                l10n.checkupTitle,
                trailing: busy
                    ? null
                    : OcSegmented<CheckupPlan>(
                        value: checkup.plan,
                        options: [
                          for (final p in CheckupPlan.values)
                            (p, _planLabel(p)),
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
                      label: l10n.checkupCancel,
                      icon: Icons.stop_rounded,
                      variant: OcButtonVariant.danger,
                      onPressed: checkup.cancel,
                    )
                  else
                    OcButton(
                      label: checkup.preparing
                          ? l10n.checkupPreparing
                          : r == null
                          ? l10n.checkupStart
                          : l10n.checkupRunAgain,
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
                          Flexible(
                            child: Text(
                              l10n.checkupNoAdminNote,
                              overflow: TextOverflow.ellipsis,
                              style: OcText.caption,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OcButton(
                            label: l10n.perfRestartAsAdmin,
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
          ? (Icons.error_rounded, Oc.danger, l10n.checkupProblemCount(bad))
          : warn > 0
          ? (
              Icons.warning_amber_rounded,
              Oc.warning,
              l10n.checkupWarningCount(warn),
            )
          : (Icons.check_circle_rounded, Oc.success, l10n.checkupAllGood);
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
            [l10n.checkupCalcErrors(errors), _planLabel(r.plan)].join(' · '),
            style: OcText.secondary,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.checkupNext(_planLabel(checkup.plan), minutes),
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
          l10n.checkupTestCount(checkup.selected.length),
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
          i == null
              ? l10n.checkupFinishing
              : l10n.checkupTestProgress(i + 1, r.tests.length),
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
          l10n.checkupProgressRemaining(
            (progress * 100).round(),
            _duration(math.max(0, total - done)),
          ),
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
              l10n.monitorPower,
              last?.cpuPower == null ? '—' : '${last!.cpuPower!.round()} W',
            ),
            _LiveStat(
              l10n.monitorClock,
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
              Text(l10n.monitorTemperature, style: OcText.caption),
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
      'pending' => (l10n.checkupStatusQueued, Oc.textTertiary),
      'done' when r.errors == 0 => (l10n.checkupStatusStable, Oc.success),
      'done' => (l10n.checkupStatusErrors(r.errors), Oc.danger),
      'aborted' => (l10n.checkupStatusStopped, Oc.danger),
      'failed' => (l10n.checkupStatusDidNotRun, Oc.warning),
      _ => (l10n.checkupStatusCancelled, Oc.textTertiary),
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
      return OcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OcCardTitle(l10n.systemCardTitle),
            const SizedBox(height: 40),
            Center(
              child: Text(l10n.systemAfterFirstCheckup, style: OcText.caption),
            ),
            const SizedBox(height: 40),
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
          OcCardTitle(l10n.systemCardTitle),
          const SizedBox(height: 10),
          if (s.board.isNotEmpty)
            _InfoRow(
              icon: Icons.developer_board_outlined,
              label: l10n.systemMotherboard,
              value: [
                s.board,
                if (s.bios.isNotEmpty) 'BIOS ${s.bios}',
              ].join(' · '),
            ),
          if (s.cpuName.isNotEmpty)
            _InfoRow(
              icon: Icons.memory_rounded,
              label: l10n.systemProcessor,
              value: s.cpuName,
            ),
          if (s.gpuName.isNotEmpty)
            _InfoRow(
              icon: Icons.videogame_asset_outlined,
              label: l10n.systemGraphicsCard,
              value: s.gpuName,
            ),
          if (m != null)
            _InfoRow(
              icon: Icons.view_week_outlined,
              label: l10n.systemMemory,
              value: [
                '${_num(totalGb)} GB',
                l10n.systemModuleCount(mods.length),
                if (m.type.isNotEmpty) '${m.type}-${m.configured}',
                if (s.slots > 0) l10n.systemSlotCount(s.slots),
              ].join(' · '),
              severity: mods.length == 1 ? Severity.warning : null,
            ),
          if (s.memTotal > 0)
            _InfoRow(
              icon: Icons.pie_chart_outline_rounded,
              label: l10n.systemMemoryInUse,
              value: l10n.systemMemoryUsedOfTotal(
                _num(s.memUsed / 1073741824, 1),
                _num(s.memTotal / 1073741824, 1),
              ),
              severity: usedPct > .85 ? Severity.warning : null,
            ),
          if (s.driveFree != null)
            _InfoRow(
              icon: Icons.storage_rounded,
              label: l10n.systemDrive,
              value: l10n.systemDriveFree(
                _num(s.driveFree! / 1073741824),
                _num(s.driveTotal! / 1073741824),
              ),
              severity: freePct < .1 ? Severity.warning : null,
            ),
          _InfoRow(
            icon: Icons.report_gmailerrorred_rounded,
            label: l10n.systemBlueScreens,
            value: s.blueScreens.isEmpty
                ? l10n.systemBlueScreensNone
                : [
                    '${s.blueScreens.length}',
                    if (suspect != null) suspect.key,
                  ].join(' · '),
            severity: s.blueScreens.isEmpty ? Severity.good : Severity.bad,
          ),
          if (s.startupApps != null)
            _InfoRow(
              icon: Icons.rocket_launch_outlined,
              label: l10n.systemStartupApps,
              value: l10n.systemStartupAppsValue(s.startupApps!),
              severity: s.startupApps! > 12 ? Severity.info : null,
            ),
          if (s.idleCpuTemp != null)
            _InfoRow(
              icon: Icons.thermostat_rounded,
              label: l10n.systemIdleCpu,
              value: l10n.systemIdleCpuValue(
                s.idleCpuTemp!.round(),
                (s.idleCpuUsage ?? 0).round(),
              ),
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
        OcCardTitle(l10n.checkupRecommendations),
        const SizedBox(height: 10),
        if (advice.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                hasReport
                    ? l10n.checkupRecommendationsEmpty
                    : l10n.systemAfterFirstCheckup,
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
        system: l10n.checkupAiSystemPrompt,
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
                      Text(l10n.checkupAiTitle, style: OcText.label),
                      const SizedBox(height: 3),
                      Text(
                        !ready
                            ? l10n.checkupAiNotReady
                            : r == null || !r.finished
                            ? l10n.checkupAiRunFirst
                            : l10n.checkupAiHint,
                        style: OcText.secondary,
                      ),
                    ],
                  ),
                ),
                OcButton(
                  label: _answer == null || stale
                      ? l10n.checkupAiAnalyze
                      : l10n.checkupAiAnalyzeAgain,
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
