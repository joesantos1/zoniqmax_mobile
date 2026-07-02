import 'package:flutter/material.dart';

/// Cores cruas da marca — fonte única dos valores hex.
/// Telas NÃO devem usar isto diretamente: use `context.zon` (tokens
/// semânticos) ou componentes. Isto existe para montar os temas.
abstract final class BrandColors {
  static const orange = Color(0xFFF2851B);
  static const orangeEdge = Color(0xFFC96A0E);
  static const ink = Color(0xFF1B1A18);
  static const inkMuted = Color(0xFF6B6F76);
  static const brown = Color(0xFF6E4329);
  static const brownEdge = Color(0xFF4E2E1B);
  static const white = Color(0xFFFFFFFF);
  static const red = Color(0xFFE53228);
  static const redEdge = Color(0xFFB0201A);
  static const blue = Color(0xFF2D6CDF);
  static const blueEdge = Color(0xFF1F4FA8);
  static const green = Color(0xFF1E7A3D);
  static const greenBright = Color(0xFF2E9E5B);
  static const purple = Color(0xFF8E44AD);

  // Neutros quentes (light) — casam com os tiles Voyager do mapa.
  static const bgWarm = Color(0xFFF7F3EC);
  static const surfaceAltWarm = Color(0xFFEFEAE2);
  static const outlineWarm = Color(0xFFE7E3DA);
  static const neutralEdge = Color(0xFFD8D3C8);
}

/// Tokens semânticos de cor. Dark mode futuro = criar `ZonColors.dark`
/// e passar para `buildAppTheme(colors: ...)` — nenhuma tela precisa mudar.
@immutable
class ZonColors extends ThemeExtension<ZonColors> {
  const ZonColors({
    required this.brand,
    required this.brandEdge,
    required this.onBrand,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.success,
    required this.successEdge,
    required this.danger,
    required this.dangerEdge,
    required this.info,
    required this.infoEdge,
    required this.warning,
    required this.xp,
    required this.territory,
    required this.territoryEdge,
    required this.streakA,
    required this.streakB,
    required this.inkEdge,
    required this.neutralEdge,
  });

  final Color brand;
  final Color brandEdge;
  final Color onBrand; // texto/ícone sobre superfícies de acento preenchidas
  final Color bg;
  final Color surface;
  final Color surfaceAlt; // trilhas de progresso, fundos sutis
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color outline;
  final Color success;
  final Color successEdge;
  final Color danger;
  final Color dangerEdge;
  final Color info;
  final Color infoEdge;
  final Color warning; // avisos amigáveis (anti-chute): tom da marca, não vermelho
  final Color xp;
  final Color territory;
  final Color territoryEdge;
  final Color streakA; // gradiente da chama de streak
  final Color streakB;
  final Color inkEdge; // edge 3D de botões ink
  final Color neutralEdge; // edge 3D de botões/cards brancos

  static const light = ZonColors(
    brand: BrandColors.orange,
    brandEdge: BrandColors.orangeEdge,
    onBrand: BrandColors.white,
    bg: BrandColors.bgWarm,
    surface: BrandColors.white,
    surfaceAlt: BrandColors.surfaceAltWarm,
    onSurface: BrandColors.ink,
    onSurfaceMuted: BrandColors.inkMuted,
    outline: BrandColors.outlineWarm,
    success: BrandColors.greenBright,
    successEdge: BrandColors.green,
    danger: BrandColors.red,
    dangerEdge: BrandColors.redEdge,
    info: BrandColors.blue,
    infoEdge: BrandColors.blueEdge,
    warning: BrandColors.orange,
    xp: BrandColors.orange,
    territory: BrandColors.brown,
    territoryEdge: BrandColors.brownEdge,
    streakA: BrandColors.orange,
    streakB: BrandColors.red,
    inkEdge: Color(0xFF000000),
    neutralEdge: BrandColors.neutralEdge,
  );

