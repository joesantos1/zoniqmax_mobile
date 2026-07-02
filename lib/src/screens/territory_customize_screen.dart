import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api_client.dart';
import '../image_compress.dart';
import '../models.dart';
import '../theme.dart';

/// Personalização da zona pelo governador: nome, cor, ícone e imagem de fundo.
class TerritoryCustomizeScreen extends StatefulWidget {
  const TerritoryCustomizeScreen({
    super.key,
    required this.api,
    required this.detail,
  });

  final ApiClient api;
  final TerritoryDetail detail;

  @override
  State<TerritoryCustomizeScreen> createState() =>
      _TerritoryCustomizeScreenState();
}

class _TerritoryCustomizeScreenState extends State<TerritoryCustomizeScreen> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.detail.customName ?? '');
  late String? _color = widget.detail.color;
  late String? _icon = widget.detail.iconName;
  late String? _bgUrl = widget.detail.backgroundUrl;

  bool _saving = false;
  bool _uploadingBg = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBackground() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _uploadingBg = true);
      final raw = await picked.readAsBytes();
      final bytes = await compressImageUnder1MB(raw); // garante < 1 MB
      final url = await widget.api.uploadImage(bytes, picked.name);
      if (!mounted) return;
      setState(() {
        _bgUrl = url;
        _uploadingBg = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingBg = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha no upload: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.customizeTerritory(
        widget.detail.id,
        customName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        color: _color,
        iconName: _icon,
        backgroundUrl: _bgUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return Scaffold(
      appBar: AppBar(title: const Text('PERSONALIZAR TERRITÓRIO')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Label('NOME DO TERRITÓRIO'),
          TextField(
            controller: _nameCtrl,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Ex.: Fortaleza do Joel'),
          ),
          const SizedBox(height: 12),
          const _Label('COR'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in AppColors.zonePalette.entries)
                _ColorSwatch(
                  color: entry.value,
                  selected: _color == entry.key,
                  onTap: () => setState(() => _color = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('ÍCONE'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in kZoneIcons.entries)
                _IconSwatch(
                  icon: entry.value,
                  selected: _icon == entry.key,
                  onTap: () => setState(() => _icon = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('IMAGEM DE FUNDO'),
          GamePanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (_bgUrl != null && _bgUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_bgUrl!,
                        height: 120, width: double.infinity, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 80,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.image,
                            size: 24, color: zon.onSurfaceMuted),
                        const SizedBox(height: 6),
                        Text('Sem imagem de fundo ainda',
                            style: AppText.caption
                                .copyWith(color: zon.onSurfaceMuted)),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                GameButton(
                  label: 'ESCOLHER IMAGEM',
                  icon: LucideIcons.image,
                  variant: GameButtonVariant.secondary,
                  size: GameButtonSize.sm,
                  loading: _uploadingBg,
                  onPressed: _uploadingBg ? null : _pickBackground,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GameButton(
            label: 'SALVAR',
            icon: LucideIcons.check,
            expanded: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// Swatch de cor da zona: quadrado "chunky" pressionável; selecionado mostra
/// um check branco e borda mais grossa.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GamePressable(
      onTap: onTap,
      faceColor: color,
      borderColor: selected ? zon.surface : Color.lerp(color, Colors.black, 0.15)!,
      edgeColor: Color.lerp(color, Colors.black, 0.25)!,
      borderWidth: selected ? 3 : 2,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: selected
            ? Icon(LucideIcons.check, size: 22, color: zon.onBrand)
            : null,
      ),
    );
  }
}

/// Swatch de ícone da zona: quadrado "chunky"; selecionado ganha tinta e
/// borda da marca.
class _IconSwatch extends StatelessWidget {
  const _IconSwatch({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zon = context.zon;
    return GamePressable(
      onTap: onTap,
      faceColor: selected
          ? Color.alphaBlend(zon.brand.withValues(alpha: 0.12), zon.surface)
          : zon.surface,
      borderColor: selected ? zon.brand : zon.outline,
      edgeColor: selected
          ? Color.lerp(zon.brand, Colors.black, 0.25)!
          : zon.neutralEdge,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon,
            size: 22, color: selected ? zon.brand : zon.onSurface),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: AppText.label
                .copyWith(color: context.zon.onSurfaceMuted)),
      );
}
