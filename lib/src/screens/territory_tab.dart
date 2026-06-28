import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'challenge_screen.dart';
import 'tab_header.dart';
import 'territory_customize_screen.dart';

/// Aba Território: dados e stats da zona ativa. Se o jogador for o governador,
/// mostra a opção de personalizar (nome, cor, ícone, fundo).
class TerritoryTab extends StatefulWidget {
  const TerritoryTab({
    super.key,
    required this.api,
    required this.territoryId,
    this.onChanged,
  });

  final ApiClient api;
  final String? territoryId;

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
          ),
        ))
        .then((_) => _reload());
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
                    FilledButton.icon(
                      onPressed: _startChallenge,
                      icon: const Icon(LucideIcons.brain, size: 18),
                      label: const Text('INICIAR DESAFIOS'),
                    ),
                    if (iAmGovernor) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _customize(d),
                        icon: const Icon(LucideIcons.palette, size: 18),
                        label: const Text('PERSONALIZAR ZONA'),
                      ),
                    ],
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

