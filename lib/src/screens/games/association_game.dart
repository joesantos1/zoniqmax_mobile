import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// Associação visual: duas colunas (esquerda/direita). O jogador toca num item
/// da esquerda e depois num da direita para ligá-los; as linhas são desenhadas
/// e animadas. Escreve o mapeamento {leftId: rightId} em [answer].
class AssociationGame extends StatefulWidget {
  const AssociationGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;

  @override
  State<AssociationGame> createState() => _AssociationGameState();
}

class _AssociationGameState extends State<AssociationGame>
    with SingleTickerProviderStateMixin {
  static const double _minRowH = 56;
  static const double _maxRowH = 104;
  static const double _gap = 14;
  static const double _connectorZone = 48;

  late List<Map<String, dynamic>> _left;
  late List<Map<String, dynamic>> _right;
  final Map<String, String> _connections = {}; // leftId -> rightId
  String? _selectedLeft;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..value = 1;

  // paleta para diferenciar ligações
  static const _palette = [
    AppColors.red,
    AppColors.blue,
    AppColors.brown,
    Color(0xFF2E9E5B),
    Color(0xFF8E44AD),
    AppColors.orange,
  ];

  @override
  void initState() {
    super.initState();
    _left = _parse('left');
    _right = _parse('right');
    widget.answer.value = <String, String>{};
  }

  List<Map<String, dynamic>> _parse(String key) {
    final raw = (widget.challenge.data[key] as List?) ?? const [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _tapLeft(String id) {
    if (widget.locked) return;
    setState(() => _selectedLeft = (_selectedLeft == id) ? null : id);
  }

  void _tapRight(String rightId) {
    if (widget.locked || _selectedLeft == null) return;
    setState(() {
      // mantém o lado direito único: remove ligação que já aponte para ele
      _connections.removeWhere((l, r) => r == rightId);
      _connections[_selectedLeft!] = rightId;
      _selectedLeft = null;
      widget.answer.value = Map<String, String>.from(_connections);
    });
    _anim.forward(from: 0);
  }

  int _indexOf(List<Map<String, dynamic>> list, String id) =>
      list.indexWhere((e) => e['id'] == id);

  Color _connColor(String leftId) {
    final i = _connections.keys.toList().indexOf(leftId);
    return _palette[i % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.challenge.prompt;
    final n = _left.length > _right.length ? _left.length : _right.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prompt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              prompt,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final colW = (w - _connectorZone) / 2;

              // distribui a altura disponível entre as linhas (cresce se sobra
              // espaço; encolhe até o mínimo; rola se ainda assim não couber).
              final maxH = constraints.maxHeight;
              final available =
                  (maxH.isFinite ? maxH : _maxRowH * n + _gap * (n - 1));
              final ideal = n > 0 ? (available - (n - 1) * _gap) / n : _minRowH;
              final rowH = ideal.clamp(_minRowH, _maxRowH).toDouble();
              final totalH = n * rowH + (n - 1) * _gap;
              final fontSize = (rowH * 0.26).clamp(15.0, 24.0).toDouble();

              final content = SizedBox(
                width: w,
                height: totalH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, _) => CustomPaint(
                          painter: _LinesPainter(
                            connections: _connections,
                            leftIndex: (id) => _indexOf(_left, id),
                            rightIndex: (id) => _indexOf(_right, id),
                            colorOf: _connColor,
                            rowH: rowH,
                            gap: _gap,
                            colW: colW,
                            width: w,
                            progress: _anim.value,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      width: colW,
                      child: Column(
                        children: [
                          for (final item in _left)
                            _itemTile(
                              label: item['label'] as String,
                              rowH: rowH,
                              fontSize: fontSize,
                              selected: _selectedLeft == item['id'],
                              connected: _connections.containsKey(item['id']),
                              color: _connections.containsKey(item['id'])
                                  ? _connColor(item['id'] as String)
                                  : null,
                              onTap: () => _tapLeft(item['id'] as String),
                              dotRight: true,
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      width: colW,
                      child: Column(
                        children: [
                          for (final item in _right)
                            _itemTile(
                              label: item['label'] as String,
                              rowH: rowH,
                              fontSize: fontSize,
                              selected: false,
                              connected:
                                  _connections.containsValue(item['id']),
                              color: _connections.containsValue(item['id'])
                                  ? _connColorByRight(item['id'] as String)
                                  : null,
                              onTap: () => _tapRight(item['id'] as String),
                              dotRight: false,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              // cabe na altura → centraliza; senão → rola
              return totalH <= available
                  ? Center(child: content)
                  : SingleChildScrollView(child: content);
            },
          ),
        ),
      ],
    );
  }

  Color? _connColorByRight(String rightId) {
    final entry = _connections.entries
        .firstWhere((e) => e.value == rightId, orElse: () => const MapEntry('', ''));
    if (entry.key.isEmpty) return null;
    return _connColor(entry.key);
  }

  Widget _itemTile({
    required String label,
    required double rowH,
    required double fontSize,
    required bool selected,
    required bool connected,
    required Color? color,
    required VoidCallback onTap,
    required bool dotRight,
  }) {
    final dot = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? (color ?? AppColors.ink) : AppColors.white,
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
    );
    return Container(
      height: rowH,
      margin: const EdgeInsets.only(bottom: _gap),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.orange : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: Row(
            children: [
              if (!dotRight) dot,
              if (!dotRight) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  textAlign: dotRight ? TextAlign.start : TextAlign.end,
                  softWrap: true, // quebra em várias linhas quando há espaço
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize,
                      height: 1.15),
                ),
              ),
              if (dotRight) const SizedBox(width: 8),
              if (dotRight) dot,
            ],
          ),
        ),
      ),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({
    required this.connections,
    required this.leftIndex,
    required this.rightIndex,
    required this.colorOf,
    required this.rowH,
    required this.gap,
    required this.colW,
    required this.width,
    required this.progress,
  });

  final Map<String, String> connections;
  final int Function(String) leftIndex;
  final int Function(String) rightIndex;
  final Color Function(String) colorOf;
  final double rowH, gap, colW, width, progress;

  double _centerY(int index) => index * (rowH + gap) + rowH / 2;

  @override
  void paint(Canvas canvas, Size size) {
    connections.forEach((leftId, rightId) {
      final li = leftIndex(leftId);
      final ri = rightIndex(rightId);
      if (li < 0 || ri < 0) return;
      final start = Offset(colW, _centerY(li));
      final end = Offset(width - colW, _centerY(ri));
      final animatedEnd = Offset.lerp(start, end, progress)!;
      final paint = Paint()
        ..color = colorOf(leftId)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, animatedEnd, paint);
    });
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) =>
      old.progress != progress || old.connections.length != connections.length;
}
