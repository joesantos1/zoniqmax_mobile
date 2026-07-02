import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Explosão de confete 100% nativa: um único AnimationController dirige um
/// CustomPainter (repaint via controller — zero setState durante a animação).
/// Física pré-computada por partícula; isolado em RepaintBoundary.
///
/// Uso: coloque num Stack cobrindo a área e mude [play] (qualquer objeto
/// não-nulo diferente do anterior) para disparar uma rajada.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.play,
    this.particleCount = 60,
    this.origin = const Alignment(0, -0.5),
  });

  /// Dispara uma rajada quando muda para um valor não-nulo diferente.
  final Object? play;
  final int particleCount;

  /// Ponto de origem da explosão dentro da área do widget.
  final Alignment origin;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  final _random = math.Random();
  List<_Particle> _particles = const [];

  static const _palette = [
    BrandColors.orange,
    BrandColors.blue,
    BrandColors.greenBright,
    BrandColors.red,
    BrandColors.purple,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.play != null) _fire();
  }

  @override
  void didUpdateWidget(ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play != null && widget.play != oldWidget.play) _fire();
  }

  void _fire() {
    _particles = List.generate(widget.particleCount, (_) {
      // Leque para cima (-90° ± 65°), gravidade puxa de volta.
      final angle =
          (-90 + (_random.nextDouble() * 130 - 65)) * math.pi / 180;
      final speed = 250 + _random.nextDouble() * 450;
      return _Particle(
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        spin: (_random.nextDouble() - 0.5) * 14,
        size: 6 + _random.nextDouble() * 6,
        color: _palette[_random.nextInt(_palette.length)],
        drift: (_random.nextDouble() - 0.5) * 60,
      );
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller,
            origin: widget.origin,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.velocity,
    required this.spin,
    required this.size,
    required this.color,
    required this.drift,
  });

  final Offset velocity; // px/s
  final double spin; // rad/s
  final double size;
  final Color color;
  final double drift; // deriva horizontal (vento)
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.origin,
  }) : super(repaint: progress);

  final List<_Particle> particles;
  final Animation<double> progress;
  final Alignment origin;

  static const _gravity = 1300.0; // px/s²
  static const _durationSec = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final t01 = progress.value;
    if (t01 <= 0 || t01 >= 1 || particles.isEmpty) return;

    final t = t01 * _durationSec;
    final o = origin.alongSize(size);
    final opacity = t01 > 0.7 ? 1 - (t01 - 0.7) / 0.3 : 1.0;
    final paint = Paint();

    for (final p in particles) {
      final x = o.dx + (p.velocity.dx + p.drift) * t;
      final y = o.dy + p.velocity.dy * t + 0.5 * _gravity * t * t;
      if (y > size.height + 20) continue;

      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.65),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles || oldDelegate.origin != origin;
}
