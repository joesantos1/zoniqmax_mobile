import 'package:flutter/material.dart';

import '../tokens.dart';

/// Grupo de skeletons: UM AnimationController compartilhado pulsa a opacidade
/// de todos os SkeletonBox descendentes (sem shader shimmer — barato).
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 0.45, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScope(
      opacity: _opacity,
      child: RepaintBoundary(child: widget.child),
    );
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.opacity, required super.child});

  final Animation<double> opacity;

  static _SkeletonScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      opacity != oldWidget.opacity;
}

/// Bloco de skeleton. Dentro de um [SkeletonGroup] pulsa; fora, fica estático.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = Corners.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.zon.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    final scope = _SkeletonScope.of(context);
    if (scope == null) return box;
    return FadeTransition(opacity: scope.opacity, child: box);
  }
}

/// Linha de texto skeleton.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: width, height: 12, radius: 6);
  }
}
