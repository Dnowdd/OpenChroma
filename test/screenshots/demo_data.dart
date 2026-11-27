import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:openchroma/src/ai/ai_service.dart';
import 'package:openchroma/src/ai/assistant.dart';
import 'package:openchroma/src/audio/audio_service.dart';
import 'package:openchroma/src/checkup/checkup.dart';
import 'package:openchroma/src/drivers/native_drivers.dart';
import 'package:openchroma/src/effects/effect_library.dart';
import 'package:openchroma/src/effects/ocfx_player.dart';
import 'package:openchroma/src/effects/ocfx_renderer.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/fans/fan_service.dart';
import 'package:openchroma/src/monitor/system_monitor.dart';
import 'package:openchroma/src/paths.dart';
import 'package:openchroma/src/plugins/plugin_library.dart';
import 'package:openchroma/src/system/launch_settings.dart';
import 'package:openchroma/src/ui/theme.dart';
import 'package:path/path.dart' as p;

class DemoAudio extends AudioService {
  @override
  bool get available => true;
}

class DemoLaunch extends LaunchSettings {
  @override
  Future<void> load() async {
    alwaysAdmin = false;
    startWithWindows = true;
    runInBackground = true;
    installSecure = true;
    loaded = true;
    notifyListeners();
  }
}

class DemoEngine extends Engine {
  DemoEngine(String dir, this.screenImage, this.screenLayout)
    : super(dataDir: dir);

  final String screenImage;
  final ScreenEdit screenLayout;
  final _audio = DemoAudio();

  @override
  AudioService get audio => _audio;

  @override
  String? screenImagePath(DeviceInstance d) =>
      d.screen == null ? null : screenImage;

  @override
  ScreenEdit screenEdit(DeviceInstance d) =>
      d.screen == null ? const ScreenEdit() : screenLayout;
}

class DemoMonitor extends SystemMonitor {
  @override
  bool get available => true;

  @override
  set active(bool value) {}
}

class DemoAi extends AiService {
  @override
  Future<void> refreshStaleModels() async {}

  @override
  Future<void> refreshModels(AiProvider p) async {}
}

const _gib = 1024.0 * 1024 * 1024;

const cpuName = 'AMD Ryzen 7 7800X3D';
const gpuName = 'NVIDIA GeForce RTX 4070 Super';

double _wave(int i, double period, double phase) =>
    math.sin(i / period * 2 * math.pi + phase);

