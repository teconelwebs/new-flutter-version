import 'package:flutter/material.dart';

import '../../../../core/constants/app_routes.dart';
import '../../data/models/product_item.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.item});

  final ProductItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.product,
          arguments: item,
        );
      },
      child: Ink(
        padding: const EdgeInsets.all(12),
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
                  color: item.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: item.imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.shopping_bag_outlined, size: 34),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_not_supported_outlined, size: 26),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6E7380), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Rs ${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.local_shipping_rounded, color: Color(0xFF6B7280), size: 13),
                const SizedBox(width: 4),
                Text(
                  item.durationMinutes > 0
                      ? '${item.durationMinutes}-${item.durationMinutes + 1} days'
                      : '7-8 days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
