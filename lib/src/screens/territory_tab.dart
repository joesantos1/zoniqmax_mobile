import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'challenge_screen.dart';
import 'player_profile_screen.dart';
import 'tab_header.dart';
import 'territory_customize_screen.dart';

/// Aba Território: dados e stats da zona ativa. Se o jogador for o governador,
/// mostra a opção de personalizar (nome, cor, ícone, fundo).
class TerritoryTab extends StatefulWidget {
  const TerritoryTab({
    super.key,
    required this.api,
    required this.territoryId,
    this.isPresent = false,
    this.userLat,
    this.userLng,
    this.onChanged,
  });

  final ApiClient api;
  final String? territoryId;

  /// O jogador está fisicamente neste território? Só então pode realizar desafios.
  final bool isPresent;
  final double? userLat;
  final double? userLng;

  /// Chamado quando a zona é personalizada (para o mapa atualizar).
  final VoidCallback? onChanged;

  @override
  State<TerritoryTab> createState() => _TerritoryTabState();
}

class _TerritoryTabState extends State<TerritoryTab> {
  TerritoryDetail? _detail;
  bool _loading = false;
  String? _error;

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

  void _reload() => _load();

  void _startChallenge() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChallengeScreen(
            api: widget.api,
            territoryId: widget.territoryId,
            userLat: widget.userLat,
            userLng: widget.userLng,
          ),
        ))
        .then((_) => _reload());
  }

  void _openPlayer(RankingEntry e) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerProfileScreen(
        api: widget.api,
        userId: e.userId,
        initialName: e.name,
      ),
    ));
  }

  void _customize(TerritoryDetail detail) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) =>
              TerritoryCustomizeScreen(api: widget.api, detail: detail),
        ))
        .then((changed) {
      if (changed == true) {
        _reload();
        widget.onChanged?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'TERRITÓRIO',
              onRefresh: widget.territoryId == null ? null : _reload,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.territoryId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Abra o mapa e escolha uma zona para ver seus dados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _detail == null) {
      return Center(child: Text(_error!));
    }
    final d = _detail!;
    final myId = widget.api.currentUserId;
    final iAmGovernor = d.governorUserId != null && d.governorUserId == myId;

    final myIndex = d.generalRanking.indexWhere((e) => e.userId == myId);
    final myInf =
        myIndex >= 0 ? d.generalRanking[myIndex].effectiveInfluence : 0.0;
    final myPos = myIndex >= 0 ? myIndex + 1 : null;

    final govName = d.governorUserId == null
        ? null
        : d.generalRanking
            .firstWhere((e) => e.userId == d.governorUserId,
                orElse: () => d.generalRanking.first)
            .name;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.orange,
      child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Header(detail: d),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: LucideIcons.crown,
                            label: 'GOVERNADOR',
                            value: govName ?? 'Livre',
                            color: AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            icon: LucideIcons.users,
                            label: 'JOGADORES',
                            value: '${d.generalRanking.length}',
                            color: AppColors.brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: LucideIcons.zap,
                            label: 'SUA INFLUÊNCIA',
                            value: myInf.toStringAsFixed(0),
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            icon: LucideIcons.trophy,
                            label: 'SUA POSIÇÃO',
                            value: myPos == null ? '—' : '#$myPos',
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (widget.isPresent)
                      FilledButton.icon(
                        onPressed: _startChallenge,
                        icon: const Icon(LucideIcons.brain, size: 18),
                        label: const Text('INICIAR DESAFIOS'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.brown.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                              color: AppColors.brown.withValues(alpha: 0.30)),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.mapPinOff,
                                size: 20, color: AppColors.brown),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Você está visualizando este território. '
                                'Vá até a zona para realizar desafios e pontuar aqui.',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (iAmGovernor) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _customize(d),
                        icon: const Icon(LucideIcons.palette, size: 18),
                        label: const Text('PERSONALIZAR TERRITÓRIO'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(LucideIcons.users,
                            size: 18, color: AppColors.brown),
                        const SizedBox(width: 8),
                        Text(
                          'JOGADORES (${d.generalRanking.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (d.generalRanking.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Nenhum jogador ativo ainda. Seja o primeiro!',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      for (final e in d.generalRanking)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PlayerRow(
                            entry: e,
                            isGovernor: e.userId == d.governorUserId,
                            isMe: e.userId == myId,
                            onTap: () => _openPlayer(e),
                          ),
                        ),
                  ],
                ),
    );
  }
}

const _classLabels = <String, String>{
  'CONQUISTADOR': 'Conquistador',
  'PESQUISADOR': 'Pesquisador',
  'MENTOR': 'Mentor',
  'EXPLORADOR': 'Explorador',
  'GUARDIAO': 'Guardião',
  'RECRUTADOR': 'Recrutador',
};

/// Linha de jogador no território: posição, foto, nome (+ tags), classes e influência.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.entry,
    required this.isGovernor,
    required this.isMe,
    required this.onTap,
  });

  final RankingEntry entry;
  final bool isGovernor;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty;
    final accent = entry.classes.isNotEmpty
        ? (AppColors.classColors[entry.classes.first] ?? AppColors.orange)
        : AppColors.brown;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: ComicPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '#${entry.position}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.18),
              backgroundImage:
                  hasAvatar ? NetworkImage(entry.avatarUrl!) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      entry.name.isNotEmpty
                          ? entry.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: accent),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      if (isGovernor) ...[
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.crown,
                            size: 15, color: AppColors.red),
                      ],
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('você',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange)),
                        ),
                      ],
                    ],
                  ),
                  if (entry.classes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in entry.classes) _ClassChip(classType: c),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(LucideIcons.zap, size: 14, color: AppColors.blue),
                const SizedBox(height: 2),
                Text(
                  entry.effectiveInfluence.toStringAsFixed(0),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({required this.classType});
  final String classType;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.classColors[classType] ?? AppColors.brown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(classIcon(classType), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _classLabels[classType] ?? classType,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});
  final TerritoryDetail detail;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.zoneColor(detail.color);
    final hasBg =
        detail.backgroundUrl != null && detail.backgroundUrl!.isNotEmpty;

    return ComicPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          children: [
            if (hasBg)
              Positioned.fill(
                child: Image.network(detail.backgroundUrl!, fit: BoxFit.cover),
              ),
            if (hasBg)
              Positioned.fill(
                child: Container(color: AppColors.ink.withValues(alpha: 0.45)),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: hasBg ? Colors.transparent : color.withValues(alpha: 0.18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(zoneIcon(detail.iconName),
                        color: AppColors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      detail.displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: hasBg ? AppColors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

