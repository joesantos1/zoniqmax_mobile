import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../components/game_panel.dart';
import '../components/progress.dart';
import '../tokens.dart';
import '../typography.dart';

/// Cartão de resultado de desafio: acerto = pop celebratório verde com XP
/// contando; erro = shake suave com tom de apoio (não punitivo).
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.success,
    required this.title,
    this.subtitle,
    this.xp,
    this.extra = const <Widget>[],
  });

  final bool success;
  final String title;
  final String? subtitle;

  /// XP ganho (mostra "+N XP" com contagem animada).
  final int? xp;

  /// Linhas extras (pontos de classe, bônus usados, etc.).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final accent = success ? zon.success : zon.danger;

    final card = GamePanel(
      color: Color.alphaBlend(
          accent.withValues(alpha: success ? 0.10 : 0.08), zon.surface),
      borderColor: accent.withValues(alpha: 0.45),
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? LucideIcons.partyPopper : LucideIcons.heartCrack,
              size: 22,
              color: accent,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.title
                        .copyWith(color: accent, fontSize: 17)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style:
                          AppText.body.copyWith(color: zon.onSurfaceMuted)),
                ],
                if (xp != null && xp! > 0) ...[
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Icon(LucideIcons.zap, size: 16, color: zon.xp),
                      const SizedBox(width: 4),
                      XpCounter(
                        value: xp!,
                        prefix: '+',
                        suffix: ' XP',
                        style: AppText.numeric
                            .copyWith(fontSize: 18, color: zon.xp),
                      ),
                    ],
                  ),
                ],
                ...extra,
              ],
            ),
          ),
        ],
      ),
    );

    return success ? _Pop(child: card) : _Shake(child: card);
  }
}

/// Entrada com pop (escala easeOutBack) — celebração.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.75, end: 1.0),
      duration: const Duration(milliseconds: 340),
      curve: AppCurves.pop,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// Entrada com shake horizontal amortecido — erro gentil.
class _Shake extends StatelessWidget {
  const _Shake({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.linear,
      builder: (context, t, child) {
        final dx = math.sin(t * math.pi * 5) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: child,
    );
  }
}
