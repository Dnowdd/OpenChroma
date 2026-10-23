/// What a hardware mode lets the user adjust (OpenRGB's MODE_FLAG_* bits).
abstract final class ModeFlag {
  static const speed = 1 << 0;
  static const directionLR = 1 << 1;
  static const directionUD = 1 << 2;
  static const directionHV = 1 << 3;
  static const brightness = 1 << 4;
  static const perLedColor = 1 << 5;
  static const modeColors = 1 << 6;
  static const randomColor = 1 << 7;
  static const directionDiag = 1 << 11;
}

/// Where a mode takes its colors from (OpenRGB's MODE_COLORS_*).
abstract final class ModeColorMode {
  static const none = 0;
  static const perLed = 1;
  static const modeSpecific = 2;
  static const random = 3;
}

/// OpenRGB's MODE_DIRECTION_* values.
abstract final class ModeDirection {
  static const left = 0;
  static const right = 1;
  static const up = 2;
  static const down = 3;
  static const horizontal = 4;
  static const vertical = 5;
  static const upLeft = 6;
  static const upRight = 7;
  static const downLeft = 8;
  static const downRight = 9;
}

/// A setting that goes from [min] (slowest, dimmest) to [max] (fastest,
/// brightest). Drivers may have the two in either numeric order.
class ModeRange {
  const ModeRange(this.min, this.max, this.initial);

  final int min;
  final int max;

  /// The value the device reported, or the plugin's default.
  final int initial;

  /// The raw value [t] (0 to 1) of the way from [min] to [max].
  int at(double t) => (min + (max - min) * t.clamp(0, 1)).round();

  /// How far (0 to 1) [value] is from [min] to [max].
  double fraction(int value) =>
      max == min ? 1 : ((value - min) / (max - min)).clamp(0, 1).toDouble();

  int clamp(int value) => min <= max
      ? value.clamp(min, max).toInt()
      : value.clamp(max, min).toInt();
}

/// One of a device's own lighting effects and what it lets the user adjust.
/// Option values (see [defaults]) are `speed` and `brightness` (raw driver
/// values), `direction` ([ModeDirection]), `colors` (0xRRGGBB each),
/// `random` (bool) and `ledColor` (0xRRGGBB for every LED).
class HardwareMode {
  const HardwareMode({
    required this.id,
    required this.name,
    this.speed,
    this.brightness,
    this.colorsMin = 0,
    this.colorsMax = 0,
    this.colors = const [],
    this.random = false,
    this.randomInitially = false,
    this.ledColor = false,
    this.directions = const [],
    this.direction,
  });

  /// A mode of the built-in drivers: [id] is its index on the device.
  factory HardwareMode.fromDriver(int id, Object? raw) {
    if (raw is! Map) return HardwareMode(id: id, name: '$raw');
    int n(String k) => (raw[k] as num?)?.toInt() ?? 0;
    final flags = n('flags');
    bool has(int f) => flags & f != 0;
    ModeRange? range(int flag, String key) {
      final min = n('${key}Min'), max = n('${key}Max');
      return has(flag) && min != max ? ModeRange(min, max, n(key)) : null;
    }

    final modeColors = has(ModeFlag.modeColors) && n('colorsMax') > 0;
    final directions = [
      if (has(ModeFlag.directionLR)) ...[
        ModeDirection.left,
        ModeDirection.right,
      ],
      if (has(ModeFlag.directionUD)) ...[ModeDirection.up, ModeDirection.down],
      if (has(ModeFlag.directionHV)) ...[
        ModeDirection.horizontal,
        ModeDirection.vertical,
      ],
      if (has(ModeFlag.directionDiag)) ...[
        ModeDirection.upLeft,
        ModeDirection.upRight,
        ModeDirection.downLeft,
        ModeDirection.downRight,
      ],
    ];
    return HardwareMode(
      id: id,
      name: '${raw['name'] ?? ''}',
      speed: range(ModeFlag.speed, 'speed'),
      brightness: range(ModeFlag.brightness, 'brightness'),
      colorsMin: modeColors ? n('colorsMin') : 0,
      colorsMax: modeColors ? n('colorsMax') : 0,
      colors: modeColors ? _driverColors(raw['colors']) : const [],
      random: has(ModeFlag.randomColor),
      randomInitially: n('colorMode') == ModeColorMode.random,
      ledColor: has(ModeFlag.perLedColor) && !modeColors,
      directions: directions,
      direction: directions.contains(n('direction'))
          ? n('direction')
          : directions.firstOrNull,
    );
  }

