import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';
import '../data/search_api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.embedded = false});

  static const routeName = AppRoutes.search;

  final bool embedded;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchApi = SearchApiService();
  final _queryCtrl = TextEditingController();
  List<String> _suggestions = const [];
  List<String> _recent = const [];
  List<SearchCategory> _categories = const [];
  bool _categoriesLoading = true;
  bool _suggestionLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await _loadRecent();
    await _loadCategories();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('recent_searches') ?? <String>[];
    if (!mounted) return;
    setState(() => _recent = raw.take(5).toList());
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final data = await _searchApi.fetchCategories();
      if (!mounted) return;
      setState(() => _categories = data);
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _saveRecent(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final next = [q, ..._recent.where((x) => x != q)].take(5).toList();
    await prefs.setStringList('recent_searches', next);
    if (!mounted) return;
    setState(() => _recent = next);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      setState(() => _suggestionLoading = true);
      try {
        final list = await _searchApi.autosuggest(value);
        if (!mounted) return;
        setState(() => _suggestions = list);
      } finally {
        if (mounted) setState(() => _suggestionLoading = false);
      }
    });
  }

  Future<void> _performSearch([String? raw]) async {
    final query = (raw ?? _queryCtrl.text).trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    _queryCtrl.text = query;
    await _saveRecent(query);
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      AppRoutes.searchResults,
      arguments: query,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (!widget.embedded)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF333333)),
                      ),
                    Expanded(
                      child: TextField(
                        controller: _queryCtrl,
                        onChanged: _onQueryChanged,
                        onSubmitted: _performSearch,
                        decoration: const InputDecoration(
                          hintText: 'Search products',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_queryCtrl.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _queryCtrl.clear();
                          _onQueryChanged('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.cancel, color: Color(0xFF999999)),
                      ),
                    IconButton(
                      onPressed: () => _performSearch(),
                      icon: const Icon(Icons.search, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildDiscovery()),
        ],
      ),
    );
  }

  Widget _buildDiscovery() {
    final q = _queryCtrl.text.trim();
    if (q.isNotEmpty) {
      if (_suggestionLoading) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      if (_suggestions.isEmpty) {
        return const Center(child: Text('No suggestions'));
      }
      return ListView.builder(
        itemCount: _suggestions.length,
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return ListTile(
            leading: const Icon(Icons.search, size: 18, color: Color(0xFF666666)),
            title: Text(s),
            onTap: () => _performSearch(s),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Searches',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('recent_searches', const []);
                  if (!mounted) return;
                  setState(() => _recent = const []);
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent
                .map(
                  (r) => ActionChip(
                    avatar: const Icon(Icons.search, size: 14),
                    label: Text(r),
                    onPressed: () => _performSearch(r),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        const Row(
          children: [
            Expanded(
              child: Text(
                'Categories',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_categoriesLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length.clamp(0, 9),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, i) {
              final c = _categories[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _performSearch(c.name),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEF2FF)),
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Image.network(
                          c.iconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.category_outlined),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
