import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../services/packs_api_service.dart';
import '../../../services/session_store.dart';
import 'pack_image_paths.dart';
import 'pack_reveal_screen.dart';

abstract final class _OpenPacksTheme {
  static const Color bg = Color(0xFF0A0A1A);
  static const Color elevated = Color(0xFF12122A);
  static const Color gold = Color(0xFFFFD700);
  static const Color onDark = Color(0xFFF5F5FF);
}

class OpenPacksPage extends StatefulWidget {
  const OpenPacksPage({super.key});

  @override
  State<OpenPacksPage> createState() => _OpenPacksPageState();
}

class _OpenPacksPageState extends State<OpenPacksPage> {
  final _api = PacksApiService();
  bool _opening = false;

  Future<void> _openStandard() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final session = await SessionStore.instance.load();
      final userId = session?.userId ?? BackendConfig.devUserId;
      final cards = await _api.openStandardPack(userId: userId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PackRevealScreen(cards: cards),
        ),
      );
    } on PacksApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _OpenPacksTheme.bg,
      appBar: AppBar(
        title: const Text('Open packs'),
        backgroundColor: _OpenPacksTheme.bg,
        foregroundColor: _OpenPacksTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Tap a pack slot to open (standard pack is wired today). Add artwork under assets/images/pack_tiles/ — see PACK_IMAGES.txt there.',
            style: TextStyle(
              color: _OpenPacksTheme.onDark.withAlpha(200),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.92,
            children: [
              _PackImageSlot(
                imageAsset: PackImagePaths.standardPack,
                busy: _opening,
                onTap: _openStandard,
              ),
              const _PackImageSlot(
                imageAsset: PackImagePaths.premiumPack,
                onTap: null,
              ),
              const _PackImageSlot(
                imageAsset: PackImagePaths.specialPack,
                onTap: null,
              ),
              const _PackImageSlot(
                imageAsset: PackImagePaths.eventPack,
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackImageSlot extends StatelessWidget {
  const _PackImageSlot({
    required this.imageAsset,
    this.onTap,
    this.busy = false,
  });

  final String imageAsset;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _OpenPacksTheme.elevated,
            border: Border.all(
              color: _OpenPacksTheme.gold.withAlpha(100),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
                ),
                if (busy)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _OpenPacksTheme.gold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
