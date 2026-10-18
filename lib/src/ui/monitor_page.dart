import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../monitor/system_monitor.dart';
import '../system/launch_settings.dart';
import 'accent.dart';
import 'shell.dart' show Pages;
import 'theme.dart';
import 'widgets.dart';

/// Temperatures and usage of the PC's main components.
class MonitorPage extends StatefulWidget {
  const MonitorPage({
    super.key,
    required this.engine,
    required this.monitor,
    required this.active,
  });
  final Engine engine;
  final SystemMonitor monitor;

  /// Whether the page is on screen; sampling only runs while it is.
  final bool active;

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  SystemMonitor get _monitor => widget.monitor;
  bool _sortByMemory = false;

  @override
  void initState() {
    super.initState();
    _monitor.setActive(this, widget.active);
  }

  @override
  void didUpdateWidget(MonitorPage old) {
    super.didUpdateWidget(old);
    _monitor.setActive(this, widget.active);
  }

  @override
  void dispose() {
    _monitor.setActive(this, false);
    super.dispose();
  }

  Future<void> _relaunchElevated() =>
      restartAsAdmin(page: Pages.performance, shutdown: widget.engine.shutdown);

  @override
  Widget build(BuildContext context) {
    if (!_monitor.available) {
      return const EmptyState(
        icon: Icons.monitor_heart_outlined,
        title: 'Monitor indisponível',
        message: 'Esta build não inclui os sensores do sistema.',
      );
    }
    return ListenableBuilder(
      listenable: _monitor,
      builder: (context, _) {
        final s = _monitor.snapshot;
        return ListView(
          children: [
            PageHeader(
              title: 'Desempenho',
              subtitle: s == null
                  ? 'Lendo os sensores…'
                  : 'Atualizado a cada segundo · PC ligado há ${_fmtUptime(s.uptime)}',
            ),
            if (s == null && _monitor.stalled)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: EmptyState(
                  icon: Icons.sensors_off_outlined,
                  title: 'Os sensores não responderam',
                  message:
                      'Nenhuma leitura chegou do sistema. Feche e abra o '
                      'OpenChroma de novo; se continuar, avise.',
                ),
              )
            else if (s == null)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Oc.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: Oc.pageInsets,
                child: LayoutBuilder(
                  builder: (context, c) => _layout(s, wide: c.maxWidth >= 1000),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _layout(SystemSnapshot s, {required bool wide}) {
    final cpu = _CpuCard(
      cpu: s.cpu,
      monitor: _monitor,
      onElevate: _relaunchElevated,
    );
    final gpu = s.gpus.isEmpty
        ? null
        : _GpuCard(gpus: s.gpus, monitor: _monitor);
    final memory = _MemoryCard(memory: s.memory, history: _monitor.memory);
    final storage = _StorageCard(disks: s.disks, volumes: s.volumes);
    final network = _NetworkCard(snapshot: s, monitor: _monitor);
    final processes = _ProcessesCard(
      processes: s.processes,
      totalMemory: s.memory.total,
      byMemory: _sortByMemory,
      onSort: (v) => setState(() => _sortByMemory = v),
    );
    const gap = SizedBox(width: 16, height: 16);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cpu,
          if (gpu != null) ...[gap, gpu],
          gap,
          memory,
          gap,
          storage,
          gap,
          network,
          gap,
          processes,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cpu),
              if (gpu != null) ...[gap, Expanded(child: gpu)],
            ],
          ),
        ),
        gap,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: memory),
              gap,
              Expanded(child: storage),
              gap,
              Expanded(child: network),
            ],
          ),
        ),
        gap,
        processes,
      ],
    );
  }
}

// ---------------------------------------------------------------- Cards

class _CpuCard extends StatelessWidget {
  const _CpuCard({
    required this.cpu,
    required this.monitor,
    required this.onElevate,
  });
  final CpuReading cpu;
  final SystemMonitor monitor;
  final VoidCallback onElevate;

