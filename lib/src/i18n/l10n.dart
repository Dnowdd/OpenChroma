import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../l10n/gen/app_localizations.dart';
import '../paths.dart';

export '../../l10n/gen/app_localizations.dart';

AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

enum AppLanguage {
  system(null),
  english('en'),
  portuguese('pt');

  const AppLanguage(this.code);
  final String? code;

  static AppLanguage byCode(String? code) =>
      values.where((l) => l.code == code && code != null).firstOrNull ?? system;

  String get label => switch (this) {
    system => l10n.languageSystem,
    english => l10n.languageEnglish,
    portuguese => l10n.languagePortuguese,
  };
}

class LanguageController extends ChangeNotifier {
  LanguageController({String? dataDir})
    : _file = p.join(dataDir ?? openChromaDataDir(), 'language.json') {
    try {
      final data = jsonDecode(File(_file).readAsStringSync()) as Map;
      _language = AppLanguage.byCode(data['language'] as String?);
    } catch (_) {}
    _apply();
  }

  final String _file;
  AppLanguage _language = AppLanguage.system;

  AppLanguage get language => _language;

  Locale get locale => l10n.localeName == 'pt'
      ? const Locale('pt', 'BR')
      : const Locale('en', 'US');

  set language(AppLanguage value) {
    if (value == _language) return;
    _language = value;
    try {
      File(_file).writeAsStringSync(jsonEncode({'language': value.code}));
    } catch (_) {}
    _apply();
    notifyListeners();
  }

  void _apply() {
    final code = _language.code ?? _systemCode();
    l10n = lookupAppLocalizations(Locale(code));
  }

  static String _systemCode() {
    final system = PlatformDispatcher.instance.locales;
    for (final l in system) {
      if (l.languageCode == 'pt') return 'pt';
      if (l.languageCode == 'en') return 'en';
    }
    return 'en';
  }
}
