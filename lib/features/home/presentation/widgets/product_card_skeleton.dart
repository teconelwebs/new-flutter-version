import 'package:flutter/material.dart';
import 'shimmer_placeholder.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth * 0.44;
    const double gap = 4.0;
    
    // Shimmer colors mapping matching react colors
    const List<Color> shimmerColors = [Color(0xFFF0F0F0), Color(0xFFE0E0E0), Color(0xFFF0F0F0)];

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: gap),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 1,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton container
          ShimmerPlaceholder(
            height: 160,
            width: double.infinity,
            shimmerColors: shimmerColors,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),

          // Content section skeletons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Skeleton
                ShimmerPlaceholder(
                  height: 12,
                  width: 50,
                  shimmerColors: shimmerColors,
                ),
                SizedBox(height: 8),

                // Title Skeleton (Line 1 & Line 2)
                ShimmerPlaceholder(
                  height: 14,
                  width: double.infinity,
                  shimmerColors: shimmerColors,
                ),
                SizedBox(height: 4),
                ShimmerPlaceholder(
                  height: 14,
                  width: 100, // 75% representation
                  shimmerColors: shimmerColors,
                ),
                SizedBox(height: 12),

                // Price Skeletons
                Row(
                  children: [
                    ShimmerPlaceholder(
                      height: 16,
                      width: 60,
                      shimmerColors: shimmerColors,
                    ),
                    SizedBox(width: 8),
                    ShimmerPlaceholder(
                      height: 14,
                      width: 50,
                      shimmerColors: shimmerColors,
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Delivery estimate skeleton
                ShimmerPlaceholder(
                  height: 12,
                  width: 110, // 80% representation
                  shimmerColors: shimmerColors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