Map<String, Object?> _snapshotJson(int i, int count) {
  final calm = i >= count - 8 ? (count - 1 - i) / 7 : 1.0;
  double mix(double target, double swing) => target + swing * calm;
  final cpuSwing =
      9 * _wave(i, 17, 0) + 6 * _wave(i, 5.3, 1) + 3.5 * _wave(i, 2.9, 2);
  final cpuUsage = mix(23, cpuSwing).clamp(6.0, 55.0);
  final cpuTemp = mix(54, 3.2 * _wave(i, 13, .4) + 1.6 * _wave(i, 4.1, 0));
  final gpuUsage = mix(31, 8 * _wave(i, 11, 2) + 4 * _wave(i, 3.7, 0));
  final gpuTemp = mix(61, 1.8 * _wave(i, 19, 1) + .8 * _wave(i, 3.1, 2));
  final memory = mix(47, 1.1 * _wave(i, 23, 0) + .5 * _wave(i, 6.1, 1));
  final down = math.max(
    0.0,
    mix(3.4e6, 2.6e6 * _wave(i, 9, 0) + 1.7e6 * _wave(i, 3.3, 1)),
  );
  final up = math.max(0.0, mix(4.2e5, 2.2e5 * _wave(i, 7, 2)));
  final threads = [
    for (var t = 0; t < 16; t++)
      (cpuUsage + 14 * _wave(i + t * 3, 6.5, t.toDouble())).clamp(2.0, 96.0),
  ];
  return {
    'uptime': 13620 + i,
    'elevated': true,
    'cpu': {
      'name': cpuName,
      'cores': 8,
      'threads': 16,
      'usage': cpuUsage,
      'clock': mix(4650, 90 * _wave(i, 8, 0)),
      'perThread': threads,
      'sensor': 'ok',
      'temp': cpuTemp,
      'ccds': [cpuTemp + 1.2],
      'power': mix(48, 7 * _wave(i, 12, 1)),
    },
    'memory': {
      'total': 32 * _gib,
      'used': 32 * _gib * memory / 100,
      'available': 32 * _gib * (1 - memory / 100),
      'committed': 21.4 * _gib,
      'commitLimit': 48 * _gib,
      'cached': 6.8 * _gib,
    },
    'gpus': [
      {
        'name': gpuName,
        'integrated': false,
        'usage': gpuUsage,
        'temp': gpuTemp,
        'memUsed': 3.6 * _gib,
        'memTotal': 12 * _gib,
        'power': mix(96, 14 * _wave(i, 11, 2)),
        'powerLimit': 220,
        'fan': 46,
        'fanRpm': 1480,
        'clock': mix(2430, 60 * _wave(i, 7, 1)),
        'memClock': 10500,
      },
    ],
    'disks': [
      {
        'number': 0,
        'model': 'Nova NVMe 2TB',
        'bus': 'NVMe',
        'temp': 41,
        'active': math.max(0.0, 3 + 4 * _wave(i, 6, 0)),
        'read': math.max(0.0, 12e6 + 9e6 * _wave(i, 8, 1)),
        'write': math.max(0.0, 4e6 + 3e6 * _wave(i, 5, 2)),
      },
      {
        'number': 1,
        'model': 'Nova SATA SSD 1TB',
        'bus': 'SATA',
        'temp': 34,
        'active': 0.0,
        'read': 0.0,
        'write': 0.0,
      },
    ],
    'volumes': [
      {
        'letter': 'C',
        'label': 'System',
        'fs': 'NTFS',
        'total': 1.0e12,
        'free': 5.9e11,
        'disk': 0,
        'removable': false,
      },
      {
        'letter': 'D',
        'label': 'Games',
        'fs': 'NTFS',
        'total': 1.0e12,
        'free': 4.4e11,
        'disk': 1,
        'removable': false,
      },
    ],
    'network': {'down': down, 'up': up},
    'processes': [
      {
        'name': 'game.exe',
        'count': 1,
        'cpu': mix(9.4, 3 * _wave(i, 6, 0)),
        'memory': 2.8 * _gib,
      },
      {
        'name': 'chrome.exe',
        'count': 14,
        'cpu': mix(3.6, 1.4 * _wave(i, 4, 1)),
        'memory': 1.9 * _gib,
      },
      {
        'name': 'obs64.exe',
        'count': 2,
        'cpu': mix(2.8, .8 * _wave(i, 5, 2)),
        'memory': .64 * _gib,
      },
      {
        'name': 'discord.exe',
        'count': 6,
        'cpu': mix(1.2, .4 * _wave(i, 3, 0)),
        'memory': .52 * _gib,
      },
      {
        'name': 'code.exe',
        'count': 9,
        'cpu': mix(.9, .3 * _wave(i, 7, 1)),
        'memory': 1.1 * _gib,
      },
      {
        'name': 'spotify.exe',
        'count': 5,
        'cpu': mix(.6, .2 * _wave(i, 4, 2)),
        'memory': .31 * _gib,
      },
      {
        'name': 'explorer.exe',
        'count': 1,
        'cpu': mix(.4, .2 * _wave(i, 9, 0)),
        'memory': .18 * _gib,
      },
      {
        'name': 'openchroma.exe',
        'count': 1,
        'cpu': mix(.3, .1 * _wave(i, 5, 1)),
        'memory': .16 * _gib,
      },
    ],
  };
}

void fillMonitor(SystemMonitor monitor, {int samples = 60}) {
  final start = DateTime.now().subtract(Duration(seconds: samples));
  for (var i = 0; i < samples; i++) {
    monitor.recordSnapshot(
      SystemSnapshot(_snapshotJson(i, samples)),
      capturedAt: start.add(Duration(seconds: i)),
    );
  }
}

double? readDemoSensor(SystemSnapshot? s, String key) {
  if (s == null) return null;
  final gpu = s.gpus.first;
  return switch (key) {
    'cpu.temp' => s.cpu.temp,
    'cpu.usage' => s.cpu.usage,
    'cpu.clock' => s.cpu.clock,
    'cpu.power' => s.cpu.power,
    'gpu.temp' => gpu.temp,
    'gpu.usage' => gpu.usage,
    'gpu.clock' => gpu.clock,
    'gpu.power' => gpu.power,
    'gpu.fan' => gpu.fan,
    'ram.usage' => s.memory.percent,
    _ => null,
  };
}