  /// A mode a plugin declared: `{ id, name, speed, brightness, colors,
  /// random }` (see docs/PLUGINS.md).
  factory HardwareMode.fromPlugin(Map raw) {
    ModeRange? range(Object? r) {
      if (r is! Map) return null;
      final min = (r['min'] as num?)?.toInt() ?? 0;
      final max = (r['max'] as num?)?.toInt() ?? 100;
      if (min == max) return null;
      final initial = (r['default'] as num?)?.toInt() ?? max;
      return ModeRange(min, max, ModeRange(min, max, 0).clamp(initial));
    }

    final c = raw['colors'];
    var count = 0, min = 0;
    var colors = <int>[];
    if (c is num) {
      count = min = c.toInt();
    } else if (c is Map) {
      min = (c['min'] as num?)?.toInt() ?? 1;
      count = (c['max'] as num?)?.toInt() ?? min;
      colors = [for (final v in c['default'] as List? ?? []) ?_color(v)];
    }
    if (count > 0) {
      if (colors.length < min) {
        colors = [
          ...colors,
          for (var i = colors.length; i < min; i++) 0xFFFFFF,
        ];
      }
      if (colors.length > count) colors = colors.sublist(0, count);
    }
    return HardwareMode(
      id: raw['id'],
      name: '${raw['name'] ?? raw['id']}',
      speed: range(raw['speed']),
      brightness: range(raw['brightness']),
      colorsMin: count > 0 ? min : 0,
      colorsMax: count,
      colors: count > 0 ? colors : const [],
      random: raw['random'] == true,
      randomInitially: raw['random'] == true,
    );
  }

  /// Many drivers start every mode color at black, which would turn the
  /// LEDs off; those start white instead.
  static List<int> _driverColors(Object? raw) {
    final colors = [for (final c in raw as List? ?? []) (c as num).toInt()];
    return colors.every((c) => c == 0)
        ? [for (final _ in colors) 0xFFFFFF]
        : colors;
  }

  static int? _color(Object? v) {
    if (v is num) return v.toInt() & 0xFFFFFF;
    final s = '$v'.replaceAll('#', '').trim();
    return s.length == 6 ? int.tryParse(s, radix: 16) : null;
  }

  final Object? id;
  final String name;
  final ModeRange? speed;
  final ModeRange? brightness;

  /// How many colors of its own the mode takes; 0 when it takes none.
  final int colorsMin;
  final int colorsMax;

  /// The mode's colors as the device reported them (0xRRGGBB).
  final List<int> colors;

  /// The mode can pick random colors instead of [colors], and whether it
  /// starts that way.
  final bool random;
  final bool randomInitially;

  /// The mode shows the LEDs' own colors; the app offers one color for all.
  final bool ledColor;

  /// Directions it can run in ([ModeDirection]) and the current one.
  final List<int> directions;
  final int? direction;

  bool get hasColors => colorsMax > 0;

  /// Whether there is anything to adjust besides choosing the mode.
  bool get adjustable =>
      speed != null ||
      brightness != null ||
      hasColors ||
      random ||
      ledColor ||
      directions.length > 1;

  /// The options as the device starts out.
  Map<String, Object?> get defaults => {
    if (speed != null) 'speed': speed!.initial,
    if (brightness != null) 'brightness': brightness!.initial,
    if (directions.isNotEmpty) 'direction': direction,
    if (hasColors) 'colors': colors,
    if (random) 'random': randomInitially,
    if (ledColor) 'ledColor': 0xFFFFFF,
  };

  /// [defaults] with the user's [saved] choices over them, each checked
  /// against what the mode allows.
  Map<String, Object?> options(Map? saved) {
    final out = defaults;
    if (saved == null) return out;
    final s = saved['speed'], b = saved['brightness'], d = saved['direction'];
    if (speed != null && s is num) out['speed'] = speed!.clamp(s.toInt());
    if (brightness != null && b is num) {
      out['brightness'] = brightness!.clamp(b.toInt());
    }
    if (d is num && directions.contains(d.toInt())) {
      out['direction'] = d.toInt();
    }
    final c = saved['colors'];
    if (hasColors && c is List) {
      final list = [for (final v in c) ?_color(v)];
      if (list.length >= colorsMin && list.length <= colorsMax) {
        out['colors'] = list;
      }
    }
    if (random && saved['random'] is bool) out['random'] = saved['random'];
    final led = _color(saved['ledColor']);
    if (ledColor && led != null) out['ledColor'] = led;
    return out;
  }
}
