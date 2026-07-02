import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../image_compress.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'settings_screen.dart';
import 'tab_header.dart';

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

/// Aba Perfil: avatar, stats gerais (XP total, acerto, tentativas, territórios),
/// lista de territórios em que participa e XP por área. Ícone de config no topo.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Me? _me;
  bool _loading = true;
  String? _error;
  bool _uploading = false;

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
      final me = await widget.api.me();
      if (!mounted) return;
      setState(() {
        _me = me;
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

  /// Atualização por pull-to-refresh (sem trocar a tela por um spinner).
  Future<void> _refresh() async {
    try {
      final me = await widget.api.me();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      final raw = await picked.readAsBytes();
      final bytes = await compressImageUnder1MB(raw); // garante < 1 MB
      await widget.api.uploadAvatar(bytes, picked.name);
      if (!mounted) return;
      setState(() => _uploading = false);
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao enviar a foto: $e')));
    }
  }

  void _showSourceSheet() {
    final zon = context.zon;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: zon.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Space.sm),
            ListTile(
              leading: Icon(LucideIcons.camera, color: zon.onSurface),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.image, color: zon.onSurface),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    final me = _me;
    if (me == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => SettingsScreen(api: widget.api, me: me),
        ))
        .then((changed) {
      if (changed == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'PERFIL',
              actions: [
                HeaderIconButton(
                  icon: LucideIcons.settings,
                  onTap: _me == null ? null : _openSettings,
                  tooltip: 'Configurações',
                  muted: true,
                ),
              ],
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final zon = context.zon;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: LucideIcons.cloudOff,
        color: zon.danger,
        title: 'Ops, algo deu errado',
        message: _error,
        action: GameButton(
          label: 'TENTAR DE NOVO',
          icon: LucideIcons.refreshCw,
          onPressed: _load,
        ),
      );
    }

    final me = _me!;
    final maxXp = me.knowledgeXp.fold<double>(1, (m, e) => e.xp > m ? e.xp : m);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: zon.brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _headerBand(me),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // stats gerais
                Row(
                  children: [
                    Expanded(
                        child: StatTile(
                            icon: LucideIcons.zap,
                            label: 'XP TOTAL',
                            value: me.totalXp.toStringAsFixed(0),
                            color: zon.xp)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatTile(
                            icon: LucideIcons.target,
                            label: 'ACERTO',
                            value: me.totalAttempts == 0
                                ? '—'
                                : '${me.accuracy.round()}%',
                            color: zon.success)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: StatTile(
                            icon: LucideIcons.activity,
                            label: 'TENTATIVAS',
                            value: '${me.totalAttempts}',
                            color: zon.info)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatTile(
                            icon: LucideIcons.hexagon,
                            label: 'TERRITÓRIOS',
                            value: '${me.territories.length}',
                            color: zon.territory)),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionHeader(
                      icon: LucideIcons.hexagon,
                      title: 'Meus territórios',
                      color: zon.territory),
                ),
                if (me.territories.isEmpty)
                  GamePanel(
                    child: Text(
                      'Você ainda não participa de nenhum território. '
                      'Jogue desafios numa zona para ganhar influência!',
                      style: AppText.body.copyWith(color: zon.onSurfaceMuted),
                    ),
                  )
                else
                  ...me.territories.map((t) => _territoryRow(t)),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionHeader(
                      icon: LucideIcons.zap,
                      title: 'XP por área',
                      color: zon.xp),
                ),
                if (me.knowledgeXp.isEmpty)
                  GamePanel(
                    child: Text(
                      'Você ainda não ganhou XP. Resolva desafios para evoluir!',
                      style: AppText.body.copyWith(color: zon.onSurfaceMuted),
                    ),
                  )
                else
                  ...me.knowledgeXp.map((xp) => _xpRow(xp, maxXp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Faixa laranja curvada do topo: avatar grande + nome + e-mail.
  Widget _headerBand(Me me) {
    final zon = context.zon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: zon.brand,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AvatarRing(
                  imageUrl: me.avatarUrl,
                  initial:
                      me.displayName.isNotEmpty ? me.displayName[0] : '?',
                  size: 88,
                  ringColor: zon.surface,
                ),
                if (_uploading)
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                        color: zon.onBrand, strokeWidth: 2.5),
                  ),
                // botão de trocar a foto sobreposto ao avatar
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: GestureDetector(
                    onTap: _uploading ? null : _showSourceSheet,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: zon.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: zon.surface, width: 2),
                        boxShadow: const [Shadows.soft],
                      ),
                      child: Icon(LucideIcons.camera,
                          size: 14, color: zon.onBrand),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            me.displayName,
            textAlign: TextAlign.center,
            style: AppText.headline.copyWith(color: zon.onBrand),
          ),
          if (me.nickname != null && me.nickname!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              me.name,
              textAlign: TextAlign.center,
              style: AppText.caption
                  .copyWith(color: zon.onBrand.withValues(alpha: 0.75)),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            me.email,
            textAlign: TextAlign.center,
            style: AppText.caption
                .copyWith(color: zon.onBrand.withValues(alpha: 0.75)),
          ),
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

  /// Linha de XP por área: ícone da área + barra de progresso + contador.
  Widget _xpRow(KnowledgeXp xp, double maxXp) {
    final accent = areaColor(xp.area);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
              child: Icon(areaIcon(xp.area), size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_areaLabels[xp.area] ?? xp.area,
                          style: AppText.bodyStrong),
                      XpCounter(
                        value: xp.xp.round(),
                        suffix: ' XP',
                        style: AppText.numeric
                            .copyWith(fontSize: 15, color: accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GameProgressBar(
                    value: (xp.xp / maxXp).clamp(0.0, 1.0),
                    color: accent,
                    height: 10,
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
