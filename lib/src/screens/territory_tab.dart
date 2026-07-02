import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'challenge_setup_screen.dart';
import 'player_profile_screen.dart';
import 'tab_header.dart';
import 'territory_customize_screen.dart';

/// Aba Território: dados e stats da zona ativa. Se o jogador for o governador,
/// mostra a opção de personalizar (nome, cor, ícone, fundo).
class TerritoryTab extends StatefulWidget {
  const TerritoryTab({
    super.key,
    required this.api,
    required this.territoryId,
    this.isPresent = false,
    this.userLat,
    this.userLng,
    this.onChanged,
    this.onBackToCurrent,
  });

  final ApiClient api;
  final String? territoryId;

  /// O jogador está fisicamente neste território? Só então pode realizar desafios.
  final bool isPresent;
  final double? userLat;
  final double? userLng;

  /// Chamado quando a zona é personalizada (para o mapa atualizar).
  final VoidCallback? onChanged;

  /// Quando definido, exibe um botão de voltar para a zona atual do jogador
  /// (visível ao visualizar outro território fora da sua localização).
  final VoidCallback? onBackToCurrent;

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
          builder: (_) => ChallengeSetupScreen(
            api: widget.api,
            territoryId: widget.territoryId,
            userLat: widget.userLat,
            userLng: widget.userLng,
          ),
        ))
        .then((_) => _reload());
  }

  void _openPlayer(RankingEntry e) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerProfileScreen(
        api: widget.api,
        userId: e.userId,
        initialName: e.name,
        territoryId: widget.territoryId,
        territoryName: _detail?.displayName,
      ),
    ));
  }

  /// Abre o diálogo de envio de bônus de tempo (mentoria) para um jogador,
  /// mostrando o XP do doador e do receptor na área (regra: só pode doar para
  /// quem tem MENOS XP que você na mesma área).
  Future<void> _sendBonus(RankingEntry e) async {
    Me me;
    PublicProfile profile;
    OutgoingBonusSummary outgoing;
    try {
      me = await widget.api.me();
      profile = await widget.api.getPlayer(e.userId);
      outgoing = await widget.api.outgoingBonuses();
    } catch (_) {
      _snack('Falha ao carregar os dados.');
      return;
    }
    final donorXp = {for (final x in me.knowledgeXp) x.area: x.xp};
    final recvXp = {for (final x in profile.knowledgeXp) x.area: x.xp};
    final areas = donorXp.entries
        .where((x) => x.value > 0)
        .map((x) => x.key)
        .toList()
      ..sort((a, b) => (_areaLabels[a] ?? a).compareTo(_areaLabels[b] ?? b));
    if (areas.isEmpty) {
      _snack('Você precisa de XP em alguma área para doar bônus.');
      return;
    }
    if (!mounted) return;

    final zon = context.zon;
    final remaining = outgoing.remainingTodaySeconds;
    final maxSend = remaining.clamp(0, 10);
    String area = areas.first;
    int seconds = maxSend >= 5 ? 5 : (maxSend > 0 ? maxSend : 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final myX = donorXp[area] ?? 0;
          final rX = recvXp[area] ?? 0;
          final allowed = myX > 0 && rX < myX;
          // bônus já enviado para esse jogador nesta área, aguardando uso
          final pendente = outgoing.pendingFor(e.userId, area);
          final noBudget = maxSend < 1;
          final canSend = allowed && pendente == null && !noBudget;
          final accent = allowed ? zon.success : zon.danger;
          return AlertDialog(
            title: Text('Bônus de tempo para ${e.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Área:', style: AppText.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in areas)
                      GameSelectChip(
                        label: _areaLabels[a] ?? a,
                        icon: areaIcon(a),
                        color: areaColor(a),
                        selected: area == a,
                        onTap: () => setS(() => area = a),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // XP comparativo + permissão (painel tonal verde/vermelho)
                GamePanel(
                  color: Color.alphaBlend(
                      accent.withValues(alpha: 0.12), zon.surface),
                  borderColor: accent.withValues(alpha: 0.45),
                  shadow: false,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Seu XP em ${_areaLabels[area] ?? area}: ${myX.round()}',
                          style: AppText.label),
                      Text('XP de ${e.name}: ${rX.round()}',
                          style: AppText.label),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                              allowed
                                  ? LucideIcons.circleCheck
                                  : LucideIcons.circleX,
                              size: 16,
                              color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              allowed
                                  ? 'Você pode enviar bônus nesta área!'
                                  : 'Esse jogador tem XP maior ou igual ao seu.',
                              style:
                                  AppText.caption.copyWith(color: accent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // bônus pendente nesta área: aguarda o receptor usar
                if (allowed && pendente != null) ...[
                  const SizedBox(height: 10),
                  GamePanel(
                    color: Color.alphaBlend(
                        zon.warning.withValues(alpha: 0.12), zon.surface),
                    borderColor: zon.warning.withValues(alpha: 0.45),
                    shadow: false,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.hourglass,
                            size: 16, color: zon.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Você já enviou +${pendente.bonusSeconds}s nesta '
                            'área — aguardando ${e.name} usar.',
                            style: AppText.caption
                                .copyWith(color: zon.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // orçamento diário do doador (reseta às 00:00)
                Row(
                  children: [
                    Icon(LucideIcons.calendarClock,
                        size: 14,
                        color:
                            noBudget ? zon.danger : zon.onSurfaceMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        noBudget
                            ? 'Limite diário atingido — volta à meia-noite!'
                            : 'Hoje: ${remaining}s de ${outgoing.dailyLimitSeconds}s disponíveis',
                        style: AppText.caption.copyWith(
                            color: noBudget
                                ? zon.danger
                                : zon.onSurfaceMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GameProgressBar(
                  value: outgoing.dailyLimitSeconds > 0
                      ? remaining / outgoing.dailyLimitSeconds
                      : 0,
                  color: noBudget ? zon.danger : zon.brand,
                  height: 6,
                ),
                if (canSend) ...[
                  const SizedBox(height: 12),
                  Text('Bônus: +$seconds s', style: AppText.bodyStrong),
                  if (maxSend > 1)
                    Slider(
                      value: seconds.clamp(1, maxSend).toDouble(),
                      min: 1,
                      max: maxSend.toDouble(),
                      divisions: maxSend - 1,
                      label: '+$seconds s',
                      onChanged: (v) => setS(() => seconds = v.round()),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              GameButton(
                label: 'ENVIAR',
                icon: LucideIcons.timer,
                size: GameButtonSize.sm,
                onPressed: canSend ? () => Navigator.pop(ctx, true) : null,
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.sendBonus(e.userId, area, seconds);
      _snack('Bônus de +$seconds s enviado para ${e.name}!');
    } on ApiException catch (err) {
      _snack(err.message);
    } catch (_) {
      _snack('Falha ao enviar o bônus.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              onBack: widget.onBackToCurrent,
              onRefresh: widget.territoryId == null ? null : _reload,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final zon = context.zon;
    if (widget.territoryId == null) {
      return const EmptyState(
        icon: LucideIcons.map,
        title: 'Escolha uma zona no mapa',
        message: 'Toque numa zona do mapa para ver os dados dela por aqui.',
      );
    }
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _detail == null) {
      return EmptyState(
        icon: LucideIcons.cloudOff,
        color: zon.danger,
        title: 'Ops, algo deu errado',
        message: _error,
        action: GameButton(
          label: 'TENTAR DE NOVO',
          icon: LucideIcons.refreshCw,
          onPressed: _reload,
        ),
      );
    }
    final d = _detail!;
    final myId = widget.api.currentUserId;
    final iAmGovernor = d.governorUserId != null && d.governorUserId == myId;

    final myIndex = d.generalRanking.indexWhere((e) => e.userId == myId);
    final myInf =
        myIndex >= 0 ? d.generalRanking[myIndex].effectiveInfluence : 0.0;
    final myPos = myIndex >= 0 ? myIndex + 1 : null;

    final governor = d.governorUserId == null || d.generalRanking.isEmpty
        ? null
        : d.generalRanking.firstWhere((e) => e.userId == d.governorUserId,
            orElse: () => d.generalRanking.first);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: zon.brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _Header(detail: d, governor: governor),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: LucideIcons.zap,
                  label: 'SUA INFLUÊNCIA',
                  value: myInf.toStringAsFixed(0),
                  color: zon.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: LucideIcons.trophy,
                  label: 'SUA POSIÇÃO',
                  value: myPos == null ? '—' : '#$myPos',
                  color: zon.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.isPresent)
            GameButton(
              label: 'INICIAR DESAFIOS',
              icon: LucideIcons.brain,
              size: GameButtonSize.lg,
              expanded: true,
              onPressed: _startChallenge,
            )
          else
            GamePanel(
              color: Color.alphaBlend(
                  zon.territory.withValues(alpha: 0.10), zon.surface),
              borderColor: zon.territory.withValues(alpha: 0.45),
              shadow: false,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: zon.territory.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(LucideIcons.mapPinOff,
                        size: 16, color: zon.territory),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Você está só de visita por aqui. '
                      'Vá até a zona para realizar desafios e pontuar!',
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (iAmGovernor) ...[
            const SizedBox(height: 12),
            GameButton(
              label: 'PERSONALIZAR TERRITÓRIO',
              icon: LucideIcons.palette,
              variant: GameButtonVariant.secondary,
              expanded: true,
              onPressed: () => _customize(d),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            icon: LucideIcons.users,
            title: 'Jogadores',
            color: zon.territory,
            trailing: GameChip(
              label: '${d.generalRanking.length}',
              color: zon.territory,
              mode: GameChipMode.tonal,
            ),
          ),
          const SizedBox(height: 12),
          if (d.generalRanking.isEmpty)
            const EmptyState(
              icon: LucideIcons.users,
              title: 'Nenhum jogador ativo ainda',
              message: 'Seja quem estreia esta zona!',
            )
          else
            for (final e in d.generalRanking)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlayerRow(
                  entry: e,
                  isGovernor: e.userId == d.governorUserId,
                  isMe: e.userId == myId,
                  onTap: () => _openPlayer(e),
                  onSendBonus: e.userId == myId
                      ? null
                      : () => _sendBonus(e),
                ),
              ),
        ],
      ),
    );
  }
}

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

const _classLabels = <String, String>{
  'CONQUISTADOR': 'Conquistador',
  'PESQUISADOR': 'Pesquisador',
  'MENTOR': 'Mentor',
  'EXPLORADOR': 'Explorador',
  'GUARDIAO': 'Guardião',
  'RECRUTADOR': 'Recrutador',
};

/// Linha de jogador no território: posição, foto, nome (+ tags), classes e influência.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.entry,
    required this.isGovernor,
    required this.isMe,
    required this.onTap,
    this.onSendBonus,
  });

  final RankingEntry entry;
  final bool isGovernor;
  final bool isMe;
  final VoidCallback onTap;
  final VoidCallback? onSendBonus;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final accent = entry.classes.isNotEmpty
        ? (kClassColors[entry.classes.first] ?? zon.brand)
        : zon.territory;

    return GamePanel(
      onTap: onTap,
      color: isMe
          ? Color.alphaBlend(zon.brand.withValues(alpha: 0.10), zon.surface)
          : null,
      borderColor: isMe ? zon.brand : null,
      padding: const EdgeInsets.all(12),
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
                style: AppText.label.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          AvatarRing(
            imageUrl: entry.avatarUrl,
            initial: entry.name.isNotEmpty ? entry.name[0] : '?',
            size: 40,
            ringColor: accent,
            ringWidth: 2,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong,
                      ),
                    ),
                    if (isGovernor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: zon.brand,
                          borderRadius: BorderRadius.circular(Corners.pill),
                        ),
                        child: Icon(LucideIcons.crown,
                            size: 10, color: zon.onBrand),
                      ),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: zon.brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(Corners.pill),
                        ),
                        child: Text('você',
                            style: AppText.caption.copyWith(
                                fontSize: 10, color: zon.brand)),
                      ),
                    ],
                  ],
                ),
                if (entry.classes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in entry.classes)
                        GameChip(
                          label: _classLabels[c] ?? c,
                          icon: classIcon(c),
                          color: kClassColors[c] ?? zon.territory,
                          mode: GameChipMode.tonal,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(LucideIcons.zap, size: 14, color: zon.info),
              const SizedBox(height: 2),
              Text(
                entry.effectiveInfluence.toStringAsFixed(0),
                style: AppText.numeric.copyWith(fontSize: 16),
              ),
            ],
          ),
          if (onSendBonus != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Enviar bônus de tempo',
              child: GestureDetector(
                onTap: () {
                  GameHaptics.tap();
                  onSendBonus!();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: zon.brand.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(LucideIcons.timer, size: 17, color: zon.brand),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero da zona: ícone + nome em destaque e a linha do governador
/// (avatar com anel + coroa em mini-pill, como no mapa).
class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.governor});

  final TerritoryDetail detail;
  final RankingEntry? governor;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    final color = AppColors.zoneColor(detail.color);
    final hasBg =
        detail.backgroundUrl != null && detail.backgroundUrl!.isNotEmpty;
    final fg = hasBg ? zon.onBrand : zon.onSurface;

    return GamePanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Corners.lg),
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
              color: hasBg ? Colors.transparent : color.withValues(alpha: 0.16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(zoneIcon(detail.iconName),
                            color: zon.onBrand, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          detail.displayName,
                          style: AppText.headline.copyWith(
                            fontWeight: FontWeight.w900,
                            color: fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (governor != null)
                    Row(
                      children: [
                        AvatarRing(
                          imageUrl: governor!.avatarUrl,
                          initial: governor!.name.isNotEmpty
                              ? governor!.name[0]
                              : '?',
                          size: 36,
                          ringColor: color,
                          ringWidth: 2,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: zon.brand,
                            borderRadius: BorderRadius.circular(Corners.pill),
                            border: Border.all(color: zon.surface, width: 1.5),
                          ),
                          child: Icon(LucideIcons.crown,
                              size: 10, color: zon.onBrand),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            governor!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong.copyWith(color: fg),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(LucideIcons.crown,
                            size: 16, color: hasBg ? zon.onBrand : color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Zona livre — conquiste este território!',
                            style: AppText.caption.copyWith(
                              color: hasBg
                                  ? zon.onBrand.withValues(alpha: 0.85)
                                  : zon.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ],
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
