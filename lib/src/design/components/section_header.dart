import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Cabeçalho de seção: ícone em quadrado arredondado tintado + título.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final accent = color ?? zon.brand;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title.copyWith(color: zon.onSurface),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
