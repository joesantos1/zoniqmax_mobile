import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// Quebra-cabeça de encaixe: um tabuleiro com células fixas e slots vazios + uma
/// bandeja de peças. O jogador arrasta cada peça para o slot certo (snap animado).
/// Escreve em [answer] o mapa { slotId: pieceId } das colocações atuais.
class PuzzleGame extends StatefulWidget {
  const PuzzleGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;

  @override
  State<PuzzleGame> createState() => _PuzzleGameState();
}

class _Cell {
  _Cell({this.fixed, this.slot});
  final String? fixed; // valor fixo (estático)
  final String? slot; // id do slot (vazio, alvo de arrasto)
  bool get isSlot => slot != null;
}

class _PuzzleGameState extends State<PuzzleGame> {
  late List<_Cell> _board;
  late Map<String, String> _pieceLabels; // pieceId -> label
  final Map<String, String> _placement = {}; // slotId -> pieceId

  @override
  void initState() {
    super.initState();
    final data = widget.challenge.data;
    _board = ((data['board'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => _Cell(
              fixed: m['fixed'] as String?,
              slot: m['slot'] as String?,
            ))
        .toList();
    final pieces = ((data['pieces'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map));
    _pieceLabels = {
      for (final p in pieces) p['id'] as String: p['label'].toString(),
    };
    _publish();
  }

  void _publish() {
    widget.answer.value = Map<String, String>.from(_placement);
  }

  Set<String> get _placedPieces => _placement.values.toSet();

  List<String> get _trayPieces =>
      _pieceLabels.keys.where((id) => !_placedPieces.contains(id)).toList();

  /// Coloca [pieceId] no [slotId], removendo-a de onde estiver.
  void _place(String slotId, String pieceId) {
    if (widget.locked) return;
    GameHaptics.correct();
    setState(() {
      _placement.removeWhere((_, pid) => pid == pieceId);
      _placement[slotId] = pieceId;
      _publish();
    });
  }

  void _clearSlot(String slotId) {
    if (widget.locked) return;
    GameHaptics.tap();
    setState(() {
      _placement.remove(slotId);
      _publish();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.challenge.prompt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Enunciado: ocupa no máximo ~3 linhas; se for maior, rola internamente.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 84),
          child: SingleChildScrollView(
            child: Text(
              prompt,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Center(child: _buildBoard()),
          ),
        ),
        const Divider(height: 24),
        const Text('Arraste as peças',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        _buildTray(),
      ],
    );
  }

  // Geometria da grade do tabuleiro (no máximo 3 por fileira).
  static const double _gapX = 22; // espaço horizontal (linha entre blocos)
  static const double _gapY = 34; // espaço vertical (faixa do fluxo na quebra)
  static const double _marginX = 16; // margem p/ o fluxo contornar na quebra
  static const double _rowH = 64; // altura do bloco

  Widget _buildBoard() {
    final n = _board.length;
    if (n == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = n < 3 ? n : 3; // no máximo 3 por fileira
        final rowsCount = (n + cols - 1) ~/ cols;
        final cellW = ((constraints.maxWidth -
                    2 * _marginX -
                    (cols - 1) * _gapX) /
                cols)
            .clamp(46.0, 132.0)
            .toDouble();
        final totalW = 2 * _marginX + cols * cellW + (cols - 1) * _gapX;
        final totalH = rowsCount * _rowH + (rowsCount - 1) * _gapY;

        double leftOf(int k) => _marginX + (k % cols) * (cellW + _gapX);
        double topOf(int k) => (k ~/ cols) * (_rowH + _gapY);

        return SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            children: [
              // linha de FLUXO ligando todos os blocos (atrás)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FlowPainter(
                    count: n,
                    cols: cols,
                    cellW: cellW,
                    rowH: _rowH,
                    gapX: _gapX,
                    gapY: _gapY,
                    marginX: _marginX,
                    totalW: totalW,
                    color: AppColors.brown,
                  ),
                ),
              ),
              // blocos posicionados na grade
              for (var k = 0; k < n; k++)
                Positioned(
                  left: leftOf(k),
                  top: topOf(k),
                  width: cellW,
                  height: _rowH,
                  child: _board[k].isSlot
                      ? _slot(_board[k].slot!)
                      : _fixedTile(_board[k].fixed ?? ''),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _fixedTile(String label) => _Tile(label: label, kind: _TileKind.fixed);

  Widget _slot(String slotId) {
    final pieceId = _placement[slotId];
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !widget.locked,
      onAcceptWithDetails: (d) => _place(slotId, d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        if (pieceId != null) {
          return GestureDetector(
            onTap: () => _clearSlot(slotId),
            child: _Tile(
              key: ValueKey('placed-$slotId-$pieceId'),
              label: _pieceLabels[pieceId] ?? '?',
              kind: _TileKind.piece,
              animateIn: true,
            ),
          );
        }
        return _Tile(
          label: '',
          kind: hovering ? _TileKind.slotHover : _TileKind.slotEmpty,
        );
      },
    );
  }

  Widget _buildTray() {
    final tray = _trayPieces;
    if (tray.isEmpty) {
      return const SizedBox(
        height: 56,
        child: Center(child: Text('Todas as peças encaixadas!')),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final id in tray)
          widget.locked
              ? _Tile(label: _pieceLabels[id] ?? '', kind: _TileKind.piece)
              : Draggable<String>(
                  data: id,
                  onDragStarted: GameHaptics.tap,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _Tile(
                      label: _pieceLabels[id] ?? '',
                      kind: _TileKind.piece,
                      scale: 1.1,
                    ),
                  ),
                  childWhenDragging: _Tile(
                    label: _pieceLabels[id] ?? '',
                    kind: _TileKind.slotEmpty,
                  ),
                  child: _Tile(label: _pieceLabels[id] ?? '', kind: _TileKind.piece),
                ),
      ],
    );
  }
}

/// Desenha a linha de "fluxo" que liga todos os blocos do tabuleiro: horizontal
/// dentro da fileira e, na quebra, contornando pela margem direita → faixa entre
/// as fileiras → margem esquerda, até o primeiro bloco da fileira de baixo.
class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.count,
    required this.cols,
    required this.cellW,
    required this.rowH,
    required this.gapX,
    required this.gapY,
    required this.marginX,
    required this.totalW,
    required this.color,
  });

  final int count, cols;
  final double cellW, rowH, gapX, gapY, marginX, totalW;
  final Color color;

  double _centerY(int k) => (k ~/ cols) * (rowH + gapY) + rowH / 2;
  double _leftX(int k) => marginX + (k % cols) * (cellW + gapX);
  double _rightX(int k) => _leftX(k) + cellW;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var k = 0; k < count - 1; k++) {
      final sameRow = (k ~/ cols) == ((k + 1) ~/ cols);
      if (sameRow) {
        // segmento horizontal no vão entre os dois blocos
        final y = _centerY(k);
        canvas.drawLine(
          Offset(_rightX(k), y), Offset(_leftX(k + 1), y), paint,
        );
      } else {
        // contorno em "fluxo": direita → desce na faixa → esquerda → sobe
        final yA = _centerY(k);
        final yB = _centerY(k + 1);
        final bandY = (k ~/ cols) * (rowH + gapY) + rowH + gapY / 2;
        final rightLine = totalW - marginX / 2;
        final leftLine = marginX / 2;
        final pts = <Offset>[
          Offset(_rightX(k), yA),
          Offset(rightLine, yA),
          Offset(rightLine, bandY),
          Offset(leftLine, bandY),
          Offset(leftLine, yB),
          Offset(_leftX(k + 1), yB),
        ];
        canvas.drawPath(_rounded(pts, 8), paint);
      }
    }
  }

  /// Polilinha ortogonal com cantos arredondados.
  Path _rounded(List<Offset> pts, double r) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final p = pts[i];
      final a = _towards(p, pts[i - 1], r);
      final b = _towards(p, pts[i + 1], r);
      path.lineTo(a.dx, a.dy);
      path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  Offset _towards(Offset from, Offset to, double r) {
    final dx = to.dx - from.dx, dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return from;
    final t = math.min(r / len, 0.5);
    return Offset(from.dx + dx * t, from.dy + dy * t);
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) =>
      old.count != count || old.cols != cols || old.cellW != cellW;
}

