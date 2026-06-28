import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

/// Cabeçalho compacto das abas (substitui a AppBar — a navegação é pela tabbar).
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    this.onRefresh,
    this.actions,
  });

  final String title;
  final VoidCallback? onRefresh;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(LucideIcons.refreshCw,
                  color: AppColors.muted, size: 20),
              tooltip: 'Atualizar',
            ),
        ],
      ),
    );
  }
}