  @override
  Widget build(BuildContext context) {
    final hasTemp = cpu.temp != null;
    return _Card(
      children: [
        _CardHeader(
          icon: Icons.memory_rounded,
          overline: 'Processador',
          title: cpu.name.isEmpty ? 'CPU' : cpu.name,
          trailing: cpu.cores > 0
              ? OcBadge('${cpu.cores} núcleos · ${cpu.threads} threads')
              : null,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: hasTemp
                  ? _TempReadout(temp: cpu.temp!, kind: _TempKind.cpu)
                  : _CpuTempUnavailable(
                      status: cpu.sensor,
                      onElevate: onElevate,
                    ),
            ),
            const SizedBox(width: 16),
            _UsageRing(percent: cpu.usage, label: 'Uso'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (hasTemp) ...[
              Expanded(
                child: _ChartBlock(
                  title: 'Temperatura',
                  history: monitor.cpuTemp,
                  format: _fmtTemp,
                  color: _TempKind.cpu.level(cpu.temp!).color,
                  range: _tempRange,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: _ChartBlock(
                title: 'Uso',
                history: monitor.cpuUsage,
                format: _fmtPercent,
                color: LiveAccent.of(context),
                range: _percentRange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _StatRow(
          stats: [
            ('Clock', cpu.clock == null ? '—' : _fmtClock(cpu.clock!)),
            ('Consumo', cpu.power == null ? '—' : '${_fmt(cpu.power!, 0)} W'),
            for (var i = 0; i < cpu.ccds.length; i++)
              (
                cpu.ccds.length == 1 ? 'CCD' : 'CCD ${i + 1}',
                _fmtTemp(cpu.ccds[i]),
              ),
          ],
        ),
        if (cpu.perThread.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Uso por thread', style: OcText.caption),
          const SizedBox(height: 8),
          _ThreadBars(values: cpu.perThread),
        ],
      ],
    );
  }
}

class _CpuTempUnavailable extends StatelessWidget {
  const _CpuTempUnavailable({required this.status, required this.onElevate});
  final CpuSensorStatus status;
  final VoidCallback onElevate;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (status) {
      CpuSensorStatus.needsAdmin => (
        'Precisa de administrador',
        'O sensor da CPU é lido pelo driver PawnIO, que só atende programas '
            'abertos como administrador.',
      ),
      CpuSensorStatus.pending => (
        'Lendo o sensor…',
        'Abrindo o driver PawnIO.',
      ),
      CpuSensorStatus.failed => (
        'O sensor não respondeu',
        'O driver PawnIO parou de responder. As outras leituras seguem normais.',
      ),
      CpuSensorStatus.noDriver => (
        'Driver PawnIO não encontrado',
        'Instale o PawnIO (pawnio.eu) para ver a temperatura da CPU.',
      ),
      _ => (
        'Sem sensor',
        'Este processador não tem um sensor de temperatura suportado.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('—', style: _bigNumber.copyWith(color: Oc.textTertiary)),
            const SizedBox(width: 4),
            const Text('°C', style: _bigUnit),
          ],
        ),
        const SizedBox(height: 6),
        Text(title, style: OcText.label),
        const SizedBox(height: 2),
        Text(message, style: OcText.secondary),
        if (status == CpuSensorStatus.needsAdmin) ...[
          const SizedBox(height: 12),
          OcButton(
            label: 'Reiniciar como administrador',
            icon: Icons.admin_panel_settings_outlined,
            onPressed: onElevate,
          ),
        ],
      ],
    );
  }
}

class _GpuCard extends StatelessWidget {
  const _GpuCard({required this.gpus, required this.monitor});
  final List<GpuReading> gpus;
  final SystemMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final g = gpus.first;
    final others = gpus.skip(1).toList();
    final memPercent = g.memUsed != null && (g.memTotal ?? 0) > 0
        ? g.memUsed! / g.memTotal! * 100
        : null;
    return _Card(
      children: [
        _CardHeader(
          icon: Icons.videogame_asset_outlined,
          overline: 'Placa de vídeo',
          title: g.name,
          trailing: g.memTotal != null
              ? OcBadge('${_fmtBytes(g.memTotal!, decimals: 0)} VRAM')
              : null,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: g.temp == null
                  ? const _NoReading(text: 'Temperatura indisponível')
                  : _TempReadout(temp: g.temp!, kind: _TempKind.gpu),
            ),
            const SizedBox(width: 16),
            _UsageRing(percent: g.usage, label: 'Uso'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (g.temp != null) ...[
              Expanded(
                child: _ChartBlock(
                  title: 'Temperatura',
                  history: monitor.gpuTemp,
                  format: _fmtTemp,
                  color: _TempKind.gpu.level(g.temp!).color,
                  range: _tempRange,
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: _ChartBlock(
                title: 'Uso',
                history: monitor.gpuUsage,
                format: _fmtPercent,
                color: LiveAccent.of(context),
                range: _percentRange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _StatRow(
          stats: [
            if (g.clock != null) ('Clock', '${_fmt(g.clock!, 0)} MHz'),
            if (g.power != null)
              (
                'Consumo',
                g.powerLimit != null
                    ? '${_fmt(g.power!, 0)} / ${_fmt(g.powerLimit!, 0)} W'
                    : '${_fmt(g.power!, 0)} W',
              ),
            if (g.fan != null || g.fanRpm != null)
              (
                'Ventoinha',
                [
                  if (g.fan != null) '${_fmt(g.fan!, 0)}%',
                  if (g.fanRpm != null) '${_fmt(g.fanRpm!, 0)} RPM',
                ].join(' · '),
              ),
          ],
        ),
        if (g.memUsed != null && memPercent != null) ...[
          const SizedBox(height: 20),
          _LabeledBar(
            label: 'Memória de vídeo',
            value: '${_fmtBytes(g.memUsed!)} de ${_fmtBytes(g.memTotal!)}',
            percent: memPercent,
          ),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(),
          for (final o in others)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      o.integrated ? '${o.name} · integrada' : o.name,
                      overflow: TextOverflow.ellipsis,
                      style: OcText.secondary,
                    ),
                  ),
                  if (o.temp != null) ...[
                    _TempInline(temp: o.temp!, kind: _TempKind.gpu),
                    const SizedBox(width: 16),
                  ],
                  SizedBox(
                    width: 48,
                    child: Text(
                      o.usage == null ? '—' : _fmtPercent(o.usage!),
                      textAlign: TextAlign.right,
                      style: OcText.mono,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory, required this.history});
  final MemoryReading memory;
  final History history;

  @override
  Widget build(BuildContext context) => _Card(
    children: [
      _CardHeader(
        icon: Icons.developer_board_outlined,
        overline: 'Memória RAM',
        title: '${_fmtBytes(memory.total, decimals: 0)} instalados',
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(_fmt(memory.percent, 0), style: _bigNumber),
          const SizedBox(width: 2),
          const Text('%', style: _bigUnit),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '${_fmtBytes(memory.used)} de ${_fmtBytes(memory.total)}',
              style: OcText.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _Bar(percent: memory.percent),
      const SizedBox(height: 20),
      _ChartBlock(
        title: 'Uso',
        history: history,
        format: _fmtPercent,
        color: LiveAccent.of(context),
        range: _percentRange,
      ),
      const SizedBox(height: 20),
      _StatRow(
        stats: [
          ('Disponível', _fmtBytes(memory.available)),
          ('Em cache', _fmtBytes(memory.cached)),
          (
            'Confirmada',
            '${_fmtBytes(memory.committed, decimals: 0)} / '
                '${_fmtBytes(memory.commitLimit, decimals: 0)}',
          ),
        ],
      ),
    ],
  );
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.disks, required this.volumes});
  final List<DiskReading> disks;
  final List<VolumeReading> volumes;

  @override
  Widget build(BuildContext context) {
    final orphans = volumes
        .where((v) => !disks.any((d) => d.number == v.disk))
        .toList();
    return _Card(
      children: [
        _CardHeader(
          icon: Icons.storage_rounded,
          overline: 'Armazenamento',
          title: disks.length == 1 ? '1 disco' : '${disks.length} discos',
        ),
        for (final d in disks) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  d.model.isEmpty ? 'Disco ${d.number}' : d.model,
                  overflow: TextOverflow.ellipsis,
                  style: OcText.label,
                ),
              ),
              if (d.bus.isNotEmpty) ...[
                const SizedBox(width: 8),
                OcBadge(d.bus),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (d.temp != null) ...[
                _TempInline(temp: d.temp!, kind: _TempKind.ssd),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  [
                    if (d.active != null) 'Ativo ${_fmtPercent(d.active!)}',
                    if (d.read != null) '↓ ${_fmtRate(d.read!)}',
                    if (d.write != null) '↑ ${_fmtRate(d.write!)}',
                  ].join('   '),
                  overflow: TextOverflow.ellipsis,
                  style: OcText.caption,
                ),
              ),
            ],
          ),
          for (final v in volumes.where((v) => v.disk == d.number)) ...[
            const SizedBox(height: 14),
            _VolumeRow(volume: v),
          ],
        ],
        for (final v in orphans) ...[
          const SizedBox(height: 14),
          _VolumeRow(volume: v),
        ],
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.volume});
  final VolumeReading volume;

  @override
  Widget build(BuildContext context) {
    final v = volume;
    final name = v.label.isNotEmpty
        ? v.label
        : (v.removable ? 'Removível' : 'Disco local');
    return _LabeledBar(
      label: '${v.letter}:  $name',
      value: '${_fmtBytes(v.free)} livres de ${_fmtBytes(v.total)}',
      percent: v.percent,
      // A nearly full drive is worth flagging.
      color: v.percent >= 90 ? Oc.danger : null,
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.snapshot, required this.monitor});
  final SystemSnapshot snapshot;
  final SystemMonitor monitor;

  @override
  Widget build(BuildContext context) => _Card(
    children: [
      const _CardHeader(
        icon: Icons.swap_vert_rounded,
        overline: 'Rede',
        title: 'Tráfego',
      ),
      const SizedBox(height: 20),
      _RateBlock(
        icon: Icons.south_rounded,
        label: 'Download',
        value: snapshot.netDown,
        history: monitor.netDown,
      ),
      const SizedBox(height: 20),
      _RateBlock(
        icon: Icons.north_rounded,
        label: 'Upload',
        value: snapshot.netUp,
        history: monitor.netUp,
      ),
    ],
  );
}

class _RateBlock extends StatelessWidget {
  const _RateBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.history,
  });
  final IconData icon;
  final String label;
  final double value;
  final History history;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 14, color: Oc.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: OcText.caption),
          const Spacer(),
          Text(
            _fmtRate(value),
            style: OcText.label.copyWith(fontFamily: Oc.mono, fontSize: 12.5),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _Sparkline(
        history: history,
        format: _fmtRate,
        color: LiveAccent.of(context),
        range: (lo, hi) => (0, math.max(hi * 1.2, 1024 * 64)),
        height: 44,
      ),
    ],
  );
}

