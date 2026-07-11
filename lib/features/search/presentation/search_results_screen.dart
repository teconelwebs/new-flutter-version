import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/state/cart_state.dart';
import '../../product/presentation/widgets/product_card.dart';
import '../data/search_api_service.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.query, this.categoryId});

  final String query;
  final String? categoryId;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _searchApi = SearchApiService();
  bool _loading = true;
  String _query = '';
  List _products = const [];

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _fetch();
    CartState.loadCartCount();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final items = await _searchApi.searchProducts(_query, categoryId: widget.categoryId);
      if (!mounted) return;
      setState(() => _products = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          _query,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.search);
            },
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFDC2626),
            ),
          ),
          IconButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('access_token') ?? '';
              if (token.isEmpty) {
                if (context.mounted) {
                  Navigator.of(context).pushNamed(AppRoutes.login);
                }
                return;
              }
              if (context.mounted) {
                Navigator.of(context).pushNamed(AppRoutes.wishlist);
              }
            },
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: Color(0xFFDC2626),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: CartState.cartCountNotifier,
            builder: (context, cartCount, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('access_token') ?? '';
                      if (token.isEmpty) {
                        if (context.mounted) {
                          Navigator.of(context).pushNamed(AppRoutes.login);
                        }
                        return;
                      }
                      if (context.mounted) {
                        Navigator.of(context).pushNamed(AppRoutes.cart);
                      }
                    },
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  if (cartCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.search_off_rounded,
                        size: 42,
                        color: Color(0xFF9AA0A6),
                      ),
                      SizedBox(height: 8),
                      Text('No products found'),
                    ],
                  ),
                )
              : (() {
                  // Split list into left and right columns
                  final leftColumnItems = [];
                  final rightColumnItems = [];
                  for (int i = 0; i < _products.length; i++) {
                    if (i % 2 == 0) {
                      leftColumnItems.add(_products[i]);
                    } else {
                      rightColumnItems.add(_products[i]);
                    }
                  }

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: leftColumnItems
                                .map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: ProductCard(item: item),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: rightColumnItems
                                .map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: ProductCard(item: item),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                })(),
    );
  }
}
