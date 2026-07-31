import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/product_item.dart';
import 'inline_product_video_player.dart';
import 'inline_video_focus_coordinator.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.item});

  final ProductItem item;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String _formatPrice(double price) {
    final intVal = price.round();
    if (intVal >= 1000) {
      final str = intVal.toString();
      return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';
    }
    return intVal.toString();
  }

  String _getDeliveryDaysText(int durationMinutes) {
    if (durationMinutes <= 0) return '3–5 days';
    final days = durationMinutes ~/ 1440;
    if (days > 0) {
      return '$days–${days + 2} days';
    }
    return '3–5 days';
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo =
        widget.item.videoUrl != null && widget.item.videoUrl!.isNotEmpty;
    final videoId =
        '${widget.item.id}_${widget.item.videoUrl ?? widget.item.imageUrl}';

    // Calculate deterministic discount and original price
    int discountPercentage;
    double originalPrice;

    if (widget.item.price.round() == 449) {
      discountPercentage = 55;
      originalPrice = 999;
    } else if (widget.item.price.round() == 1299) {
      discountPercentage = 48;
      originalPrice = 2499;
    } else if (widget.item.price.round() == 899) {
      discountPercentage = 50;
      originalPrice = 1799;
    } else if (widget.item.price.round() == 1499) {
      discountPercentage = 55;
      originalPrice = 3299;
    } else {
      discountPercentage = 30 + (widget.item.id.hashCode % 6) * 5;
      originalPrice = (widget.item.price / (1 - discountPercentage / 100) / 10).round() * 10 - 1;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.product,
            arguments: widget.item,
          );
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image / Video
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          // ignore: deprecated_member_use
                          color: widget.item.color.withOpacity(0.4),
                          child: hasVideo
                              ? FocusTrackedVideo(
                                  videoId: videoId,
                                  builder: (context, isActive) {
                                    return InlineProductVideoPlayer(
                                      videoUrl: widget.item.videoUrl!,
                                      placeholderUrl: widget.item.imageUrl,
                                      autoPlay: true,
                                      loop: true,
                                      initialMuted: true,
                                      isActive: isActive,
                                      showControls: false,
                                    );
                                  },
                                )
                              : (widget.item.imageUrl.isEmpty
                                  ? const Center(
                                      child: Icon(Icons.shopping_bag_outlined, size: 34),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: widget.item.imageUrl,
                                      fit: BoxFit.contain,
                                      memCacheWidth: 250,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      placeholder: (context, url) => const ShimmerLoading(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                      errorWidget: (context, url, error) => const Center(
                                        child: Icon(Icons.image_not_supported_outlined, size: 26),
                                      ),
                                    )),
                        ),
                      ),
                      // Discount Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFB5404),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$discountPercentage% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Product Info Area
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Info Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1.0),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: Color(0xFFFB5404),
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Est. delivery: ${_getDeliveryDaysText(widget.item.durationMinutes)}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title (Max 2 lines, then ellipsis)
                    Text(
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1F2937),
                        height: 1.25,
                      ),
                    ),

                    // Brand Name (displays only when present, card height will adjust automatically)
                    if (widget.item.brand.trim().isNotEmpty &&
                        widget.item.brand.trim().toLowerCase() != 'no brand') ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.item.brand.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6E7380),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),

                    // Prices Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${_formatPrice(widget.item.price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${_formatPrice(originalPrice)}',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
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
