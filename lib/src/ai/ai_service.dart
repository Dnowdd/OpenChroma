import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../i18n/l10n.dart';
import '../paths.dart';
import 'secret_store.dart';

/// Where the assistant's requests go.
enum AiProvider {
  anthropic('Anthropic (Claude)', 'https://api.anthropic.com/v1'),
  openai('OpenAI (GPT)', 'https://api.openai.com/v1'),

  /// Any server that speaks the OpenAI chat API: OpenRouter, Groq, Mistral,
  /// DeepSeek, a local Ollama or LM Studio...
  compatible('OpenAI-compatible', 'https://openrouter.ai/api/v1');

  const AiProvider(this._label, this.defaultBaseUrl);
  final String _label;
  final String defaultBaseUrl;

  String get label => this == compatible ? l10n.aiProviderCompatible : _label;

  static AiProvider byName(String? n) =>
      values.where((v) => v.name == n).firstOrNull ?? anthropic;
}

class AiModel {
  const AiModel(this.id, this.name);
  final String id;
  final String name;

  Map<String, String> toJson() => {'id': id, 'name': name};
  static AiModel fromJson(Map j) =>
      AiModel('${j['id']}', '${j['name'] ?? j['id']}');
}

class AiMessage {
  const AiMessage(this.role, this.text);

  /// `user` or `assistant`.
  final String role;
  final String text;
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One configured gateway: its key (sealed with DPAPI on disk), base URL,
/// the chosen model and the models it offered the last time it was asked.
class AiGateway {
  AiGateway(this.provider);
  final AiProvider provider;
  String key = '';
  String baseUrl = '';
  String model = '';
  List<AiModel> models = [];
  DateTime? modelsFetched;

  String get url => (baseUrl.trim().isEmpty ? provider.defaultBaseUrl : baseUrl)
      .trim()
      .replaceAll(RegExp(r'/+$'), '');

  /// A local server (Ollama, LM Studio) needs no key.
  bool get configured =>
      key.isNotEmpty ||
      (provider == AiProvider.compatible && baseUrl.trim().isNotEmpty);

  Map<String, Object?> toJson() => {
    'key': SecretStore.seal(key),
    'baseUrl': baseUrl,
    'model': model,
    'models': [for (final m in models) m.toJson()],
    'modelsFetched': modelsFetched?.toIso8601String(),
  };

  void load(Map j) {
    key = SecretStore.open('${j['key'] ?? ''}');
    baseUrl = '${j['baseUrl'] ?? ''}';
    model = '${j['model'] ?? ''}';
    models = [
      for (final m in j['models'] as List? ?? []) AiModel.fromJson(m as Map),
    ];
    modelsFetched = DateTime.tryParse('${j['modelsFetched'] ?? ''}');
  }
}

/// The assistant's settings and the calls to the model providers. Keys stay
/// on this PC (encrypted for the Windows user) and go only to the provider
/// they belong to.
class AiService extends ChangeNotifier {
  AiService() {
    _load();
    // Model lists change often; refresh them in the background.
    Timer.run(refreshStaleModels);
    _refreshTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => refreshStaleModels(),
    );
  }

  final gateways = {for (final p in AiProvider.values) p: AiGateway(p)};
  AiProvider active = AiProvider.anthropic;
  Timer? _refreshTimer;
  final Set<AiProvider> loadingModels = {};
  final Map<AiProvider, String> modelErrors = {};

  AiGateway get current => gateways[active]!;
  bool get ready => current.configured && current.model.isNotEmpty;

  String get _file => p.join(openChromaDataDir(), 'ai.json');

  void _load() {
    try {
      final j = jsonDecode(File(_file).readAsStringSync()) as Map;
      active = AiProvider.byName(j['active'] as String?);
      final g = j['gateways'] as Map? ?? {};
      for (final e in gateways.entries) {
        final v = g[e.key.name];
        if (v is Map) e.value.load(v);
      }
    } catch (_) {}
  }

