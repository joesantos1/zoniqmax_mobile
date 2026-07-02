import 'package:flutter/material.dart';

import '../theme.dart';

/// Chip de classe com ícone (Lucide) + rótulo (e opcionalmente um valor).
/// Pill sólida na cor da classe, estilo GameChip preenchido.
class ClassChip extends StatelessWidget {
  const ClassChip({super.key, required this.classType, this.label, this.value});

  final String classType;
  final String? label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final color = kClassColors[classType] ?? zon.territory;
    final text = value != null ? '${label ?? ''} $value'.trim() : (label ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 13, 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(classIcon(classType), color: zon.onBrand, size: 14),
          const SizedBox(width: 6),
          Text(text, style: AppText.caption.copyWith(color: zon.onBrand)),
        ],
      ),
    );
  }
}

/// Cartão de métrica: ícone (Lucide) num quadrado arredondado tonalizado +
/// rótulo + valor. Usado nas grades de stats (perfil, perfil público,
/// território, desafio).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GamePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.caption.copyWith(color: zon.onSurfaceMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.numeric
                      .copyWith(fontSize: 20, color: zon.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
