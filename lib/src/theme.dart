/// Shim de compatibilidade — o design system agora vive em `design/`.
/// Este arquivo re-exporta tudo e mantém os nomes antigos apontando para os
/// novos tokens, para as telas existentes compilarem sem edição.
///
/// Código novo deve usar `context.zon` + componentes de `design/design.dart`.
library;

import 'package:flutter/material.dart';

import 'design/design.dart';

export 'design/design.dart';

/// Paleta legada. Novos usos: prefira `context.zon` (dark-ready).
class AppColors {
  // texto / tinta
  static const ink = BrandColors.ink;
  static const muted = BrandColors.inkMuted;

  // superfícies neutras (aquecidas no redesign)
  static const bg = BrandColors.bgWarm;
  static const surface = BrandColors.white;
  static const line = BrandColors.outlineWarm;
  static const paper = surface;
  static const paperDark = BrandColors.surfaceAltWarm;

  // cores de marca / ação
  static const orange = BrandColors.orange;
  static const red = BrandColors.red;
  static const blue = BrandColors.blue;
  static const brown = BrandColors.brown;
  static const green = BrandColors.green;
  static const white = BrandColors.white;

  /// Sombra suave padrão dos cartões.
  static const softShadow = Shadows.soft;

  /// Cor associada a cada classe.
  static const classColors = kClassColors;

  /// Paleta para personalização de zona (chave -> cor).
  static const zonePalette = kZonePalette;

  static Color zoneColor(String? key) => zoneColorOf(key);
}

/// Raios legados (aumentados no redesign).
class AppRadius {
  static const card = Corners.lg;
  static const button = Corners.md;
  static const field = Corners.md;
}

/// Cartão legado — hoje é o GamePanel (mesma API: child/color/padding/onTap).
typedef ComicPanel = GamePanel;
typedef AppCard = GamePanel;

/// Etiqueta legada — hoje é o GameChip sólido.
class ComicTag extends StatelessWidget {
  const ComicTag(
      {super.key, required this.label, this.color = AppColors.orange});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GameChip(label: label, color: color);
  }
}

typedef AppChip = ComicTag;
