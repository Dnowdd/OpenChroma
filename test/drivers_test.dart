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
}
