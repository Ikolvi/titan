import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../models/bazaar.dart';
import '../pillars/bazaar_pillar.dart';

// ---------------------------------------------------------------------------
// BazaarScreen — E-Commerce product listing with categories & search
// ---------------------------------------------------------------------------
//
// Demonstrates:
//   Vestige            — Reactive widget consumer
//   Codex + Envoy      — HTTP-backed paginated product grid
//   Recall             — Cancel token for search with server-side search
//   Quarry + Envoy     — Category fetching via envoyQuarry
//   Sort & Filter      — Sorting via API query params
//   Category filter    — Products by category via API endpoint
//   EnvoyMetric        — Live request metrics display
//   Atlas navigation   — Push to product detail screen
//   Gate               — Concurrency throttle for parallel requests
//   POST via Envoy     — Creating a new product
//   DELETE via Envoy   — Removing a product
// ---------------------------------------------------------------------------

/// The Bazaar — a hero marketplace for buying and selling wares.
///
/// Shows a paginated grid of products from DummyJSON with real search,
/// category filtering, sorting, and a live network metrics dashboard.
class BazaarScreen extends StatelessWidget {
  const BazaarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Vestige<BazaarPillar>(
      builder: (context, pillar) {
        final isSearchActive = pillar.isSearchActive.value;
        final searchResults = pillar.searchResults.value;
        final isSearchLoading = pillar.isSearchLoading.value;
        final items = pillar.products.items.value;
        final isLoading = pillar.products.isLoading.value;
        final hasMore = pillar.products.hasMore.value;
        final error = pillar.products.error.value;
        final displayItems = isSearchActive ? searchResults : items;
        final cartCount = pillar.cofferItemCount.value;

        return Column(
          children: [
            // Network metrics banner
            _MetricsBanner(pillar: pillar),

            // Category chips
            _CategoryChips(pillar: pillar),

            // Search bar with sort
            _SearchBar(pillar: pillar, cartCount: cartCount),

            // Error display
            if (error != null)
              MaterialBanner(
                content: Text('Network error: $error'),
                backgroundColor: Colors.red.shade50,
                actions: [
                  TextButton(
                    onPressed: pillar.refreshProducts,
                    child: const Text('Retry'),
                  ),
                ],
              ),

            // Product grid
            Expanded(
              child: (isLoading || isSearchLoading) && displayItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : displayItems.isEmpty && isSearchActive
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No wares match your search',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: pillar.refreshProducts,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: isSearchActive
                            ? displayItems.length
                            : displayItems.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (!isSearchActive && index >= displayItems.length) {
                            // Load more trigger
                            pillar.loadMore();
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return _WaresCard(
                            wares: displayItems[index],
                            onTap: () => context.atlas.to(
                              '/wares/${displayItems[index].id}',
                            ),
                            onAddToCart: () =>
                                pillar.addToCoffer(wares: displayItems[index]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _MetricsBanner — Live HTTP metrics display
// ---------------------------------------------------------------------------

class _MetricsBanner extends StatelessWidget {
  final BazaarPillar pillar;

  const _MetricsBanner({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricChip(
            icon: Icons.http,
            label: '${pillar.totalRequests.value} requests',
          ),
          _MetricChip(
            icon: Icons.timer,
            label: '${pillar.avgLatency.value.inMilliseconds}ms avg',
          ),
          _MetricChip(
            icon: Icons.cached,
            label: '${pillar.cacheHits.value} cached',
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CategoryChips — Horizontal scrolling category filter
// ---------------------------------------------------------------------------

class _CategoryChips extends StatelessWidget {
  final BazaarPillar pillar;

  const _CategoryChips({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final categories = pillar.categories.data.value;
    final selected = pillar.selectedCategory.value;

    if (categories == null || categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: categories.length + 1, // +1 for "All"
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => pillar.filterByCategory(null),
              ),
            );
          }
          final cat = categories[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(cat.name),
              selected: selected?.slug == cat.slug,
              onSelected: (_) => pillar.filterByCategory(
                selected?.slug == cat.slug ? null : cat,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SearchBar — Search input with sort and cart button
// ---------------------------------------------------------------------------

class _SearchBar extends StatefulWidget {
  final BazaarPillar pillar;
  final int cartCount;

  const _SearchBar({required this.pillar, required this.cartCount});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search the Bazaar...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: widget.pillar.isSearchActive.value
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _controller.clear();
                          widget.pillar.clearSearch();
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onChanged: (query) => widget.pillar.searchProducts(query),
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          PopupMenuButton<WaresSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort products',
            onSelected: widget.pillar.changeSortOrder,
            itemBuilder: (_) => const [
              PopupMenuItem(value: WaresSortOrder.none, child: Text('Default')),
              PopupMenuItem(
                value: WaresSortOrder.priceLowToHigh,
                child: Text('Price: Low → High'),
              ),
              PopupMenuItem(
                value: WaresSortOrder.priceHighToLow,
                child: Text('Price: High → Low'),
              ),
              PopupMenuItem(
                value: WaresSortOrder.ratingDesc,
                child: Text('Rating: Best First'),
              ),
              PopupMenuItem(
                value: WaresSortOrder.nameAsc,
                child: Text('Name: A → Z'),
              ),
            ],
          ),
          // Cart button
          Badge(
            label: Text('${widget.cartCount}'),
            isLabelVisible: widget.cartCount > 0,
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => context.atlas.to('/coffer'),
              tooltip: 'View Cart',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WaresCard — Product card for the grid
// ---------------------------------------------------------------------------

class _WaresCard extends StatelessWidget {
  final Wares wares;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _WaresCard({
    required this.wares,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = wares.discountPercentage > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: 'View ${wares.title}',
          button: true,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    wares.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_not_supported, size: 48),
                    ),
                  ),
                  // Discount badge
                  if (hasDiscount)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${wares.discountPercentage.toStringAsFixed(0)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Low stock indicator
                  if (wares.isLowStock)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Low Stock',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      wares.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Rating
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          wares.rating.toStringAsFixed(1),
                          style: theme.textTheme.labelSmall,
                        ),
                        if (wares.brand != null) ...[
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              wares.brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Price row with add-to-cart
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasDiscount)
                                Text(
                                  '\$${wares.price.toStringAsFixed(2)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              Text(
                                '\$${wares.discountedPrice.toStringAsFixed(2)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton.filled(
                            onPressed: onAddToCart,
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            padding: EdgeInsets.zero,
                            tooltip: 'Add to cart',
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
        ),
      ),
    );
  }
}
