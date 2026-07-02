import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tokens.dart';

/// Ícone (Lucide) por classe de jogador.
IconData classIcon(String classType) {
  switch (classType) {
    case 'CONQUISTADOR':
      return LucideIcons.swords;
    case 'PESQUISADOR':
      return LucideIcons.flaskConical;
    case 'MENTOR':
      return LucideIcons.graduationCap;
    case 'EXPLORADOR':
      return LucideIcons.compass;
    case 'GUARDIAO':
      return LucideIcons.shield;
    case 'RECRUTADOR':
      return LucideIcons.userPlus;
    default:
      return LucideIcons.star;
  }
}

/// Ícones (Lucide) para personalização de zona (chave -> IconData).
const Map<String, IconData> kZoneIcons = {
  'hexagon': LucideIcons.hexagon,
  'flag': LucideIcons.flag,
  'star': LucideIcons.star,
  'bolt': LucideIcons.zap,
  'shield': LucideIcons.shield,
  'crown': LucideIcons.crown,
  'rocket': LucideIcons.rocket,
  'leaf': LucideIcons.leaf,
  'castle': LucideIcons.castle,
  'anchor': LucideIcons.anchor,
};

IconData zoneIcon(String? key) => kZoneIcons[key] ?? LucideIcons.flag;

/// Ícone (Lucide) por área de conhecimento.
IconData areaIcon(String area) {
  switch (area) {
    case 'MATEMATICA':
      return LucideIcons.calculator;
    case 'LOGICA':
      return LucideIcons.puzzle;
    case 'MEMORIA':
      return LucideIcons.brain;
    case 'BIOLOGIA':
      return LucideIcons.leaf;
    case 'HISTORIA':
      return LucideIcons.landmark;
    case 'PORTUGUES':
      return LucideIcons.bookOpen;
    case 'GEOGRAFIA':
      return LucideIcons.globe;
    case 'CIENCIAS':
      return LucideIcons.flaskConical;
    case 'ESTRATEGIA':
      return LucideIcons.swords;
    case 'OBSERVACAO':
      return LucideIcons.eye;
    default:
      return LucideIcons.sparkles;
  }
}

/// Cor de acento fixa por área de conhecimento (para chips/cards do setup).
Color areaColor(String area) {
  switch (area) {
    case 'MATEMATICA':
      return BrandColors.blue;
    case 'LOGICA':
      return BrandColors.purple;
    case 'MEMORIA':
      return BrandColors.orange;
    case 'BIOLOGIA':
      return BrandColors.greenBright;
    case 'HISTORIA':
      return BrandColors.brown;
    case 'PORTUGUES':
      return BrandColors.red;
    case 'GEOGRAFIA':
      return BrandColors.green;
    case 'CIENCIAS':
      return BrandColors.blue;
    case 'ESTRATEGIA':
      return BrandColors.ink;
    case 'OBSERVACAO':
      return BrandColors.purple;
    default:
      return BrandColors.orange;
  }
}
