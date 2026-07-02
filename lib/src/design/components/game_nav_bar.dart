import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../tokens.dart';
import '../typography.dart';

class GameNavItem {
  const GameNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Barra de navegação inferior do jogo: superfície flutuante com cantos
/// superiores arredondados, item ativo em pill tonal com pop de escala.
class GameNavBar extends StatelessWidget {
  const GameNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GameNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Container(
      decoration: BoxDecoration(
        color: zon.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(Corners.xl)),
        boxShadow: const [Shadows.lifted],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () {
                      if (i != selectedIndex) {
                        GameHaptics.tap();
                        onSelected(i);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GameNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final color = selected ? zon.brand : zon.onSurfaceMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              curve: AppCurves.out,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? zon.brand.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Corners.pill),
              ),
              child: AnimatedScale(
                scale: selected ? 1.15 : 1.0,
                duration: AppDurations.fast,
                curve: AppCurves.pop,
                child: Icon(item.icon, size: 23, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
