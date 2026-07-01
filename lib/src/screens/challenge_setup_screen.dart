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
      appBar: AppBar(title: const Text('CONFIGURAR DESAFIOS')),
      body: FutureBuilder<List<ChallengeOption>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (_catalog.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Você já resolveu todos os desafios disponíveis! Volte mais tarde.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
          return _content();
        },
      ),
    );
  }

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
              _section(LucideIcons.layers, 'ÁREAS'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Todas', _selAreas.isEmpty,
                      () => setState(() {
                            _selAreas.clear();
                            _reconcileSelection();
                          })),
                  for (final a in _areas)
                    _chip(_areaLabel(a), _selAreas.contains(a),
                        () => _toggleArea(a)),
                ],
              ),
              if (themes.isNotEmpty) ...[
                const SizedBox(height: 20),
                _section(LucideIcons.tag, 'TEMAS'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Todos', _selThemes.isEmpty,
                        () => setState(() {
                              _selThemes.clear();
                              _reconcileSelection();
                            })),
                    for (final t in themes)
                      _chip(t, _selThemes.contains(t), () => _toggleTheme(t)),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _section(LucideIcons.gauge, 'NÍVEL'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Qualquer', _difficulty == null,
                      () => setState(() => _difficulty = null)),
                  for (final d in diffs)
                    _chip('Nível $d', _difficulty == d,
                        () => setState(() => _difficulty = d)),
                ],
              ),
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
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: count == 0 ? null : _start,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                icon: const Icon(LucideIcons.play, size: 20),
                label: const Text('INICIAR'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewToggle() {
    return ComicPanel(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          const Icon(LucideIcons.repeat, size: 20, color: AppColors.red),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo revisão',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Incluir desafios já pontuados',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: _includeSolved,
            activeThumbColor: AppColors.red,
            onChanged: _setIncludeSolved,
          ),
        ],
      ),
    );
  }

  Widget _reviewWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 20, color: AppColors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Atenção: nos desafios que você já pontuou, o tempo é reduzido pela '
              'metade (−50%). Resolva mais rápido para pontuar de novo!',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(IconData icon, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.brown),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5)),
          ],
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _countCard(int count) {
    final newN = _newTotal;
    final revN = _revisionTotal;
    // detalhamento: "X novos · Y em revisão" (revisão só quando o modo está on)
    final parts = <String>[
      '$newN novo${newN == 1 ? '' : 's'}',
      if (_includeSolved) '$revN em revisão',
    ];
    final subtitle = count == 0 ? 'Ajuste os filtros acima.' : parts.join(' · ');

    return ComicPanel(
      color: count == 0 ? AppColors.paperDark : AppColors.paper,
      child: Row(
        children: [
          Icon(count == 0 ? LucideIcons.circleOff : LucideIcons.brain,
              color: count == 0 ? AppColors.muted : AppColors.orange, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? 'Nenhum desafio'
                      : '$count desafio${count == 1 ? '' : 's'} disponíve${count == 1 ? 'l' : 'is'}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
