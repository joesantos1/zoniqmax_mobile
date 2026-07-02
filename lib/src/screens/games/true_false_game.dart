import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models.dart';
import '../../theme.dart';

/// Verdadeiro ou falso relâmpago: cartões deslizantes (estilo Tinder) — deslize
/// para a DIREITA (verdadeiro) ou ESQUERDA (falso); há botões de apoio embaixo.
/// Escreve em [answer] a lista de booleans na ordem das afirmações e chama
/// [onComplete] quando a última é respondida (auto-submit).
class TrueFalseGame extends StatefulWidget {
  const TrueFalseGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
    required this.onComplete,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;
  final VoidCallback onComplete;

  @override
  State<TrueFalseGame> createState() => _TrueFalseGameState();
}

class _TrueFalseGameState extends State<TrueFalseGame>
    with SingleTickerProviderStateMixin {
  late final List<String> _afirmacoes;
  final List<bool> _answers = [];
  int _index = 0;

  Offset _drag = Offset.zero;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Animation<Offset>? _anim; // voo para fora ou retorno ao centro
  bool? _pending; // resposta a registrar quando o voo terminar

  bool get _animating => _ctrl.isAnimating;
  bool get _done => _index >= _afirmacoes.length;

  @override
  void initState() {
    super.initState();
    _afirmacoes = ((widget.challenge.data['afirmacoes'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    widget.answer.value = <bool>[];
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (widget.locked || _animating || _done) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (widget.locked || _animating || _done) return;
    final w = context.size?.width ?? 320;
    if (_drag.dx.abs() > w * 0.35) {
      _flyOut(_drag.dx > 0);
    } else {
      _settleBack();
    }
  }

  /// Anima o cartão para fora da tela e registra a resposta ao terminar.
  void _flyOut(bool value) {
    final w = context.size?.width ?? 320;
    _pending = value;
    GameHaptics.tap();
    _anim = Tween<Offset>(
      begin: _drag,
      end: Offset((value ? 1 : -1) * w * 1.4, _drag.dy * 1.4),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    setState(() {});
    _ctrl.forward(from: 0).whenComplete(_commit);
  }

  /// Volta o cartão ao centro (soltou antes do limiar).
  void _settleBack() {
    _pending = null;
    _anim = Tween<Offset>(begin: _drag, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    setState(() {});
    _ctrl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _drag = Offset.zero;
        _anim = null;
      });
    });
  }

  void _commit() {
    final v = _pending;
    if (v == null || !mounted) return;
    setState(() {
      _answers.add(v);
      widget.answer.value = List<bool>.of(_answers);
      _index++;
      _drag = Offset.zero;
      _anim = null;
      _pending = null;
    });
    if (_done) {
      GameHaptics.celebrate();
      widget.onComplete();
    }
  }

  /// Resposta via botões (mesma animação de saída).
  void _answerButton(bool value) {
    if (widget.locked || _animating || _done) return;
    _flyOut(value);
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final total = _afirmacoes.length;

    return Column(
      children: [
        // progresso
        Row(
          children: [
            Expanded(
              child: GameProgressBar(
                value: total == 0 ? 0 : _answers.length / total,
                height: 8,
              ),
            ),
            const SizedBox(width: 10),
            Text('${_answers.length} de $total',
                style: AppText.caption.copyWith(color: zon.onSurfaceMuted)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _done
              ? Center(
                  child: Icon(LucideIcons.circleCheck,
                      size: 48, color: zon.success),
                )
              : AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final offset = _anim?.value ?? _drag;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // cartão de trás (próxima afirmação)
                        if (_index + 1 < total)
                          Transform.scale(
                            scale: 0.94,
                            child: Transform.translate(
                              offset: const Offset(0, 10),
                              child: _card(_afirmacoes[_index + 1],
                                  interactive: false, offset: Offset.zero),
                            ),
                          ),
                        // cartão do topo (arrastável)
                        Transform.translate(
                          offset: offset,
                          child: Transform.rotate(
                            angle: offset.dx / 340,
                            child: GestureDetector(
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: _card(_afirmacoes[_index],
                                  interactive: true, offset: offset),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        // botões de apoio (mesma resposta do swipe)
        Row(
          children: [
            Expanded(
              child: GameButton(
                label: 'FALSO',
                icon: LucideIcons.x,
                variant: GameButtonVariant.danger,
                onPressed:
                    widget.locked || _done ? null : () => _answerButton(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GameButton(
                label: 'VERDADEIRO',
                icon: LucideIcons.check,
                variant: GameButtonVariant.success,
                onPressed:
                    widget.locked || _done ? null : () => _answerButton(true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _card(String text, {required bool interactive, required Offset offset}) {
    final zon = context.zon;
    final w = context.size?.width ?? 320;
    final strength = (offset.dx.abs() / (w * 0.35)).clamp(0.0, 1.0);
    final right = offset.dx > 0;
    final accent = right ? zon.success : zon.danger;
    final border = interactive && strength > 0.05
        ? Color.lerp(zon.outline, accent, strength)!
        : zon.outline;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: zon.surface,
        borderRadius: BorderRadius.circular(Corners.lg),
        border: Border.all(color: border, width: 2.5),
        boxShadow: [
          BoxShadow(color: zon.neutralEdge, offset: const Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.headline.copyWith(fontSize: 20),
            ),
          ),
          // selos VERDADEIRO / FALSO durante o arrasto
          if (interactive && strength > 0.05)
            Positioned(
              top: 0,
              left: right ? 0 : null,
              right: right ? null : 0,
              child: Opacity(
                opacity: strength,
                child: Transform.rotate(
                  angle: right ? -0.15 : 0.15,
                  child: GameChip(
                    label: right ? 'VERDADEIRO' : 'FALSO',
                    color: accent,
                    icon: right ? LucideIcons.check : LucideIcons.x,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
