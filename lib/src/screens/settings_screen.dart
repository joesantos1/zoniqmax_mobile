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
        appBar: AppBar(title: const Text('Configurações')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child:
                  SectionHeader(icon: LucideIcons.user, title: 'Meus dados'),
            ),
            GamePanel(
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
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GameChip(
                          label: _nickMsg!,
                          mode: GameChipMode.tonal,
                          icon: _nickFree
                              ? LucideIcons.check
                              : LucideIcons.circleAlert,
                          color: _nickFree
                              ? context.zon.success
                              : context.zon.danger,
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
                  const SizedBox(height: 14),
                  GameButton(
                    label: 'SALVAR PERFIL',
                    icon: LucideIcons.save,
                    expanded: true,
                    loading: _savingName,
                    onPressed: _savingName ? null : _saveProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SectionHeader(
                  icon: LucideIcons.lock, title: 'Trocar senha'),
            ),
            GamePanel(
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
                  const SizedBox(height: 14),
                  GameButton(
                    label: 'ALTERAR SENHA',
                    icon: LucideIcons.keyRound,
                    variant: GameButtonVariant.secondary,
                    expanded: true,
                    loading: _savingPass,
                    onPressed: _savingPass ? null : _changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GameButton(
              label: 'SAIR DA CONTA',
              icon: LucideIcons.logOut,
              variant: GameButtonVariant.danger,
              expanded: true,
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
