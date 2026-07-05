import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'record_duel_screen.dart';

/// Hub de duelos: escolha do modo (Quebra de Recordes ativo; Tempo Real em
/// breve), seletor de oponente no território e histórico "seus últimos duelos"
/// — onde o defensor também descobre defesas vencidas.
class DuelModeScreen extends StatefulWidget {
  const DuelModeScreen({
    super.key,
    required this.api,
    required this.territoryId,
    this.territoryName,
  });

  final ApiClient api;
  final String territoryId;
  final String? territoryName;

  @override
  State<DuelModeScreen> createState() => _DuelModeScreenState();
}

class _DuelModeScreenState extends State<DuelModeScreen> {
  List<RankingEntry> _players = const [];
  List<RecordDuel> _history = const [];
  bool _loading = true;
  bool _creating = false;
  bool _showOpponents = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.getTerritory(widget.territoryId);
      final history = await widget.api.myRecordDuels();
      if (!mounted) return;
      setState(() {
        _players = detail.generalRanking
            .where((e) => e.userId != widget.api.currentUserId)
            .toList();
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _challenge(RankingEntry e) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final duel =
          await widget.api.createRecordDuel(e.userId, widget.territoryId);
      if (!mounted) return;
      await Navigator.of(context).push(appRoute(
        RecordDuelScreen(api: widget.api, initialDuel: duel),
      ));
      if (mounted) _load(); // atualiza o histórico ao voltar
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Falha ao criar o duelo.')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      appBar: AppBar(title: const Text('Duelos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: LucideIcons.cloudOff,
                  title: 'Ops, algo deu errado',
                  message: _error,
                  action: GameButton(
                    label: 'TENTAR DE NOVO',
                    icon: LucideIcons.refreshCw,
                    onPressed: _load,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ---- modos ----
                    _modeCard(
                      icon: LucideIcons.trophy,
                      color: zon.brand,
                      title: 'Quebra de Recordes',
                      description:
                          'Corra contra os recordes de outro jogador: supere '
                          'os melhores XP dele em uma série de desafios. Ele '
                          'não precisa estar online!',
                      enabled: true,
                      onTap: () =>
                          setState(() => _showOpponents = !_showOpponents),
                      trailing: Icon(
                        _showOpponents
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 18,
                        color: zon.onSurfaceMuted,
                      ),
                    ),
                    if (_showOpponents) ...[
                      const SizedBox(height: 8),
                      _opponentList(zon),
                    ],
                    const SizedBox(height: 10),
                    _modeCard(
                      icon: LucideIcons.zap,
                      color: zon.onSurfaceMuted,
                      title: 'Tempo Real',
                      description:
                          'Duelo ao vivo contra outro jogador online, no mesmo '
                          'desafio, valendo tudo.',
                      enabled: false,
                      trailing: const GameChip(
                        label: 'EM BREVE',
                        mode: GameChipMode.tonal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ---- histórico ----
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: SectionHeader(
                        icon: LucideIcons.history,
                        title: 'Seus últimos duelos',
                      ),
                    ),
                    if (_history.isEmpty)
                      Text(
                        'Nenhum duelo ainda — desafie alguém do seu território!',
                        style:
                            AppText.body.copyWith(color: zon.onSurfaceMuted),
                      )
                    else
                      for (final d in _history) _historyRow(zon, d),
                  ],
                ),
    );
  }

  Widget _modeCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool enabled,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final zon = context.zon;
    return GamePressable(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(16),
      radius: Corners.lg,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.title.copyWith(
                        color:
                            enabled ? zon.onSurface : zon.onSurfaceMuted)),
                const SizedBox(height: 2),
                Text(description,
                    style: AppText.caption
                        .copyWith(color: zon.onSurfaceMuted)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _opponentList(ZonColors zon) {
    if (_players.isEmpty) {
      return GamePanel(
        child: Text(
          'Ninguém para desafiar por aqui ainda — o ranking '
          '${widget.territoryName != null ? 'de ${widget.territoryName} ' : ''}'
          'está vazio.',
          style: AppText.body.copyWith(color: zon.onSurfaceMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'Só é possível desafiar jogadores mais fortes que você '
            '(influência maior aqui ou XP total maior).',
            style: AppText.caption.copyWith(color: zon.onSurfaceMuted),
          ),
        ),
        for (final e in _players)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GamePanel(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  AvatarRing(
                    imageUrl: e.avatarUrl,
                    initial: e.name.isNotEmpty ? e.name[0] : '?',
                    size: 40,
                    ringWidth: 2.5,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong),
                  ),
                  GameButton(
                    label: 'DESAFIAR',
                    icon: LucideIcons.swords,
                    size: GameButtonSize.sm,
                    loading: _creating,
                    onPressed: _creating ? null : () => _challenge(e),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _historyRow(ZonColors zon, RecordDuel d) {
    final meId = widget.api.currentUserId;
    final iAmChallenger = d.challenger.id == meId;
    final opponent = iAmChallenger ? d.defender : d.challenger;
    final myWins = iAmChallenger ? d.challengerWins : d.defenderWins;
    final theirWins = iAmChallenger ? d.defenderWins : d.challengerWins;

    final (String label, Color color) = switch (d.status) {
      'EM_ANDAMENTO' => ('EM ANDAMENTO', zon.warning),
      'VITORIA_DESAFIANTE' =>
        iAmChallenger ? ('VITÓRIA', zon.success) : ('DERROTA', zon.danger),
      'VITORIA_DEFENSOR' =>
        iAmChallenger ? ('DERROTA', zon.danger) : ('DEFENDIDO', zon.success),
      'ABANDONADO' => iAmChallenger
          ? ('ABANDONADO', zon.danger)
          : ('DEFENDIDO', zon.success),
      _ => (d.status, zon.onSurfaceMuted),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GamePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              iAmChallenger ? LucideIcons.swords : LucideIcons.shield,
              size: 18,
              color: zon.onSurfaceMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    iAmChallenger
                        ? 'Você × ${opponent.name}'
                        : '${opponent.name} × seus recordes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  if (d.territoryName != null)
                    Text(d.territoryName!,
                        style: AppText.caption
                            .copyWith(color: zon.onSurfaceMuted)),
                ],
              ),
            ),
            Text('$myWins × $theirWins',
                style: AppText.numeric.copyWith(fontSize: 16)),
            const SizedBox(width: 10),
            GameChip(label: label, color: color, mode: GameChipMode.tonal),
          ],
        ),
      ),
    );
  }
}
