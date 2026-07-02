import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../theme.dart';
import 'home_shell.dart';

/// Tela de login / cadastro: hero laranja da marca no topo + formulário em
/// cartão, com toggle segmentado entre entrar/criar conta.
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
        _nickMsg = ok ? 'Apelido disponível' : 'Apelido já está em uso';
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

  void _setMode(bool register) {
    if (_loading || register == _isRegister) return;
    GameHaptics.tap();
    setState(() {
      _isRegister = register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _heroHeader(zon),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GamePanel(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _modeToggle(zon),
                          const SizedBox(height: 20),
                          if (_isRegister) ...[
                            TextFormField(
                              controller: _nameCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Nome'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe o nome'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nickCtrl,
                              onChanged: _onNickChanged,
                              decoration: InputDecoration(
                                labelText: 'Apelido',
                                helperText:
                                    'Letras, números e _ (sem acento/espaço)',
                                suffixIcon: _nickOk
                                    ? Icon(LucideIcons.circleCheck,
                                        color: zon.success)
                                    : null,
                              ),
                              validator: (v) {
                                final nick = (v ?? '').trim();
                                if (!_nickRegex.hasMatch(nick)) {
                                  return 'Apelido inválido (3 a 20: letras, números, _)';
                                }
                                if (!_nickOk) {
                                  return 'Apelido indisponível ou não verificado';
                                }
                                return null;
                              },
                            ),
                            AnimatedSwitcher(
                              duration: AppDurations.fast,
                              child: _nickMsg == null
                                  ? const SizedBox(height: 8)
                                  : Padding(
                                      key: ValueKey(_nickMsg),
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 4),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: GameChip(
                                          label: _nickMsg!,
                                          mode: GameChipMode.tonal,
                                          icon: _nickOk
                                              ? LucideIcons.check
                                              : (_nickMsg == 'Verificando…'
                                                  ? LucideIcons.loader
                                                  : LucideIcons.circleAlert),
                                          color: _nickOk
                                              ? zon.success
                                              : (_nickMsg == 'Verificando…'
                                                  ? zon.onSurfaceMuted
                                                  : zon.danger),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: _isRegister
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            decoration: InputDecoration(
                                labelText:
                                    _isRegister ? 'E-mail' : 'E-mail ou apelido'),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (_isRegister) {
                                return s.contains('@') ? null : 'E-mail inválido';
                              }
                              return s.isEmpty
                                  ? 'Informe e-mail ou apelido'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: 'Senha'),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Mínimo de 6 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _errorBanner(zon, _error!),
                            ),
                          GameButton(
                            label: _isRegister ? 'CRIAR CONTA' : 'ENTRAR',
                            icon: _isRegister
                                ? LucideIcons.userPlus
                                : LucideIcons.logIn,
                            size: GameButtonSize.lg,
                            expanded: true,
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Faixa hero laranja com a marca: hexágono + nome + tagline.
  Widget _heroHeader(ZonColors zon) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 40, 24, 36),
      decoration: BoxDecoration(
        color: zon.brand,
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(LucideIcons.hexagon, size: 72, color: zon.onBrand),
              Text('Z',
                  style: AppText.display
                      .copyWith(fontSize: 30, color: zon.onBrand)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ZonIQmax',
            style: AppText.display.copyWith(color: zon.onBrand),
          ),
          const SizedBox(height: 2),
          Text(
            'Domine territórios pela inteligência',
            textAlign: TextAlign.center,
            style: AppText.label
                .copyWith(color: zon.onBrand.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  /// Toggle segmentado entrar ↔ criar conta.
  Widget _modeToggle(ZonColors zon) {
    Widget seg(String label, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: AppCurves.out,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active ? zon.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(Corners.pill),
                boxShadow: active ? const [Shadows.soft] : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: AppText.label.copyWith(
                    color: active ? zon.brand : zon.onSurfaceMuted,
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: zon.surfaceAlt,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Row(
        children: [
          seg('ENTRAR', !_isRegister, () => _setMode(false)),
          seg('CRIAR CONTA', _isRegister, () => _setMode(true)),
        ],
      ),
    );
  }

  /// Painel de erro com entrada em shake.
  Widget _errorBanner(ZonColors zon, String message) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, t, child) {
        final dx = math.sin(t * math.pi * 5) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: zon.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Corners.sm),
          border: Border.all(color: zon.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.circleAlert, size: 18, color: zon.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: AppText.label.copyWith(color: zon.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
