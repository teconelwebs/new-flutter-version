import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_routes.dart';
import '../../search/presentation/search_screen.dart';
import '../data/category_api_service.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _api = CategoryApiService();
  bool _loading = true;
  bool _innerLoading = false;
  List<MainCategory> _categories = const [];
  List<InnerSection> _sections = const [];
  int _activeIndex = 0;
  String _bannerImage = '';

  @override
  void initState() {
    super.initState();
    _loadMain();
  }

  Future<void> _loadMain() async {
    setState(() => _loading = true);
    try {
      final bundle = await _api.fetchMainCategories();
      if (!mounted) return;
      _categories = bundle.categories;
      _bannerImage = bundle.bannerImage;
      _activeIndex = 0;
      setState(() {});
      if (_categories.isNotEmpty) {
        await _loadInner(_categories.first.id);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInner(String catId) async {
    setState(() => _innerLoading = true);
    try {
      final sections = await _api.fetchInnerSections(catId);
      if (!mounted) return;
      setState(() => _sections = sections);
    } finally {
      if (mounted) setState(() => _innerLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_categories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light,    // iOS
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Header - always visible
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Categories',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // 🔥 Action Bar: Search, Wishlist, Cart
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(SearchScreen.routeName),
                        icon: const Icon(
                          Icons.search_outlined,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamed('/ProfileScreen/Wishlist'),
                        icon: const Icon(
                          Icons.favorite_border_outlined,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .pushNamed('/(tabs)/Cart'),
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 86,
                  color: const Color(0xFFF5F6F8),
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final c = _categories[i];
                      final active = i == _activeIndex;
                      return InkWell(
                        onTap: () async {
                          if (_activeIndex == i) return;
                          setState(() => _activeIndex = i);
                          await _loadInner(c.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color:
                                active ? Colors.white : const Color(0xFFF5F6F8),
                            border: const Border(
                              bottom: BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
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
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: active
                                      ? const Color(0xFFF47405)
                                      : const Color(0xFF4B5563),
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: _innerLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (_bannerImage.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _bannerImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            if (_bannerImage.isNotEmpty)
                              const SizedBox(height: 14),
                            ..._sections.map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 14,
                                      children: s.children
                                          .map(
                                            (child) => SizedBox(
                                              width: (MediaQuery.sizeOf(context)
                                                          .width -
                                                      130) /
                                                  3,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () {
                                                  Navigator.of(context)
                                                      .pushNamed(
                                                    AppRoutes.searchResults,
                                                    arguments: child.name,
                                                  );
                                                },
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      width: 65,
                                                      height: 65,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Color(0xFFF5F6F8),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      child: Image.network(
                                                        child.imageUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Icon(Icons
                                                                .image_outlined),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      child.name,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Color(0xFF4B5563),
                                                        height: 1.25,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
