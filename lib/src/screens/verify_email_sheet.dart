import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/code_input.dart';

/// Abre o sheet de verificação de e-mail (código tipo 2FA).
/// Pede o código ao abrir e retorna `true` quando o e-mail for verificado.
Future<bool> showVerifyEmailSheet(
  BuildContext context,
  ApiClient api, {
  required String email,
}) async {
  final verified = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VerifyEmailSheet(api: api, email: email),
  );
  return verified == true;
}

class _VerifyEmailSheet extends StatefulWidget {
  const _VerifyEmailSheet({required this.api, required this.email});

  final ApiClient api;
  final String email;

  @override
  State<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends State<_VerifyEmailSheet> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _request(initial: true);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _request({bool initial = false}) async {
    setState(() {
      _error = null;
      if (!initial) _info = null;
    });
    try {
      await widget.api.requestEmailVerification();
      if (!mounted) return;
      setState(() => _info = 'Código enviado para ${widget.email}');
    } on ApiException catch (e) {
      if (!mounted) return;
      // cooldown de reenvio (429) logo após o cadastro é esperado: o código
      // do cadastro ainda vale — segue o fluxo sem alarde
      if (e.statusCode == 429 && initial) {
        setState(() => _info = 'Use o código enviado para ${widget.email}');
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Falha de conexão.');
    }
  }

  Future<void> _confirm() async {
    if (_codeCtrl.text.length < 6) {
      setState(() => _error = 'Digite o código de 6 dígitos.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.confirmEmailVerification(_codeCtrl.text);
      if (!mounted) return;
      GameHaptics.celebrate();
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      GameHaptics.wrong();
      setState(() {
        _error = e.message;
        _codeCtrl.clear();
      });
    } catch (_) {
      setState(() => _error = 'Falha de conexão.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Padding(
      // respeita o teclado do sistema, se aberto
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: zon.outline,
                    borderRadius: BorderRadius.circular(Corners.pill),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: zon.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.mailCheck,
                        size: 20, color: zon.brand),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Verificar e-mail', style: AppText.title),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _info ?? 'Enviando código para ${widget.email}…',
                style: AppText.body.copyWith(color: zon.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              CodeBoxes(controller: _codeCtrl),
              const SizedBox(height: 10),
              GameNumpad(
                controller: _codeCtrl,
                enabled: !_loading,
                allowDecimal: false,
                allowNegative: false,
                maxLength: 6,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(color: zon.danger)),
              ],
              const SizedBox(height: 14),
              GameButton(
                label: 'CONFIRMAR',
                icon: LucideIcons.check,
                size: GameButtonSize.lg,
                expanded: true,
                loading: _loading,
                onPressed: _loading ? null : _confirm,
              ),
              TextButton(
                onPressed: _loading ? null : () => _request(),
                child: const Text('Reenviar código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
