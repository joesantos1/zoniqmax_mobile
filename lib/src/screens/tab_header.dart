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
    final zon = context.zon;
    return Container(
      padding: EdgeInsets.fromLTRB(onBack != null ? 8 : 16, 14, 12, 6),
      child: Row(
        children: [
          if (onBack != null) ...[
            HeaderIconButton(
              icon: LucideIcons.arrowLeft,
              onTap: onBack,
              tooltip: 'Voltar para sua zona atual',
            ),
            const SizedBox(width: Space.sm),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline.copyWith(color: zon.onSurface),
            ),
          ),
          if (actions != null) ...actions!,
          if (onRefresh != null) ...[
            const SizedBox(width: Space.sm),
            HeaderIconButton(
              icon: LucideIcons.refreshCw,
              onTap: onRefresh,
              tooltip: 'Atualizar',
              muted: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Botão circular de cabeçalho (voltar / atualizar / ações das abas):
/// superfície branca com contorno, ícone centralizado e haptic no toque.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.muted = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// true = ícone na cor apagada (ações secundárias, ex.: atualizar).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final enabled = onTap != null;
    final fg = enabled
        ? (muted ? zon.onSurfaceMuted : zon.onSurface)
        : zon.onSurfaceMuted.withValues(alpha: 0.5);

    final button = GestureDetector(
      onTap: enabled
          ? () {
              GameHaptics.tap();
              onTap!();
            }
          : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: zon.surface,
          shape: BoxShape.circle,
          border: Border.all(color: zon.outline, width: 2),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
