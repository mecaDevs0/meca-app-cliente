import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Tela utilitária para gerar `encryptedCard` via JS oficial do PagSeguro/PagBank.
///
/// Script: https://assets.pagseguro.com.br/checkout-sdk-js/rc/dist/browser/pagseguro.min.js
/// API: `window.PagSeguro.encryptCard({ publicKey, holder, number, expMonth, expYear, securityCode })`
class PagBankEncryptCardScreen extends StatefulWidget {
  final String publicKey;
  final String holderName;
  final String number;
  final String expMonth;
  final String expYear;
  final String securityCode;

  const PagBankEncryptCardScreen({
    super.key,
    required this.publicKey,
    required this.holderName,
    required this.number,
    required this.expMonth,
    required this.expYear,
    required this.securityCode,
  });

  @override
  State<PagBankEncryptCardScreen> createState() => _PagBankEncryptCardScreenState();
}

class _PagBankEncryptCardScreenState extends State<PagBankEncryptCardScreen> {
  bool _done = false;
  String? _error;

  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PagBank',
        onMessageReceived: (message) {
          if (_done) return;
          _done = true;

          try {
            final decoded = jsonDecode(message.message);
            if (decoded is Map<String, dynamic>) {
              final success = decoded['success'] == true;
              if (success) {
                final encryptedCard = decoded['encryptedCard']?.toString();
                if (encryptedCard != null && encryptedCard.isNotEmpty) {
                  if (mounted) {
                    Navigator.of(context).pop(encryptedCard);
                  }
                  return;
                }
              }

              final err = decoded['error']?.toString();
              setState(() => _error = err ?? 'Não foi possível criptografar o cartão.');
              return;
            }
          } catch (e, st) {
            log('PagBankEncryptCardScreen: parse error', error: e, stackTrace: st);
          }

          setState(() => _error = 'Não foi possível criptografar o cartão.');
        },
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    // Nunca logar dados do cartão. Aqui só serializamos para o HTML interno do WebView.
    final payload = jsonEncode({
      'publicKey': widget.publicKey,
      'holder': widget.holderName,
      'number': widget.number,
      'expMonth': widget.expMonth,
      'expYear': widget.expYear,
      'securityCode': widget.securityCode,
    });

    return '''
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>PagBank Encrypt</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; padding: 16px; }
    .muted { color: #666; font-size: 14px; }
  </style>
  <script src="https://assets.pagseguro.com.br/checkout-sdk-js/rc/dist/browser/pagseguro.min.js"></script>
  <script>
    function send(obj) {
      try { PagBank.postMessage(JSON.stringify(obj)); } catch (e) {}
    }
    function runEncrypt() {
      try {
        if (!window.PagSeguro || !window.PagSeguro.encryptCard) {
          send({ success: false, error: 'SDK do PagSeguro não carregou.' });
          return;
        }
        var input = $payload;
        var result = window.PagSeguro.encryptCard({
          publicKey: input.publicKey,
          holder: input.holder,
          number: input.number,
          expMonth: input.expMonth,
          expYear: input.expYear,
          securityCode: input.securityCode,
        });
        if (result && result.hasErrors) {
          send({ success: false, error: (result.errors || []).join(', ') || 'Erro ao criptografar cartão.' });
          return;
        }
        send({ success: true, encryptedCard: result.encryptedCard });
      } catch (e) {
        send({ success: false, error: String(e) });
      }
    }
    window.onload = function() { setTimeout(runEncrypt, 50); };
  </script>
</head>
<body>
  <div class="muted">Criptografando cartão com segurança…</div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validando cartão'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Não foi possível criptografar o cartão',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Voltar'),
                      ),
                    ),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }
}

