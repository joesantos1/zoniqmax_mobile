import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens.dart';
import '../typography.dart';

/// Barra de progresso pill com preenchimento animado.
class GameProgressBar extends StatelessWidget {
  const GameProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 12,
    this.trackColor,
  });

  /// 0..1
  final double value;
  final Color? color;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Corners.pill),
      child: Container(
        height: height,
        color: trackColor ?? zon.surfaceAlt,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 600),
          curve: AppCurves.out,
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color ?? zon.brand,
              borderRadius: BorderRadius.circular(Corners.pill),
            ),
          ),
        ),
      ),
    );
  }
}

/// Número que "conta" animado até o valor (XP, pontos, contagens).
/// Retarga automaticamente a partir do valor animado atual quando muda.
class XpCounter extends StatelessWidget {
  const XpCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: duration,
      curve: AppCurves.out,
      builder: (context, v, _) => Text(
        '$prefix${v.round()}$suffix',
        style: style ?? AppText.numeric,
      ),
    );
  }
}

/// Chama de streak com gradiente da marca; dá um "pop" quando o valor sobe.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.count, this.size = 20});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return TweenAnimationBuilder<double>(
      // key troca a cada valor -> reinicia o pop de escala.
      key: ValueKey<int>(count),
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: AppCurves.pop,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [zon.streakA, zon.streakB],
            ).createShader(bounds),
            child: Icon(LucideIcons.flame, size: size, color: Colors.white),
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: AppText.numeric.copyWith(
              fontSize: size * 0.85,
              color: zon.streakB,
            ),
          ),
        ],
      ),
    );
  }
}
