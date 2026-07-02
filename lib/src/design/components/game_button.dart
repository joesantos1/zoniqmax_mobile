import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../tokens.dart';
import '../typography.dart';

enum GameButtonVariant { primary, secondary, success, danger, ink, ghost }

enum GameButtonSize { sm, md, lg }

/// Botão "chunky 3D" — assinatura visual do jogo (estilo Duolingo):
/// face sólida sobre uma borda inferior mais escura; pressionar desliza a
/// face para baixo. Implementado com sombra dura (blur 0) + translate, tudo
/// animado por um único AnimatedContainer de 90ms.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = GameButtonVariant.primary,
    this.size = GameButtonSize.md,
    this.expanded = false,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameButtonVariant variant;
  final GameButtonSize size;

  /// true = ocupa toda a largura disponível.
  final bool expanded;

  /// true = mostra spinner no lugar do ícone e desabilita o toque.
  final bool loading;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
        GameButtonSize.sm => 44,
        GameButtonSize.md => 52,
        GameButtonSize.lg => 60,
      };

  static const _edge = 4.0;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final enabled = widget.onPressed != null && !widget.loading;
    final ghost = widget.variant == GameButtonVariant.ghost;

    final (Color face, Color edge, Color fg, Color? border) = switch (widget.variant) {
      GameButtonVariant.primary => (zon.brand, zon.brandEdge, zon.onBrand, null),
      GameButtonVariant.success => (zon.success, zon.successEdge, zon.onBrand, null),
      GameButtonVariant.danger => (zon.danger, zon.dangerEdge, zon.onBrand, null),
      GameButtonVariant.ink => (zon.onSurface, zon.inkEdge, zon.surface, null),
      GameButtonVariant.secondary => (zon.surface, zon.neutralEdge, zon.onSurface, zon.outline),
      GameButtonVariant.ghost => (Colors.transparent, Colors.transparent, zon.brand, null),
    };

    final faceColor = enabled ? face : (ghost ? Colors.transparent : zon.surfaceAlt);
    final fgColor = enabled ? fg : zon.onSurfaceMuted;
    final hasEdge = enabled && !ghost;

    final fontSize = widget.size == GameButtonSize.sm ? 14.0 : 16.0;
    final iconSize = widget.size == GameButtonSize.sm ? 18.0 : 20.0;
    final hPad = switch (widget.size) {
      GameButtonSize.sm => 16.0,
      GameButtonSize.md => 20.0,
      GameButtonSize.lg => 24.0,
    };

    Widget? leading;
    if (widget.loading) {
      leading = SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: fgColor),
      );
    } else if (widget.icon != null) {
      leading = Icon(widget.icon, size: iconSize, color: fgColor);
    }

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.button.copyWith(fontSize: fontSize, color: fgColor),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled
            ? (_) {
                setState(() => _pressed = true);
                GameHaptics.tap();
              }
            : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: AppDurations.press,
          curve: Curves.easeOut,
          height: _height,
          width: widget.expanded ? double.infinity : null,
          // Reserva o espaço do edge para a altura total ficar estável.
          margin: const EdgeInsets.only(bottom: _edge),
          transform: Matrix4.translationValues(
              0, hasEdge && _pressed ? _edge : 0, 0),
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: faceColor,
            borderRadius: BorderRadius.circular(Corners.md),
            border: border != null && enabled
                ? Border.all(color: border, width: 2)
                : null,
            boxShadow: hasEdge
                ? [
                    BoxShadow(
                      color: edge,
                      offset: Offset(0, _pressed ? 0 : _edge),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(widthFactor: widget.expanded ? null : 1, child: content),
        ),
      ),
    );
  }
}