class _ProcessesCard extends StatelessWidget {
  const _ProcessesCard({
    required this.processes,
    required this.totalMemory,
    required this.byMemory,
    required this.onSort,
  });
  final List<ProcessReading> processes;
  final double totalMemory;
  final bool byMemory;
  final ValueChanged<bool> onSort;

  static const _rows = 12;

  @override
  Widget build(BuildContext context) {
    final list = [...processes]
      ..sort(
        (a, b) => byMemory
            ? b.memory.compareTo(a.memory)
            : b.cpu.compareTo(a.cpu) != 0
            ? b.cpu.compareTo(a.cpu)
            : b.memory.compareTo(a.memory),
      );
    return _Card(
      children: [
        _CardHeader(
          icon: Icons.apps_rounded,
          overline: 'Processos',
          title: byMemory ? 'Os que mais usam memória' : 'Os que mais usam CPU',
          trailing: OcSegmented<bool>(
            value: byMemory,
            options: const [(false, 'CPU'), (true, 'Memória')],
            onChanged: onSort,
          ),
        ),
        const SizedBox(height: 16),
        const _ProcessRow.header(),
        const Divider(),
        for (final p in list.take(_rows))
          _ProcessRow(
            name: p.name.toLowerCase().endsWith('.exe')
                ? p.name.substring(0, p.name.length - 4)
                : p.name,
            count: p.count,
            cpu: p.cpu,
            memory: p.memory,
            memoryPercent: totalMemory > 0 ? p.memory / totalMemory * 100 : 0,
            byMemory: byMemory,
          ),
      ],
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.name,
    required this.count,
    required this.cpu,
    required this.memory,
    required this.memoryPercent,
    required this.byMemory,
  }) : header = false;