Map<String, Object?> _fan(
  String id,
  String device,
  int index,
  double rpm,
  double duty, {
  bool gpu = false,
}) => {
  'id': id,
  'group': gpu ? 'gpu' : 'board',
  'device': device,
  'index': index,
  'rpm': rpm,
  'duty': duty,
  'controllable': true,
  'controlled': true,
};

FanService buildFans(SystemMonitor monitor) {
  final fans = FanService(monitor);
  const chip = 'ITE IT8689E';
  fans.snapshot = FanSnapshot({
    'elevated': true,
    'superio': 'ok',
    'chip': chip,
    'nvidia': gpuName,
    'conflict': '',
    'fans': [
      _fan('cpu_fan', chip, 0, 1186, 38),
      _fan('pump', chip, 1, 2640, 72),
      _fan('cha_fan1', chip, 2, 912, 34),
      _fan('cha_fan2', chip, 3, 934, 34),
      _fan('cha_fan3', chip, 4, 871, 34),
      _fan('gpu0', gpuName, 0, 1480, 46, gpu: true),
      _fan('gpu1', gpuName, 1, 1465, 46, gpu: true),
    ],
  });
  fans.customCurve = [(30, 25), (45, 30), (60, 45), (72, 68), (85, 95)];
  fans.profile = FanProfile.custom;
  fans.pumpAnswered = true;
  for (final (id, name) in const [
    ('cpu_fan', 'CPU fan'),
    ('pump', 'AIO pump'),
    ('cha_fan1', 'Front 1'),
    ('cha_fan2', 'Front 2'),
    ('cha_fan3', 'Rear'),
  ]) {
    fans
      ..rename(id, name)
      ..setMode(id, FanMode.curve);
  }
  fans
    ..setPump('pump', true)
    ..setZeroRpm('cha_fan1', true)
    ..setZeroRpm('cha_fan2', true)
    ..setMode('gpu0', FanMode.curve)
    ..setMode('gpu1', FanMode.curve);
  return fans;
}

DemoAi buildAi() {
  final ai = DemoAi();
  ai.gateways[AiProvider.anthropic]!
    ..key = 'sk-ant-demo-0000000000000000'
    ..model = 'claude-sonnet-5-5'
    ..modelsFetched = DateTime.now()
    ..models = const [
      AiModel('claude-opus-5-5', 'Claude Opus 5.5'),
      AiModel('claude-sonnet-5-5', 'Claude Sonnet 5.5'),
    ];
  return ai;
}

Assistant buildAssistant(
  AiService ai,
  Engine engine,
  SystemMonitor monitor,
  FanService fans,
) {
  final assistant = Assistant(
    ai: ai,
    engine: engine,
    monitor: monitor,
    fans: fans,
  );
  assistant.turns
    ..add(AssistantTurn('user', 'Why do my fans get loud when I game?'))
    ..add(
      AssistantTurn(
        'assistant',
        'Your GPU sits around 61 °C while gaming, and the custom curve '
            'pushes the front fans to about 45% from 60 °C. Raising that point '
            'to 66 °C keeps temperatures under 70 °C and makes the case '
            'noticeably quieter.',
      ),
    );
  return assistant;
}

