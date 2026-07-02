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
  'REACAO_PRECISAO': 'Reação',
  'TOMADA_DECISAO': 'Decisão',
  'VERDADEIRO_FALSO': 'V ou F',
  'CACA_PALAVRAS': 'Caça-palavras',
  'ANAGRAMA': 'Anagrama',
  'BALANCA_LOGICA': 'Balança',
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
            return _loadingSkeleton();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: LucideIcons.cloudOff,
              color: context.zon.danger,
              title: 'Ops, algo deu errado',
              message: '${snap.error}',
            );
          }
          final items = snap.data ?? const [];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: context.zon.brand,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyState(
                        icon: LucideIcons.scrollText,
                        title: 'Nada por aqui ainda',
                        message:
                            '${widget.playerName} ainda não tem ações registradas. '
                            'A aventura está só começando!',
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
                          child: GameButton(
                            label: 'VER MAIS',
                            icon: LucideIcons.chevronDown,
                            variant: GameButtonVariant.secondary,
                            size: GameButtonSize.sm,
                            expanded: true,
                            onPressed: _seeMore,
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  /// Skeleton do carregamento: 6 linhas placeholder pulsando.
  Widget _loadingSkeleton() {
    return SkeletonGroup(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: GamePanel(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    SkeletonBox(width: 36, height: 36, radius: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(width: 160),
                          SizedBox(height: 8),
                          SkeletonLine(width: 100),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    SkeletonLine(width: 36),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Cabeçalho indicando o escopo do histórico (território específico ou geral).
  Widget _scopeHeader() {
    final inTerritory = widget.territoryName != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionHeader(
        icon: inTerritory ? LucideIcons.mapPin : LucideIcons.scrollText,
        color: context.zon.territory,
        title: inTerritory
            ? 'Ações em ${widget.territoryName}'
            : 'Histórico geral de ações',
      ),
    );
  }

  Widget _tile(ActivityItem it) {
    final zon = context.zon;
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;
    double xpDelta = 0;

    if (it.kind == 'bonus_sent') {
      icon = LucideIcons.timer;
      color = zon.brand;
      title = 'Enviou bônus de +${it.bonusSeconds}s';
      subtitle = '${_areaLabel(it.area)} · para ${it.receiverName ?? '—'}'
          '${it.status == 'USADO' ? ' · usado' : ''}';
    } else {
      final ok = it.success ?? false;
      icon = ok ? LucideIcons.check : LucideIcons.x;
      color = ok ? zon.success : zon.danger;
      xpDelta = it.score ?? 0;
      title = '${_typeLabel(it.challengeType)} de ${_areaLabel(it.area)}';
      // o território só é mostrado no extrato GERAL (sem filtro de território),
      // pois quando filtrado por território seria redundante.
      final showTerritory = widget.territoryId == null && it.territory != null;
      subtitle = '${ok ? 'Acertou' : 'Errou'}'
          '${showTerritory ? ' · ${it.territory}' : ''}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GamePanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.bodyStrong.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          AppText.caption.copyWith(color: zon.onSurfaceMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (xpDelta > 0)
                  Text('+${xpDelta.toStringAsFixed(0)}',
                      style: AppText.numeric
                          .copyWith(fontSize: 15, color: zon.xp)),
                if (xpDelta > 0) const SizedBox(height: 2),
                Text(_ago(it.at),
                    style:
                        AppText.caption.copyWith(color: zon.onSurfaceMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
