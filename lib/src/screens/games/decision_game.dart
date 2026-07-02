import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models.dart';
import '../../theme.dart';

/// Tomada de decisão: cenário narrativo + cartões de ação. O jogador escolhe a
/// melhor decisão. Escreve em [answer] o índice (0-based) da opção escolhida.
/// Renderiza o próprio enunciado (painel de cenário) — está em _rendersOwnPrompt.
class DecisionGame extends StatefulWidget {
  const DecisionGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;

  @override
  State<DecisionGame> createState() => _DecisionGameState();
}

class _DecisionGameState extends State<DecisionGame> {
  int? _selected;

  List<String> get _opcoes =>
      ((widget.challenge.data['opcoes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();

  String get _cenario =>
      (widget.challenge.data['cenario'] as String?) ?? widget.challenge.prompt;

  void _choose(int i) {
    if (widget.locked) return;
    GameHaptics.tap();
    setState(() {
      _selected = i;
      widget.answer.value = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    const letters = 'ABCD';
    final opcoes = _opcoes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // painel do cenário — visual narrativo (marrom do território)
        GamePanel(
          color: Color.alphaBlend(
              zon.territory.withValues(alpha: 0.08), zon.surface),
          borderColor: zon.territory.withValues(alpha: 0.35),
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.quote, size: 16, color: zon.territory),
                  const SizedBox(width: 6),
                  GameChip(
                    label: 'CENÁRIO',
                    color: zon.territory,
                    mode: GameChipMode.tonal,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_cenario,
                  style: AppText.body.copyWith(fontSize: 16, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Qual é a melhor decisão?',
            style: AppText.label.copyWith(color: zon.onSurfaceMuted)),
        const SizedBox(height: 8),
        for (var i = 0; i < opcoes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GamePressable(
              onTap: widget.locked ? null : () => _choose(i),
              haptic: false,
              faceColor: _selected == i
                  ? Color.alphaBlend(
                      zon.brand.withValues(alpha: 0.12), zon.surface)
                  : zon.surface,
              borderColor: _selected == i ? zon.brand : zon.outline,
              edgeColor: _selected == i ? zon.brandEdge : zon.neutralEdge,
              borderWidth: _selected == i ? 2.5 : 2,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _selected == i ? zon.brand : zon.surfaceAlt,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i < letters.length ? letters[i] : '${i + 1}',
                      style: AppText.label.copyWith(
                        color: _selected == i
                            ? zon.onBrand
                            : zon.onSurfaceMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(opcoes[i],
                        style: AppText.bodyStrong.copyWith(fontSize: 15.5)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
