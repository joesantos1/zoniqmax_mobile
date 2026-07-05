import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/code_input.dart';

/// Recuperação de senha ("esqueci a senha") em 2 passos, com código tipo 2FA:
/// 1) informa o e-mail e recebe o código;
/// 2) digita o código no numpad do jogo + define a nova senha.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.api, this.initialEmail});

  final ApiClient api;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail ?? '');
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _codeSent = false; // passo 1 → passo 2
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _email => _emailCtrl.text.trim();

  Future<void> _requestCode() async {
    if (!_email.contains('@')) {
      setState(() => _error = 'Informe um e-mail válido.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.forgotPassword(_email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _codeCtrl.clear();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Falha de conexão. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_codeCtrl.text.length < 6) {
      setState(() => _error = 'Digite o código de 6 dígitos.');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'A nova senha precisa de ao menos 6 caracteres.');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'A confirmação não confere.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.resetPassword(_email, _codeCtrl.text, _passCtrl.text);
      if (!mounted) return;
      GameHaptics.correct();
      Navigator.pop(context, true); // volta ao login com sucesso
    } on ApiException catch (e) {
      GameHaptics.wrong();
      setState(() {
        _error = e.message;
        _codeCtrl.clear();
      });
    } catch (_) {
      setState(() => _error = 'Falha de conexão. Tente de novo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GamePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: zon.brand.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(LucideIcons.keyRound,
                                size: 20, color: zon.brand),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _codeSent
                                  ? 'Digite o código enviado para o seu e-mail e crie a nova senha.'
                                  : 'Informe o e-mail da sua conta para receber o código de recuperação.',
                              style: AppText.body
                                  .copyWith(color: zon.onSurfaceMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailCtrl,
                        enabled: !_codeSent && !_loading,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(labelText: 'E-mail'),
                        onSubmitted: (_) => _codeSent ? null : _requestCode(),
                      ),
                      if (_codeSent) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GameChip(
                            label: 'Código enviado! Confira sua caixa de entrada',
                            icon: LucideIcons.mailCheck,
                            color: zon.success,
                            mode: GameChipMode.tonal,
                          ),
                        ),
                        const SizedBox(height: 14),
                        CodeBoxes(controller: _codeCtrl),
                        const SizedBox(height: 10),
                        GameNumpad(
                          controller: _codeCtrl,
                          enabled: !_loading,
                          allowDecimal: false,
                          allowNegative: false,
                          maxLength: 6,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          enabled: !_loading,
                          decoration:
                              const InputDecoration(labelText: 'Nova senha'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          enabled: !_loading,
                          decoration: const InputDecoration(
                              labelText: 'Confirmar nova senha'),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: zon.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(Corners.sm),
                            border: Border.all(
                                color: zon.danger.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.circleAlert,
                                  size: 18, color: zon.danger),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!,
                                    style: AppText.label
                                        .copyWith(color: zon.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GameButton(
                        label: _codeSent ? 'REDEFINIR SENHA' : 'ENVIAR CÓDIGO',
                        icon: _codeSent
                            ? LucideIcons.lockKeyholeOpen
                            : LucideIcons.send,
                        size: GameButtonSize.lg,
                        expanded: true,
                        loading: _loading,
                        onPressed:
                            _loading ? null : (_codeSent ? _reset : _requestCode),
                      ),
                      if (_codeSent)
                        TextButton(
                          onPressed: _loading ? null : _requestCode,
                          child: const Text('Reenviar código'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