  const _ProcessRow.header()
    : header = true,
      name = '',
      count = 0,
      cpu = 0,
      memory = 0,
      memoryPercent = 0,
      byMemory = false;

  final bool header;
  final String name;
  final int count;
  final double cpu;
  final double memory;
  final double memoryPercent;
  final bool byMemory;

  @override
  Widget build(BuildContext context) {
    if (header) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text('Nome', style: OcText.caption)),
            SizedBox(width: 200, child: Text('CPU', style: OcText.caption)),
            SizedBox(width: 24),
            SizedBox(width: 200, child: Text('Memória', style: OcText.caption)),
          ],
        ),
      );
    }
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: OcText.body,
                  ),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 8),
                  Text('×$count', style: OcText.caption),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 200,
            child: _InlineMeter(
              percent: cpu,
              text: '${_fmt(cpu, 1)}%',
              emphasized: !byMemory,
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 200,
            child: _InlineMeter(
              percent: memoryPercent,
              text: _fmtBytes(memory),
              emphasized: byMemory,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Pieces

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Oc.panel,
      borderRadius: Oc.r24,
      border: Border.all(color: Oc.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.overline,
    required this.title,
    this.trailing,
  });
  final IconData icon;
  final String overline;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Oc.raised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: Oc.textSecondary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(overline.toUpperCase(), style: OcText.overline),
            const SizedBox(height: 2),
            Text(title, overflow: TextOverflow.ellipsis, style: OcText.label),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

const _bigNumber = TextStyle(
  fontFamily: Oc.fontDisplay,
  fontSize: 44,
  fontWeight: FontWeight.w600,
  letterSpacing: -1.2,
  height: 1,
  color: Oc.text,
);
const _bigUnit = TextStyle(
  fontFamily: Oc.fontDisplay,
  fontSize: 18,
  fontWeight: FontWeight.w500,
  color: Oc.textSecondary,
);

enum _TempKind {
  cpu(75, 88),
  gpu(75, 85),
  ssd(60, 70);

  const _TempKind(this.warm, this.hot);
  final double warm;
  final double hot;

  _TempLevel level(double t) => t >= hot
      ? _TempLevel.hot
      : t >= warm
      ? _TempLevel.warm
      : _TempLevel.normal;
}

enum _TempLevel {
  normal('Normal', Oc.success),
  warm('Quente', Oc.warning),
  hot('Muito quente', Oc.danger);

  const _TempLevel(this.label, this.color);
  final String label;
  final Color color;
}

class _TempReadout extends StatelessWidget {
  const _TempReadout({required this.temp, required this.kind});
  final double temp;
  final _TempKind kind;

  @override
  Widget build(BuildContext context) {
    final level = kind.level(temp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _fmt(temp, 0),
              style: _bigNumber.copyWith(
                color: level == _TempLevel.normal ? Oc.text : level.color,
              ),
            ),
            const SizedBox(width: 4),
            const Text('°C', style: _bigUnit),
          ],
        ),
        const SizedBox(height: 10),
        OcBadge(level.label, dot: level.color),
      ],
    );
  }
}

