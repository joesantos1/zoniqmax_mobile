import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'player_profile_screen.dart';
import 'tab_header.dart';

/// Aba Ranking: ranking geral (Governador) + líderes por classe da zona ativa.
class RankingTab extends StatefulWidget {
  const RankingTab({super.key, required this.api, required this.territoryId});

  final ApiClient api;
  final String? territoryId;

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  TerritoryDetail? _detail;
  bool _loading = false;
  String? _error;

  static const _classLabels = {
    'CONQUISTADOR': 'Conquistador',
    'PESQUISADOR': 'Pesquisador',
    'MENTOR': 'Mentor',
    'EXPLORADOR': 'Explorador',
    'GUARDIAO': 'Guardião',
    'RECRUTADOR': 'Recrutador',
  };

  @override
  void initState() {
    super.initState();
    if (widget.territoryId != null) _load();
  }

  Future<void> _load() async {
    if (widget.territoryId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.api.getTerritory(widget.territoryId!);
      if (mounted) setState(() => _detail = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Pull-to-refresh sem trocar a tela por um spinner.
  Future<void> _refresh() async {
    if (widget.territoryId == null) return;
    try {
      final d = await widget.api.getTerritory(widget.territoryId!);
      if (mounted) setState(() => _detail = d);
    } catch (_) {}
  }

  void _openPlayer(String userId, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerProfileScreen(
        api: widget.api,
        userId: userId,
        initialName: name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'RANKING',
              onRefresh: widget.territoryId == null ? null : _load,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.territoryId == null) {
      return const _EmptyTab(
          text: 'Abra o mapa e escolha uma zona para ver o ranking.');
    }
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _detail == null) {
      return Center(child: Text(_error!));
    }
    final d = _detail!;
    final myId = widget.api.currentUserId;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.orange,
      child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(d.displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const _SectionTitle('Ranking Geral'),
                    if (d.generalRanking.isEmpty)
                      const _Hint('Ninguém pontuou aqui ainda.')
                    else
                      ...d.generalRanking.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ComicPanel(
                            color: e.userId == myId
                                ? AppColors.orange
                                : AppColors.white,
                            padding: const EdgeInsets.all(12),
                            onTap: () => _openPlayer(e.userId, e.name),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.ink,
                                  child: Text('${e.position}',
                                      style: const TextStyle(
                                          color: AppColors.paper,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (e.userId == d.governorUserId)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Icon(LucideIcons.crown,
                                        color: AppColors.orange, size: 18),
                                  ),
                                Text(
                                  e.effectiveInfluence.toStringAsFixed(0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const _SectionTitle('Líderes por Classe'),
                    if (d.rankingByClass.isEmpty)
                      const _Hint('Sem líderes de classe ainda.')
                    else
                      ...d.rankingByClass.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ComicPanel(
                            padding: const EdgeInsets.all(12),
                            onTap: entry.value.isEmpty
                                ? null
                                : () => _openPlayer(entry.value.first.userId,
                                    entry.value.first.name),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.classColors[entry.key] ??
                                        AppColors.brown,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_classLabels[entry.key] ?? entry.key,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                        entry.value.isEmpty
                                            ? '—'
                                            : '${entry.value.first.name} • ${entry.value.first.score.toStringAsFixed(0)} pts',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(LucideIcons.medal,
                                    color: AppColors.muted, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text),
      );
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
