import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../models/bazaar.dart';
import '../pillars/bazaar_pillar.dart';

// ---------------------------------------------------------------------------
// CofferScreen — Shopping cart with quantities, totals, checkout
// ---------------------------------------------------------------------------
//
// Demonstrates:
//   Vestige            — Reactive widget consumer
//   Derived            — Computed cart totals and savings
//   Core               — Mutable cart item list
//   POST via Envoy     — Submit cart to DummyJSON API
//   PUT via Envoy      — Update server cart
//   Quarry + Envoy     — Fetch server-side cart for comparison
//   Atlas              — Navigation back to Bazaar
//   EnvoyMetric        — Network activity tracking
// ---------------------------------------------------------------------------

/// The Coffer — a hero's shopping cart filled with marketplace wares.
///
/// Shows cart items with quantity controls, price totals, discount
/// savings, and a checkout flow that submits to the DummyJSON cart API.
class CofferScreen extends StatelessWidget {
  const CofferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
        title: const Text('Your Coffer'),
        actions: [
          Vestige<BazaarPillar>(
            builder: (context, p) {
              final count = p.cofferItemCount.value;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '$count items',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Vestige<BazaarPillar>(
        builder: (context, pillar) {
          final items = pillar.cofferItems.value;

          if (items.isEmpty) {
            return _emptyCoffer(context: context);
          }

          return Column(
            children: [
              // Cart items list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _CofferItemTile(item: items[index], pillar: pillar),
                ),
              ),

              // Server-cart comparison card
              _ServerCofferCard(pillar: pillar),

              // Order summary
              _OrderSummary(pillar: pillar),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyCoffer — Empty cart state
// ---------------------------------------------------------------------------

Widget _emptyCoffer({required BuildContext context}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shopping_cart_outlined,
          size: 80,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'Your coffer is empty',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Browse the Bazaar to find wares worthy of a hero',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.atlas.back(),
          icon: const Icon(Icons.storefront),
          label: const Text('Visit the Bazaar'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// _CofferItemTile — Individual cart item with quantity controls
// ---------------------------------------------------------------------------

class _CofferItemTile extends StatelessWidget {
  final CofferItem item;
  final BazaarPillar pillar;

  const _CofferItemTile({required this.item, required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = item.discountPercentage > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.thumbnail,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 72,
                  height: 72,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (hasDiscount) ...[
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '\$${(item.price * (1 - item.discountPercentage / 100)).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          '-${item.discountPercentage.toStringAsFixed(0)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quantity controls
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: () => pillar.updateCofferQuantity(
                          productId: item.id,
                          quantity: item.quantity - 1,
                        ),
                        icon: const Icon(Icons.remove, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        onPressed: () => pillar.updateCofferQuantity(
                          productId: item.id,
                          quantity: item.quantity + 1,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const Spacer(),
                      // Line total
                      Text(
                        '\$${item.total.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () => _confirmRemove(context, item),
              tooltip: 'Remove from cart',
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, CofferItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Coffer?'),
        content: Text('Remove "${item.title}" from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              pillar.removeFromCoffer(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ServerCofferCard — Compare with server-side cart
// ---------------------------------------------------------------------------

class _ServerCofferCard extends StatelessWidget {
  final BazaarPillar pillar;

  const _ServerCofferCard({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serverCart = pillar.serverCoffer.data.value;
    final isLoading = pillar.serverCoffer.isLoading.value;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, size: 18, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Server Cart (API Demo)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (serverCart != null) ...[
              const SizedBox(height: 8),
              Text(
                '${serverCart.totalProducts} products · '
                '${serverCart.totalQuantity} items · '
                'Total: \$${serverCart.total.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'After discounts: \$${serverCart.discountedTotal.toStringAsFixed(2)} '
                '(saved \$${serverCart.totalSavings.toStringAsFixed(2)})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _OrderSummary — Price breakdown and checkout button
// ---------------------------------------------------------------------------

class _OrderSummary extends StatelessWidget {
  final BazaarPillar pillar;

  const _OrderSummary({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = pillar.cofferTotal.value;
    final discountedTotal = pillar.cofferDiscountedTotal.value;
    final savings = pillar.cofferSavings.value;

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
        child: Column(
          children: [
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: theme.textTheme.bodyMedium),
                Text(
                  '\$${subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (savings > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discount Savings',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    '-\$${savings.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${discountedTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmClear(context),
                    child: const Text('Clear Cart'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _checkout(context),
                    icon: const Icon(Icons.payment),
                    label: const Text('Checkout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Coffer?'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              pillar.clearCoffer();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Submit cart to DummyJSON API
    final result = await pillar.submitCoffer();

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading

    if (result != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Order Submitted!'),
          content: Text(
            'Cart #${result.id} created successfully.\n\n'
            '${result.totalProducts} products · '
            '${result.totalQuantity} items\n'
            'Total: \$${result.total.toStringAsFixed(2)}\n'
            'After discounts: \$${result.discountedTotal.toStringAsFixed(2)}',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                pillar.clearCoffer();
                Navigator.pop(ctx);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
