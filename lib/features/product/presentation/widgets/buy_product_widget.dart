// lib/features/product/presentation/widgets/buy_product_widget.dart
// Converted from: component/BuyProduct.tsx

import 'package:flutter/material.dart';

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
    final rawStock = data['stock'] ??
        data['product']?['stock'] ??
        data['stocks']?[0]?['qty'] ??
        0;

    final int stock = int.tryParse(rawStock.toString()) ?? 0;
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Limit Reached',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xB3111111),
            behavior: SnackBarBehavior.floating,
            width: MediaQuery.sizeOf(context).width * 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Price Label & Calculated Value
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Price',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              // const SizedBox(height: 4),
              Text(
                '₹ ${(price * quantity).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          // Stepper Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                // Minus
                GestureDetector(
                  onTap: decreaseQuantity,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Opacity(
                      opacity: quantity <= 1 ? 0.45 : 1.0,
                      child: const Text(
                        '−',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ),

                // Qty Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Plus
                GestureDetector(
                  onTap: increaseQuantity,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF008083),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Opacity(
                      opacity: quantity >= maxLimit ? 0.45 : 1.0,
                      child: const Text(
                        '+',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }
}
