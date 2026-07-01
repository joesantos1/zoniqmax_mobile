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
                GestureDetector(
                  onTap: () => setState(() => _color = entry.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: _color == entry.key ? 5 : 2,
                      ),
                    ),
                  ),
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
                GestureDetector(
                  onTap: () => setState(() => _icon = entry.key),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _icon == entry.key
                          ? AppColors.orange
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _icon == entry.key
                            ? AppColors.orange
                            : AppColors.line,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(entry.value, color: AppColors.ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('IMAGEM DE FUNDO'),
          ComicPanel(
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
                    child: const Text('Sem imagem de fundo'),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _uploadingBg ? null : _pickBackground,
                  icon: _uploadingBg
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.image, size: 18),
                  label: const Text('Escolher imagem'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ink, width: 2),
                    foregroundColor: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.ink))
                : const Text('SALVAR'),
          ),
        ],
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
            style: const TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}