  void _save() {
    try {
      File(_file).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'active': active.name,
          'gateways': {
            for (final e in gateways.entries) e.key.name: e.value.toJson(),
          },
        }),
      );
    } catch (_) {}
  }

  void setActive(AiProvider p) {
    active = p;
    _save();
    notifyListeners();
    if (gateways[p]!.configured && gateways[p]!.models.isEmpty) {
      refreshModels(p);
    }
  }

  void setKey(AiProvider p, String key) {
    final g = gateways[p]!;
    if (g.key == key.trim()) return;
    g.key = key.trim();
    g.models = [];
    g.modelsFetched = null;
    _save();
    notifyListeners();
    if (g.configured) refreshModels(p);
  }

  void setBaseUrl(AiProvider p, String url) {
    final g = gateways[p]!;
    if (g.baseUrl == url.trim()) return;
    final before = Uri.tryParse(g.url)?.host;
    g.baseUrl = url.trim();
    if (Uri.tryParse(g.url)?.host != before) g.key = '';
    g.models = [];
    _save();
    notifyListeners();
    if (g.configured) refreshModels(p);
  }

  void setModel(AiProvider p, String model) {
    gateways[p]!.model = model;
    _save();
    notifyListeners();
  }

  Future<void> refreshStaleModels() async {
    for (final g in gateways.values) {
      final age = g.modelsFetched == null
          ? null
          : DateTime.now().difference(g.modelsFetched!);
      if (g.configured && (age == null || age > const Duration(hours: 6))) {
        await refreshModels(g.provider);
      }
    }
  }

  /// Asks the provider which models this key can use.
  Future<void> refreshModels(AiProvider p) async {
    final g = gateways[p]!;
    if (!g.configured || loadingModels.contains(p)) return;
    loadingModels.add(p);
    modelErrors.remove(p);
    notifyListeners();
    try {
      final models = p == AiProvider.anthropic
          ? await _anthropicModels(g)
          : await _openAiModels(g);
      g.models = models;
      g.modelsFetched = DateTime.now();
      if (models.isNotEmpty && !models.any((m) => m.id == g.model)) {
        g.model = _preferredModel(p, models);
      }
      _save();
    } on AiException catch (e) {
      modelErrors[p] = e.message;
    } catch (e) {
      modelErrors[p] = l10n.aiErrorListModels('$e');
    } finally {
      loadingModels.remove(p);
      notifyListeners();
    }
  }

  static String _preferredModel(AiProvider p, List<AiModel> models) {
    const anthropic = ['claude-opus-5-5', 'claude-sonnet-5-5'];
    if (p == AiProvider.anthropic) {
      for (final id in anthropic) {
        if (models.any((m) => m.id == id)) return id;
      }
    }
    return models.first.id;
  }

  // ------------------------------------------------------------------ HTTP
  static final _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri,
    Map<String, String> headers, {
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final HttpClientResponse res;
    final String text;
    if (uri.scheme != 'https' && !_isLoopback(uri.host)) {
      throw AiException(l10n.aiErrorInsecureUrl(uri.host));
    }
    try {
      final req = await _http.openUrl(method, uri);
      req.followRedirects = false;
      headers.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      res = await req.close().timeout(timeout);
      text = await res.transform(utf8.decoder).join().timeout(timeout);
    } on TimeoutException {
      throw AiException(l10n.aiErrorTimeout);
    } on SocketException catch (e) {
      throw AiException(l10n.aiErrorNoConnection(uri.host, e.message));
    } on HandshakeException {
      throw AiException(l10n.aiErrorSecureConnection(uri.host));
    }
    Object? json;
    try {
      json = jsonDecode(text);
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw AiException(_errorMessage(res.statusCode, json, text));
    }
    if (json is! Map<String, dynamic>) {
      throw AiException(l10n.aiErrorUnexpectedResponse);
    }
    return json;
  }

  static bool _isLoopback(String host) =>
      host == 'localhost' ||
      host == '::1' ||
      host == '[::1]' ||
      RegExp(r'^127\.\d+\.\d+\.\d+$').hasMatch(host);

  static String _errorMessage(int status, Object? json, String raw) {
    var detail = '';
    if (json is Map) {
      final e = json['error'];
      detail = e is Map ? '${e['message'] ?? ''}' : '${e ?? ''}';
    }
    return switch (status) {
      401 || 403 => l10n.aiErrorInvalidKey,
      404 => '${l10n.aiErrorNotFound} $detail'.trim(),
      429 => l10n.aiErrorRateLimit,
      >= 500 => l10n.aiErrorProviderUnstable(status),
      _ => detail.isEmpty ? l10n.aiErrorStatus(status) : detail,
    };
  }

  Map<String, String> _anthropicHeaders(AiGateway g) => {
    'x-api-key': g.key,
    'anthropic-version': '2023-06-01',
  };

  Map<String, String> _openAiHeaders(AiGateway g) => {
    if (g.key.isNotEmpty) 'authorization': 'Bearer ${g.key}',
    // OpenRouter shows these on its dashboard.
    'http-referer': 'https://github.com/Dnowdd/OpenChroma',
    'x-title': 'OpenChroma',
  };

  Future<List<AiModel>> _anthropicModels(AiGateway g) async {
    final out = <AiModel>[];
    String? after;
    for (var page = 0; page < 10; page++) {
      final uri = Uri.parse('${g.url}/models')
          .replace(queryParameters: {'limit': '1000', 'after_id': ?after});
      final j = await _request('GET', uri, _anthropicHeaders(g));
      for (final m in j['data'] as List? ?? []) {
        out.add(AiModel('${m['id']}', '${m['display_name'] ?? m['id']}'));
      }
      if (j['has_more'] != true) break;
      after = j['last_id'] as String?;
      if (after == null) break;
    }
    return out;
  }

  // Models in OpenAI's list that cannot chat.
  static final _notChat = RegExp(
    r'embed|whisper|tts|dall-e|davinci|babbage|moderation|audio|realtime|'
    r'transcribe|image|search|computer-use|sora',
  );

  Future<List<AiModel>> _openAiModels(AiGateway g) async {
    final j = await _request(
      'GET',
      Uri.parse('${g.url}/models'),
      _openAiHeaders(g),
    );
    final data = (j['data'] as List? ?? []).cast<Map>();
    final official = g.provider == AiProvider.openai;
    final models = [
      for (final m in data)
        if (!official ||
            (RegExp(r'^(gpt-|o\d|chatgpt-)').hasMatch('${m['id']}') &&
                !_notChat.hasMatch('${m['id']}')))
          (
            AiModel('${m['id']}', '${m['name'] ?? m['id']}'),
            (m['created'] as num?)?.toInt() ?? 0,
          ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final m in models) m.$1];
  }

  // ------------------------------------------------------------------ chat
  /// Sends a conversation to the active gateway and returns the reply.
  Future<String> chat({
    required String system,
    required List<AiMessage> messages,
    int maxTokens = 4000,
  }) async {
    final g = current;
    if (!g.configured) {
      throw AiException(l10n.aiErrorNoKey);
    }
    if (g.model.isEmpty) {
      throw AiException(l10n.aiErrorNoModel);
    }
    const timeout = Duration(minutes: 3);
    return switch (g.provider) {
      AiProvider.anthropic => _anthropicChat(g, system, messages, maxTokens),
      AiProvider.openai => _responsesChat(g, system, messages, maxTokens),
      AiProvider.compatible => _completionsChat(g, system, messages, maxTokens),
    }.timeout(timeout);
  }

  // Models that accept the server-side refusal fallback.
  static const _fallbackModels = {
    'claude-fable-5-1',
    'claude-opus-5-5',
    'claude-opus-5',
    'claude-sonnet-5-5',
  };

  Future<String> _anthropicChat(
    AiGateway g,
    String system,
    List<AiMessage> messages,
    int maxTokens,
  ) async {
    final fallback = _fallbackModels.contains(g.model);
    final j = await _request(
      'POST',
      Uri.parse('${g.url}/messages'),
      {
        ..._anthropicHeaders(g),
        if (fallback) 'anthropic-beta': 'server-side-fallback-2026-07-01',
      },
      body: {
        'model': g.model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          for (final m in messages) {'role': m.role, 'content': m.text},
        ],
        if (fallback) 'fallbacks': 'default',
      },
      timeout: const Duration(minutes: 3),
    );
    if (j['stop_reason'] == 'refusal') {
      throw AiException(l10n.aiErrorRefused);
    }
    final text = [
      for (final b in j['content'] as List? ?? [])
        if (b is Map && b['type'] == 'text') '${b['text']}',
    ].join('\n').trim();
    if (text.isEmpty) throw AiException(l10n.aiErrorEmptyReply);
    return text;
  }

  /// OpenAI's Responses API, which every current OpenAI model supports.
  Future<String> _responsesChat(
    AiGateway g,
    String system,
    List<AiMessage> messages,
    int maxTokens,
  ) async {
    final j = await _request(
      'POST',
      Uri.parse('${g.url}/responses'),
      _openAiHeaders(g),
      body: {
        'model': g.model,
        'instructions': system,
        'input': [
          for (final m in messages) {'role': m.role, 'content': m.text},
        ],
        'max_output_tokens': maxTokens,
      },
      timeout: const Duration(minutes: 3),
    );
    final parts = <String>[];
    for (final item in j['output'] as List? ?? []) {
      if (item is! Map || item['type'] != 'message') continue;
      for (final c in item['content'] as List? ?? []) {
        if (c is Map && c['type'] == 'output_text') parts.add('${c['text']}');
        if (c is Map && c['type'] == 'refusal') {
          throw AiException(l10n.aiErrorRefused);
        }
      }
    }
    final text = parts.join('\n').trim();
    if (text.isEmpty) throw AiException(l10n.aiErrorEmptyReply);
    return text;
  }

  /// Chat Completions, the API OpenAI-compatible servers implement.
  Future<String> _completionsChat(
    AiGateway g,
    String system,
    List<AiMessage> messages,
    int maxTokens,
  ) async {
    final j = await _request(
      'POST',
      Uri.parse('${g.url}/chat/completions'),
      _openAiHeaders(g),
      body: {
        'model': g.model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          for (final m in messages) {'role': m.role, 'content': m.text},
        ],
      },
      timeout: const Duration(minutes: 3),
    );
    final choice = (j['choices'] as List?)?.firstOrNull;
    final text = choice is Map
        ? '${(choice['message'] as Map?)?['content'] ?? ''}'.trim()
        : '';
    if (text.isEmpty) throw AiException(l10n.aiErrorEmptyReply);
    return text;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
