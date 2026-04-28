class ShopItem {
  const ShopItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.price,
    required this.quantityAvailable,
    this.subtitle,
    this.originalPrice,
    this.imageUrl,
    this.badge,
    this.isFeatured = false,
    this.description,
  });

  final int itemId;
  final String name;
  final String? subtitle;
  final String category;
  final double price;
  final double? originalPrice;
  final int quantityAvailable;
  final String? imageUrl;
  final String? badge;
  final bool isFeatured;
  final String? description;

  bool get inStock => quantityAvailable > 0;

  String get formattedPrice => '\$${price.toStringAsFixed(2)}';
  String? get formattedOriginalPrice =>
      originalPrice != null ? '\$${originalPrice!.toStringAsFixed(2)}' : null;

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      itemId: (json['item_id'] as num).toInt(),
      name: json['name'] as String,
      subtitle: json['subtitle'] as String?,
      category: json['category'] as String? ?? 'All Items',
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      quantityAvailable: (json['quantity_available'] as num).toInt(),
      imageUrl: json['image_url'] as String?,
      badge: json['badge'] as String?,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      description: json['description'] as String?,
    );
  }
}