/// A compact temperature with its level: "57 °C ● Normal".
class _TempInline extends StatelessWidget {
  const _TempInline({required this.temp, required this.kind});
  final double temp;
  final _TempKind kind;

  @override
  Widget build(BuildContext context) {
    final level = kind.level(temp);
    return Tooltip(
      message: level.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OcStatusDot(color: level.color, size: 6),
          const SizedBox(width: 6),
          Text(
            _fmtTemp(temp),
            style: OcText.label.copyWith(fontFamily: Oc.mono, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _NoReading extends StatelessWidget {
  const _NoReading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('—', style: _bigNumber.copyWith(color: Oc.textTertiary)),
      const SizedBox(height: 10),
      Text(text, style: OcText.secondary),
    ],
  );
}

class _UsageRing extends StatelessWidget {
  const _UsageRing({required this.percent, required this.label});
  final double? percent;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 96,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: (percent ?? 0).clamp(0, 100) / 100),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        painter: _RingPainter(v, LiveAccent.of(context)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                percent == null ? '—' : '${_fmt(percent!, 0)}%',
                style: const TextStyle(
                  fontFamily: Oc.fontDisplay,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Oc.text,
                ),
              ),
              Text(label, style: OcText.caption),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, paint..color = Oc.hover);
    if (value > 0.005) {
      canvas.drawArc(rect, start, sweep * value, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 28,
      runSpacing: 12,
      children: [
        for (final (label, value) in stats)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: OcText.caption),
              const SizedBox(height: 3),
              Text(
                value,
                style: OcText.label.copyWith(
                  fontFamily: Oc.mono,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.percent, this.color, this.height = 6});
  final double percent;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: SizedBox(
      height: height,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Oc.hover)),
          FractionallySizedBox(
            widthFactor: (percent / 100).clamp(0, 1),
            heightFactor: 1,
            child: ColoredBox(color: color ?? LiveAccent.of(context)),
          ),
        ],
      ),
    ),
  );
}

