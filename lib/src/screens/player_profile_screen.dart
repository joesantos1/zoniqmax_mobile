import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'history_screen.dart';

/// Perfil PÚBLICO de um jogador (aberto ao tocar no nome dele no ranking).
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({
    super.key,
    required this.api,
    required this.userId,
    this.initialName,
    this.territoryId,
    this.territoryName,
  });

  final ApiClient api;
  final String userId;
  final String? initialName;

  /// Quando aberto a partir de um território, o histórico fica escopado a ele.
  final String? territoryId;
  final String? territoryName;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late Future<PublicProfile> _future;

  static const _classLabels = {
    'CONQUISTADOR': 'Conquistador',
    'PESQUISADOR': 'Pesquisador',
    'MENTOR': 'Mentor',
    'EXPLORADOR': 'Explorador',
    'GUARDIAO': 'Guardião',
    'RECRUTADOR': 'Recrutador',
  };

  static const _typeLabels = {
    'SEQUENCIA_LOGICA': 'Sequência lógica',
    'MEMORIA_VISUAL': 'Memória',
    'ORDENACAO_RAPIDA': 'Ordenação',
    'IDENTIFICACAO_PADROES': 'Padrões',
    'RACIOCINIO_ESPACIAL': 'Espacial',
    'TOMADA_DECISAO': 'Decisão',
    'INTERPRETACAO_GRAFICOS': 'Gráficos',
    'CALCULO_MENTAL': 'Cálculo',
    'REACAO_PRECISAO': 'Reação',
    'ASSOCIACAO_VISUAL': 'Associação',
    'MINI_PUZZLE': 'Puzzle',
    'QUIZ': 'Quiz',
    'VERDADEIRO_FALSO': 'V ou F',
    'CACA_PALAVRAS': 'Caça-palavras',
    'ANAGRAMA': 'Anagrama',
    'BALANCA_LOGICA': 'Balança',
  };

  @override
  void initState() {
    super.initState();
    _future = widget.api.getPlayer(widget.userId);
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      appBar: AppBar(
        title: Text((widget.initialName ?? 'JOGADOR').toUpperCase()),
        actions: [
          IconButton(
            tooltip: 'Histórico de ações',
            icon: const Icon(LucideIcons.scrollText),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HistoryScreen(
                api: widget.api,
                userId: widget.userId,
                playerName: widget.initialName ?? 'Jogador',
                territoryId: widget.territoryId,
                territoryName: widget.territoryName,
              ),
            )),
          ),
        ],
      ),
      body: FutureBuilder<PublicProfile>(
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
            );
          }
          final p = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _headerBand(p),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // stats
                    Row(children: [
                      Expanded(
                          child: StatTile(
                              icon: LucideIcons.zap,
                              label: 'XP TOTAL',
                              value: p.totalXp.toStringAsFixed(0),
                              color: zon.xp)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: StatTile(
                              icon: LucideIcons.target,
                              label: 'ACERTO',
                              value: p.totalAttempts == 0
                                  ? '—'
                                  : '${p.accuracy.round()}%',
                              color: zon.success)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: StatTile(
                              icon: LucideIcons.activity,
                              label: 'TENTATIVAS',
                              value: '${p.totalAttempts}',
                              color: zon.info)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: StatTile(
                              icon: LucideIcons.hexagon,
                              label: 'TERRITÓRIOS',
                              value: '${p.territories.length}',
                              color: zon.territory)),
                    ]),
                    const SizedBox(height: 24),
                    // classes
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: SectionHeader(
                          icon: LucideIcons.medal, title: 'Classes'),
                    ),
                    if (p.classTotals.isEmpty)
                      GamePanel(
                        child: Text('Sem pontos de classe ainda.',
                            style: AppText.body
                                .copyWith(color: zon.onSurfaceMuted)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.classTotals
                            .map((c) => GameChip(
                                  mode: GameChipMode.tonal,
                                  color: kClassColors[c.classType] ??
                                      zon.territory,
                                  icon: classIcon(c.classType),
                                  label:
                                      '${_classLabels[c.classType] ?? c.classType} '
                                      '${c.score.toStringAsFixed(0)}',
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 24),
                    // territórios
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionHeader(
                          icon: LucideIcons.hexagon,
                          title: 'Territórios',
                          color: zon.territory),
                    ),
                    if (p.territories.isEmpty)
                      GamePanel(
                        child: Text('Não participa de nenhum território.',
                            style: AppText.body
                                .copyWith(color: zon.onSurfaceMuted)),
                      )
                    else
                      ...p.territories.map(_territoryRow),
                    const SizedBox(height: 24),
                    // últimos desafios
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionHeader(
                          icon: LucideIcons.history,
                          title: 'Últimos desafios',
                          color: zon.info),
                    ),
                    if (p.recentAttempts.isEmpty)
                      GamePanel(
                        child: Text('Nenhum desafio realizado ainda.',
                            style: AppText.body
                                .copyWith(color: zon.onSurfaceMuted)),
                      )
                    else
                      ...p.recentAttempts.map(_attemptRow),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Faixa laranja curvada do topo: avatar grande + nome do jogador.
  Widget _headerBand(PublicProfile p) {
    final zon = context.zon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: BoxDecoration(
        color: zon.brand,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          AvatarRing(
            imageUrl: p.avatarUrl,
            initial: p.displayName.isNotEmpty ? p.displayName[0] : '?',
            size: 88,
            ringColor: zon.surface,
          ),
          const SizedBox(height: Space.md),
          Text(
            p.displayName,
            textAlign: TextAlign.center,
            style: AppText.headline.copyWith(color: zon.onBrand),
          ),
          if (p.nickname != null && p.nickname!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              p.name,
              textAlign: TextAlign.center,
              style: AppText.caption
                  .copyWith(color: zon.onBrand.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
  }

  /// Linha de território: ícone tintado + nome + coroa (se governa) + influência.
  Widget _territoryRow(TerritoryParticipation t) {
    final zon = context.zon;
    final accent = t.isGovernor ? zon.brand : zon.territory;
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
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                t.isGovernor ? LucideIcons.crown : LucideIcons.hexagon,
                size: 16,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(t.displayName, style: AppText.bodyStrong)),
            if (t.isGovernor)
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
            Text('${t.effectiveInfluence.toStringAsFixed(0)} inf.',
                style: AppText.numeric.copyWith(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  /// Linha de desafio recente: acerto/erro + tipo + área + XP ganho.
  Widget _attemptRow(AttemptSummary a) {
    final zon = context.zon;
    final accent = a.success ? zon.success : zon.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GamePanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                a.success ? LucideIcons.check : LucideIcons.x,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_typeLabels[a.type] ?? a.type,
                      style: AppText.bodyStrong.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${a.area} · ${_timeAgo(a.createdAt)}',
                      style: AppText.caption
                          .copyWith(color: zon.onSurfaceMuted)),
                ],
              ),
            ),
            if (a.success)
              Text('+${a.scoreAwarded.toStringAsFixed(0)} XP',
                  style:
                      AppText.numeric.copyWith(fontSize: 15, color: zon.xp))
            else
              Text('—',
                  style: AppText.numeric
                      .copyWith(fontSize: 15, color: zon.onSurfaceMuted)),
          ],
        ),
      ),
    );
  }
}