CheckupReport _buildCheckup() {
  final now = DateTime.now();
  final started = DateTime(now.year, now.month, now.day, 17, 42);
  final samples = <Map<String, Object?>>[];
  List<Map<String, Object?>> series(
    double from,
    int seconds,
    double Function(int) cpuT,
    double Function(int) gpuT,
    double cpuP,
    double gpuP,
  ) {
    final out = <Map<String, Object?>>[];
    for (var s = 0; s < seconds; s++) {
      out.add({
        't': from + s,
        'ct': cpuT(s),
        'cp': cpuP + 2 * math.sin(s / 3),
        'cc': 4720.0,
        'cu': 100.0,
        'gt': gpuT(s),
        'gp': gpuP + 3 * math.sin(s / 4),
        'gu': 98.0,
      });
    }
    return out;
  }

  double ramp(int s, double from, double to, int over) =>
      from + (to - from) * (1 - math.exp(-s / over));

  samples
    ..addAll(series(0, 15, (s) => ramp(s, 42, 63, 6), (_) => 44, 42, 20))
    ..addAll(series(18, 40, (s) => ramp(s, 55, 78, 12), (_) => 45, 84, 22))
    ..addAll(series(60, 30, (_) => 60, (s) => ramp(s, 46, 68, 10), 40, 198))
    ..addAll(
      series(
        93,
        30,
        (s) => ramp(s, 60, 73, 9),
        (s) => ramp(s, 62, 71, 9),
        70,
        190,
      ),
    );

  Map<String, Object?> test(
    String id,
    Map<String, Object?> extra, {
    required int from,
    required int count,
  }) => {
    'id': id,
    'status': 'done',
    'errors': 0,
    'seconds': count.toDouble(),
    'elapsed': count.toDouble(),
    ...extra,
    'samples': samples.skip(from).take(count).toList(),
  };

  return CheckupReport.fromJson({
    'started': started.toIso8601String(),
    'plan': 'quick',
    'system': {
      'board': 'Nova X670E Aero',
      'bios': 'F12',
      'slots': 4,
      'modules': [
        {
          'slot': 'DIMM_A2',
          'bank': 'P0 CHANNEL A',
          'type': 'DDR5',
          'megabytes': 16384,
          'speed': 6000,
          'configured': 4800,
          'maker': 'Nova',
          'part': 'NV516G60D5',
        },
        {
          'slot': 'DIMM_B2',
          'bank': 'P0 CHANNEL B',
          'type': 'DDR5',
          'megabytes': 16384,
          'speed': 6000,
          'configured': 4800,
          'maker': 'Nova',
          'part': 'NV516G60D5',
        },
      ],
      'cpuName': cpuName,
      'gpuName': gpuName,
      'avx2': true,
      'elevated': true,
      'memTotal': 32 * _gib,
      'memUsed': 9.2 * _gib,
      'memCommitted': 14.6 * _gib,
      'driveFree': 5.9e11,
      'driveTotal': 1.0e12,
      'idleCpuTemp': 38.0,
      'idleCpuUsage': 4.0,
      'blueScreens': <Object>[],
      'suspects': <String, int>{},
      'dumpsRead': 0,
      'startupApps': 16,
    },
    'tests': [
      test(
        'cpu1',
        {'cpuRate': 3180.0, 'cpuKernel': 'avx2', 'threads': 1},
        from: 0,
        count: 15,
      ),
      test(
        'cpu',
        {'cpuRate': 41800.0, 'cpuKernel': 'avx2', 'threads': 16},
        from: 18,
        count: 40,
      ),
      test(
        'memory',
        {'memRead': 61.4, 'memWrite': 54.9, 'megabytes': 2048},
        from: 0,
        count: 0,
      ),
      test('gpu', {'gpuTflops': 31.6, 'gpuName': gpuName}, from: 60, count: 30),
      test(
        'cpugpu',
        {'cpuRate': 36900.0, 'gpuTflops': 29.8, 'gpuName': gpuName},
        from: 93,
        count: 30,
      ),
      test(
        'disk',
        {'diskWrite': 5120.0, 'diskRead': 6840.0, 'megabytes': 1024},
        from: 0,
        count: 0,
      ),
    ],
  });
}

final _keyboardRows = [
  'X.XXXX.XXXX.XXXX.XXX',
  'XXXXXXXXXXXXXXXX.XXX',
  'XXXXXXXXXXXXXXXX.XXX',
  'XXXXXXXXXXXXXXX.....',
  'XXXXXXXXXXXXXXXX..X.',
  'XXX.XXXXXXXX.XXX.XXX',
];

Map<String, Object?> _matrixZone(String name, List<String> rows) {
  final width = rows.first.length;
  final map = <int>[];
  var led = 0;
  for (final row in rows) {
    for (final cell in row.split('')) {
      map.add(cell == 'X' ? led++ : DriverZone.noLed);
    }
  }
  return {
    'name': name,
    'type': ZoneType.matrix,
    'count': led,
    'width': width,
    'height': rows.length,
    'map': map,
  };
}

Map<String, Object?> _linear(String name, int count, {int max = 0}) => {
  'name': name,
  'type': ZoneType.linear,
  'count': count,
  if (max > 0) ...{'min': 0, 'max': max},
};

