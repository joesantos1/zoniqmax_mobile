import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';

/// Perfil do jogador: dados e XP por área de conhecimento.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Me> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.me();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PERFIL')),
      body: FutureBuilder<Me>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final me = snapshot.data!;
          final maxXp = me.knowledgeXp.fold<double>(
            1,
            (m, e) => e.xp > m ? e.xp : m,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ComicPanel(
                color: AppColors.orange,
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.ink,
                      child: Icon(Icons.person, color: AppColors.paper, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            me.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(me.email,
                              style: const TextStyle(color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'XP POR ÁREA',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              if (me.knowledgeXp.isEmpty)
                const ComicPanel(
                  child: Text(
                    'Você ainda não ganhou XP. Resolva desafios para evoluir!',
                  ),
                )
              else
                ...me.knowledgeXp.map(
                  (xp) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ComicPanel(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(xp.area,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${xp.xp.toStringAsFixed(0)} XP',
                                  style: const TextStyle(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (xp.xp / maxXp).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: AppColors.paperDark,
                              color: AppColors.blue,
                            ),
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
