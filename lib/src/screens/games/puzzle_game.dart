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
    setState(() {
      _placement.removeWhere((_, pid) => pid == pieceId);
      _placement[slotId] = pieceId;
      _publish();
    });
  }

  void _clearSlot(String slotId) {
    if (widget.locked) return;
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

  Widget _buildBoard() {
    // Os blocos fluem em linha (row) e quebram para a próxima linha ao atingir
    // a borda da tela — ocupando toda a largura disponível.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: [
              for (final cell in _board)
                cell.isSlot ? _slot(cell.slot!) : _fixedTile(cell.fixed ?? ''),
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
    late Color bg;
    late Color border;
    late Color fg;
    switch (kind) {
      case _TileKind.fixed:
        bg = AppColors.surface;
        border = AppColors.line;
        fg = AppColors.ink;
        break;
      case _TileKind.piece:
        bg = AppColors.brown;
        border = AppColors.brown;
        fg = AppColors.white;
        break;
      case _TileKind.slotEmpty:
        bg = AppColors.paperDark;
        border = AppColors.line;
        fg = AppColors.muted;
        break;
      case _TileKind.slotHover:
        bg = AppColors.orange.withValues(alpha: 0.18);
        border = AppColors.orange;
        fg = AppColors.orange;
        break;
    }

    final isLong = label.length > _wrapThreshold;
    final fontSize = isLong ? 11.0 : 22.0; // 50% menor quando o texto é longo

    Widget tile = Container(
      constraints: const BoxConstraints(
        minWidth: _minSize,
        minHeight: _minSize,
        maxWidth: _maxWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
        boxShadow: kind == _TileKind.piece
            ? const [
                BoxShadow(
                    color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3)),
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
