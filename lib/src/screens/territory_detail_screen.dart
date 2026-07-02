import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'challenge_screen.dart';
import 'duel_screen.dart';

/// Detalhe do território: ranking geral (Governador) e rankings por classe.
class TerritoryDetailScreen extends StatefulWidget {
  const TerritoryDetailScreen({
    super.key,
    required this.api,
    required this.territory,
  });

  final ApiClient api;
  final Territory territory;

  @override
  State<TerritoryDetailScreen> createState() => _TerritoryDetailScreenState();
}

class _TerritoryDetailScreenState extends State<TerritoryDetailScreen> {
  late Future<TerritoryDetail> _future;

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
    _future = widget.api.getTerritory(widget.territory.id);
  }

  void _reload() {
    setState(() {
      _future = widget.api.getTerritory(widget.territory.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.territory.name),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<TerritoryDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: LucideIcons.cloudOff,
              color: zon.danger,
              title: 'Ops, algo deu errado',
              message: '${snapshot.error}',
              action: GameButton(
                label: 'TENTAR DE NOVO',
                icon: LucideIcons.refreshCw,
                onPressed: _reload,
              ),
            );
          }
          final detail = snapshot.data!;
          final govName = detail.governorUserId == null
              ? null
              : detail.generalRanking
                  .firstWhere((e) => e.userId == detail.governorUserId,
                      orElse: () => detail.generalRanking.first)
                  .name;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // stats rápidos da zona
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: LucideIcons.crown,
                      label: 'GOVERNADOR',
                      value: govName ?? 'Livre',
                      color: zon.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: LucideIcons.users,
                      label: 'JOGADORES',
                      value: '${detail.generalRanking.length}',
                      color: zon.territory,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SectionHeader(
                    icon: LucideIcons.gamepad2, title: 'Atividades'),
              ),
              Row(
                children: [
                  Expanded(
                    child: _ActivityButton(
                      icon: LucideIcons.brain,
                      label: 'DESAFIO',
                      color: zon.info,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChallengeScreen(
                            api: widget.api,
                            territoryId: widget.territory.id,
                          ),
                        ),
                      ).then((_) => _reload()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActivityButton(
                      icon: LucideIcons.swords,
                      label: 'DUELO',
                      color: zon.danger,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DuelScreen(
                            api: widget.api,
                            territoryId: widget.territory.id,
                          ),
                        ),
                      ).then((_) => _reload()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SectionHeader(
                    icon: LucideIcons.trophy, title: 'Ranking geral'),
              ),
              if (detail.generalRanking.isEmpty)
                const _EmptyHint(
                    'Ninguém pontuou aqui ainda. Seja quem abre o placar!')
              else
                ...detail.generalRanking.map(
                  (e) => _RankRow(
                    entry: e,
                    isGovernor: e.userId == detail.governorUserId,
                  ),
                ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionHeader(
                    icon: LucideIcons.medal,
                    title: 'Líderes por classe',
                    color: zon.territory),
              ),
              if (detail.rankingByClass.isEmpty)
                const _EmptyHint('Sem líderes de classe ainda.')
              else
                ...detail.rankingByClass.entries.map(
                  (entry) => _ClassLeaderRow(
                    classType: entry.key,
                    label: _classLabels[entry.key] ?? entry.key,
                    leader:
                        entry.value.isEmpty ? null : entry.value.first,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Cartão de atividade "chunky" (desafio / duelo) na cor da ação.
class _ActivityButton extends StatelessWidget {
  const _ActivityButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GamePressable(
      onTap: onTap,
      faceColor: color,
      borderColor: color,
      edgeColor: Color.lerp(color, Colors.black, 0.25)!,
      radius: Corners.lg,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: zon.onBrand, size: 32),
          const SizedBox(height: 6),
          Text(label, style: AppText.button.copyWith(color: zon.onBrand)),
        ],
      ),
    );
  }
}

/// Linha do ranking geral: badge de posição + avatar + nome + influência.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isGovernor});

  final RankingEntry entry;
  final bool isGovernor;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GamePanel(
        padding: const EdgeInsets.all(10),
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
              child: Text('${entry.position}',
                  style: AppText.label
                      .copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            AvatarRing(
              imageUrl: entry.avatarUrl,
              initial: entry.name.isNotEmpty ? entry.name[0] : '?',
              size: 36,
              ringColor: isGovernor ? zon.brand : zon.outline,
              ringWidth: 2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong),
            ),
            if (isGovernor)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: zon.brand,
                    borderRadius: BorderRadius.circular(Corners.pill),
                  ),
                  child:
                      Icon(LucideIcons.crown, size: 11, color: zon.onBrand),
                ),
              ),
            Text(entry.effectiveInfluence.toStringAsFixed(0),
                style: AppText.numeric.copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Linha de líder de classe: ícone da classe + nome do líder + pontos.
class _ClassLeaderRow extends StatelessWidget {
  const _ClassLeaderRow({
    required this.classType,
    required this.label,
    required this.leader,
  });

  final String classType;
  final String label;
  final ClassRankingEntry? leader;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final color = kClassColors[classType] ?? zon.territory;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GamePanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(classIcon(classType), size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    leader == null ? 'Posto vago — bora liderar?' : leader!.name,
                    style:
                        AppText.caption.copyWith(color: zon.onSurfaceMuted),
                  ),
                ],
              ),
            ),
            if (leader != null)
              Text('${leader!.score.toStringAsFixed(0)} pts',
                  style: AppText.numeric.copyWith(fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: AppText.body.copyWith(color: zon.onSurfaceMuted)),
    );
  }
}
