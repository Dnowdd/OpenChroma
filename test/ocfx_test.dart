import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openchroma/src/effects/effect_library.dart';

void main() {
  final bundled = Directory('assets/effects')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.ocfx'))
      .toList();

  test('bundled effects exist', () => expect(bundled, isNotEmpty));

  for (final f in bundled) {
    test('${f.uri.pathSegments.last} is a valid effect', () {
      final e = parseOcfx(f.path);
      expect(e.title, isNotEmpty);
      expect(e.description, isNotEmpty);
      final params = e.properties.map((p) => p.name).toSet();
      // Every "$name" reference must point at a declared parameter.
      final refs = RegExp(r'"\$(\w+)"').allMatches(f.readAsStringSync()).map((m) => m.group(1));
      expect(refs.where((r) => !params.contains(r)), isEmpty);
    });
  }

  test('rejects documents without layers', () {
    final tmp = File('${Directory.systemTemp.path}/bad.ocfx')
      ..writeAsStringSync('{"openchroma": 1, "name": "x", "layers": []}');
    expect(() => parseOcfx(tmp.path), throwsFormatException);
  });
}
