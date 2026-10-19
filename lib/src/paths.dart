import 'dart:io';

import 'package:path/path.dart' as p;

/// OpenChroma's own data folder (%APPDATA%\OpenChroma).
String openChromaDataDir() {
  final dir = p.join(Platform.environment['APPDATA'] ?? '', 'OpenChroma');
  Directory(dir).createSync(recursive: true);
  return dir;
}
