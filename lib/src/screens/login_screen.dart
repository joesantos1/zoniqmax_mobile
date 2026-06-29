import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../theme.dart';
import 'home_shell.dart';

/// Tela de login / cadastro.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  static final _nickRegex = RegExp(r'^[A-Za-z0-9_]{3,20}$');

  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  // Verificador de disponibilidade do apelido
  int _nickSeq = 0;
  bool _nickOk = false;
  String? _nickMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nickCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onNickChanged(String v) async {
    final nick = v.trim();
    setState(() {
      _nickOk = false;
      _nickMsg = null;
    });
    if (nick.isEmpty) return;
    if (!_nickRegex.hasMatch(nick)) {
      setState(() => _nickMsg =
          'Use 3 a 20 caracteres: letras (sem acento), números e _');
      return;
    }
    final seq = ++_nickSeq;
    setState(() => _nickMsg = 'Verificando…');
    try {
      final ok = await widget.api.nicknameAvailable(nick);
      if (seq != _nickSeq || !mounted) return;
      setState(() {
        _nickOk = ok;
        _nickMsg = ok ? 'Apelido disponível ✓' : 'Apelido já está em uso';
      });
    } catch (_) {
      if (seq != _nickSeq || !mounted) return;
      setState(() => _nickMsg = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await widget.api.register(
          _nameCtrl.text.trim(),
          _nickCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      } else {
        await widget.api.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShell(api: widget.api),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Falha de conexão. Verifique a API.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(LucideIcons.hexagon,
                      size: 56, color: AppColors.orange),
                  const SizedBox(height: 12),
                  Text(
                    'ZonIQmax',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Domine territórios pela inteligência',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  if (_isRegister) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nickCtrl,
                      onChanged: _onNickChanged,
                      decoration: InputDecoration(
                        labelText: 'Apelido',
                        helperText: 'Letras, números e _ (sem acento/espaço)',
                        suffixIcon: _nickOk
                            ? const Icon(LucideIcons.circleCheck,
                                color: AppColors.green)
                            : null,
                      ),
                      validator: (v) {
                        final nick = (v ?? '').trim();
                        if (!_nickRegex.hasMatch(nick)) {
                          return 'Apelido inválido (3 a 20: letras, números, _)';
                        }
                        if (!_nickOk) return 'Apelido indisponível ou não verificado';
                        return null;
                      },
                    ),
                    if (_nickMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          _nickMsg!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _nickOk ? AppColors.green : AppColors.red,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: _isRegister
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    decoration: InputDecoration(
                        labelText: _isRegister ? 'E-mail' : 'E-mail ou apelido'),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (_isRegister) {
                        return s.contains('@') ? null : 'E-mail inválido';
                      }
                      return s.isEmpty ? 'Informe e-mail ou apelido' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo de 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegister ? 'Cadastrar' : 'Entrar'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                            }),
                    child: Text(_isRegister
                        ? 'Já tenho conta — entrar'
                        : 'Criar uma conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
