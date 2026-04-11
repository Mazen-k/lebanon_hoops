import 'package:flutter/material.dart';

import '../../../config/backend_config.dart';
import '../../../services/packs_api_service.dart';
import '../../../services/session_store.dart';
import '../../../theme/colors.dart';
import 'pack_reveal_screen.dart';

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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Open packs'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tap a pack to open. Cards are drawn at random from the database and saved to your account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Packs save to your logged-in user. Fallback id: ${BackendConfig.devUserId} if no session.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 24),
          _StandardPackTile(
            busy: _opening,
            onOpen: _openStandard,
          ),
        ],
      ),
    );
  }
}

class _StandardPackTile extends StatelessWidget {
  const _StandardPackTile({
    required this.busy,
    required this.onOpen,
  });

  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppColors.signatureGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(120),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(35),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              if (busy)
                const CircularProgressIndicator(color: AppColors.onPrimary),
              if (!busy)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 64, color: AppColors.onPrimary.withAlpha(240)),
                      const SizedBox(height: 12),
                      Text(
                        'STANDARD PACK',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to open • 4 random cards',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onPrimary.withAlpha(220),
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
