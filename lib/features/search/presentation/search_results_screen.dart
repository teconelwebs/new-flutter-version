import 'package:flutter/material.dart';

import '../../product/presentation/widgets/product_card.dart';
import '../data/search_api_service.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.query});

  final String query;

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
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final items = await _searchApi.searchProducts(_query);
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
        title: Row(
          children: [
            const Icon(Icons.search, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _query,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.67,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (_, i) => ProductCard(item: _products[i]),
                ),
    );
  }
}
