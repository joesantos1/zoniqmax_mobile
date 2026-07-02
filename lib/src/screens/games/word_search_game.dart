import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// Caça-palavras: arraste o dedo pela grade em linha reta (horizontal,
/// vertical ou diagonal) para marcar as palavras escondidas. Escreve em
/// [answer] a lista de palavras encontradas (ordenada) e chama [onComplete]
/// quando todas forem achadas (auto-submit). A grade vem pronta do conteúdo.
class WordSearchGame extends StatefulWidget {
  const WordSearchGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
    required this.onComplete,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;
  final VoidCallback onComplete;

  @override
  State<WordSearchGame> createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<WordSearchGame> {
  late final List<String> _rows;
  late final List<String> _palavras;
  int get _cols => _rows.isEmpty ? 0 : _rows[0].length;

  /// palavra encontrada -> células que a formam (para o highlight persistente)
  final Map<String, List<math.Point<int>>> _found = {};

  /// cores estáveis por palavra encontrada (cicla a paleta da marca)
  static const _palette = [
    BrandColors.orange,
    BrandColors.greenBright,
    BrandColors.blue,
    BrandColors.purple,
    BrandColors.brown,
    BrandColors.red,
  ];

  // seleção em andamento (durante o pan)
  math.Point<int>? _selStart;
  List<math.Point<int>> _selCells = const [];
  bool _flashWrong = false; // flash breve na seleção errada (one-shot)

  @override
  void initState() {
    super.initState();
    _rows = ((widget.challenge.data['grade'] as List?) ?? const [])
        .map((e) => e.toString().toUpperCase())
        .toList();
    _palavras = ((widget.challenge.data['palavras'] as List?) ?? const [])
        .map((e) => e.toString().toUpperCase())
        .toList();
    widget.answer.value = <String>[];
  }

  Color _colorOf(String word) =>
      _palette[_found.keys.toList().indexOf(word) % _palette.length];

  // ---- gesto ----

  math.Point<int>? _cellAt(Offset local, double cell) {
    final c = (local.dx / cell).floor();
    final r = (local.dy / cell).floor();
    if (r < 0 || r >= _rows.length || c < 0 || c >= _cols) return null;
    return math.Point<int>(c, r);
  }

  /// Trava a seleção numa das 8 direções a partir da célula inicial.
  List<math.Point<int>> _lineBetween(math.Point<int> a, math.Point<int> b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    int stepX;
    int stepY;
    int len;
    if (dy.abs() >= 2 * dx.abs()) {
      // vertical dominante
      stepX = 0;
      stepY = dy.sign;
      len = dy.abs();
    } else if (dx.abs() >= 2 * dy.abs()) {
      // horizontal dominante
      stepX = dx.sign;
      stepY = 0;
      len = dx.abs();
    } else {
      // diagonal
      stepX = dx.sign;
      stepY = dy.sign;
      len = math.max(dx.abs(), dy.abs());
    }
    if (stepX == 0 && stepY == 0) return [a];
    final cells = <math.Point<int>>[];
    for (var k = 0; k <= len; k++) {
      final x = a.x + stepX * k;
      final y = a.y + stepY * k;
      if (x < 0 || x >= _cols || y < 0 || y >= _rows.length) break;
      cells.add(math.Point<int>(x, y));
    }
    return cells;
  }

  void _panStart(Offset local, double cell) {
    if (widget.locked) return;
    final p = _cellAt(local, cell);
    if (p == null) return;
    setState(() {
      _selStart = p;
      _selCells = [p];
      _flashWrong = false;
    });
  }

  void _panUpdate(Offset local, double cell) {
    if (widget.locked || _selStart == null) return;
    final p = _cellAt(local, cell);
    if (p == null) return;
    final line = _lineBetween(_selStart!, p);
    if (line.length != _selCells.length ||
        (line.isNotEmpty && line.last != _selCells.last)) {
      setState(() => _selCells = line);
    }
  }

  void _panEnd() {
    if (widget.locked || _selStart == null) return;
    final cells = _selCells;
    _selStart = null;
    if (cells.length < 2) {
      setState(() => _selCells = const []);
      return;
    }
    final word = cells.map((p) => _rows[p.y][p.x]).join();
    final reversed = word.split('').reversed.join();

    String? hit;
    List<math.Point<int>> hitCells = cells;
    if (_palavras.contains(word) && !_found.containsKey(word)) {
      hit = word;
    } else if (_palavras.contains(reversed) &&
        !_found.containsKey(reversed)) {
      hit = reversed;
      hitCells = cells.reversed.toList();
    }

    if (hit != null) {
      GameHaptics.correct();
      setState(() {
        _found[hit!] = hitCells;
        _selCells = const [];
        widget.answer.value = _found.keys.toList()..sort();
      });
      if (_found.length == _palavras.length) {
        GameHaptics.celebrate();
        widget.onComplete();
      }
    } else {
      GameHaptics.wrong();
      setState(() => _flashWrong = true);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _selCells = const [];
          _flashWrong = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    if (_rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _cols / _rows.length,
              child: LayoutBuilder(
                builder: (context, c) {
                  final cell = c.maxWidth / _cols;
                  return GestureDetector(
                    onPanStart: (d) => _panStart(d.localPosition, cell),
                    onPanUpdate: (d) => _panUpdate(d.localPosition, cell),
                    onPanEnd: (_) => _panEnd(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: zon.surface,
                        borderRadius: BorderRadius.circular(Corners.md),
                        border: Border.all(color: zon.outline, width: 2),
                        boxShadow: const [Shadows.soft],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Corners.md - 2),
                        child: Stack(
                          children: [
                            // highlights (palavras achadas + seleção atual)
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _HighlightPainter(
                                    cell: cell,
                                    found: _found,
                                    colorOf: _colorOf,
                                    selection: _selCells,
                                    selectionColor: _flashWrong
                                        ? zon.danger
                                        : zon.brand,
                                  ),
                                ),
                              ),
                            ),
                            // letras
                            IgnorePointer(
                              child: Column(
                                children: [
                                  for (var r = 0; r < _rows.length; r++)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          for (var cc = 0; cc < _cols; cc++)
                                            Expanded(
                                              child: Center(
                                                child: Text(
                                                  _rows[r][cc],
                                                  style: AppText.numeric
                                                      .copyWith(
                                                    fontSize: cell * 0.48,
                                                    color: zon.onSurface,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // lista de palavras (riscadas quando achadas)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final w in _palavras)
              _found.containsKey(w)
                  ? _FoundChip(word: w, color: _colorOf(w))
                  : GameChip(
                      label: w,
                      color: zon.onSurfaceMuted,
                      mode: GameChipMode.tonal,
                    ),
          ],
        ),
      ],
    );
  }
}

/// Chip de palavra encontrada: cor da palavra + texto riscado.
class _FoundChip extends StatelessWidget {
  const _FoundChip({required this.word, required this.color});

  final String word;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Corners.pill),
      ),
      child: Text(
        word,
        style: AppText.caption.copyWith(
          color: color,
          decoration: TextDecoration.lineThrough,
          decorationColor: color,
          decorationThickness: 2,
        ),
      ),
    );
  }
}

/// Desenha as cápsulas de highlight: linha grossa com pontas redondas sobre as
/// células de cada palavra achada (cor estável) e da seleção em andamento.
class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.cell,
    required this.found,
    required this.colorOf,
    required this.selection,
    required this.selectionColor,
  });

  final double cell;
  final Map<String, List<math.Point<int>>> found;
  final Color Function(String) colorOf;
  final List<math.Point<int>> selection;
  final Color selectionColor;

  Offset _center(math.Point<int> p) =>
      Offset((p.x + 0.5) * cell, (p.y + 0.5) * cell);

  void _capsule(Canvas canvas, List<math.Point<int>> cells, Color color) {
    if (cells.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = cell * 0.72
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (cells.length == 1) {
      canvas.drawLine(_center(cells.first),
          _center(cells.first).translate(0.1, 0), paint);
    } else {
      canvas.drawLine(_center(cells.first), _center(cells.last), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    found.forEach((word, cells) {
      _capsule(canvas, cells, colorOf(word).withValues(alpha: 0.35));
    });
    if (selection.isNotEmpty) {
      _capsule(canvas, selection, selectionColor.withValues(alpha: 0.30));
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.found.length != found.length ||
      old.selection != selection ||
      old.selectionColor != selectionColor ||
      old.cell != cell;
}
