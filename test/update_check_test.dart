import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/system/update_check.dart';

void main() {
  test('compares release versions', () {
    expect(isNewer('0.9.1', '0.9.0'), isTrue);
    expect(isNewer('1.0.0', '0.9.9'), isTrue);
    expect(isNewer('0.10.0', '0.9.0'), isTrue);
    expect(isNewer('0.9.0', '0.9.0'), isFalse);
    expect(isNewer('0.8.5', '0.9.0'), isFalse);
    expect(isNewer('0.9.0', '0.9.0-beta.1'), isTrue);
    expect(isNewer('0.9.0-beta.2', '0.9.0'), isFalse);
    expect(isNewer('garbage', '0.9.0'), isFalse);
  });

  test('remembers the switch and the dismissed version', () {
    final dir = Directory.systemTemp.createTempSync('oc_update');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = UpdateChecker(dataDir: dir.path, currentVersion: '0.9.0');
    expect(a.enabled, isTrue);
    a.enabled = false;
    final b = UpdateChecker(dataDir: dir.path, currentVersion: '0.9.0');
    expect(b.enabled, isFalse);
  });
}
