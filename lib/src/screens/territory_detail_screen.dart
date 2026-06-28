import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.territory.name),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<TerritoryDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final detail = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionTitle('Atividades'),
              Row(
                children: [
                  Expanded(
                    child: _ActivityButton(
                      icon: Icons.psychology,
                      label: 'DESAFIO',
                      color: AppColors.blue,
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
                      icon: Icons.sports_kabaddi,
                      label: 'DUELO',
                      color: AppColors.red,
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
              const SizedBox(height: 16),
              const _SectionTitle('Ranking Geral (Governador)'),
              if (detail.generalRanking.isEmpty)
                const _EmptyHint('Ninguém pontuou aqui ainda.')
              else
                ...detail.generalRanking.map(
                  (e) => Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${e.position}')),
                      title: Text(e.name),
                      trailing: Text(
                        e.effectiveInfluence.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: e.userId == detail.governorUserId
                          ? const Text('👑 Governador')
                          : null,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const _SectionTitle('Líderes por Classe'),
              if (detail.rankingByClass.isEmpty)
                const _EmptyHint('Sem líderes de classe ainda.')
              else
                ...detail.rankingByClass.entries.map(
                  (entry) => Card(
                    child: ListTile(
                      title: Text(_classLabels[entry.key] ?? entry.key),
                      subtitle: Text(entry.value.isEmpty
                          ? '—'
                          : '${entry.value.first.name} • ${entry.value.first.score.toStringAsFixed(0)} pts'),
                      trailing: const Icon(Icons.military_tech_outlined),
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
    return ComicPanel(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: AppColors.white, size: 32),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