Map<String, Object?> _mode(
  String name, {
  int flags = 0,
  int speedMin = 0,
  int speedMax = 0,
  int speed = 0,
  List<int> colors = const [],
  int colorsMax = 0,
  int direction = 0,
}) => {
  'name': name,
  'flags': flags,
  'speedMin': speedMin,
  'speedMax': speedMax,
  'speed': speed,
  'brightnessMin': 0,
  'brightnessMax': 100,
  'brightness': 85,
  'direction': direction,
  'colorMode': ModeColorMode.modeSpecific,
  'colorsMin': colors.isEmpty ? 0 : 1,
  'colorsMax': colorsMax,
  'colors': colors,
};

DeviceInstance _device(
  int id,
  String name,
  String type,
  List<Map<String, Object?>> zones, {
  String vendor = 'Nova',
  List<Object> modes = const [],
  PluginInfo? plugin,
}) {
  final driver = DriverDevice.fromJson({
    'id': id,
    'name': name,
    'vendor': vendor,
    'type': type,
    'location': 'HID: demo-$id',
    'version': '1.0.$id',
    'leds': zones.fold<int>(0, (sum, z) => sum + (z['count'] as int)),
    'zones': zones,
    'modes': modes,
  });
  return DeviceInstance(
    driver.key,
    driver,
    source: plugin == null ? DeviceSource.native : DeviceSource.plugin,
    plugin: plugin,
  );
}

class DemoDevices {
  DemoDevices(this.all, this.cooler, this.motherboard);
  final List<DeviceInstance> all;
  final DeviceInstance cooler;
  final DeviceInstance motherboard;
}

DemoDevices buildDevices() {
  const flags =
      ModeFlag.speed |
      ModeFlag.brightness |
      ModeFlag.modeColors |
      ModeFlag.randomColor |
      ModeFlag.directionLR;
  final keyboard = _device(1, 'Nova K75 Keyboard', 'keyboard', [
    _matrixZone('Keyboard', _keyboardRows),
  ]);
  final mouse = _device(2, 'Nova M3 Wireless Mouse', 'mouse', [
    _linear('Body', 8),
  ])..battery = 82;
  final stand = _device(3, 'Nova H2 Headset Stand', 'headset', [
    _linear('Ring', 16),
  ]);
  final motherboard = _device(
    4,
    'Nova X670E Aero',
    'motherboard',
    [
      _linear('Rear I/O', 6),
      _linear('Chipset', 4),
      _linear('D_LED1', 36, max: 300),
      _linear('D_LED2', 24, max: 300),
    ],
    modes: [
      'Direct',
      _mode(
        'Static',
        flags: ModeFlag.brightness | ModeFlag.modeColors,
        colors: [0x7C5CFF],
        colorsMax: 1,
      ),
      _mode(
        'Wave',
        flags: flags,
        speedMin: 10,
        speedMax: 0,
        speed: 4,
        colors: [0x7C5CFF, 0x2DD4BF],
        colorsMax: 4,
        direction: ModeDirection.right,
      ),
      _mode('Breathing', flags: flags, speedMin: 10, speedMax: 0, speed: 6),
      _mode('Spectrum cycle', flags: ModeFlag.speed, speedMin: 10, speedMax: 0),
    ],
  );
  motherboard
    ..modes = motherboard.device.modes
    ..activeMode = 'Wave';
  final ram1 = _device(5, 'Nova DDR5 DRAM 1', 'ram', [_linear('DIMM', 8)]);
  final ram2 = _device(6, 'Nova DDR5 DRAM 2', 'ram', [_linear('DIMM', 8)]);
  final gpu = _device(7, 'GeForce RTX 4070 Super', 'gpu', [
    _linear('Logo', 3),
    _linear('Side strip', 14),
  ], vendor: 'NVIDIA');
  final cooler = _device(8, 'Nova Frost 360 AIO', 'cooler', [
    _linear('Pump ring', 16),
    _linear('Fans', 36),
  ], plugin: _coolerPlugin());
  cooler
    ..screen = const ScreenSpec(480, 480, round: true, liveValues: 5)
    ..modes = const [];
  return DemoDevices(
    [keyboard, mouse, stand, motherboard, ram1, ram2, gpu, cooler],
    cooler,
    motherboard,
  );
}

