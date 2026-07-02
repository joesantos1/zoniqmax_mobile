import 'package:flutter/material.dart';

import '../tokens.dart';

/// Cartão padrão do jogo: superfície clara, cantos generosos, sombra suave.
/// Substitui o antigo ComicPanel (mesma API: child/color/padding/onTap).
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.radius = Corners.lg,
    this.shadow = true,
  });

  final Widget child;

  /// null = superfície do tema (dark-ready).
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.zon.surface,
        borderRadius: borderRadius,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
        boxShadow: shadow ? const [Shadows.soft] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
