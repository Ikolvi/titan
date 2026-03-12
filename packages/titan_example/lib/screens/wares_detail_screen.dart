import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/bazaar_pillar.dart';

// ---------------------------------------------------------------------------
// WaresDetailScreen — Product detail with images, reviews, add-to-cart
// ---------------------------------------------------------------------------
//
// Demonstrates:
//   Spark (hooks)           — useEffect for loading trigger
//   Quarry + Envoy          — SWR data fetching with retry
//   Stale-while-revalidate  — Background refresh indicator
//   Atlas                   — Back navigation with context.atlas.back()
//   EnvoyMetric             — Per-request performance metrics
//   POST via Envoy          — Add product to cart
//   PUT via Envoy           — Update product
//   DELETE via Envoy        — Delete product
//   Image carousel          — PageView for product images
// ---------------------------------------------------------------------------

/// Displays a single product with images, reviews, and add-to-cart.
///
/// Uses the Spark widget (hooks-based) to trigger loading on mount
/// and Vestige for reactive state rendering.
class WaresDetailScreen extends Spark {
  /// The product ID parsed from the route (e.g. `/wares/42`).
  final String waresId;

  const WaresDetailScreen({super.key, required this.waresId});

  @override
  Widget ignite(BuildContext context) {
    final pillar = context.pillar<BazaarPillar>();
    final id = int.tryParse(waresId) ?? 0;

    useEffect(() {
      pillar.loadWaresDetail(id);
      return null;
    }, [waresId]);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
        title: const Text('Wares Detail'),
        actions: [
          Vestige<BazaarPillar>(
            builder: (context, p) {
              final isFetching = p.waresDetail.isFetching.value;
              return IconButton(
                icon: isFetching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: isFetching ? null : p.refreshDetail,
                tooltip: 'Refresh',
              );
            },
          ),
          Vestige<BazaarPillar>(
            builder: (context, p) {
              final count = p.cofferItemCount.value;
              return Badge(
                label: Text('$count'),
                isLabelVisible: count > 0,
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => context.atlas.to('/coffer'),
                  tooltip: 'View Cart',
                ),
              );
            },
          ),
        ],
      ),
      body: Vestige<BazaarPillar>(
        builder: (context, p) {
          final wares = p.waresDetail.data.value;
          final isLoading = p.waresDetail.isLoading.value;
          final error = p.waresDetail.error.value;

          if (isLoading && wares == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null && wares == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to load wares: $error'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => p.loadWaresDetail(id),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (wares == null) {
            return const Center(child: Text('No wares data'));
          }

          return _WaresDetailBody(wares: wares, pillar: p);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WaresDetailBody — Product detail content
// ---------------------------------------------------------------------------

class _WaresDetailBody extends StatelessWidget {
  final dynamic wares;
  final BazaarPillar pillar;

  const _WaresDetailBody({required this.wares, required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // SWR background refresh indicator
        if (pillar.waresDetail.isFetching.value)
          const LinearProgressIndicator(),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image carousel
                _ImageCarousel(images: wares.images as List<String>),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & brand
                      Text(
                        wares.title as String,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (wares.brand != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          wares.brand as String,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Price section
                      _PriceSection(wares: wares),

                      const SizedBox(height: 12),

                      // Info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Rating
                          Chip(
                            avatar: Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            label: Text(
                              '${(wares.rating as double).toStringAsFixed(1)} / 5',
                            ),
                          ),
                          // Stock
                          Chip(
                            avatar: Icon(
                              Icons.inventory_2,
                              size: 16,
                              color: (wares.isLowStock as bool)
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            label: Text('${wares.stock} in stock'),
                          ),
                          // Category
                          Chip(
                            avatar: const Icon(Icons.category, size: 16),
                            label: Text(wares.category as String),
                          ),
                          // SKU
                          if (wares.sku != null)
                            Chip(
                              avatar: const Icon(Icons.qr_code, size: 16),
                              label: Text(wares.sku as String),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        wares.description as String,
                        style: theme.textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 16),

                      // Additional info
                      _InfoSection(wares: wares),

                      const SizedBox(height: 16),

                      // Tags
                      if ((wares.tags as List<String>).isNotEmpty) ...[
                        Text(
                          'Tags',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (wares.tags as List<String>)
                              .map(
                                (tag) => Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Reviews section
                      _ReviewsSection(reviews: wares.reviews as List),

                      const SizedBox(height: 16),

                      // Network metrics
                      _NetworkInfoCard(pillar: pillar),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom bar with add-to-cart
        _BottomBar(wares: wares, pillar: pillar),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ImageCarousel — PageView product image gallery
// ---------------------------------------------------------------------------

class _ImageCarousel extends StatefulWidget {
  final List<String> images;

  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.images.isEmpty) {
      return Container(
        height: 250,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported, size: 64)),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (_, index) => Image.network(
              widget.images[index],
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, size: 64),
              ),
            ),
          ),
          // Page indicators
          if (widget.images.length > 1)
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.images.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentPage
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PriceSection — Price display with discount
// ---------------------------------------------------------------------------

class _PriceSection extends StatelessWidget {
  final dynamic wares;

  const _PriceSection({required this.wares});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = (wares.discountPercentage as double) > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${(wares.discountedPrice as double).toStringAsFixed(2)}',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 8),
          Text(
            '\$${(wares.price as double).toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SAVE ${(wares.discountPercentage as double).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _InfoSection — Shipping, warranty, return policy
// ---------------------------------------------------------------------------

class _InfoSection extends StatelessWidget {
  final dynamic wares;

  const _InfoSection({required this.wares});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final infos = <MapEntry<IconData, String>>[];

    if (wares.shippingInformation != null) {
      infos.add(MapEntry(Icons.local_shipping, wares.shippingInformation!));
    }
    if (wares.warrantyInformation != null) {
      infos.add(MapEntry(Icons.verified_user, wares.warrantyInformation!));
    }
    if (wares.returnPolicy != null) {
      infos.add(MapEntry(Icons.assignment_return, wares.returnPolicy!));
    }
    if (wares.availabilityStatus != null) {
      infos.add(MapEntry(Icons.check_circle, wares.availabilityStatus!));
    }
    if (wares.minimumOrderQuantity != null) {
      infos.add(
        MapEntry(
          Icons.shopping_bag,
          'Min order: ${wares.minimumOrderQuantity}',
        ),
      );
    }
    if (wares.weight != null) {
      infos.add(
        MapEntry(
          Icons.scale,
          '${(wares.weight as double).toStringAsFixed(1)} kg',
        ),
      );
    }

    if (infos.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Info',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...infos.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(e.key, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(e.value, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReviewsSection — Product reviews with star ratings
// ---------------------------------------------------------------------------

class _ReviewsSection extends StatelessWidget {
  final List reviews;

  const _ReviewsSection({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Reviews',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                '${reviews.length}',
                style: theme.textTheme.labelSmall,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          Text(
            'No reviews yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          )
        else
          ...reviews.map((review) => _ReviewCard(review: review)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final dynamic review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text((review.reviewerName as String).substring(0, 1)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName as String,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < (review.rating as int)
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment as String, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NetworkInfoCard — Shows recent HTTP metrics
// ---------------------------------------------------------------------------

class _NetworkInfoCard extends StatelessWidget {
  final BazaarPillar pillar;

  const _NetworkInfoCard({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMetrics = pillar.metrics.value;
    final recentMetrics = allMetrics.length > 5
        ? allMetrics.sublist(allMetrics.length - 5)
        : allMetrics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.network_check, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Network Activity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...recentMetrics.map(
              (m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    _StatusDot(statusCode: m.statusCode),
                    const SizedBox(width: 8),
                    Text(
                      m.method,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    Text(
                      '${m.duration.inMilliseconds}ms',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (m.cached) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.cached,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final int? statusCode;

  const _StatusDot({required this.statusCode});

  @override
  Widget build(BuildContext context) {
    final code = statusCode ?? 0;
    final color = code >= 200 && code < 300
        ? Colors.green
        : code >= 400
        ? Colors.red
        : Colors.orange;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// _BottomBar — Add to cart button
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final dynamic wares;
  final BazaarPillar pillar;

  const _BottomBar({required this.wares, required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${(wares.discountedPrice as double).toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((wares.stock as int) > 0)
                    Text(
                      'In Stock',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    )
                  else
                    Text(
                      'Out of Stock',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: (wares.stock as int) > 0
                  ? () {
                      pillar.addToCoffer(wares: wares);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${wares.title} added to cart'),
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'View Cart',
                            onPressed: () => context.atlas.to('/coffer'),
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }
}
