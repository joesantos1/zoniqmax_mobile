import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  void _onReorderItem(int oldIndex, int newIndex) {
    if (widget.locked) return;
    GameHaptics.tap();
    // onReorderItem já entrega o newIndex ajustado (sem o "-1" manual)
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _publish();
    });
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // desliga os handles padrão (que usam long-press com atraso)
      buildDefaultDragHandles: false,
      onReorderItem: _onReorderItem,
      // item em arraste: cresce levemente e ganha sombra elevada
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeOut.transform(animation.value);
          return Transform.scale(
            scale: 1 + 0.03 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Corners.lg),
                boxShadow: const [Shadows.lifted],
              ),
              child: child,
            ),
          );
        },
      ),
      children: [
        for (int i = 0; i < _items.length; i++)
          // arraste imediato (sem espera) a partir de qualquer ponto do item
          ReorderableDragStartListener(
            key: ValueKey(_items[i]['id']),
            index: i,
            enabled: !widget.locked,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GamePanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: zon.territory.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: AppText.label
                            .copyWith(color: zon.territory, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _items[i]['label'] as String,
                        style: AppText.bodyStrong.copyWith(fontSize: 16),
                      ),
                    ),
                    if (!widget.locked)
                      Icon(LucideIcons.gripVertical,
                          color: zon.onSurfaceMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
