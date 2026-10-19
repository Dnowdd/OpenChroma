import 'package:flutter/material.dart';

import '../ai/ai_service.dart';
import 'theme.dart';
import 'widgets.dart';

/// Settings for the assistant: which gateway answers, its key (hidden like
/// a password), its address and the model, picked from the list the
/// provider returns.
class AiSettingsPanel extends StatelessWidget {
  const AiSettingsPanel({super.key, required this.ai});
  final AiService ai;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ai,
    builder: (context, _) {
      final g = ai.current;
      final p = ai.active;
      final loading = ai.loadingModels.contains(p);
      final error = ai.modelErrors[p];
      return OcPanel(
        children: [
          OcRow(
            leading: const OcIconTile(
              Icons.hub_rounded,
              color: Color(0xFF5E5CE6),
            ),
            title: 'Provedor',
            trailing: OcSelect(
              value: p.name,
              options: [for (final v in AiProvider.values) v.name],
              labelOf: (n) => AiProvider.byName(n).label,
              onChanged: (n) => ai.setActive(AiProvider.byName(n)),
              width: 240,
            ),
          ),
          OcRow(
            leading: const OcIconTile(
              Icons.key_rounded,
              color: Color(0xFFFF9F0A),
            ),
            title: 'Chave de API',
            description: switch (p) {
              AiProvider.anthropic => 'Crie em console.anthropic.com.',
              AiProvider.openai => 'Crie em platform.openai.com.',
              AiProvider.compatible =>
                'Opcional para servidores locais (Ollama, LM Studio).',
            },
            trailing: SizedBox(
              width: 300,
              child: _SecretField(
                key: ValueKey('key-${p.name}'),
                value: g.key,
                onSubmitted: (v) => ai.setKey(p, v),
              ),
            ),
          ),
          if (p == AiProvider.compatible)
            OcRow(
              leading: const OcIconTile(
                Icons.link_rounded,
                color: Color(0xFF40C8E0),
              ),
              title: 'Endereço da API',
              description:
                  'Ex.: https://openrouter.ai/api/v1, '
                  'http://localhost:11434/v1 (Ollama).',
              trailing: SizedBox(
                width: 300,
                child: _TextField(
                  key: ValueKey('url-${p.name}'),
                  value: g.baseUrl,
                  hint: p.defaultBaseUrl,
                  onSubmitted: (v) => ai.setBaseUrl(p, v),
                ),
              ),
            ),
          OcRow(
            leading: const OcIconTile(
              Icons.psychology_rounded,
              color: Color(0xFFBF5AF2),
            ),
            title: 'Modelo',
            description:
                error ??
                (loading
                    ? 'Buscando os modelos disponíveis…'
                    : !g.configured
                    ? 'Informe a chave para ver os modelos.'
                    : g.models.isEmpty
                    ? 'Nenhum modelo encontrado.'
                    : '${g.models.length} disponíveis, atualizado sozinho.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (g.models.isNotEmpty)
                  OcSelect(
                    value: g.models.any((m) => m.id == g.model)
                        ? g.model
                        : g.models.first.id,
                    options: [for (final m in g.models) m.id],
                    labelOf: (id) =>
                        g.models.firstWhere((m) => m.id == id).name,
                    onChanged: (id) => ai.setModel(p, id),
                    width: 260,
                  ),
                const SizedBox(width: 8),
                OcIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Atualizar lista',
                  onPressed: g.configured && !loading
                      ? () => ai.refreshModels(p)
                      : null,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// A key field that never shows the key unless asked, and saves on Enter or
/// when it loses focus.
class _SecretField extends StatefulWidget {
  const _SecretField({
    super.key,
    required this.value,
    required this.onSubmitted,
  });
  final String value;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmitted(_c.text);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FieldBox(
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            focusNode: _focus,
            obscureText: !_visible,
            obscuringCharacter: '•',
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: widget.onSubmitted,
            style: OcText.mono.copyWith(color: Oc.text),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Cole a chave aqui',
              hintStyle: TextStyle(fontSize: 12.5, color: Oc.textTertiary),
            ),
          ),
        ),
        OcIconButton(
          icon: _visible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          tooltip: _visible ? 'Esconder' : 'Mostrar',
          size: 28,
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ],
    ),
  );
}

class _TextField extends StatefulWidget {
  const _TextField({
    super.key,
    required this.value,
    required this.hint,
    required this.onSubmitted,
  });
  final String value;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmitted(_c.text);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FieldBox(
    child: TextField(
      controller: _c,
      focusNode: _focus,
      autocorrect: false,
      onSubmitted: widget.onSubmitted,
      style: OcText.mono.copyWith(color: Oc.text),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: Oc.textTertiary),
      ),
    ),
  );
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: Oc.control,
    padding: const EdgeInsets.only(left: 12, right: 4),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Oc.raised,
      borderRadius: Oc.r8,
      border: Border.all(color: Oc.line),
    ),
    child: child,
  );
}
