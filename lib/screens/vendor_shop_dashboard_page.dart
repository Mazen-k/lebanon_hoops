import 'package:flutter/material.dart';

import '../models/shop_vendor_session.dart';
import '../services/shop_vendor_auth_api_service.dart';
import '../theme/colors.dart';

const _kCategories = ['Jerseys', 'Headwear', 'Memorabilia', 'Training', 'Other'];

/// Single hub for a shop owner: items, photos, pricing, and stock.
class VendorShopDashboardPage extends StatefulWidget {
  const VendorShopDashboardPage({
    super.key,
    required this.session,
    required this.onSignedOut,
  });

  final ShopVendorSession session;
  final Future<void> Function() onSignedOut;

  @override
  State<VendorShopDashboardPage> createState() => _VendorShopDashboardPageState();
}

class _VendorShopDashboardPageState extends State<VendorShopDashboardPage> {
  final _api = ShopVendorAuthApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  ShopVendorSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listItems(s.token);
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } on ShopVendorApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _itemId(Map<String, dynamic> m) {
    final v = m['item_id'] ?? m['itemId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.parse(v.toString());
  }

  List<Map<String, dynamic>> _parsePhotos(Map<String, dynamic> item) {
    final raw = item['photos'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  // ── Add item ──────────────────────────────────────────────────────────────

  Future<void> _addItem() async {
    final nameCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final origPriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final imageCtrl = TextEditingController();
    final badgeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var category = _kCategories[0];
    var isFeatured = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => _SheetScaffold(
              title: 'New item',
              subtitle: 'Add a product to your shop. You can add extra photos once it is created.',
              icon: Icons.add_box_rounded,
              primaryLabel: 'Create item',
              onPrimary: () {
                final p = double.tryParse(priceCtrl.text.trim());
                final q = int.tryParse(qtyCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty || p == null || q == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name, price and quantity are required.'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              onDismiss: () => Navigator.pop(ctx, false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ShopTextField(controller: nameCtrl, label: 'Item name', hint: 'e.g. Home Jersey', icon: Icons.shopping_bag_outlined, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: subtitleCtrl, label: 'Subtitle', hint: 'e.g. 2024 Edition', icon: Icons.short_text_rounded, textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 12),
                  _CategoryDropdown(value: category, onChanged: (v) => setSheet(() => category = v!)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _ShopTextField(controller: priceCtrl, label: 'Price (USD)', hint: '0.00', icon: Icons.attach_money_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 12),
                    Expanded(child: _ShopTextField(controller: origPriceCtrl, label: 'Original price', hint: 'optional', icon: Icons.money_off_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: qtyCtrl, label: 'Quantity available', hint: '0', icon: Icons.inventory_2_outlined, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: imageCtrl, label: 'Main image URL', hint: 'https://…', icon: Icons.image_outlined, keyboardType: TextInputType.url),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: badgeCtrl, label: 'Badge', hint: 'e.g. Authentic, Limited', icon: Icons.label_outline_rounded, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: descCtrl, label: 'Description', hint: 'optional', icon: Icons.notes_rounded, textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 16),
                  _SwitchRow(title: 'Featured item', subtitle: 'Featured items appear as the hero card in the fan shop.', value: isFeatured, onChanged: (v) => setSheet(() => isFeatured = v)),
                ],
              ),
            ),
          ),
        );
      },
    );

    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim());
    final origPrice = double.tryParse(origPriceCtrl.text.trim());
    final qty = int.tryParse(qtyCtrl.text.trim());
    final imageUrl = imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim();
    final badge = badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim();
    final desc = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
    final subtitle = subtitleCtrl.text.trim().isEmpty ? null : subtitleCtrl.text.trim();
    for (final c in [nameCtrl, subtitleCtrl, priceCtrl, origPriceCtrl, qtyCtrl, imageCtrl, badgeCtrl, descCtrl]) {
      c.dispose();
    }
    if (ok != true || !mounted || name.isEmpty || price == null || qty == null) return;

    try {
      await _api.createItem(
        s.token,
        name: name,
        category: category,
        price: price,
        quantityAvailable: qty,
        subtitle: subtitle,
        originalPrice: origPrice,
        imageUrl: imageUrl,
        badge: badge,
        isFeatured: isFeatured,
        description: desc,
      );
      await _load();
    } on ShopVendorApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Edit item ─────────────────────────────────────────────────────────────

  Future<void> _editItem(Map<String, dynamic> item) async {
    final id = _itemId(item);
    final nameCtrl = TextEditingController(text: '${item['name'] ?? ''}');
    final subtitleCtrl = TextEditingController(text: '${item['subtitle'] ?? ''}');
    final priceCtrl = TextEditingController(text: '${item['price'] ?? ''}');
    final origPriceCtrl = TextEditingController(text: '${item['original_price'] ?? ''}');
    final qtyCtrl = TextEditingController(text: '${item['quantity_available'] ?? 0}');
    final imageCtrl = TextEditingController(text: '${item['image_url'] ?? ''}');
    final badgeCtrl = TextEditingController(text: '${item['badge'] ?? ''}');
    final descCtrl = TextEditingController(text: '${item['description'] ?? ''}');
    var category = (_kCategories.contains('${item['category']}')) ? '${item['category']}' : _kCategories[0];
    var isFeatured = item['is_featured'] == true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => _SheetScaffold(
              title: 'Edit item',
              subtitle: 'Update how this product appears in the fan shop.',
              icon: Icons.edit_rounded,
              primaryLabel: 'Save changes',
              onPrimary: () {
                final p = double.tryParse(priceCtrl.text.trim());
                final q = int.tryParse(qtyCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty || p == null || q == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name, price and quantity are required.'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              onDismiss: () => Navigator.pop(ctx, false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ShopTextField(controller: nameCtrl, label: 'Item name', hint: 'Display name', icon: Icons.shopping_bag_outlined, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: subtitleCtrl, label: 'Subtitle', hint: 'optional', icon: Icons.short_text_rounded, textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 12),
                  _CategoryDropdown(value: category, onChanged: (v) => setSheet(() => category = v!)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _ShopTextField(controller: priceCtrl, label: 'Price (USD)', hint: '0.00', icon: Icons.attach_money_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 12),
                    Expanded(child: _ShopTextField(controller: origPriceCtrl, label: 'Original price', hint: 'optional', icon: Icons.money_off_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: qtyCtrl, label: 'Quantity available', hint: '0', icon: Icons.inventory_2_outlined, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: imageCtrl, label: 'Main image URL', hint: 'https://…', icon: Icons.image_outlined, keyboardType: TextInputType.url),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: badgeCtrl, label: 'Badge', hint: 'e.g. Authentic', icon: Icons.label_outline_rounded, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  _ShopTextField(controller: descCtrl, label: 'Description', hint: 'optional', icon: Icons.notes_rounded, textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 16),
                  _SwitchRow(title: 'Featured item', subtitle: 'Featured items appear as the hero card in the fan shop.', value: isFeatured, onChanged: (v) => setSheet(() => isFeatured = v)),
                ],
              ),
            ),
          ),
        );
      },
    );

    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim());
    final origPrice = double.tryParse(origPriceCtrl.text.trim());
    final qty = int.tryParse(qtyCtrl.text.trim());
    final imageUrl = imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim();
    final badge = badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim();
    final desc = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
    final subtitle = subtitleCtrl.text.trim().isEmpty ? null : subtitleCtrl.text.trim();
    for (final c in [nameCtrl, subtitleCtrl, priceCtrl, origPriceCtrl, qtyCtrl, imageCtrl, badgeCtrl, descCtrl]) {
      c.dispose();
    }
    if (ok != true || !mounted || name.isEmpty || price == null || qty == null) return;

    try {
      await _api.patchItem(
        s.token,
        itemId: id,
        name: name,
        subtitle: subtitle,
        category: category,
        price: price,
        originalPrice: origPrice,
        quantityAvailable: qty,
        imageUrl: imageUrl,
        badge: badge,
        isFeatured: isFeatured,
        description: desc,
      );
      await _load();
    } on ShopVendorApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Delete item ───────────────────────────────────────────────────────────

  Future<void> _deleteItem(int itemId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item'),
        content: Text('Remove "$name" from your shop? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteItem(s.token, itemId: itemId);
      await _load();
    } on ShopVendorApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<void> _addPhoto(int itemId) async {
    final urlCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _SheetScaffold(
          title: 'Add photo',
          subtitle: 'Paste a direct image URL (HTTPS). It will appear in the item gallery.',
          icon: Icons.add_photo_alternate_rounded,
          primaryLabel: 'Add to gallery',
          onPrimary: () {
            if (urlCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Paste an image URL.'), behavior: SnackBarBehavior.floating),
              );
              return;
            }
            Navigator.pop(ctx, true);
          },
          onDismiss: () => Navigator.pop(ctx, false),
          child: _ShopTextField(controller: urlCtrl, label: 'Image URL', hint: 'https://…', icon: Icons.link_rounded, keyboardType: TextInputType.url),
        ),
      ),
    );
    if (ok != true || !mounted) { urlCtrl.dispose(); return; }
    final url = urlCtrl.text.trim();
    urlCtrl.dispose();
    if (url.isEmpty) return;

    try {
      await _api.addItemPhoto(s.token, itemId: itemId, photoUrl: url);
      await _load();
    } on ShopVendorApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deletePhoto(int photoId) async {
    try {
      await _api.deletePhoto(s.token, photoId: photoId);
      await _load();
    } on ShopVendorApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(s.shopName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(tooltip: 'Sign out', onPressed: widget.onSignedOut, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha((255 * 0.35).round()), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: FloatingActionButton.extended(
          onPressed: _loading ? null : _addItem,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add item', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceContainerLow, AppColors.surface],
          ),
        ),
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: _loading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator(color: AppColors.primary))],
                )
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      children: [
                        _ShopHeroCard(session: s),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(width: 4, height: 22, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 10),
                            Text('YOUR ITEMS', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_items.isEmpty)
                          _EmptyItemsCard(onAdd: _addItem)
                        else
                          ..._items.map((item) => _buildItemCard(context, item)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final id = _itemId(item);
    final name = '${item['name'] ?? ''}';
    final price = (item['price'] is num) ? (item['price'] as num).toDouble() : double.tryParse('${item['price']}') ?? 0;
    final qty = (item['quantity_available'] is num) ? (item['quantity_available'] as num).toInt() : int.tryParse('${item['quantity_available']}') ?? 0;
    final category = '${item['category'] ?? ''}';
    final isFeatured = item['is_featured'] == true;
    final photos = _parsePhotos(item);
    final lowStock = qty < 10 && qty > 0;
    final outOfStock = qty == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outlineVariant.withAlpha((255 * 0.85).round())),
            boxShadow: [BoxShadow(color: AppColors.onSurface.withAlpha((255 * 0.04).round()), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
              collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(gradient: AppColors.signatureGradient, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.shopping_bag_rounded, color: AppColors.onPrimary, size: 26),
              ),
              title: Text(name, style: const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3, color: AppColors.onSurface)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text('\$${price.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: outOfStock
                            ? AppColors.error.withAlpha(30)
                            : lowStock
                                ? AppColors.secondary.withAlpha(30)
                                : AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        outOfStock ? 'Sold out' : '$qty left',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: outOfStock ? AppColors.error : lowStock ? AppColors.secondary : AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              iconColor: AppColors.primary,
              collapsedIconColor: AppColors.secondary,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(label: category, icon: Icons.category_outlined),
                    if (isFeatured) _Chip(label: 'Featured', icon: Icons.star_rounded, color: AppColors.primary),
                    if (item['badge'] != null && '${item['badge']}'.isNotEmpty)
                      _Chip(label: '${item['badge']}', icon: Icons.label_rounded),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _editItem(item),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Edit'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addPhoto(id),
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                        label: const Text('Photo'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: AppColors.outlineVariant)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _deleteItem(id, name),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        side: BorderSide(color: AppColors.error.withAlpha(120)),
                        foregroundColor: AppColors.error,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Gallery', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (photos.isEmpty)
                  Text('No extra photos yet — add some to showcase the product.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary, height: 1.35))
                else
                  ...photos.map((ph) {
                    final pid = ph['photo_id'];
                    final url = '${ph['photo_url'] ?? ''}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, color: AppColors.secondary.withAlpha((255 * 0.8).round())),
                          const SizedBox(width: 10),
                          Expanded(child: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                          if (pid != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              onPressed: () => _deletePhoto(pid is int ? pid : (pid as num).toInt()),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero card ──────────────────────────────────────────────────────────────

class _ShopHeroCard extends StatelessWidget {
  const _ShopHeroCard({required this.session});

  final ShopVendorSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.signatureGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withAlpha((255 * 0.28).round()), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.onPrimary.withAlpha((255 * 0.15).round()), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.store_rounded, color: AppColors.onPrimary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  session.shopName,
                  style: const TextStyle(fontFamily: 'Lexend', fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1, color: AppColors.onPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Owner · ${session.username}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onPrimary.withAlpha((255 * 0.88).round()), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyItemsCard extends StatelessWidget {
  const _EmptyItemsCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.outlineVariant)),
      child: Column(
        children: [
          Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.primary.withAlpha((255 * 0.5).round())),
          const SizedBox(height: 16),
          Text('No items yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Add your first product — set the name, price, stock, and upload photos.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.4)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
          ),
        ],
      ),
    );
  }
}

// ── Sheet chrome ───────────────────────────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDismiss,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(99))),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: AppColors.signatureGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: AppColors.primary.withAlpha((255 * 0.25).round()), blurRadius: 12, offset: const Offset(0, 6))],
                          ),
                          child: Icon(icon, color: AppColors.onPrimary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontFamily: 'Lexend', fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -0.6, height: 1.1, color: AppColors.onSurface)),
                              const SizedBox(height: 8),
                              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDismiss,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppColors.outlineVariant), foregroundColor: AppColors.onSurface),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: AppColors.signatureGradient),
                      child: ElevatedButton(
                        onPressed: onPrimary,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: AppColors.onPrimary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text(primaryLabel, style: const TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.w900)),
                      ),
                    ),
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

// ── Form widgets ───────────────────────────────────────────────────────────

class _ShopTextField extends StatelessWidget {
  const _ShopTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.secondary),
          items: _kCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: Theme.of(context).textTheme.bodyLarge)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary, height: 1.35)),
        value: value,
        activeTrackColor: AppColors.primary.withAlpha((255 * 0.35).round()),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.primary : AppColors.outline),
        onChanged: onChanged,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}
