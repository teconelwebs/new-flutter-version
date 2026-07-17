import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
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
  @override
  Widget build(BuildContext context) {
    final hasVideo =
        widget.item.videoUrl != null && widget.item.videoUrl!.isNotEmpty;
    final videoId =
        '${widget.item.id}_${widget.item.videoUrl ?? widget.item.imageUrl}';

    return Align(
      alignment: Alignment.topCenter,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).pushNamed(
            AppRoutes.product,
            arguments: widget.item,
          );
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: widget.item.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                              child:
                                  Icon(Icons.shopping_bag_outlined, size: 34),
                            )
                          : Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image_not_supported_outlined,
                                    size: 26),
                              ),
                            )),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              if (widget.item.brand.trim().isNotEmpty &&
                  widget.item.brand.trim().toLowerCase() != 'no brand') ...[
                const SizedBox(height: 4),
                Text(
                  widget.item.brand.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6E7380), fontSize: 12),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Rs ${widget.item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (widget.item.durationMinutes > 0) ...[
                    const Spacer(),
                    const Icon(Icons.local_shipping_rounded,
                        color: Color(0xFF6B7280), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      _getDeliveryDaysText(widget.item.durationMinutes),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDeliveryDaysText(int durationMinutes) {
    if (durationMinutes <= 0) return '';
    final days = durationMinutes ~/ 1440;
    if (days > 0) return '$days - ${days + 1} days';
    final hours = (durationMinutes % 1440) ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0) return '$hours hr${hours > 1 ? 's' : ''}';
    if (mins > 0) return '$mins min${mins > 1 ? 's' : ''}';
    return '';
  }
}
