import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// Ordenação rápida: o jogador arrasta os itens para a ordem correta.
/// Escreve a ordem atual (lista de ids) em [answer].
class OrderingGame extends StatefulWidget {
  const OrderingGame({
    super.key,
    required this.challenge,
    required this.answer,
    required this.locked,
  });

  final Challenge challenge;
  final ValueNotifier<Object?> answer;
  final bool locked;

  @override
  State<OrderingGame> createState() => _OrderingGameState();
}

class _OrderingGameState extends State<OrderingGame> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    final raw = (widget.challenge.data['items'] as List?) ?? const [];
    _items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _publish();
  }

  void _publish() {
    widget.answer.value = _items.map((e) => e['id'] as String).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _publish();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: !widget.locked,
      // ignore: deprecated_member_use
      onReorder: widget.locked ? (_, __) {} : _onReorder,
      children: [
        for (int i = 0; i < _items.length; i++)
          Padding(
            key: ValueKey(_items[i]['id']),
            padding: const EdgeInsets.only(bottom: 10),
            child: ComicPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.brown,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _items[i]['label'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (!widget.locked)
                    const Icon(Icons.drag_handle, color: AppColors.ink),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
