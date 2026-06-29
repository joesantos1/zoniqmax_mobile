import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import 'settings_screen.dart';
import 'tab_header.dart';

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
      final bytes = await picked.readAsBytes();
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.ink),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.ink),
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
                IconButton(
                  onPressed: _me == null ? null : _openSettings,
                  icon: const Icon(LucideIcons.settings,
                      color: AppColors.muted, size: 22),
                  tooltip: 'Configurações',
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
          ],
        ),
      );
    }

    final me = _me!;
    final maxXp = me.knowledgeXp.fold<double>(1, (m, e) => e.xp > m ? e.xp : m);
    final hasPhoto = me.avatarUrl != null && me.avatarUrl!.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.orange,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // cabeçalho com avatar
        ComicPanel(
          color: AppColors.orange,
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 3),
                      image: hasPhoto
                          ? DecorationImage(
                              image: NetworkImage(me.avatarUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: _uploading
                        ? const CircularProgressIndicator(
                            color: AppColors.paper, strokeWidth: 2)
                        : (hasPhoto
                            ? null
                            : Text(
                                me.displayName.isNotEmpty
                                    ? me.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppColors.paper,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 28),
                              )),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _uploading ? null : _showSourceSheet,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.ink, width: 2),
                        ),
                        child: const Icon(LucideIcons.pencil,
                            size: 13, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.displayName,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    if (me.nickname != null && me.nickname!.isNotEmpty)
                      Text(me.name,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    Text(me.email,
                        style: const TextStyle(
                            color: AppColors.ink, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // stats gerais
        Row(
          children: [
            Expanded(
                child: StatTile(
                    icon: LucideIcons.zap,
                    label: 'XP TOTAL',
                    value: me.totalXp.toStringAsFixed(0),
                    color: AppColors.orange)),
            const SizedBox(width: 12),
            Expanded(
                child: StatTile(
                    icon: LucideIcons.target,
                    label: 'ACERTO',
                    value: me.totalAttempts == 0
                        ? '—'
                        : '${me.accuracy.round()}%',
                    color: AppColors.green)),
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
                    color: AppColors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: StatTile(
                    icon: LucideIcons.hexagon,
                    label: 'TERRITÓRIOS',
                    value: '${me.territories.length}',
                    color: AppColors.brown)),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('MEUS TERRITÓRIOS'),
        if (me.territories.isEmpty)
          const ComicPanel(
            child: Text('Você ainda não participa de nenhum território. '
                'Jogue desafios numa zona para ganhar influência!'),
          )
        else
          ...me.territories.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ComicPanel(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(t.isGovernor ? LucideIcons.crown : LucideIcons.hexagon,
                        size: 20,
                        color: t.isGovernor ? AppColors.red : AppColors.brown),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(t.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    if (t.isGovernor)
                      const Padding(
                          padding: EdgeInsets.only(right: 6), child: Text('👑')),
                    Text('${t.effectiveInfluence.toStringAsFixed(0)} inf.',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        const _SectionTitle('XP POR ÁREA'),
        if (me.knowledgeXp.isEmpty)
          const ComicPanel(
            child: Text('Você ainda não ganhou XP. Resolva desafios para evoluir!'),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${xp.xp.toStringAsFixed(0)} XP',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.ink)),
      );
}
