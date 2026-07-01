import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';

const _areaLabels = <String, String>{
  'MATEMATICA': 'Matemática',
  'LOGICA': 'Lógica',
  'MEMORIA': 'Memória',
  'BIOLOGIA': 'Biologia',
  'HISTORIA': 'História',
  'PORTUGUES': 'Português',
  'GEOGRAFIA': 'Geografia',
  'CIENCIAS': 'Ciências',
  'ESTRATEGIA': 'Estratégia',
  'OBSERVACAO': 'Observação',
};

const _typeLabels = <String, String>{
  'QUIZ': 'Quiz',
  'CALCULO_MENTAL': 'Cálculo',
  'SEQUENCIA_LOGICA': 'Sequência',
  'ORDENACAO_RAPIDA': 'Ordenação',
  'ASSOCIACAO_VISUAL': 'Associação',
  'MEMORIA_VISUAL': 'Memória',
  'MINI_PUZZLE': 'Quebra-cabeça',
};

String _areaLabel(String a) => _areaLabels[a] ?? a;
String _typeLabel(String? t) => t == null ? '' : (_typeLabels[t] ?? t);

/// Histórico/extrato PÚBLICO das ações de um jogador (desafios + bônus enviados).
/// Opcionalmente escopado a um território (filtra os desafios).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.api,
    required this.userId,
    required this.playerName,
    this.territoryId,
    this.territoryName,
  });

  final ApiClient api;
  final String userId;
  final String playerName;
  final String? territoryId;
  final String? territoryName;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _pageSmall = 20;
  static const int _pageLarge = 100;

  late Future<List<ActivityItem>> _future;
  int _limit = _pageSmall;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ActivityItem>> _load() => widget.api.playerHistory(
        widget.userId,
        territoryId: widget.territoryId,
        limit: _limit,
      );

  Future<void> _refresh() async {
    final list = await _load();
    if (mounted) setState(() => _future = Future.value(list));
  }

  void _seeMore() {
    setState(() {
      _limit = _pageLarge;
      _future = _load();
    });
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    if (d.inDays < 30) return 'há ${d.inDays} d';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.playerName.toUpperCase())),
      body: FutureBuilder<List<ActivityItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final items = snap.data ?? const [];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.orange,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          '${widget.playerName} ainda não tem ações por aqui.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _scopeHeader(),
                      for (final it in items) _tile(it),
                      // "Ver mais" quando a 1ª página veio cheia (pode haver mais)
                      if (_limit == _pageSmall && items.length >= _pageSmall)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: OutlinedButton.icon(
                            onPressed: _seeMore,
                            icon: const Icon(LucideIcons.chevronDown, size: 18),
                            label: const Text('Ver mais (até 100)'),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  /// Cabeçalho indicando o escopo do histórico (território específico ou geral).
  Widget _scopeHeader() {
    final inTerritory = widget.territoryName != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(inTerritory ? LucideIcons.mapPin : LucideIcons.scrollText,
              size: 16, color: AppColors.brown),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              inTerritory
                  ? 'Ações em ${widget.territoryName}'
                  : 'Histórico geral de ações',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(ActivityItem it) {
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;

    if (it.kind == 'bonus_sent') {
      icon = LucideIcons.timer;
      color = AppColors.orange;
      title = 'Enviou bônus de +${it.bonusSeconds}s';
      subtitle =
          '${_areaLabel(it.area)} · para ${it.receiverName ?? '—'}'
          '${it.status == 'USADO' ? ' · usado' : ''}';
    } else {
      final ok = it.success ?? false;
      icon = ok ? LucideIcons.circleCheck : LucideIcons.circleX;
      color = ok ? AppColors.green : AppColors.red;
      final pts = (it.score ?? 0) > 0 ? ' · +${it.score!.toStringAsFixed(0)} pts' : '';
      title = '${_typeLabel(it.challengeType)} de ${_areaLabel(it.area)}';
      // o território só é mostrado no extrato GERAL (sem filtro de território),
      // pois quando filtrado por território seria redundante.
      final showTerritory = widget.territoryId == null && it.territory != null;
      subtitle = '${ok ? 'Acertou' : 'Errou'}$pts'
          '${showTerritory ? ' · ${it.territory}' : ''}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ComicPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_ago(it.at),
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
