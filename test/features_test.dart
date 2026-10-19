import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/ai/secret_store.dart';
import 'package:openchroma/src/alerts/alert_service.dart';
import 'package:openchroma/src/engine/engine.dart';
import 'package:openchroma/src/monitor/system_monitor.dart';
import 'package:openchroma/src/ui/device_art.dart';

void main() {
  test('secrets survive a round trip and are not stored in clear', () {
    const key = 'sk-ant-api03-abcdefghijklmnop';
    final sealed = SecretStore.seal(key);
    expect(sealed, isNot(contains('abcdefghijklmnop')));
    expect(SecretStore.open(sealed), key);
    expect(SecretStore.open(''), '');
    expect(SecretStore.open('garbage!'), '');
  });

  test('reactive light goes from blue to red', () {
    expect(Engine.reactiveColorFor(10), Engine.reactiveScale.first);
    expect(Engine.reactiveColorFor(120), Engine.reactiveScale.last);
    final mid = Engine.reactiveColorFor(60);
    expect(mid, isNot(Engine.reactiveScale.first));
    expect(mid, isNot(Engine.reactiveScale.last));
  });

  test('alerts flag heat, full memory and full disks', () {
    final s = SystemSnapshot({
      'cpu': {'temp': 93.0},
      'gpus': [
        {'name': 'GPU', 'temp': 60.0},
      ],
      'memory': {'total': 100.0, 'used': 96.0, 'available': 4.0},
      'volumes': [
        {'letter': 'C', 'total': 100.0, 'free': 3.0},
        {'letter': 'D', 'total': 100.0, 'free': 50.0},
      ],
    });
    final alerts = evaluateAlerts(s);
    final keys = {for (final a in alerts) a.key: a.level};
    expect(keys['temp:cpu'], AlertLevel.critical);
    expect(keys.containsKey('temp:gpu'), isFalse);
    expect(keys['memory'], AlertLevel.critical);
    expect(keys['volume:C'], AlertLevel.critical);
    expect(keys.containsKey('volume:D'), isFalse);
  });

  test('device artwork falls back on the name', () {
    expect(deviceKindOf('headphones', 'X'), DeviceKind.headset);
    expect(deviceKindOf('other', 'Sony DualShock 4'), DeviceKind.gamepad);
    expect(deviceKindOf('other', 'Something'), DeviceKind.other);
    expect(
      deviceKindOf('lightingcontroller', 'ARGB Hub'),
      DeviceKind.controller,
    );
  });

  test('profiles keep their settings through JSON', () {
    final p = LightProfile(
      id: 'x',
      name: 'Teste',
      icon: 'game',
      effect: 'Aurora',
      props: {'speed': 10},
      brightness: 40,
    );
    final back = LightProfile.fromJson(p.toJson());
    expect(back.effect, 'Aurora');
    expect(back.props['speed'], 10);
    expect(back.brightness, 40);
  });
}
