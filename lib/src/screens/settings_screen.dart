import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Configurações gerais: meus dados (nome), trocar senha e logout.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api, required this.me});

  final ApiClient api;
  final Me me;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.me.name);
  late final TextEditingController _nickCtrl =
      TextEditingController(text: widget.me.nickname ?? '');
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  static final _nickRegex = RegExp(r'^[A-Za-z0-9_]{3,20}$');

  bool _savingName = false;
  bool _savingPass = false;
  bool _changed = false;

  // Verificador de disponibilidade do apelido
  int _nickSeq = 0;
  String? _nickMsg;
  bool _nickFree = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nickCtrl.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onNickChanged(String v) async {
    final nick = v.trim();
    setState(() {
      _nickFree = false;
      _nickMsg = null;
    });
    if (nick.isEmpty) return;
    if (nick.toLowerCase() == (widget.me.nickname ?? '').toLowerCase()) {
      setState(() => _nickFree = true); // o próprio apelido atual
      return;
    }
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
        _nickFree = ok;
        _nickMsg = ok ? 'Apelido disponível ✓' : 'Apelido já está em uso';
      });
    } catch (_) {
      if (seq != _nickSeq || !mounted) return;
      setState(() => _nickMsg = null);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final nick = _nickCtrl.text.trim();
    if (name.isEmpty) return;
    if (!_nickRegex.hasMatch(nick)) {
      _snack('Apelido inválido: 3 a 20 letras, números e _');
      return;
    }
    if (!_nickFree) {
      _snack('Esse apelido já está em uso.');
      return;
    }
    setState(() => _savingName = true);
    try {
      await widget.api.updateProfile(name: name, nickname: nick);
      _changed = true;
      _snack('Perfil atualizado!');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newCtrl.text.length < 6) {
      _snack('A nova senha precisa de ao menos 6 caracteres.');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      _snack('A confirmação não confere.');
      return;
    }
    setState(() => _savingPass = true);
    try {
      await widget.api.changePassword(_currentCtrl.text, _newCtrl.text);
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      _snack('Senha alterada!');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('CONFIGURAÇÕES')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Section('MEUS DADOS'),
            ComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nickCtrl,
                    onChanged: _onNickChanged,
                    decoration: const InputDecoration(
                      labelText: 'Apelido',
                      helperText: 'Letras, números e _ (sem acento/espaço)',
                    ),
                  ),
                  if (_nickMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        _nickMsg!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _nickFree ? AppColors.green : AppColors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      hintText: widget.me.email,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _savingName ? null : _saveProfile,
                    child: _savingName
                        ? const _Spin()
                        : const Text('SALVAR PERFIL'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Section('TROCAR SENHA'),
            ComicPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _currentCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Senha atual'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nova senha'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirmar nova senha'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _savingPass ? null : _changePassword,
                    child: _savingPass
                        ? const _Spin()
                        : const Text('ALTERAR SENHA'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(LucideIcons.logOut, color: AppColors.red, size: 18),
              label: const Text('SAIR DA CONTA',
                  style: TextStyle(color: AppColors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.red, width: 2.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );
}

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
      );
}
