import 'package:flutter/material.dart';

import '../models/reel.dart';
import '../utils/flutter_nav.dart';

class CaptionSheet {
  static Future<void> show(
    BuildContext context, {
    required String caption,
    required int views,
    required List<ReelProduct> products,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.5;

        return lightSheetWrapper(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (views > 0)
                        Text(
                          '$views views',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        caption.isNotEmpty ? caption : 'No caption',
                        style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                      ),
                      if (products.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Products',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final p = products[i];
                              return GestureDetector(
                                onTap: () => openProductInShop(
                                  p.slug ?? p.id,
                                  context: context,
                                ),
                                child: Container(
                                  width: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (p.imageUrl != null &&
                                          p.imageUrl!.isNotEmpty)
                                        Expanded(
                                          child: Image.network(
                                            p.imageUrl!,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