class _LabeledBar extends StatelessWidget {
  const _LabeledBar({
    required this.label,
    required this.value,
    required this.percent,
    this.color,
  });
  final String label;
  final String value;
  final double percent;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: OcText.secondary.copyWith(color: Oc.text),
            ),
          ),
          Text(_fmtPercent(percent), style: OcText.mono),
        ],
      ),
      const SizedBox(height: 6),
      _Bar(percent: percent, color: color),
      const SizedBox(height: 6),
      Text(value, style: OcText.caption),
    ],
  );
}

class _InlineMeter extends StatelessWidget {
  const _InlineMeter({
    required this.percent,
    required this.text,
    required this.emphasized,
  });
  final double percent;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 72,
        child: Text(
          text,
          style: OcText.mono.copyWith(
            color: emphasized ? Oc.text : Oc.textSecondary,
          ),
        ),
      ),
      Expanded(
        child: _Bar(
          percent: percent,
          height: 4,
          color: emphasized ? LiveAccent.of(context) : Oc.lineStrong,
        ),
      ),
    ],
  );
}

class _ThreadBars extends StatelessWidget {
  const _ThreadBars({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Tooltip(
              message: 'Thread ${i + 1}: ${_fmtPercent(values[i])}',
              child: Container(
                height: 32,
                alignment: Alignment.bottomCenter,
                decoration: const BoxDecoration(
                  color: Oc.raised,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                ),
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  heightFactor: (values[i] / 100).clamp(0.04, 1),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: LiveAccent.of(context),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------- Charts

typedef _Range = (double, double) Function(double lo, double hi);

(double, double) _percentRange(double lo, double hi) => (0, 100);

(double, double) _tempRange(double lo, double hi) => (
  math.min(30, (lo / 10).floor() * 10.0),
  math.max(100, (hi / 10).ceil() * 10.0),
);

class _ChartBlock extends StatelessWidget {
  const _ChartBlock({
    required this.title,
    required this.history,
    required this.format,
    required this.color,
    required this.range,
  });
  final String title;
  final History history;
  final String Function(double) format;
  final Color color;
  final _Range range;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(title, style: OcText.caption),
          const Spacer(),
          Text('60 s', style: OcText.caption),
        ],
      ),
      const SizedBox(height: 8),
      _Sparkline(history: history, format: format, color: color, range: range),
    ],
  );
}

/// A minute of one metric as a line over a soft fill, newest on the right.
/// Hovering shows the value at that moment.
class _Sparkline extends StatefulWidget {
  const _Sparkline({
    required this.history,
    required this.format,
    required this.color,
    required this.range,
    this.height = 56,
  });
  final History history;
  final String Function(double) format;
  final Color color;
  final _Range range;
  final double height;

