import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'challenge_screen.dart';

const _areaLabels = <String, String>{
  'MATEMATICA': 'Matemática',
  'LOGICA': 'Lógica',
  'MEMORIA': 'Memória',
  'BIOLOGIA': 'Biologia',
  'HISTORIA': 'História',
  'PORTUGUES': 'Português',
  'GEOGRAFIA': 'Geografia',
  'CIENCIAS': 'Ciências',
  'ESTRATEGIA': 'Estratégia',
  'OBSERVACAO': 'Observação',
};

String _areaLabel(String a) => _areaLabels[a] ?? a;

/// Tela de configuração que antecede os desafios: define nível, área e tema,
/// mostrando ao vivo quantos desafios estão disponíveis para os filtros.
class ChallengeSetupScreen extends StatefulWidget {
  const ChallengeSetupScreen({
    super.key,
    required this.api,
    this.territoryId,
    this.userLat,
    this.userLng,
  });

  final ApiClient api;
  final String? territoryId;
  final double? userLat;
  final double? userLng;

  @override
  State<ChallengeSetupScreen> createState() => _ChallengeSetupScreenState();
}

class _ChallengeSetupScreenState extends State<ChallengeSetupScreen> {
  late Future<List<ChallengeOption>> _future;
  List<ChallengeOption> _catalog = const [];

  final Set<String> _selAreas = {}; // vazio = todas
  final Set<String> _selThemes = {}; // vazio = todos
  int? _difficulty; // null = qualquer
  bool _includeSolved = false; // revisão: inclui já pontuados (½ tempo)

  @override
  void initState() {
    super.initState();
    // entrar na página de desafios reinicia o streak anti-chute
    widget.api.startChallengeSession();
    _future = _load();
  }

  Future<List<ChallengeOption>> _load() async {
    final cat = await widget.api.challengeCatalog();
    if (mounted) setState(() => _catalog = cat);
    return cat;
  }

  // ---- derivações do catálogo ----

  /// Quantos desafios um grupo oferece de acordo com o modo (revisão soma os
  /// já resolvidos; senão, só os novos).
  int _pool(ChallengeOption o) =>
      o.newCount + (_includeSolved ? o.solvedCount : 0);

  bool _areaSelected(String a) => _selAreas.isEmpty || _selAreas.contains(a);
  bool _themeSelected(String t) => _selThemes.isEmpty || _selThemes.contains(t);

  List<String> get _areas {
    final s = <String>{for (final o in _catalog) if (_pool(o) > 0) o.area};
    return s.toList()..sort((a, b) => _areaLabel(a).compareTo(_areaLabel(b)));
  }

  /// Temas das áreas selecionadas (ou de todas, se nenhuma área marcada).
  List<String> get _themes {
    final s = <String>{
      for (final o in _catalog)
        if (_pool(o) > 0 &&
            _areaSelected(o.area) &&
            o.theme != null &&
            o.theme!.isNotEmpty)
          o.theme!,
    };
    return s.toList()..sort();
  }

  List<int> get _difficulties {
    final s = <int>{
      for (final o in _catalog)
        if (_pool(o) > 0 &&
            _areaSelected(o.area) &&
            (o.theme == null ? _selThemes.isEmpty : _themeSelected(o.theme!)))
          o.difficulty,
    };
    return s.toList()..sort();
  }

  bool _matches(ChallengeOption o) =>
      _areaSelected(o.area) &&
      (_difficulty == null || o.difficulty == _difficulty) &&
      (_selThemes.isEmpty ||
          (o.theme != null && _selThemes.contains(o.theme)));

  int get _newTotal =>
      _catalog.where(_matches).fold(0, (a, o) => a + o.newCount);
  int get _revisionTotal =>
      _catalog.where(_matches).fold(0, (a, o) => a + o.solvedCount);
  int get _total => _newTotal + (_includeSolved ? _revisionTotal : 0);

  void _setIncludeSolved(bool v) {
    setState(() {
      _includeSolved = v;
      _reconcileSelection();
    });
  }