  @override
  ZonColors copyWith({
    Color? brand,
    Color? brandEdge,
    Color? onBrand,
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? outline,
    Color? success,
    Color? successEdge,
    Color? danger,
    Color? dangerEdge,
    Color? info,
    Color? infoEdge,
    Color? warning,
    Color? xp,
    Color? territory,
    Color? territoryEdge,
    Color? streakA,
    Color? streakB,
    Color? inkEdge,
    Color? neutralEdge,
  }) {
    return ZonColors(
      brand: brand ?? this.brand,
      brandEdge: brandEdge ?? this.brandEdge,
      onBrand: onBrand ?? this.onBrand,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      successEdge: successEdge ?? this.successEdge,
      danger: danger ?? this.danger,
      dangerEdge: dangerEdge ?? this.dangerEdge,
      info: info ?? this.info,
      infoEdge: infoEdge ?? this.infoEdge,
      warning: warning ?? this.warning,
      xp: xp ?? this.xp,
      territory: territory ?? this.territory,
      territoryEdge: territoryEdge ?? this.territoryEdge,
      streakA: streakA ?? this.streakA,
      streakB: streakB ?? this.streakB,
      inkEdge: inkEdge ?? this.inkEdge,
      neutralEdge: neutralEdge ?? this.neutralEdge,
    );
  }

  @override
  ZonColors lerp(ZonColors? other, double t) {
    if (other is! ZonColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ZonColors(
      brand: l(brand, other.brand),
      brandEdge: l(brandEdge, other.brandEdge),
      onBrand: l(onBrand, other.onBrand),
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceMuted: l(onSurfaceMuted, other.onSurfaceMuted),
      outline: l(outline, other.outline),
      success: l(success, other.success),
      successEdge: l(successEdge, other.successEdge),
      danger: l(danger, other.danger),
      dangerEdge: l(dangerEdge, other.dangerEdge),
      info: l(info, other.info),
      infoEdge: l(infoEdge, other.infoEdge),
      warning: l(warning, other.warning),
      xp: l(xp, other.xp),
      territory: l(territory, other.territory),
      territoryEdge: l(territoryEdge, other.territoryEdge),
      streakA: l(streakA, other.streakA),
      streakB: l(streakB, other.streakB),
      inkEdge: l(inkEdge, other.inkEdge),
      neutralEdge: l(neutralEdge, other.neutralEdge),
    );
  }
}

/// Atalho: `context.zon.brand` em vez de `Theme.of(context).extension<...>`.
extension ZonContext on BuildContext {
  ZonColors get zon => Theme.of(this).extension<ZonColors>() ?? ZonColors.light;
}

/// Cor associada a cada classe de jogador (fixa da marca, igual nos 2 temas).
const kClassColors = <String, Color>{
  'CONQUISTADOR': BrandColors.red,
  'PESQUISADOR': BrandColors.blue,
  'MENTOR': BrandColors.orange,
  'EXPLORADOR': BrandColors.greenBright,
  'GUARDIAO': BrandColors.brown,
  'RECRUTADOR': BrandColors.purple,
};

/// Paleta para personalização de zona (chave -> cor).
const kZonePalette = <String, Color>{
  'red': BrandColors.red,
  'orange': BrandColors.orange,
  'blue': BrandColors.blue,
  'green': BrandColors.green,
  'brown': BrandColors.brown,
  'purple': BrandColors.purple,
  'ink': BrandColors.ink,
};

Color zoneColorOf(String? key) => kZonePalette[key] ?? BrandColors.red;

/// Escala de espaçamento.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const huge = 32.0;
}

/// Escala de raios de canto (jogo = cantos generosos).
abstract final class Corners {
  static const sm = 12.0;
  static const md = 16.0; // botões, campos, chips quadrados
  static const lg = 20.0; // cartões
  static const xl = 24.0; // sheets, painéis hero
  static const pill = 999.0;
}

/// Sombras padrão.
abstract final class Shadows {
  static const soft = BoxShadow(
    color: Color(0x14000000), // ~8% preto
    blurRadius: 16,
    offset: Offset(0, 6),
  );
  static const lifted = BoxShadow(
    color: Color(0x1F000000), // ~12% preto
    blurRadius: 24,
    offset: Offset(0, 10),
  );
}

/// Durações e curvas de animação.
class AppDurations {
  static const press = Duration(milliseconds: 90); // press-down de botões
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 400);
  static const celebrate = Duration(milliseconds: 1200);
}

abstract final class AppCurves {
  static const out = Curves.easeOutCubic;
  static const pop = Curves.easeOutBack; // entradas celebratórias
}
