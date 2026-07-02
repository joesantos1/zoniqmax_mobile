import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../tokens.dart';

/// Card pressionável genérico com o mesmo efeito "chunky 3D" do GameButton:
/// borda + edge inferior escuro que afunda ao pressionar. Usado por opções de
/// quiz, cards de área, swatches de cor, etc.
class GamePressable extends StatefulWidget {
  const GamePressable({
    super.key,
    required this.child,
    this.onTap,
    this.faceColor,
    this.borderColor,
    this.edgeColor,
    this.borderWidth = 2,
    this.edgeHeight = 3,
    this.radius = Corners.md,
    this.padding = const EdgeInsets.all(14),
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? faceColor;
  final Color? borderColor;
  final Color? edgeColor;
  final double borderWidth;
  final double edgeHeight;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool haptic;

  @override
  State<GamePressable> createState() => _GamePressableState();
}

class _GamePressableState extends State<GamePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final enabled = widget.onTap != null;
    final face = widget.faceColor ?? zon.surface;
    final border = widget.borderColor ?? zon.outline;
    final edge = widget.edgeColor ?? zon.neutralEdge;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              setState(() => _pressed = true);
              if (widget.haptic) GameHaptics.tap();
            }
          : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppDurations.press,
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: widget.edgeHeight),
        transform: Matrix4.translationValues(
            0, enabled && _pressed ? widget.edgeHeight : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: border, width: widget.borderWidth),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: edge,
                    offset: Offset(0, _pressed ? 0 : widget.edgeHeight),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