enum _TileKind { fixed, piece, slotEmpty, slotHover }

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.kind,
    this.animateIn = false,
    this.scale = 1.0,
  });

  final String label;
  final _TileKind kind;
  final bool animateIn;
  final double scale;

  /// Acima deste número de caracteres, o texto fica 50% menor e quebra em linhas.
  static const _wrapThreshold = 5;

  // ---- Dimensões dos blocos (ajuste a LARGURA aqui) ----
  static const double _minSize = 56; // lado mínimo (bloco quadrado de 1 caractere)
  static const double _maxWidth = 140; // largura máxima antes do texto quebrar

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    late Color bg;
    late Color border;
    late Color fg;
    switch (kind) {
      case _TileKind.fixed:
        bg = zon.surface;
        border = zon.territory;
        fg = zon.onSurface;
        break;
      case _TileKind.piece:
        bg = zon.territory;
        border = zon.territory;
        fg = zon.onBrand;
        break;
      case _TileKind.slotEmpty:
        bg = zon.surfaceAlt;
        border = zon.territory.withValues(alpha: 0.4);
        fg = zon.onSurfaceMuted;
        break;
      case _TileKind.slotHover:
        bg = zon.brand.withValues(alpha: 0.18);
        border = zon.brand;
        fg = zon.brand;
        break;
    }

    final isLong = label.length > _wrapThreshold;
    // fonte grande para rótulos curtos; menor (com quebra) para longos
    final fontSize = isLong ? 15.0 : 28.0;

    Widget tile = Container(
      constraints: const BoxConstraints(
        minWidth: _minSize,
        minHeight: _minSize,
        maxWidth: _maxWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 2),
        // peças com edge "chunky" (sombra dura), estilo botão do jogo
        boxShadow: kind == _TileKind.piece
            ? [
                BoxShadow(
                    color: zon.territoryEdge,
                    offset: const Offset(0, 3),
                    blurRadius: 0),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: label.isEmpty
          ? const SizedBox(width: 24, height: 24)
          : Text(
              label,
              textAlign: TextAlign.center,
              softWrap: true, // quebra o texto interno em várias linhas
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.1,
              ),
            ),
    );

    if (scale != 1.0) {
      tile = Transform.scale(scale: scale, child: tile);
    }

    if (animateIn) {
      // "snap" ao encaixar: escala com bounce
      return TweenAnimationBuilder<double>(
        key: key,
        tween: Tween(begin: 0.7, end: 1.0),
        duration: const Duration(milliseconds: 360),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: tile,
      );
    }
    return tile;
  }
}