PluginInfo _coolerPlugin() => PluginInfo(
  path: 'nova-frost.js',
  name: 'Nova Frost 360 AIO',
  vendor: 'Nova',
  type: 'cooler',
  devices: const [],
  settings: {
    'screenOn': {
      'label': 'Screen',
      'type': 'boolean',
      'default': true,
      'description': 'Turn the cooler screen on or off.',
    },
    'brightness': {
      'label': 'Screen brightness',
      'type': 'number',
      'min': 10,
      'max': 100,
      'default': 80,
    },
  },
  bundled: true,
);

class DemoPlayback {
  DemoPlayback(EffectInfo effect, Engine engine)
    : _renderer = OcfxRenderer(
        effect.definition!,
        width: frameWidth,
        height: frameHeight,
      )..params = effectPropValues(engine, effect);

  final OcfxRenderer _renderer;

  CanvasFrame frameAt(double t) {
    _renderer.audio = demoAudio(t);
    return CanvasFrame(frameWidth, frameHeight, _renderer.render(t));
  }

  CanvasFrame frameAfter(double t) {
    const step = 1 / 30;
    for (var s = math.max(0.0, t - 4); s < t; s += step) {
      _renderer.audio = demoAudio(s);
      _renderer.render(s);
    }
    return frameAt(t);
  }
}

Future<void> writeUpdateState(String dir) async {
  File(p.join(dir, 'updates.json')).writeAsStringSync(
    jsonEncode({
      'enabled': true,
      'lastCheck': DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    }),
  );
}

Future<String> writeScreenBackdrop(String dir) async {
  const size = 480.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFF07070B),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = ui.Gradient.sweep(
        const Offset(size / 2, size / 2),
        const [
          Color(0xFF7C5CFF),
          Color(0xFF2DD4BF),
          Color(0xFF38BDF8),
          Color(0xFFF472B6),
          Color(0xFF7C5CFF),
        ],
        const [0, .25, .5, .75, 1],
      ),
  );
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size / 2),
        size * .62,
        const [Color(0xF20A0A10), Color(0xCC0A0A10), Color(0x00000000)],
        const [0, .58, 1],
      ),
  );
  final image = await recorder.endRecording().toImage(480, 480);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(p.join(dir, 'screen-backdrop.png'))
    ..writeAsBytesSync(data!.buffer.asUint8List());
  return file.path;
}

class DemoText extends ScreenText {
  const DemoText({
    super.text,
    super.x,
    super.y,
    super.size,
    super.color,
    super.source,
  });

  @override
  ui.TextStyle uiStyle(double screenHeight, {bool shadow = true}) =>
      ui.TextStyle(
        color: ui.Color(color),
        fontSize: size * screenHeight,
        fontWeight: ui.FontWeight.w700,
        fontFamily: Oc.font,
      );
}

const demoScreenEdit = ScreenEdit(
  texts: [
    DemoText(text: 'CPU', x: .5, y: .27, size: .075, color: 0xFFB8C0FF),
    DemoText(source: 'cpu.temp', x: .46, y: .45, size: .26),
    DemoText(text: '°C', x: .73, y: .41, size: .08, color: 0xFFB8C0FF),
    DemoText(text: 'GPU', x: .34, y: .72, size: .06, color: 0xFFB8C0FF),
    DemoText(source: 'gpu.temp', x: .52, y: .72, size: .1),
    DemoText(text: '°C', x: .66, y: .71, size: .055, color: 0xFFB8C0FF),
  ],
);

void writeCheckupState() {
  File(p.join(openChromaDataDir(), 'checkup.json'))
      .writeAsStringSync(jsonEncode(_buildCheckup().toJson()));
}

List<PluginInfo> bundledPlugins() => [
  for (final (file, name, vendor, type) in const [
    ('attack-shark-x11', 'Attack Shark X11', 'Attack Shark', 'mouse'),
    ('logitech-g403-hero', 'Logitech G403 HERO', 'Logitech', 'mouse'),
    ('royuan-keyboard', 'Royuan keyboard', 'Royuan', 'keyboard'),
    ('smartmonitor-cooler', 'SmartMonitor cooler', 'SmartMonitor', 'cooler'),
    ('sony-dualshock4', 'Sony DualShock 4', 'Sony', 'gamepad'),
  ])
    PluginInfo(
      path: '$file.js',
      name: name,
      vendor: vendor,
      type: type,
      devices: const [],
      settings: const {},
      bundled: true,
    ),
];

final demoNow = DateTime(2026, 11, 27, 20, 45);
