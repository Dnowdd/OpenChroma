import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../paths.dart';

const appVersion = String.fromEnvironment('OC_VERSION', defaultValue: 'dev');

const releasesUrl = 'https://github.com/Dnowdd/OpenChroma/releases';

class AvailableUpdate {
  const AvailableUpdate(this.version, this.url);
  final String version;
  final String url;
}

class UpdateChecker extends ChangeNotifier {
  UpdateChecker({String? dataDir, this.currentVersion = appVersion})
    : _file = p.join(dataDir ?? openChromaDataDir(), 'updates.json') {
    try {
      final data = jsonDecode(File(_file).readAsStringSync()) as Map;
      _enabled = data['enabled'] != false;
      _dismissed = data['dismissed'] as String?;
      final last = data['lastCheck'] as String?;
      _lastCheck = last == null ? null : DateTime.tryParse(last);
    } catch (_) {}
  }

  static const _api =
      'https://api.github.com/repos/Dnowdd/OpenChroma/releases/latest';
  static const _interval = Duration(hours: 24);

  final String _file;
  final String currentVersion;
  bool _enabled = true;
  String? _dismissed;
  DateTime? _lastCheck;
  AvailableUpdate? _available;
  bool checking = false;
  Timer? _timer;

  bool get enabled => _enabled;
  DateTime? get lastCheck => _lastCheck;

  AvailableUpdate? get available =>
      _available != null && _available!.version != _dismissed
      ? _available
      : null;

  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _persist();
    if (value) check();
    notifyListeners();
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => _maybeCheck());
    Timer(const Duration(seconds: 20), _maybeCheck);
  }

  void dismiss() {
    _dismissed = _available?.version;
    _persist();
    notifyListeners();
  }

  void _maybeCheck() {
    if (!_enabled) return;
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < _interval) return;
    check();
  }

  Future<void> check() async {
    if (checking || currentVersion == 'dev') return;
    checking = true;
    notifyListeners();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'OpenChroma/$currentVersion';
    try {
      final req = await client.getUrl(Uri.parse(_api));
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body =
            jsonDecode(await res.transform(utf8.decoder).join()) as Map;
        final tag = (body['tag_name'] as String? ?? '').trim();
        final url = body['html_url'] as String? ?? releasesUrl;
        final version = tag.startsWith('v') ? tag.substring(1) : tag;
        _available =
            body['draft'] != true &&
                body['prerelease'] != true &&
                isNewer(version, currentVersion)
            ? AvailableUpdate(version, url)
            : null;
      } else {
        await res.drain<void>();
      }
      _lastCheck = DateTime.now();
      _persist();
    } catch (_) {
    } finally {
      client.close(force: true);
      checking = false;
      notifyListeners();
    }
  }

  void _persist() {
    try {
      File(_file).writeAsStringSync(
        jsonEncode({
          'enabled': _enabled,
          'dismissed': _dismissed,
          'lastCheck': _lastCheck?.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

@visibleForTesting
bool isNewer(String candidate, String current) {
  List<int>? parse(String v) {
    final core = v.split(RegExp(r'[-+]')).first.split('.');
    if (core.length != 3) return null;
    final nums = core.map(int.tryParse).toList();
    return nums.contains(null) ? null : nums.cast<int>();
  }

  final a = parse(candidate);
  final b = parse(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return !candidate.contains('-') && current.contains('-');
}
