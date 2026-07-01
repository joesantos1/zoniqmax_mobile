import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'player_profile_screen.dart';
import 'tab_header.dart';

/// Aba Ranking: ranking geral (Governador) + líderes por classe da zona ativa.
class RankingTab extends StatefulWidget {
  const RankingTab({
    super.key,
    required this.api,
    required this.territoryId,
    this.onBackToCurrent,
  });

  final ApiClient api;
  final String? territoryId;

  /// Botão de voltar para a zona atual (ao ver outro território).
  final VoidCallback? onBackToCurrent;

  @override
  State<RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<RankingTab> {
  TerritoryDetail? _detail;
  bool _loading = false;
  String? _error;
  String _view = 'INFLUENCIA'; // 'INFLUENCIA' ou um classType

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
              onBack: widget.onBackToCurrent,
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
    // classes que têm pontuação (na ordem das classes do app)
    final classKeys = _classLabels.keys
        .where((c) => (d.rankingByClass[c] ?? const []).isNotEmpty)
        .toList();
    final byInfluence = _view == 'INFLUENCIA';
    final caption = byInfluence
        ? 'Ordenado pela influência efetiva no território.'
        : 'Ordenado pela pontuação de ${_classLabels[_view] ?? _view}.';

    final rows = <Widget>[];
    if (byInfluence) {
      if (d.generalRanking.isEmpty) {
        rows.add(const _Hint('Ninguém pontuou aqui ainda.'));
      } else {
        for (final e in d.generalRanking) {
          rows.add(_rankRow(
            position: e.position,
            userId: e.userId,
            name: e.name,
            avatarUrl: e.avatarUrl,
            value: e.effectiveInfluence,
            unit: 'inf.',
            isMe: e.userId == myId,
            isGovernor: e.userId == d.governorUserId,
          ));
        }
      }
    } else {
      final list = d.rankingByClass[_view] ?? const [];
      if (list.isEmpty) {
        rows.add(const _Hint('Ninguém pontuou nesta classe ainda.'));
      } else {
        for (final e in list) {
          rows.add(_rankRow(
            position: e.position,
            userId: e.userId,
            name: e.name,
            avatarUrl: e.avatarUrl,
            value: e.score,
            unit: 'pts',
            isMe: e.userId == myId,
            isGovernor: false,
          ));
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.orange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Território: 🗺️${d.displayName}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // seletor: Influência + classes
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _viewChip('INFLUENCIA', 'Influência', LucideIcons.zap),
                for (final c in classKeys)
                  _viewChip(c, _classLabels[c] ?? c, classIcon(c)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(caption,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  /// Chip de seleção da visão do ranking (influência / classe).
  Widget _viewChip(String value, String label, IconData icon) {
    final selected = _view == value;
    final color = value == 'INFLUENCIA'
        ? AppColors.orange
        : (AppColors.classColors[value] ?? AppColors.brown);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _view = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : AppColors.line, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? AppColors.white : AppColors.muted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? AppColors.white : AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }

  /// Linha do ranking com foto (ou placeholder), posição, nome e valor.
  Widget _rankRow({
    required int position,
    required String userId,
    required String name,
    required String? avatarUrl,
    required double value,
    required String unit,
    required bool isMe,
    required bool isGovernor,
  }) {
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ComicPanel(
        color: isMe ? AppColors.orange : AppColors.white,
        padding: const EdgeInsets.all(10),
        onTap: () => _openPlayer(userId, name),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('#$position',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.muted)),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.paperDark,
              backgroundImage:
                  hasPhoto ? CachedNetworkImageProvider(avatarUrl) : null,
              child: hasPhoto
                  ? null
                  : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (isGovernor)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child:
                    Icon(LucideIcons.crown, color: AppColors.orange, size: 18),
              ),
            Text('${value.toStringAsFixed(0)} $unit',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
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