  void _toggleArea(String a) {
    setState(() {
      if (_selAreas.contains(a)) {
        _selAreas.remove(a);
      } else {
        _selAreas.add(a);
      }
      _reconcileSelection();
    });
  }

  void _toggleTheme(String t) {
    setState(() {
      if (_selThemes.contains(t)) {
        _selThemes.remove(t);
      } else {
        _selThemes.add(t);
      }
      _reconcileSelection();
    });
  }

  /// Garante que as seleções continuem válidas após mudar área/tema/modo.
  void _reconcileSelection() {
    final areas = _areas.toSet();
    _selAreas.removeWhere((a) => !areas.contains(a));
    final themes = _themes.toSet();
    _selThemes.removeWhere((t) => !themes.contains(t));
    if (_difficulty != null && !_difficulties.contains(_difficulty)) {
      _difficulty = null;
    }
  }

  void _start() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChallengeScreen(
        api: widget.api,
        territoryId: widget.territoryId,
        areas: _selAreas.isEmpty ? null : _selAreas.toList(),
        themes: _selThemes.isEmpty ? null : _selThemes.toList(),
        initialDifficulty: _difficulty,
        includeSolved: _includeSolved,
        userLat: widget.userLat,
        userLng: widget.userLng,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher desafios')),
      body: FutureBuilder<List<ChallengeOption>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: LucideIcons.cloudOff,
              title: 'Ops, algo deu errado',
              message: '${snap.error}',
              action: GameButton(
                label: 'TENTAR DE NOVO',
                icon: LucideIcons.refreshCw,
                onPressed: () => setState(() => _future = _load()),
              ),
            );
          }
          if (_catalog.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.trophy,
              title: 'Você zerou os desafios!',
              message:
                  'Já resolveu todos os disponíveis. Volte mais tarde para novos desafios.',
            );
          }
          return _content();
        },
      ),
    );
  }

  /// Pool total de uma área com o modo atual (novos + revisão se ligada).
  int _areaPool(String a) =>
      _catalog.where((o) => o.area == a).fold(0, (s, o) => s + _pool(o));

  int get _allAreasPool =>
      _catalog.fold(0, (s, o) => s + _pool(o));

  Widget _content() {
    final themes = _themes;
    final diffs = _difficulties;
    final count = _total;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SectionHeader(icon: LucideIcons.layers, title: 'Áreas'),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 8,
                childAspectRatio: 3.1,
                children: [
                  _AreaCard(
                    label: 'Todas',
                    icon: LucideIcons.sparkles,
                    color: context.zon.brand,
                    count: _allAreasPool,
                    selected: _selAreas.isEmpty,
                    onTap: () => setState(() {
                      _selAreas.clear();
                      _reconcileSelection();
                    }),
                  ),
                  for (final a in _areas)
                    _AreaCard(
                      label: _areaLabel(a),
                      icon: areaIcon(a),
                      color: areaColor(a),
                      count: _areaPool(a),
                      selected: _selAreas.contains(a),
                      onTap: () => _toggleArea(a),
                    ),
                ],
              ),
              if (themes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SectionHeader(icon: LucideIcons.tag, title: 'Temas'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GameSelectChip(
                        label: 'Todos',
                        selected: _selThemes.isEmpty,
                        onTap: () => setState(() {
                              _selThemes.clear();
                              _reconcileSelection();
                            })),
                    for (final t in themes)
                      GameSelectChip(
                          label: t,
                          selected: _selThemes.contains(t),
                          onTap: () => _toggleTheme(t)),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SectionHeader(icon: LucideIcons.gauge, title: 'Nível'),
              ),
              _levelRow(diffs),
              const SizedBox(height: 20),
              _reviewToggle(),
              if (_includeSolved) ...[
                const SizedBox(height: 10),
                _reviewWarning(),
              ],
              const SizedBox(height: 24),
              _countCard(count),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: GameButton(
              label: 'INICIAR',
              icon: LucideIcons.play,
              size: GameButtonSize.lg,
              expanded: true,
              onPressed: count == 0 ? null : _start,
            ),
          ),
        ),
      ],
    );
  }

  /// Steppers quadrados de nível + pill "Qualquer" abaixo.
  Widget _levelRow(List<int> diffs) {
    final zon = context.zon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final d in diffs)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GamePressable(
                    onTap: () => setState(() => _difficulty = d),
                    faceColor: d == _difficulty ? zon.brand : zon.surface,
                    borderColor: d == _difficulty ? zon.brand : zon.outline,
                    edgeColor:
                        d == _difficulty ? zon.brandEdge : zon.neutralEdge,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        '$d',
                        style: AppText.numeric.copyWith(
                          fontSize: 18,
                          color: d == _difficulty
                              ? zon.onBrand
                              : zon.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GamePressable(
          onTap: () => setState(() => _difficulty = null),
          faceColor: _difficulty == null ? zon.brand : zon.surface,
          borderColor: _difficulty == null ? zon.brand : zon.outline,
          edgeColor: _difficulty == null ? zon.brandEdge : zon.neutralEdge,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              'Qualquer nível',
              style: AppText.label.copyWith(
                color:
                    _difficulty == null ? zon.onBrand : zon.onSurfaceMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewToggle() {
    final zon = context.zon;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Icon(LucideIcons.repeat, size: 20, color: zon.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Modo revisão', style: AppText.bodyStrong),
                Text('Incluir desafios já pontuados',
                    style: AppText.caption
                        .copyWith(color: zon.onSurfaceMuted)),
              ],
            ),
          ),
          Switch(value: _includeSolved, onChanged: _setIncludeSolved),
        ],
      ),
    );
  }

  Widget _reviewWarning() {
    final zon = context.zon;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: zon.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: zon.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.timer, size: 20, color: zon.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Na revisão o tempo cai pela metade (−50%). Resolva mais '
              'rápido para pontuar de novo!',
              style: AppText.label.copyWith(color: zon.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countCard(int count) {
    final zon = context.zon;
    final newN = _newTotal;
    final revN = _revisionTotal;
    // detalhamento: "X novos · Y em revisão" (revisão só quando o modo está on)
    final parts = <String>[
      '$newN novo${newN == 1 ? '' : 's'}',
      if (_includeSolved) '$revN em revisão',
    ];
    final subtitle = count == 0 ? 'Ajuste os filtros acima.' : parts.join(' · ');

    return GamePanel(
      color: count == 0 ? zon.surfaceAlt : zon.surface,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: (count == 0 ? zon.onSurfaceMuted : zon.brand)
                  .withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              count == 0 ? LucideIcons.circleOff : LucideIcons.brain,
              color: count == 0 ? zon.onSurfaceMuted : zon.brand,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    XpCounter(
                      value: count,
                      duration: const Duration(milliseconds: 500),
                      style: AppText.display.copyWith(fontSize: 28),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        count == 1 ? 'desafio' : 'desafios',
                        style: AppText.title
                            .copyWith(color: zon.onSurfaceMuted),
                      ),
                    ),
                  ],
                ),
                Text(subtitle,
                    style: AppText.caption
                        .copyWith(color: zon.onSurfaceMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card chunky selecionável de área de conhecimento (grid 2 colunas).
class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GamePressable(
      onTap: onTap,
      faceColor: selected
          ? Color.alphaBlend(color.withValues(alpha: 0.12), zon.surface)
          : zon.surface,
      borderColor: selected ? color : zon.outline,
      edgeColor: selected
          ? Color.lerp(color, const Color(0xFF000000), 0.25)!
          : zon.neutralEdge,
      borderWidth: selected ? 2.5 : 2,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label
                  .copyWith(color: selected ? color : zon.onSurface),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? color : zon.surfaceAlt,
              borderRadius: BorderRadius.circular(Corners.pill),
            ),
            child: Text(
              '$count',
              style: AppText.caption.copyWith(
                fontSize: 11,
                color: selected ? zon.onBrand : zon.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
