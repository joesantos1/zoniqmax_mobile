import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models.dart';
import '../../theme.dart';

/// Jogo da memória: as cartas preenchem toda a área disponível. Flip 3D ao virar,
/// "pop" ao casar um par e "shake" ao errar. Ao completar, escreve os pares em
/// [answer] e chama [onComplete].
class MemoryGame extends StatefulWidget {
  const MemoryGame({
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
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  late List<String> _cards;
  late List<int> _order; // posição na tela -> índice original da carta
  final List<int> _flipped = []; // índices originais virados (não casados), máx. 2
  final Set<int> _matched = {};
  final Set<int> _wrong = {}; // par errado em destaque momentâneo
  final List<List<int>> _pairs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cards = ((widget.challenge.data['cards'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    // Embaralha apenas a ORDEM de exibição; os índices originais (usados na
    // resposta ao servidor) são preservados via _order.
    _order = List<int>.generate(_cards.length, (i) => i)
      ..shuffle(math.Random());
    widget.answer.value = _pairs;
  }

  void _tap(int i) {
    if (widget.locked || _busy) return;
    if (_matched.contains(i) || _flipped.contains(i)) return;

    GameHaptics.tap();
    setState(() => _flipped.add(i));

    if (_flipped.length == 2) {
      _busy = true;
      final a = _flipped[0];
      final b = _flipped[1];
      if (_cards[a] == _cards[b]) {
        Future.delayed(const Duration(milliseconds: 320), () {
          if (!mounted) return;
          setState(() {
            _matched.addAll([a, b]);
            _pairs.add([a, b]);
            _flipped.clear();
            _busy = false;
            widget.answer.value = _pairs;
          });
          if (_matched.length == _cards.length) {
            GameHaptics.celebrate();
            widget.onComplete();
          } else {
            GameHaptics.correct();
          }
        });
      } else {
        GameHaptics.wrong();
        setState(() => _wrong.addAll([a, b]));
        Future.delayed(const Duration(milliseconds: 850), () {
          if (!mounted) return;
          setState(() {
            _flipped.clear();
            _wrong.clear();
            _busy = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _cards.length;
    final cols = n <= 4 ? 2 : (n <= 6 ? 3 : 4);
    final rows = (n / cols).ceil();
    const spacing = 10.0;

    return LayoutBuilder(
      builder: (context, c) {
        final cellW = (c.maxWidth - (cols - 1) * spacing) / cols;
        final cellH =
            (c.maxHeight - (rows - 1) * spacing) / rows;
        final aspect = (cellH > 0 && cellW > 0) ? cellW / cellH : 1.0;
        return GridView.count(
          crossAxisCount: cols,
          childAspectRatio: aspect,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (int p = 0; p < n; p++)
              () {
                final i = _order[p]; // índice original da carta nesta posição
                return _FlipCard(
                  value: _cards[i],
                  faceUp: _matched.contains(i) || _flipped.contains(i),
                  matched: _matched.contains(i),
                  wrong: _wrong.contains(i),
                  onTap: () => _tap(i),
                );
              }(),
          ],
        );
      },
    );
  }
}

/// Carta com flip 3D (rotação Y), "pop" ao casar e "shake" ao errar.
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    required this.value,
    required this.faceUp,
    required this.matched,
    required this.wrong,
    required this.onTap,
  });

  final String value;
  final bool faceUp;
  final bool matched;
  final bool wrong;
  final VoidCallback onTap;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.faceUp ? 1 : 0,
  );
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(covariant _FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.faceUp != old.faceUp) {
      widget.faceUp ? _flip.forward() : _flip.reverse();
    }
    if (widget.matched && !old.matched) _pop.forward(from: 0);
    if (widget.wrong && !old.wrong) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _flip.dispose();
    _pop.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flip, _pop, _shake]),
        builder: (context, _) {
          final angle = _flip.value * math.pi;
          final isFront = angle > math.pi / 2;
          final popScale = 1 + math.sin(_pop.value * math.pi) * 0.18;
          final shakeDx =
              math.sin(_shake.value * math.pi * 4) * 8 * (1 - _shake.value);

          final zon = context.zon;
          return Transform.translate(
            offset: Offset(shakeDx, 0),
            child: Transform.scale(
              scale: popScale,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFront
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _face(
                          bg: widget.matched
                              ? Color.alphaBlend(
                                  zon.success.withValues(alpha: 0.14),
                                  zon.surface)
                              : zon.surface,
                          border: widget.wrong
                              ? zon.danger
                              : (widget.matched ? zon.success : zon.outline),
                          back: false,
                        ),
                      )
                    : _face(
                        bg: zon.brand,
                        border: zon.brandEdge,
                        back: true,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _face({
    required Color bg,
    required Color border,
    required bool back,
  }) {
    final zon = context.zon;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: border, width: 2),
        // edge inferior "chunky" (sombra dura) só no verso laranja
        boxShadow: back
            ? [
                BoxShadow(
                    color: zon.brandEdge,
                    offset: const Offset(0, 2.5),
                    blurRadius: 0),
              ]
            : null,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.biggest.shortestSide;
          if (back) {
            // hexágono branco da marca com "?" — verso das cartas
            return Stack(
              alignment: Alignment.center,
              children: [
                Icon(LucideIcons.hexagon,
                    color: zon.onBrand.withValues(alpha: 0.9),
                    size: s * 0.62),
                Text(
                  '?',
                  style: AppText.numeric.copyWith(
                      fontSize: s * 0.28, color: zon.onBrand),
                ),
              ],
            );
          }
          return Text(
            widget.value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: s * 0.78, height: 1.0),
          );
        },
      ),
    );
  }
}