  @override
  State<_Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<_Sparkline> {
  // Pointer position and chart width from the last hover event. No
  // LayoutBuilder here: the chart sits inside IntrinsicHeight rows, which
  // cannot measure one.
  double? _hoverX;
  double _width = 0;

  @override
  Widget build(BuildContext context) {
    final values = widget.history.values;
    final cap = widget.history.capacity;
    final present = values.whereType<double>();
    final (lo, hi) = present.isEmpty
        ? widget.range(0, 1)
        : widget.range(present.reduce(math.min), present.reduce(math.max));
    final w = _width;
    final offset = cap - values.length;
    int? index;
    if (_hoverX != null && values.isNotEmpty && w > 0) {
      index = ((_hoverX! / (w / (cap - 1))).round() - offset).clamp(
        0,
        values.length - 1,
      );
      if (values[index] == null) index = null;
    }
    final x = index == null ? 0.0 : (index + offset) * w / (cap - 1);
    final leftHalf = index != null && index + offset < cap / 2;
    return MouseRegion(
      onHover: (e) => setState(() {
        _hoverX = e.localPosition.dx;
        _width = context.size?.width ?? 0;
      }),
      onExit: (_) => setState(() => _hoverX = null),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: values,
                  capacity: cap,
                  lo: lo,
                  hi: hi,
                  color: widget.color,
                  highlight: index,
                ),
              ),
            ),
            if (index != null)
              Positioned(
                top: -4,
                left: leftHalf ? x + 8 : null,
                right: leftHalf ? null : w - x + 8,
                child: _Tip(
                  value: widget.format(values[index]!),
                  when: values.length - 1 - index,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.value, required this.when});
  final String value;
  final int when;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Oc.pressed,
      borderRadius: Oc.r6,
      border: Border.all(color: Oc.lineStrong),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Oc.text),
          ),
          TextSpan(
            text: when == 0 ? '  agora' : '  há $when s',
            style: const TextStyle(color: Oc.textSecondary),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 11.5),
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.capacity,
    required this.lo,
    required this.hi,
    required this.color,
    required this.highlight,
  }) : _signature = Object.hashAll(values);

  final List<double?> values;
  final int capacity;
  final double lo;
  final double hi;
  final Color color;
  final int? highlight;
  final int _signature;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Oc.line
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - .5),
      Offset(size.width, size.height - .5),
      grid,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid..color = Oc.line.withValues(alpha: .5),
    );
    if (values.isEmpty) return;

    final step = size.width / (capacity - 1);
    final offset = capacity - values.length;
    Offset point(int i) {
      final v = values[i]!;
      final t = hi > lo ? ((v - lo) / (hi - lo)).clamp(0.0, 1.0) : 0.0;
      // Keep the 2px line fully inside the box.
      return Offset((i + offset) * step, 1 + (size.height - 2) * (1 - t));
    }

    // Split into runs of consecutive readings.
    final runs = <List<Offset>>[];
    List<Offset>? run;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == null) {
        run = null;
        continue;
      }
      if (run == null) runs.add(run = []);
      run.add(point(i));
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    for (final r in runs) {
      final path = Path()..moveTo(r.first.dx, r.first.dy);
      for (final p in r.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final area = Path.from(path)
        ..lineTo(r.last.dx, size.height)
        ..lineTo(r.first.dx, size.height)
        ..close();
      canvas.drawPath(area, fill);
      canvas.drawPath(path, line);
    }

    // The latest reading.
    if (values.last != null && highlight == null) {
      final p = point(values.length - 1);
      canvas.drawCircle(p, 4, Paint()..color = Oc.panel);
      canvas.drawCircle(p, 3, Paint()..color = color);
    }

    if (highlight != null) {
      final p = point(highlight!);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = Oc.lineStrong
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 5, Paint()..color = Oc.panel);
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old._signature != _signature ||
      old.highlight != highlight ||
      old.lo != lo ||
      old.hi != hi ||
      old.color != color;
}

// ---------------------------------------------------------------- Format

/// A number with a decimal comma.
String _fmt(double v, int decimals) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

String _fmtPercent(double v) => '${_fmt(v, 0)}%';

String _fmtTemp(double v) => '${_fmt(v, 0)} °C';

String _fmtClock(double mhz) =>
    mhz >= 1000 ? '${_fmt(mhz / 1000, 2)} GHz' : '${_fmt(mhz, 0)} MHz';

String _fmtBytes(double b, {int decimals = 1}) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  while (b >= 1000 && i < units.length - 1) {
    b /= 1024;
    i++;
  }
  return '${_fmt(b, i >= 3 ? decimals : 0)} ${units[i]}';
}

String _fmtRate(double bytesPerSecond) => '${_fmtBytes(bytesPerSecond)}/s';

String _fmtUptime(Duration d) {
  if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}
