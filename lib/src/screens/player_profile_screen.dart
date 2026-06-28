import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';

/// Perfil PÚBLICO de um jogador (aberto ao tocar no nome dele no ranking).
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({
    super.key,
    required this.api,
    required this.userId,
    this.initialName,
  });

  final ApiClient api;
  final String userId;
  final String? initialName;

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
    return Scaffold(
      appBar: AppBar(title: Text((widget.initialName ?? 'JOGADOR').toUpperCase())),
      body: FutureBuilder<PublicProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final p = snapshot.data!;
          final hasPhoto = p.avatarUrl != null && p.avatarUrl!.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // cabeçalho
              ComicPanel(
                color: AppColors.orange,
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 3),
                        image: hasPhoto
                            ? DecorationImage(
                                image: NetworkImage(p.avatarUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: hasPhoto
                          ? null
                          : Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppColors.paper,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(p.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // stats
              Row(children: [
                Expanded(
                    child: StatTile(
                        icon: LucideIcons.zap,
                        label: 'XP TOTAL',
                        value: p.totalXp.toStringAsFixed(0),
                        color: AppColors.orange)),
                const SizedBox(width: 12),
                Expanded(
                    child: StatTile(
                        icon: LucideIcons.target,
                        label: 'ACERTO',
                        value:
                            p.totalAttempts == 0 ? '—' : '${p.accuracy.round()}%',
                        color: AppColors.green)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: StatTile(
                        icon: LucideIcons.activity,
                        label: 'TENTATIVAS',
                        value: '${p.totalAttempts}',
                        color: AppColors.blue)),
                const SizedBox(width: 12),
                Expanded(
                    child: StatTile(
                        icon: LucideIcons.hexagon,
                        label: 'TERRITÓRIOS',
                        value: '${p.territories.length}',
                        color: AppColors.brown)),
              ]),
              const SizedBox(height: 20),
              // classes
              const _SectionTitle('CLASSES'),
              if (p.classTotals.isEmpty)
                const ComicPanel(child: Text('Sem pontos de classe ainda.'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.classTotals
                      .map((c) => ClassChip(
                            classType: c.classType,
                            label: _classLabels[c.classType] ?? c.classType,
                            value: c.score.toStringAsFixed(0),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 20),
              // territórios
              const _SectionTitle('TERRITÓRIOS'),
              if (p.territories.isEmpty)
                const ComicPanel(
                    child: Text('Não participa de nenhum território.'))
              else
                ...p.territories.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ComicPanel(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                              t.isGovernor
                                  ? LucideIcons.crown
                                  : LucideIcons.hexagon,
                              size: 20,
                              color:
                                  t.isGovernor ? AppColors.red : AppColors.brown),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(t.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ),
                          if (t.isGovernor)
                            const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Text('👑')),
                          Text('${t.effectiveInfluence.toStringAsFixed(0)} inf.',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // últimos desafios
              const _SectionTitle('ÚLTIMOS DESAFIOS'),
              if (p.recentAttempts.isEmpty)
                const ComicPanel(child: Text('Nenhum desafio realizado ainda.'))
              else
                ...p.recentAttempts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ComicPanel(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                              a.success
                                  ? LucideIcons.circleCheck
                                  : LucideIcons.circleX,
                              size: 20,
                              color: a.success ? AppColors.green : AppColors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_typeLabels[a.type] ?? a.type,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text('${a.area} • ${_timeAgo(a.createdAt)}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            a.success
                                ? '+${a.scoreAwarded.toStringAsFixed(0)} XP'
                                : '—',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color:
                                    a.success ? AppColors.green : AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.ink)),
      );
}
