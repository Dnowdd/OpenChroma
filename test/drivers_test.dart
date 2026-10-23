import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/drivers/native_drivers.dart';
import 'package:openchroma/src/engine/engine.dart';

void main() {
  final json = {
    'id': 1234,
    'name': '',
    'description': 'IT5701 controller',
    'type': 'motherboard',
    'location': 'HID: path',
    'leds': 7,
    'zones': [
      // A 3x2 matrix with one empty cell: LEDs 0..4.
      {
        'name': 'Keys',
        'type': ZoneType.matrix,
        'count': 5,
        'width': 3,
        'height': 2,
        'map': [0, 1, 2, 3, DriverZone.noLed, 4],
      },
      // An ARGB header with 2 LEDs, resizable up to 100.
      {
        'name': 'D_LED1',
        'type': ZoneType.linear,
        'count': 2,
        'min': 0,
        'max': 100,
      },
      // An empty header is not placed.
      {
        'name': 'D_LED2',
        'type': ZoneType.linear,
        'count': 0,
        'min': 0,
        'max': 100,
      },
    ],
  };

  test('devices without a name fall back to the description', () {
    expect(DriverDevice.fromJson(json).name, 'IT5701 controller');
  });

  test('zones map their cells to device LEDs', () {
    final d = DeviceInstance('k', DriverDevice.fromJson(json));
    expect(d.zones.map((z) => z.key), ['zone:Keys', 'zone:D_LED1']);
    final keys = d.zones.first;
    expect([keys.width, keys.height], [3, 2]);
    expect(keys.positions, [
      [0, 0],
      [1, 0],
      [2, 0],
      [0, 1],
      [2, 1],
    ]);
    expect(keys.leds, [0, 1, 2, 3, 4]);
    // The header's LEDs come after the matrix's five.
    expect(d.zones[1].leds, [5, 6]);
    expect(d.resizableZones.map((z) => z.$1), [1, 2]);
  });

  group('hardware modes', () {
    // A wave with speed 0x0A (slowest) to 0x00 (fastest), brightness 0-100,
    // up to 4 colors of its own, random colors and left/right.
    final wave = {
      'name': 'Wave',
      'flags':
          ModeFlag.speed |
          ModeFlag.brightness |
          ModeFlag.modeColors |
          ModeFlag.randomColor |
          ModeFlag.directionLR,
      'speedMin': 10,
      'speedMax': 0,
      'speed': 5,
      'brightnessMin': 0,
      'brightnessMax': 100,
      'brightness': 100,
      'direction': ModeDirection.right,
      'colorMode': ModeColorMode.modeSpecific,
      'colorsMin': 1,
      'colorsMax': 4,
      'colors': [0xFF0000, 0x0000FF],
    };

    test('built-in driver modes describe what they adjust', () {
      final d = DriverDevice.fromJson({
        'id': 1,
        'name': 'Board',
        'modes': ['Direct', wave],
      });
      expect(d.modes.map((m) => m.name), ['Direct', 'Wave']);
      final m = d.modes[1];
      expect(m.id, 1);
      expect(m.adjustable, isTrue);
      expect(d.modes[0].adjustable, isFalse);
      expect(m.directions, [ModeDirection.left, ModeDirection.right]);
      expect(m.defaults, {
        'speed': 5,
        'brightness': 100,
        'direction': ModeDirection.right,
        'colors': [0xFF0000, 0x0000FF],
        'random': false,
      });
    });

    test('modes whose colors all start black start white', () {
      final m = HardwareMode.fromDriver(0, {
        ...wave,
        'colors': [0, 0],
      });
      expect(m.colors, [0xFFFFFF, 0xFFFFFF]);
    });

    test('speed runs from slowest to fastest even when inverted', () {
      final speed = HardwareMode.fromDriver(0, wave).speed!;
      expect(speed.at(0), 10);
      expect(speed.at(1), 0);
      expect(speed.fraction(5), .5);
    });

    test('saved options are checked against the mode', () {
      final m = HardwareMode.fromDriver(0, wave);
      final o = m.options({
        'speed': 50,
        'direction': ModeDirection.up,
        'colors': [1, 2, 3, 4, 5],
        'random': true,
      });
      expect(o['speed'], 10);
      expect(o['direction'], ModeDirection.right);
      expect(o['colors'], [0xFF0000, 0x0000FF]);
      expect(o['random'], isTrue);
    });

    test('plugin modes fill in default colors', () {
      final m = HardwareMode.fromPlugin({
        'id': 2,
        'name': 'Respirar',
        'speed': {'min': 0, 'max': 5, 'default': 9},
        'colors': 1,
        'random': true,
      });
      expect(m.defaults, {
        'speed': 5,
        'colors': [0xFFFFFF],
        'random': true,
      });
      expect(
        HardwareMode.fromPlugin({'id': 0, 'name': 'Off'}).adjustable,
        isFalse,
      );
    });
  });
}
