import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_routes.dart';
import '../data/search_api_service.dart';
import 'widgets/app_search_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.embedded = false, this.initialQuery});

  static const routeName = AppRoutes.search;

  final bool embedded;
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchApi = SearchApiService();
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _suggestions = const [];
  List<String> _recent = const [];
  List<SearchCategory> _categories = const [];
  bool _categoriesLoading = true;
  bool _suggestionLoading = false;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _queryCtrl.text = widget.initialQuery!.trim();
    }
    _queryCtrl.addListener(_onTextChanged);
    _loadInitial();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onTextChanged() => setState(() {});

  Future<void> _loadInitial() async {
    await _loadRecent();
    await _loadCategories();
    if (_queryCtrl.text.trim().isNotEmpty) {
      _onQueryChanged(_queryCtrl.text);
    }
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
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = const [];
        _suggestionLoading = false;
      });
      return;
    }
    setState(() {
      _suggestionLoading = true;
      _suggestions = const []; // Clear old suggestions immediately while typing new characters
    });
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      try {
        final list = await _searchApi.autosuggest(trimmed);
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
    setState(() {
      _isSearching = true;
    });
    FocusScope.of(context).unfocus();
    _queryCtrl.text = query;
    await _saveRecent(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_search_keyword', query);
    if (!mounted) return;
    
    await Navigator.of(context).pushNamed(
      AppRoutes.searchResults,
      arguments: query,
    );

    if (mounted) {
      setState(() {
        _isSearching = false;
      });
      final q = _queryCtrl.text.trim();
      if (q.isNotEmpty) {
        _onQueryChanged(q);
      } else {
        _loadRecent();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.removeListener(_onTextChanged);
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.sizeOf(context).width < 360 ? 8 : 10,
              ),
              child: AppSearchBar.editable(
                controller: _queryCtrl,
                focusNode: _focusNode,
                autofocus: !widget.embedded,
                hintText: 'Search products',
                showBackButton: !widget.embedded,
                onBack: () => Navigator.of(context).pop(),
                onChanged: _onQueryChanged,
                onSubmitted: _performSearch,
                onClear: () {
                  _queryCtrl.clear();
                  _onQueryChanged('');
                },
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
      if (_suggestionLoading || _isSearching) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFB5404),
          ),
        );
      }
      if (_suggestions.isEmpty) {
        return Center(
          child: Text(
            'No suggestions for "$q"',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 52, color: Color(0xFFF3F4F6)),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.search_rounded,
                  size: 18, color: Color(0xFF6B7280)),
            ),
            title: Text(
              s,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
            ),
            trailing: const Icon(Icons.north_west_rounded,
                size: 16, color: Color(0xFF9CA3AF)),
            onTap: () => _performSearch(s),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('recent_searches', const []);
                  if (!mounted) return;
                  setState(() => _recent = const []);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFB5404),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
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
                    backgroundColor: const Color(0xFFF9FAFB),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    avatar: const Icon(Icons.history_rounded,
                        size: 14, color: Color(0xFF6B7280)),
                    label: Text(
                      r,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF374151)),
                    ),
                    onPressed: () => _performSearch(r),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'Browse Categories',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF111827),
          ),
        ),
        if (_categoriesLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFB5404),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length.clamp(0, 9),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width < 360 ? 3 : 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio:
                  MediaQuery.sizeOf(context).width < 360 ? 0.95 : 1.05,
            ),
            itemBuilder: (_, i) {
              final c = _categories[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _performSearch(c.name),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Image.network(
                          c.iconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.category_outlined,
                              color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                          height: 1.15,
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
