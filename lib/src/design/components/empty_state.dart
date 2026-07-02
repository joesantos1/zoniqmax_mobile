import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Estado vazio amigável: ícone grande tintado + título + mensagem + ação.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final accent = color ?? zon.brand;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: accent),
            ),
            const SizedBox(height: Space.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(color: zon.onSurface),
            ),
            if (message != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: zon.onSurfaceMuted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Space.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
