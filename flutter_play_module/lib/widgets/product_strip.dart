import 'package:flutter/material.dart';

import '../models/live_product.dart';
import '../models/reel.dart';

/// Callback: (slug_or_id) — use slug for RN product page navigation.
typedef OnProductTap = void Function(String slugOrId);

class ProductStrip extends StatelessWidget {
  final List<LiveProduct> liveProducts;
  final List<ReelProduct> reelProducts;
  final bool loading;
  final String? error;
  final bool visible;
  final VoidCallback onClose;
  final OnProductTap? onProductTap;

  const ProductStrip({
    super.key,
    required this.liveProducts,
    required this.reelProducts,
    required this.loading,
    this.error,
    required this.visible,
    required this.onClose,
    this.onProductTap,
  });

  bool get hasProducts => liveProducts.isNotEmpty || reelProducts.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      offset: visible ? Offset.zero : const Offset(1, 0),
      child: SizedBox(
        height: 120,
        child: loading
            ? _wrapClose(const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text('Loading products...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ))
            : error != null
                ? _wrapClose(Center(
                    child: Text(error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  ))
                : !hasProducts
                    ? _wrapClose(const Center(
                        child: Text('No products linked to this play', style: TextStyle(color: Colors.white70)),
                      ))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        itemCount: liveProducts.isNotEmpty ? liveProducts.length : reelProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (liveProducts.isNotEmpty) {
                            final p = liveProducts[index];
                            return _LiveCard(
                              product: p,
                              showClose: index == 0,
                              onClose: onClose,
                              onTap: onProductTap != null
                                  ? () => onProductTap!(p.slug ?? p.id)
                                  : null,
                            );
                          }
                          final p = reelProducts[index];
                          return _ReelCard(
                            product: p,
                            showClose: index == 0,
                            onClose: onClose,
                            onTap: onProductTap != null
                                ? () => onProductTap!(p.slug ?? p.id)
                                : null,
                          );
                        },
                      ),
      ),
    );
  }

  Widget _wrapClose(Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 4,
          left: 4,
          child: _CloseBtn(onClose: onClose),
        ),
      ],
    );
  }
}

class _CloseBtn extends StatelessWidget {
  final VoidCallback onClose;
  const _CloseBtn({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Live product card (from search API)
// ─────────────────────────────────────────────
class _LiveCard extends StatelessWidget {
  final LiveProduct product;
  final bool showClose;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  const _LiveCard({
    required this.product,
    required this.showClose,
    required this.onClose,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1A1A1A),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Product image
            Positioned.fill(
              child: _ProductImage(url: product.imageUrl),
            ),
            // Dark gradient overlay for readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                  ),
                ),
              ),
            ),
            // Close button
            if (showClose) Positioned(top: 4, left: 4, child: _CloseBtn(onClose: onClose)),
            // Product info
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (product.mrpPrice > 0)
                        Text(
                          '₹${product.mrpPrice.toInt()}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${product.activePrice.toInt()}',
                        style: const TextStyle(color: Color(0xFFfb5404), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Tap ripple hint
            if (onTap != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reel-attached product card (from reel JSON)
// ─────────────────────────────────────────────
class _ReelCard extends StatelessWidget {
  final ReelProduct product;
  final bool showClose;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  const _ReelCard({
    required this.product,
    required this.showClose,
    required this.onClose,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF1A1A1A)),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: _ProductImage(url: product.imageUrl),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
                  ),
                ),
              ),
            ),
            if (showClose) Positioned(top: 4, left: 4, child: _CloseBtn(onClose: onClose)),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  if (product.price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '₹${product.price}',
                        style: const TextStyle(color: Color(0xFFfb5404), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Product image with placeholder fallback
// ─────────────────────────────────────────────
class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: Colors.white24, size: 32),
      ),
    );
  }
}
