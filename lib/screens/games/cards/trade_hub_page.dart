import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/backend_config.dart';
import '../../../models/catalog_card.dart';
import '../../../services/catalog_api_service.dart';
import '../../../services/session_store.dart';
import '../../../services/trade_api_service.dart';
import '../../../services/wishlist_api_service.dart';
import '../../../util/card_image_url.dart' show BundledPlayCardImage;
import 'card_game_ui_theme.dart';
import 'trade_room_page.dart';
import 'wishlist_editor_page.dart';

/// Wishlist capacity shown in the trade hub (UI copy; server may differ).
const int kTradeHubWishlistMax = 15;

class TradeHubPage extends StatefulWidget {
  const TradeHubPage({super.key});

  @override
  State<TradeHubPage> createState() => _TradeHubPageState();
}

class _TradeHubPageState extends State<TradeHubPage> {
  final _wishlistApi = WishlistApiService();
  final _catalogApi = CatalogApiService();
  final _tradeMessageCtrl = TextEditingController();

  List<CatalogCard> _wishlistPreview = [];
  int _wishlistCount = 0;
  bool _loadingWishlist = true;
  String? _wishlistError;

  @override
  void initState() {
    super.initState();
    _loadWishlistPreview();
  }

  @override
  void dispose() {
    _tradeMessageCtrl.dispose();
    super.dispose();
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _loadWishlistPreview() async {
    setState(() {
      _loadingWishlist = true;
      _wishlistError = null;
    });
    final userId = await _userId();
    try {
      final ids = await _wishlistApi.getWishlist(userId: userId);
      final count = ids.length;
      final previewIds = ids.take(3).toList();
      List<CatalogCard> preview = [];
      if (previewIds.isNotEmpty) {
        final catalog = await _catalogApi.fetchCatalog(userId: userId);
        final byId = {for (final c in catalog) c.cardId: c};
        for (final id in previewIds) {
          final c = byId[id];
          if (c != null) preview.add(c);
        }
      }
      if (!mounted) return;
      setState(() {
        _wishlistCount = count;
        _wishlistPreview = preview;
        _loadingWishlist = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wishlistError = e.toString();
        _wishlistCount = 0;
        _wishlistPreview = [];
        _loadingWishlist = false;
      });
    }
  }

  void _onRandomTrade() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Random matchmaking is not available yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showFriendTradeDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(200),
      builder: (_) => _FriendTradeDialog(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CardGameUiTheme.bg,
      appBar: AppBar(
        title: const Text('Trade'),
        backgroundColor: CardGameUiTheme.bg,
        foregroundColor: CardGameUiTheme.onDark,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: CardGameUiTheme.gold,
        onRefresh: _loadWishlistPreview,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TradeHubTopTile(
                      icon: Icons.shuffle_rounded,
                      title: 'Random trade',
                      subtitle: 'Match with any player looking to trade',
                      onTap: _onRandomTrade,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TradeHubTopTile(
                      icon: Icons.group_rounded,
                      title: 'Trade with a friend',
                      subtitle: 'Room code',
                      onTap: _showFriendTradeDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _WishlistPreviewPanel(
                loading: _loadingWishlist,
                error: _wishlistError,
                count: _wishlistCount,
                maxCount: kTradeHubWishlistMax,
                previewCards: _wishlistPreview,
                onOpenFullWishlist: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const WishlistEditorPage()),
                ),
                onRetry: _loadWishlistPreview,
              ),
              const SizedBox(height: 22),
              _TradeMessageSection(controller: _tradeMessageCtrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeHubTopTile extends StatelessWidget {
  const _TradeHubTopTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: CardGameUiTheme.panel.withAlpha(240),
            border: Border.all(color: CardGameUiTheme.gold.withAlpha(90), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(35),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: CardGameUiTheme.gold),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CardGameUiTheme.onDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CardGameUiTheme.onDark.withAlpha(150),
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistPreviewPanel extends StatelessWidget {
  const _WishlistPreviewPanel({
    required this.loading,
    required this.error,
    required this.count,
    required this.maxCount,
    required this.previewCards,
    required this.onOpenFullWishlist,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final int count;
  final int maxCount;
  final List<CatalogCard> previewCards;
  final VoidCallback onOpenFullWishlist;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenFullWishlist,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: CardGameUiTheme.panel.withAlpha(235),
            border: Border.all(color: CardGameUiTheme.gold.withAlpha(85), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: CardGameUiTheme.orangeGlow.withAlpha(30),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_rounded, color: CardGameUiTheme.gold.withAlpha(230), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wishlist',
                      style: TextStyle(
                        color: CardGameUiTheme.onDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Text(
                    '$count / $maxCount',
                    style: TextStyle(
                      color: CardGameUiTheme.gold.withAlpha(220),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: CardGameUiTheme.onDark.withAlpha(160), size: 22),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to edit · showing up to 3 cards here',
                style: TextStyle(
                  color: CardGameUiTheme.onDark.withAlpha(140),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Could not load wishlist',
                        style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(200), fontSize: 13),
                      ),
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry', style: TextStyle(color: CardGameUiTheme.gold)),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 118,
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: CardGameUiTheme.gold,
                          ),
                        ),
                      )
                    : Row(
                        children: List.generate(3, (i) {
                          final card = i < previewCards.length ? previewCards[i] : null;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == 2 ? 0 : 6),
                              child: _WishlistThumb(card: card),
                            ),
                          );
                        }),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistThumb extends StatelessWidget {
  const _WishlistThumb({this.card});

  final CatalogCard? card;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CardGameUiTheme.gold.withAlpha(70), width: 1),
          color: CardGameUiTheme.elevated,
        ),
        clipBehavior: Clip.antiAlias,
        child: card == null
            ? Center(
                child: Icon(
                  Icons.add_card_outlined,
                  size: 28,
                  color: CardGameUiTheme.onDark.withAlpha(100),
                ),
              )
            : BundledPlayCardImage(
                cardId: card!.cardId,
                fit: BoxFit.cover,
                errorPlaceholder: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      card!.playerLabel,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CardGameUiTheme.onDark.withAlpha(180),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TradeMessageSection extends StatelessWidget {
  const _TradeMessageSection({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Trading message',
          style: TextStyle(
            color: CardGameUiTheme.onDark,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 4,
          minLines: 3,
          style: const TextStyle(color: CardGameUiTheme.onDark, fontSize: 14, height: 1.35),
          cursorColor: CardGameUiTheme.gold,
          decoration: InputDecoration(
            hintText: 'Type a message to your trade partner…',
            hintStyle: TextStyle(color: CardGameUiTheme.onDark.withAlpha(120)),
            filled: true,
            fillColor: CardGameUiTheme.elevated.withAlpha(240),
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: CardGameUiTheme.panelBorder.withAlpha(200)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: CardGameUiTheme.gold.withAlpha(180), width: 1.4),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Messaging is not connected yet — you can type for now; sending will be added later.',
          style: TextStyle(
            color: CardGameUiTheme.onDark.withAlpha(130),
            fontSize: 11.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _FriendTradeDialog extends StatefulWidget {
  const _FriendTradeDialog({required this.parentContext});

  /// Hub page context — still valid after this dialog is closed.
  final BuildContext parentContext;

  @override
  State<_FriendTradeDialog> createState() => _FriendTradeDialogState();
}

class _FriendTradeDialogState extends State<_FriendTradeDialog> {
  final _codeCtrl = TextEditingController();
  final _api = TradeApiService();
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<int> _userId() async {
    final s = await SessionStore.instance.load();
    return s?.userId ?? BackendConfig.devUserId;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final uid = await _userId();
      final code = await _api.createRoom(userId: uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      final parent = widget.parentContext;
      if (!parent.mounted) return;
      await showDialog<void>(
        context: parent,
        builder: (ctx) => AlertDialog(
          backgroundColor: CardGameUiTheme.panel,
          title: const Text('Room created', style: TextStyle(color: CardGameUiTheme.onDark)),
          content: SelectableText(
            'Share this code:\n\n$code',
            style: const TextStyle(
              color: CardGameUiTheme.onDark,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: CardGameUiTheme.gold)),
            ),
          ],
        ),
      );
      if (!parent.mounted) return;
      Navigator.of(parent).push<void>(
        MaterialPageRoute<void>(builder: (_) => TradeRoomPage(roomCode: code)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final raw = _codeCtrl.text.trim().toUpperCase();
    if (raw.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the room code')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final uid = await _userId();
      await _api.joinRoom(code: raw, userId: uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      final parent = widget.parentContext;
      if (parent.mounted) {
        Navigator.of(parent).push<void>(
          MaterialPageRoute<void>(builder: (_) => TradeRoomPage(roomCode: raw)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: CardGameUiTheme.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CardGameUiTheme.gold.withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: CardGameUiTheme.orangeGlow.withAlpha(40),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trade with a friend',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CardGameUiTheme.onDark,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a room and share the code, or join with your partner\'s code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(150), fontSize: 12.5, height: 1.3),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                    )
                  : const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Create room'),
              style: FilledButton.styleFrom(
                backgroundColor: CardGameUiTheme.gold.withAlpha(230),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Join room',
              style: TextStyle(
                color: CardGameUiTheme.onDark.withAlpha(200),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(color: CardGameUiTheme.onDark, letterSpacing: 2, fontWeight: FontWeight.w600),
              cursorColor: CardGameUiTheme.gold,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
              decoration: InputDecoration(
                hintText: 'e.g. AB3K9M',
                hintStyle: TextStyle(color: CardGameUiTheme.onDark.withAlpha(100)),
                filled: true,
                fillColor: CardGameUiTheme.elevated.withAlpha(230),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: CardGameUiTheme.panelBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: CardGameUiTheme.gold.withAlpha(180)),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : _join,
              style: OutlinedButton.styleFrom(
                foregroundColor: CardGameUiTheme.gold,
                side: BorderSide(color: CardGameUiTheme.gold.withAlpha(160)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Join room', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: CardGameUiTheme.onDark.withAlpha(180))),
            ),
          ],
        ),
      ),
    );
  }
}
