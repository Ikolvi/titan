/// E-commerce models for the Bazaar — the hero marketplace.
///
/// Maps to the DummyJSON API (https://dummyjson.com) — a real,
/// working REST API with products, categories, carts, and reviews.
///
/// Themed as a marketplace where heroes buy and sell their wares:
///   [Wares]          — A product available in the Bazaar
///   [WaresReview]    — A hero's review of purchased wares
///   [WaresCategory]  — A category (guild section) in the Bazaar
///   [Coffer]         — A shopping cart (treasure coffer)
///   [CofferItem]     — An item within a coffer
library;

// ---------------------------------------------------------------------------
// Wares — Product
// ---------------------------------------------------------------------------

/// A product available in the Bazaar marketplace.
///
/// Maps to a DummyJSON product with full details including
/// pricing, ratings, stock, reviews, and images.
class Wares {
  final int id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;
  final List<String> tags;
  final String? brand;
  final String? sku;
  final double? weight;
  final String? warrantyInformation;
  final String? shippingInformation;
  final String? availabilityStatus;
  final String? returnPolicy;
  final int? minimumOrderQuantity;
  final String thumbnail;
  final List<String> images;
  final List<WaresReview> reviews;

  const Wares({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.stock,
    required this.tags,
    this.brand,
    this.sku,
    this.weight,
    this.warrantyInformation,
    this.shippingInformation,
    this.availabilityStatus,
    this.returnPolicy,
    this.minimumOrderQuantity,
    required this.thumbnail,
    required this.images,
    required this.reviews,
  });

  /// The final price after discount.
  double get discountedPrice => price * (1 - discountPercentage / 100);

  /// Whether the item is low on stock (≤ 5 remaining).
  bool get isLowStock => stock <= 5;

  /// Creates [Wares] from a DummyJSON product JSON response.
  factory Wares.fromJson(Map<String, dynamic> json) => Wares(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    price: (json['price'] as num).toDouble(),
    discountPercentage: (json['discountPercentage'] as num).toDouble(),
    rating: (json['rating'] as num).toDouble(),
    stock: json['stock'] as int,
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    brand: json['brand'] as String?,
    sku: json['sku'] as String?,
    weight: (json['weight'] as num?)?.toDouble(),
    warrantyInformation: json['warrantyInformation'] as String?,
    shippingInformation: json['shippingInformation'] as String?,
    availabilityStatus: json['availabilityStatus'] as String?,
    returnPolicy: json['returnPolicy'] as String?,
    minimumOrderQuantity: json['minimumOrderQuantity'] as int?,
    thumbnail: json['thumbnail'] as String,
    images: (json['images'] as List?)?.cast<String>() ?? [],
    reviews:
        (json['reviews'] as List?)
            ?.map((e) => WaresReview.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  /// Serializes to JSON for POST/PUT requests.
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'price': price,
    'brand': brand,
    'stock': stock,
    'tags': tags,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Wares && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------------------------------------------------------------------
// WaresReview — Product Review
// ---------------------------------------------------------------------------

/// A hero's review of purchased wares.
///
/// Maps to a DummyJSON product review.
class WaresReview {
  final int rating;
  final String comment;
  final DateTime date;
  final String reviewerName;
  final String reviewerEmail;

  const WaresReview({
    required this.rating,
    required this.comment,
    required this.date,
    required this.reviewerName,
    required this.reviewerEmail,
  });

  /// Creates a [WaresReview] from a DummyJSON review JSON.
  factory WaresReview.fromJson(Map<String, dynamic> json) => WaresReview(
    rating: json['rating'] as int,
    comment: json['comment'] as String,
    date: DateTime.parse(json['date'] as String),
    reviewerName: json['reviewerName'] as String,
    reviewerEmail: json['reviewerEmail'] as String,
  );
}

// ---------------------------------------------------------------------------
// WaresCategory — Product Category
// ---------------------------------------------------------------------------

/// A category (guild section) in the Bazaar.
///
/// Maps to a DummyJSON category with slug, display name, and URL.
class WaresCategory {
  final String slug;
  final String name;
  final String url;

  const WaresCategory({
    required this.slug,
    required this.name,
    required this.url,
  });

  /// Creates a [WaresCategory] from a DummyJSON category JSON.
  factory WaresCategory.fromJson(Map<String, dynamic> json) => WaresCategory(
    slug: json['slug'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
  );
}

// ---------------------------------------------------------------------------
// Coffer — Shopping Cart
// ---------------------------------------------------------------------------

/// A shopping cart (treasure coffer) for a hero's purchases.
///
/// Maps to a DummyJSON cart response.
class Coffer {
  final int id;
  final List<CofferItem> products;
  final double total;
  final double discountedTotal;
  final int userId;
  final int totalProducts;
  final int totalQuantity;

  const Coffer({
    required this.id,
    required this.products,
    required this.total,
    required this.discountedTotal,
    required this.userId,
    required this.totalProducts,
    required this.totalQuantity,
  });

  /// Total savings from discounts.
  double get totalSavings => total - discountedTotal;

  /// Creates a [Coffer] from a DummyJSON cart JSON response.
  factory Coffer.fromJson(Map<String, dynamic> json) => Coffer(
    id: json['id'] as int,
    products: (json['products'] as List)
        .map((e) => CofferItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    total: (json['total'] as num).toDouble(),
    discountedTotal: (json['discountedTotal'] as num).toDouble(),
    userId: json['userId'] as int,
    totalProducts: json['totalProducts'] as int,
    totalQuantity: json['totalQuantity'] as int,
  );
}

// ---------------------------------------------------------------------------
// CofferItem — Cart Item
// ---------------------------------------------------------------------------

/// An individual item within a hero's coffer (cart).
///
/// Maps to a DummyJSON cart product entry.
class CofferItem {
  final int id;
  final String title;
  final double price;
  final int quantity;
  final double total;
  final double discountPercentage;
  final double discountedTotal;
  final String thumbnail;

  const CofferItem({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    required this.total,
    required this.discountPercentage,
    required this.discountedTotal,
    required this.thumbnail,
  });

  /// Creates a [CofferItem] from a DummyJSON cart product JSON.
  factory CofferItem.fromJson(Map<String, dynamic> json) => CofferItem(
    id: json['id'] as int,
    title: json['title'] as String,
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int,
    total: (json['total'] as num).toDouble(),
    discountPercentage: (json['discountPercentage'] as num).toDouble(),
    discountedTotal:
        (json['discountedTotal'] as num? ?? json['discountedPrice'] as num?)
            ?.toDouble() ??
        0.0,
    thumbnail: json['thumbnail'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CofferItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
