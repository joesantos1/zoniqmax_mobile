import 'package:flutter/material.dart';

/// Paleta e tema do ZonIQmax — estilo HQ / comic art.
/// Cores-base: laranja, preto, marrom, vermelho, azul, branco.
class AppColors {
  // tinta / contornos
  static const ink = Color(0xFF14110F); // preto (outlines, texto)
  static const paper = Color(0xFFFAF1DF); // branco "papel de HQ"
  static const paperDark = Color(0xFFEFE2C4);

  // cores de ação
  static const orange = Color(0xFFF2851B); // primária
  static const red = Color(0xFFE53228); // vermelho (Conquistador / perigo)
  static const blue = Color(0xFF2D6CDF); // azul (Pesquisador / info)
  static const brown = Color(0xFF6E4329); // marrom (território / terra)
  static const white = Color(0xFFFFFFFF);

  /// Cor associada a cada classe (para chips e rankings).
  static const classColors = <String, Color>{
    'CONQUISTADOR': red,
    'PESQUISADOR': blue,
    'MENTOR': orange,
    'EXPLORADOR': Color(0xFF2E9E5B), // verde de apoio
    'GUARDIAO': brown,
    'RECRUTADOR': Color(0xFF8E44AD), // roxo de apoio
  };
}

/// Tema global no estilo HQ: papel creme, tinta preta, alto contraste.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.orange,
      secondary: AppColors.blue,
      error: AppColors.red,
      surface: AppColors.paper,
      brightness: Brightness.light,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: AppColors.paper,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.ink, width: 2.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.orange, width: 3),
      ),
    ),
  );
}

/// Painel estilo HQ: fundo claro, contorno preto grosso e sombra "dura" (sem blur).
class ComicPanel extends StatelessWidget {
  const ComicPanel({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4), blurRadius: 0),
        ],
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return GestureDetector(onTap: onTap, child: panel);
  }
}

/// Selo/etiqueta colorida com contorno (chip de classe, badge, etc.).
class ComicTag extends StatelessWidget {
  const ComicTag({super.key, required this.label, this.color = AppColors.orange});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
