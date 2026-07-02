import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// Timer circular do desafio: anel que esvazia suavemente a 60fps com um
/// AnimationController próprio (repaint direto no painter — zero setState),
/// enquanto a LÓGICA do jogo continua sendo do Timer.periodic de 1s do
/// ChallengePlayer, que fornece [secondsLeft] para os dígitos.
class TimerRing extends StatefulWidget {
  const TimerRing({
    super.key,
    required this.totalSeconds,
    required this.secondsLeft,
    this.running = true,
    this.size = 64,
  });

  final int totalSeconds;
  final int secondsLeft;

  /// false = congela o anel (respondido/enviando).
  final bool running;
  final double size;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.totalSeconds.clamp(1, 3600)),
  );

  @override
  void initState() {
    super.initState();
    if (widget.running) _controller.forward();
  }

  @override
  void didUpdateWidget(TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.running && oldWidget.running) {
      _controller.stop();
    } else if (widget.running && !oldWidget.running) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final low = widget.secondsLeft <= 5 && widget.running;
    final digits = widget.secondsLeft < 0 ? 0 : widget.secondsLeft;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        // pulso por segundo nos últimos 5s (re-dispara a cada tique)
        key: low ? ValueKey<int>(widget.secondsLeft) : const ValueKey('calm'),
        tween: Tween(begin: low ? 1.09 : 1.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  progress: _controller,
                  track: zon.surfaceAlt,
                  from: zon.brand,
                  to: zon.danger,
                ),
              ),
              Text(
                '$digits',
                style: AppText.numeric.copyWith(
                  fontSize: widget.size * 0.32,
                  color: low ? zon.danger : zon.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.from,
    required this.to,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color track;
  final Color from;
  final Color to;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.10;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    paint.color = track;
    canvas.drawArc(arcRect, 0, 6.2832, false, paint);

    final remaining = (1 - progress.value).clamp(0.0, 1.0);
    if (remaining <= 0) return;

    // cor: marca -> perigo quando resta <25%
    paint.color = remaining < 0.25
        ? Color.lerp(to, from, remaining / 0.25)!
        : from;
    canvas.drawArc(arcRect, -1.5708, 6.2832 * remaining, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.track != track ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}
