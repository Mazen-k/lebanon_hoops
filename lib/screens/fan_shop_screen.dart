import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../services/shop_api_service.dart';

class FanShopScreen extends StatefulWidget {
  const FanShopScreen({super.key});

  @override
  State<FanShopScreen> createState() => _FanShopScreenState();
}

class _FanShopScreenState extends State<FanShopScreen> {
  int _selectedCategory = 0;
  final List<String> _categories = [
    'All Items',
    'Jerseys',
    'Headwear',
    'Memorabilia',
    'Training',
  ];

  final _service = ShopApiService();
  List<ShopItem> _items = [];
  bool _loading = true;
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
      final category = _categories[_selectedCategory];
      final items = await _service.fetchItems(category: category);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  ShopItem? get _featured =>
      _items.where((i) => i.isFeatured).firstOrNull ?? (_items.isNotEmpty ? _items.first : null);

  List<ShopItem> get _standardItems {
    final f = _featured;
    if (f == null) return _items;
    return _items.where((i) => i.itemId != f.itemId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'FAN SHOP',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 20,
          ),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 128, left: 24, right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroBanner(context),
                const SizedBox(height: 48),
                _buildCategoryFilters(context),
                const SizedBox(height: 48),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: CircularProgressIndicator(),
                  ))
                else if (_error != null)
                  _buildError(context)
                else if (_items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Text(
                        'No items found.',
                        style: TextStyle(fontFamily: 'Inter', color: colorScheme.secondary),
                      ),
                    ),
                  )
                else ...[
                  if (_featured != null) ...[
                    _buildFeaturedProduct(context, _featured!),
                    const SizedBox(height: 32),
                  ],
                  if (_standardItems.isNotEmpty)
                    _buildProductGrid(context, _standardItems),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Could not load shop items.',
              style: TextStyle(fontFamily: 'Lexend', fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 340,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuB2F4mXAhrehyYkaSQPdQQ1dR2wxLNX1XPrcB6V6lxlXqCZf28yFRXtd2pT0w83wae8N2gmhS2unSlqSzgqUKlrfZfOZqtfHv7UsGARUI1rkCQM0_jo7Sm8eGGi1j8qHWHYkVeuAZQCIZARigfKNPpbSsmRA2uMMtbEpSXGK86y_Cv-zq9MFpzo9S8j9cyA9VIiFUKeZ4ug1XDvY9Hqcmup0pwY9T9D4Ntf36YqtfKgzTYBc450HXwfTDTx4xifUKB6fmHaJM2ake0a',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surface.withAlpha((255 * 0.4).round()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 32,
              left: 32,
              right: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: colorScheme.primary,
                    child: const Text(
                      'Limited Drop',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'REPRESENT THE LEGACY',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Explore the official 2024 Lebanese League collection. Authentic gear for the ultimate fan.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: colorScheme.onSurface.withAlpha((255 * 0.8).round()),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'SHOP EXCLUSIVES',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildCategoryFilters(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final isActive = _selectedCategory == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = index);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primary : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isActive
                    ? [BoxShadow(color: colorScheme.primary.withAlpha((255 * 0.2).round()), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedProduct(BuildContext context, ShopItem product) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: product.imageUrl != null
                    ? Image.network(product.imageUrl!, fit: BoxFit.cover, width: double.infinity)
                    : Container(color: colorScheme.surfaceContainerHighest),
              ),
              if (product.badge != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      product.badge!,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              if (!product.inStock)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withAlpha((255 * 0.45).round()),
                    alignment: Alignment.center,
                    child: const Text(
                      'SOLD OUT',
                      style: TextStyle(fontFamily: 'Lexend', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                    ),
                  ),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(32),
            color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: colorScheme.onSurface, height: 1.1),
                          ),
                          if (product.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              product.subtitle!,
                              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colorScheme.secondary),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${product.quantityAvailable} in stock',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: product.quantityAvailable < 10 ? colorScheme.error : colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: TextStyle(fontFamily: 'Lexend', fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.primary),
                        ),
                        if (product.formattedOriginalPrice != null)
                          Text(
                            product.formattedOriginalPrice!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: colorScheme.secondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: product.inStock ? () {} : null,
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                    label: Text(
                      product.inStock ? 'QUICK ADD' : 'SOLD OUT',
                      style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, List<ShopItem> products) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 32,
        mainAxisSpacing: 32,
        childAspectRatio: 0.5,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: colorScheme.surface,
                      child: product.imageUrl != null
                          ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                          : const SizedBox(),
                    ),
                    if (!product.inStock)
                      Container(
                        color: Colors.black.withAlpha((255 * 0.45).round()),
                        alignment: Alignment.center,
                        child: const Text(
                          'SOLD OUT',
                          style: TextStyle(fontFamily: 'Lexend', fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(fontFamily: 'Lexend', fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface, height: 1.1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                product.subtitle!,
                                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: colorScheme.secondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              '${product.quantityAvailable} left',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                color: product.quantityAvailable < 10 ? colorScheme.error : colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product.formattedPrice,
                            style: TextStyle(fontFamily: 'Lexend', fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                          ),
                          GestureDetector(
                            onTap: product.inStock ? () {} : null,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: product.inStock
                                    ? colorScheme.onInverseSurface
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.add,
                                color: product.inStock ? colorScheme.surface : colorScheme.secondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
