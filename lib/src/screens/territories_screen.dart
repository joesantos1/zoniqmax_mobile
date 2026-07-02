import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'territory_detail_screen.dart';

/// Lista de territórios (representação simplificada do mapa no MVP).
class TerritoriesScreen extends StatefulWidget {
  const TerritoriesScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<TerritoriesScreen> createState() => _TerritoriesScreenState();
}

class _TerritoriesScreenState extends State<TerritoriesScreen> {
  late Future<List<Territory>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listTerritories();
  }

  void _reload() {
    setState(() {
      _future = widget.api.listTerritories();
    });
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TERRITÓRIOS'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(api: widget.api)),
            ),
            icon: const Icon(LucideIcons.circleUser),
            tooltip: 'Perfil',
          ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Recarregar',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(LucideIcons.logOut),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: FutureBuilder<List<Territory>>(
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
          final territories = snapshot.data ?? [];
          if (territories.isEmpty) {
            return EmptyState(
              icon: LucideIcons.map,
              title: 'Nenhuma zona por aqui ainda',
              message: 'O mapa ainda está sendo desbravado. '
                  'Atualize para procurar novos territórios!',
              action: GameButton(
                label: 'ATUALIZAR',
                icon: LucideIcons.refreshCw,
                variant: GameButtonVariant.secondary,
                onPressed: _reload,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: zon.brand,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: territories.length,
              itemBuilder: (context, i) {
                final t = territories[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GamePanel(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TerritoryDetailScreen(api: widget.api, territory: t),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: zon.territory.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(LucideIcons.hexagon,
                              color: zon.territory, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, style: AppText.bodyStrong),
                              const SizedBox(height: 2),
                              Text(
                                '${t.centerLat.toStringAsFixed(4)}, ${t.centerLng.toStringAsFixed(4)}',
                                style: AppText.caption
                                    .copyWith(color: zon.onSurfaceMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.chevronRight,
                            color: zon.onSurfaceMuted, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
