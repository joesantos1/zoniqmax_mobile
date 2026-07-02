import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../tokens.dart';
import '../typography.dart';

enum GameChipMode {
  /// Cor sólida + texto branco (substitui o antigo ComicTag).
  filled,

  /// Fundo da cor a 12% + texto na cor (etiquetas suaves).
  tonal,
}

/// Chip/etiqueta pill do jogo.
class GameChip extends StatelessWidget {
  const GameChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.mode = GameChipMode.filled,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final GameChipMode mode;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final accent = color ?? zon.brand;
    final (bg, fg) = switch (mode) {
      GameChipMode.filled => (accent, zon.onBrand),
      GameChipMode.tonal => (accent.withValues(alpha: 0.12), accent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppText.caption.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Chip selecionável (filtros de área/tema/dificuldade):
/// desmarcado = superfície + contorno; marcado = cor sólida + edge inferior.
class GameSelectChip extends StatelessWidget {
  const GameSelectChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final accent = color ?? zon.brand;
    final fg = selected ? zon.onBrand : zon.onSurface;

    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              GameHaptics.tap();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : zon.surface,
          borderRadius: BorderRadius.circular(Corners.pill),
          border: Border.all(
            color: selected ? accent : zon.outline,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Color.lerp(accent, const Color(0xFF000000), 0.25)!,
                    offset: const Offset(0, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
            ],
            Text(label, style: AppText.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
