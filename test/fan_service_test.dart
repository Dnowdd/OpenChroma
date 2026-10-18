import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/fans/fan_service.dart';

void main() {
  group('speedAt', () {
    const curve = [(20.0, 30.0), (50.0, 40.0), (70.0, 65.0), (100.0, 100.0)];

    test('holds the ends outside the curve', () {
      expect(FanService.speedAt(curve, 0), 30);
      expect(FanService.speedAt(curve, 120), 100);
    });

    test('interpolates between points', () {
      expect(FanService.speedAt(curve, 50), 40);
      expect(FanService.speedAt(curve, 60), closeTo(52.5, 1e-9));
    });

    test('presets never slow down as it gets hotter', () {
      for (final c in FanService.presets.values) {
        for (var t = 0.0; t < 110; t++) {
          expect(
            FanService.speedAt(c, t + 1),
            greaterThanOrEqualTo(FanService.speedAt(c, t)),
          );
        }
      }
    });
  });

  test('settings survive a save and load', () {
    final s = FanSettings()
      ..name = 'Bomba'
      ..mode = FanMode.fixed
      ..fixed = 80
      ..source = TempSource.gpu
      ..pump = true;
    final back = FanSettings.fromJson(s.toJson());
    expect(back.name, 'Bomba');
    expect(back.mode, FanMode.fixed);
    expect(back.fixed, 80);
    expect(back.source, TempSource.gpu);
    expect(back.pump, isTrue);
    expect(back.zeroRpm, isFalse);
  });

  test('unknown values fall back to safe defaults', () {
    final s = FanSettings.fromJson({'mode': 'warp', 'source': 'moon'});
    expect(s.mode, FanMode.auto);
    expect(s.source, isNull);
  });

  test('snapshot parses native readings', () {
    final s = FanSnapshot({
      'elevated': true,
      'superio': 'ok',
      'chip': 'IT8689E',
      'conflict': '',
      'fans': [
        {
          'id': 'it8689e/0',
          'group': 'motherboard',
          'device': 'IT8689E',
          'index': 0,
          'rpm': 2586.2,
          'duty': null,
          'controllable': true,
          'controlled': false,
        },
        {'id': 'nvidia0/1', 'group': 'gpu', 'index': 1, 'rpm': 0, 'duty': 0},
      ],
    });
    expect(s.superIo, SuperIoStatus.ok);
    expect(s.fans.first.duty, isNull);
    expect(s.fans.first.rpm, closeTo(2586.2, 1e-9));
    expect(s.fans.last.gpu, isTrue);
  });
}
