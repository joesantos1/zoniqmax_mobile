import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models.dart';
import '../../theme.dart';

/// Reação e precisão: uma grade de itens aparece (entrada em cascata) e o
/// jogador toca APENAS nos que obedecem à regra do enunciado. Escreve em
/// [answer] a lista de ids selecionados, em ordem alfabética (resposta-conjunto).
class PrecisionGame extends StatefulWidget {
  const PrecisionGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;

  @override
  State<PrecisionGame> createState() => _PrecisionGameState();
}

class _PrecisionGameState extends State<PrecisionGame>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _itens;
  final Set<String> _selected = {};

  // entrada em cascata one-shot (sem loop)
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void initState() {
    super.initState();
    final raw = (widget.challenge.data['itens'] as List?) ?? const [];
    _itens = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    widget.answer.value = <String>[];
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    if (widget.locked) return;
    GameHaptics.tap();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      widget.answer.value = _selected.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final n = _itens.length;
    final longLabels =
        _itens.any((it) => (it['label'] as String).length > 8);
    final cols = longLabels ? 2 : 3;

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 8,
      childAspectRatio: longLabels ? 2.6 : 1.7,
      children: [
        for (var i = 0; i < n; i++)
          () {
            final it = _itens[i];
            final id = it['id'] as String;
            final selected = _selected.contains(id);
            // cascata: cada tile entra num intervalo próprio da animação
            final start = (i / n) * 0.6;
            final anim = CurvedAnimation(
              parent: _intro,
              curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
                  curve: AppCurves.pop),
            );
            return FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: anim,
                child: GamePressable(
                  onTap: widget.locked ? null : () => _toggle(id),
                  haptic: false, // haptic já disparado no _toggle
                  faceColor: selected
                      ? Color.alphaBlend(
                          zon.brand.withValues(alpha: 0.12), zon.surface)
                      : zon.surface,
                  borderColor: selected ? zon.brand : zon.outline,
                  edgeColor: selected ? zon.brandEdge : zon.neutralEdge,
                  borderWidth: selected ? 2.5 : 2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          it['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong.copyWith(
                            fontSize: longLabels ? 14 : 17,
                            color: selected ? zon.brand : zon.onSurface,
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(LucideIcons.circleCheck,
                              size: 15, color: zon.brand),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
