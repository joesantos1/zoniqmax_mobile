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
    final zon = context.zon;
    if (widget.territoryId == null) {
      return const EmptyState(
        icon: LucideIcons.map,
        title: 'Escolha uma zona no mapa',
        message: 'Toque numa zona do mapa para ver quem manda por lá.',
      );
    }
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _detail == null) {
      return EmptyState(
        icon: LucideIcons.cloudOff,
        color: zon.danger,
        title: 'Ops, algo deu errado',
        message: _error,
        action: GameButton(
          label: 'TENTAR DE NOVO',
          icon: LucideIcons.refreshCw,
          onPressed: _load,
        ),
      );
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

    final items = <_RankItem>[];
    if (byInfluence) {
      for (final e in d.generalRanking) {
        items.add(_RankItem(
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
    } else {
      for (final e in d.rankingByClass[_view] ?? const <ClassRankingEntry>[]) {
        items.add(_RankItem(
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

    return RefreshIndicator(
      onRefresh: _refresh,
      color: zon.brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            icon: LucideIcons.map,
            title: d.displayName,
            color: zon.territory,
          ),
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
              style: AppText.caption.copyWith(color: zon.onSurfaceMuted)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            EmptyState(
              icon: LucideIcons.trophy,
              title: byInfluence
                  ? 'Ninguém pontuou aqui ainda'
                  : 'Ninguém pontuou nesta classe ainda',
              message: 'Que tal ser quem estreia o placar?',
            )
          else ...[
            _Podium(
              items: items.take(3).toList(),
              onTap: (it) => _openPlayer(it.userId, it.name),
            ),
            const SizedBox(height: 16),
            for (final it in items.skip(3)) _rankRow(it),
          ],
        ],
      ),
    );
  }

  /// Chip de seleção da visão do ranking (influência / classe).
  Widget _viewChip(String value, String label, IconData icon) {
    final color = value == 'INFLUENCIA'
        ? context.zon.brand
        : (kClassColors[value] ?? context.zon.territory);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GameSelectChip(
        label: label,
        icon: icon,
        color: color,
        selected: _view == value,
        onTap: () => setState(() => _view = value),
      ),
    );
  }

  /// Linha do ranking (4º lugar em diante): badge de posição, avatar, nome e valor.
  Widget _rankRow(_RankItem it) {
    final zon = context.zon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GamePanel(
        color: it.isMe
            ? Color.alphaBlend(zon.brand.withValues(alpha: 0.10), zon.surface)
            : null,
        borderColor: it.isMe ? zon.brand : null,
        padding: const EdgeInsets.all(10),
        onTap: () => _openPlayer(it.userId, it.name),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: zon.surfaceAlt,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('${it.position}',
                  style: AppText.label.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            AvatarRing(
              imageUrl: it.avatarUrl,
              initial: it.name.isNotEmpty ? it.name[0] : '?',
              size: 36,
              ringColor: it.isMe ? zon.brand : zon.outline,
              ringWidth: 2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(it.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong),
            ),
            if (it.isGovernor)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: _CrownPill(),
              ),
            Text('${it.value.toStringAsFixed(0)} ${it.unit}',
                style: AppText.numeric.copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Entrada normalizada do ranking (influência ou pontos de classe).
class _RankItem {
  const _RankItem({
    required this.position,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.value,
    required this.unit,
    required this.isMe,
    required this.isGovernor,
  });

  final int position;
  final String userId;
  final String name;
  final String? avatarUrl;
  final double value;
  final String unit;
  final bool isMe;
  final bool isGovernor;
}

/// Pódio do top-3: 1º ao centro (maior, anel da marca e coroa),
/// 2º à esquerda e 3º à direita.
class _Podium extends StatelessWidget {
  const _Podium({required this.items, required this.onTap});

  final List<_RankItem> items;
  final void Function(_RankItem) onTap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final first = items.isNotEmpty ? items[0] : null;
    final second = items.length > 1 ? items[1] : null;
    final third = items.length > 2 ? items[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: second == null
              ? const SizedBox.shrink()
              : _PodiumSpot(
                  item: second,
                  size: 48,
                  ringColor: zon.onSurfaceMuted,
                  onTap: () => onTap(second),
                ),
        ),
        Expanded(
          child: first == null
              ? const SizedBox.shrink()
              : _PodiumSpot(
                  item: first,
                  size: 64,
                  ringColor: zon.brand,
                  crowned: true,
                  onTap: () => onTap(first),
                ),
        ),
        Expanded(
          child: third == null
              ? const SizedBox.shrink()
              : _PodiumSpot(
                  item: third,
                  size: 48,
                  ringColor: zon.territory,
                  onTap: () => onTap(third),
                ),
        ),
      ],
    );
  }
}

/// Um lugar do pódio: avatar com anel, posição, nome e valor.
class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    required this.item,
    required this.size,
    required this.ringColor,
    required this.onTap,
    this.crowned = false,
  });

  final _RankItem item;
  final double size;
  final Color ringColor;
  final VoidCallback onTap;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        GameHaptics.tap();
        onTap();
      },
      child: Column(
        children: [
          SizedBox(
            height: size + 10,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 0,
                  child: AvatarRing(
                    imageUrl: item.avatarUrl,
                    initial: item.name.isNotEmpty ? item.name[0] : '?',
                    size: size,
                    ringColor: ringColor,
                  ),
                ),
                if (crowned) const Positioned(top: -4, child: _CrownPill()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('${item.position}º',
              style: AppText.caption.copyWith(color: zon.onSurfaceMuted)),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: zon.onSurface),
          ),
          Text('${item.value.toStringAsFixed(0)} ${item.unit}',
              style: AppText.numeric.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

/// Mini-pill laranja com coroa (governador / 1º lugar), estilo sticker.
class _CrownPill extends StatelessWidget {
  const _CrownPill();

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: zon.brand,
        borderRadius: BorderRadius.circular(Corners.pill),
        border: Border.all(color: zon.surface, width: 1.5),
        boxShadow: const [Shadows.soft],
      ),
      child: Icon(LucideIcons.crown, size: 10, color: zon.onBrand),
    );
  }
}
