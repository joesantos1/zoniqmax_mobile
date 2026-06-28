import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Paleta e tema do ZonIQmax — visual limpo, fundo neutro, cartões com sombra suave.
/// Mantém a paleta de marca (laranja, vermelho, azul, marrom, verde) nos acentos.
class AppColors {
  // texto / tinta
  static const ink = Color(0xFF1B1A18); // texto primário
  static const muted = Color(0xFF6B6F76); // texto secundário

  // superfícies neutras
  static const bg = Color(0xFFF4F5F7); // fundo do app
  static const surface = Color(0xFFFFFFFF); // cartões
  static const line = Color(0xFFE7E8EC); // hairline / divisores
  static const paper = surface; // compat: usado como fundo claro de cartões
  static const paperDark = Color(0xFFEDEFF2); // trilho de progresso, fundo sutil

  // cores de marca / ação
  static const orange = Color(0xFFF2851B); // primária
  static const red = Color(0xFFE53228); // Conquistador / perigo
  static const blue = Color(0xFF2D6CDF); // Pesquisador / info
  static const brown = Color(0xFF6E4329); // território / Guardião
  static const green = Color(0xFF1E7A3D); // sucesso / acerto
  static const white = Color(0xFFFFFFFF);

  /// Sombra suave padrão dos cartões.
  static const softShadow = BoxShadow(
    color: Color(0x14000000), // ~8% preto
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  /// Cor associada a cada classe.
  static const classColors = <String, Color>{
    'CONQUISTADOR': red,
    'PESQUISADOR': blue,
    'MENTOR': orange,
    'EXPLORADOR': Color(0xFF2E9E5B),
    'GUARDIAO': brown,
    'RECRUTADOR': Color(0xFF8E44AD),
  };

  /// Paleta para personalização de zona (chave -> cor).
  static const zonePalette = <String, Color>{
    'red': red,
    'orange': orange,
    'blue': blue,
    'green': green,
    'brown': brown,
    'purple': Color(0xFF8E44AD),
    'ink': ink,
  };

  static Color zoneColor(String? key) => zonePalette[key] ?? red;
}

/// Raios e durações padrão.
class AppRadius {
  static const card = 16.0;
  static const button = 12.0;
  static const field = 12.0;
}

class AppDurations {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 240);
}

/// Ícone (Lucide) por classe.
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

/// Rota com transição leve (fade + leve slide) para navegação empurrada.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppDurations.fast,
    reverseTransitionDuration: AppDurations.fast,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Tema global: superfícies neutras, cartões claros, acentos da paleta.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.orange,
      onPrimary: AppColors.white,
      secondary: AppColors.blue,
      error: AppColors.red,
      surface: AppColors.surface,
      brightness: Brightness.light,
    ),
  );

  final text = base.textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.ink,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        elevation: 0,
        textStyle: const TextStyle(
            fontWeight: FontWeight.w700, letterSpacing: 0.3, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle:
            const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.orange),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.muted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.orange.withValues(alpha: 0.16),
      elevation: 0,
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
            color: selected ? AppColors.orange : AppColors.muted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.orange : AppColors.muted,
        );
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Cartão limpo: superfície clara, cantos arredondados, sombra suave, sem borda
/// preta. Mantém a API antiga (child/color/padding/onTap) para compatibilidade.
class ComicPanel extends StatelessWidget {
  const ComicPanel({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: const [AppColors.softShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Chip/etiqueta colorida e limpa (sem borda grossa).
class ComicTag extends StatelessWidget {
  const ComicTag({super.key, required this.label, this.color = AppColors.orange});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Aliases para nomenclatura nova (uso opcional em código futuro).
typedef AppCard = ComicPanel;
typedef AppChip = ComicTag;
