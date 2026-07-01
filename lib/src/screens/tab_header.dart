import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme.dart';

/// Cabeçalho compacto das abas (substitui a AppBar — a navegação é pela tabbar).
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    this.onRefresh,
    this.onBack,
    this.actions,
  });

  final String title;
  final VoidCallback? onRefresh;

  /// Quando definido, exibe um botão de voltar (ex.: sair de outro território
  /// para a sua zona atual).
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 16, 14, 8, 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.arrowLeft,
                  color: AppColors.ink, size: 22),
              tooltip: 'Voltar para sua zona atual',
            ),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.ink,
              ),
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
