// lib/features/product/presentation/widgets/buy_product_widget.dart
// Converted from: component/BuyProduct.tsx

import 'package:flutter/material.dart';
import '../../../../core/utils/top_toast.dart';

class BuyProductWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  // ignore: use_super_parameters
  const BuyProductWidget({
    Key? key,
    required this.data,
    required this.quantity,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int stock;
    final stocksList = data['stocks'];
    if (stocksList is List && stocksList.isNotEmpty) {
      final currentId = data['id']?.toString();
      final matchingStock = stocksList.firstWhere(
        (s) => s is Map && s['product_id']?.toString() == currentId,
        orElse: () => null,
      );
      if (matchingStock != null) {
        stock = int.tryParse(matchingStock['qty']?.toString() ?? '0') ?? 0;
      } else {
        stock = int.tryParse(stocksList[0]?['qty']?.toString() ?? '0') ?? 0;
      }
    } else {
      final rawStock = data['stock'] ?? data['product']?['stock'] ?? 0;
      stock = int.tryParse(rawStock.toString()) ?? 0;
    }
    final bool isOutOfStock = stock <= 0;
    final int maxLimit = stock < 2 ? stock : 2;

    final double price = double.tryParse(
          (data['final_price']?['sellPrice'] ?? data['price'] ?? 0).toString(),
        ) ??
        0.0;

    void increaseQuantity() {
      if (isOutOfStock) return;
      if (quantity < maxLimit) {
        onQuantityChanged(quantity + 1);
      } else {
        TopToast.show(context, 'Maximum purchase limit is 2 units');
      }
    }

    void decreaseQuantity() {
      if (quantity > 1) {
        onQuantityChanged(quantity - 1);
      }
    }

    if (isOutOfStock) {
      return const SizedBox.shrink();
    }

    String formatPrice(double value) {
      final int val = value.round();
      final String str = val.toString();
      final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Divider stretched edge-to-edge
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              return Transform.scale(
                scaleX: screenWidth / (screenWidth - 40),
                child: const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total Price (Inline text and value)
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Total Price: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '₹${formatPrice(price * quantity)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Stepper Box
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    // Minus Button
                    GestureDetector(
                      onTap: decreaseQuantity,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Opacity(
                          opacity: quantity <= 1 ? 0.3 : 1.0,
                          child: const Text(
                            '−',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Qty Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),

                    // Plus Button
                    GestureDetector(
                      onTap: increaseQuantity,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Opacity(
                          opacity: quantity >= maxLimit ? 0.3 : 1.0,
                          child: const Text(
                            '+',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom Divider stretched edge-to-edge
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              return Transform.scale(
                scaleX: screenWidth / (screenWidth - 40),
                child: const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
              );
            },
          ),
        ],
      ),
    );
  }
}
