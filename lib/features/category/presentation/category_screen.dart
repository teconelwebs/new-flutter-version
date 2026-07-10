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
  List<MainCategory> _categories = const [];
  
  // Cache of fetched inner category sections for each index
  List<List<InnerSection>?> _innerCategories = [];
  
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  final Map<int, GlobalKey> _blockKeys = {};
  final Set<int> _loadingIndexes = {};
  
  int _activeIndex = 0;
  String _bannerImage = '';
  bool _isSidebarClick = false;

  @override
  void initState() {
    super.initState();
    _loadMain();
    _rightScrollController.addListener(_onRightScroll);
  }

  @override
  void dispose() {
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMain() async {
    setState(() => _loading = true);
    try {
      final bundle = await _api.fetchMainCategories();
      if (!mounted) return;
      _categories = bundle.categories;
      _bannerImage = bundle.bannerImage;
      _activeIndex = 0;
      
      // Initialize inner category list with same length as main categories
      _innerCategories = List<List<InnerSection>?>.filled(_categories.length, null);
      
      setState(() {});
      if (_categories.isNotEmpty) {
        _lazyLoadInner(0);
      }
    } catch (e) {
      debugPrint('Error loading main categories: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _lazyLoadInner(int index) async {
    if (index < 0 || index >= _categories.length) return;
    if (_innerCategories.length != _categories.length) {
      _innerCategories = List<List<InnerSection>?>.filled(_categories.length, null);
    }
    if (_innerCategories[index] != null || _loadingIndexes.contains(index)) return;
    
    _loadingIndexes.add(index);
    try {
      final sections = await _api.fetchInnerSections(_categories[index].id);
      if (!mounted) return;
      setState(() {
        _innerCategories[index] = sections;
      });
    } catch (e) {
      debugPrint('Error lazy loading category $index: $e');
    } finally {
      _loadingIndexes.remove(index);
    }
  }

  void _scrollToLeftIndex(int index) {
    if (!_leftScrollController.hasClients) return;
    const itemHeight = 94.0; // Estimated height of sidebar item (padding + child height)
    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetOffset = index * itemHeight - (screenHeight / 2) + (itemHeight / 2);
    _leftScrollController.animateTo(
      targetOffset.clamp(0.0, _leftScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _handleCategoryPress(int index) async {
    if (_activeIndex == index) return;
    
    setState(() {
      _activeIndex = index;
      _isSidebarClick = true;
    });

    _scrollToLeftIndex(index);

    // Load category if not already fetched
    if (_innerCategories[index] == null) {
      _lazyLoadInner(index);
    }

    // Scroll right list to selected category block
    final key = _blockKeys[index];
    if (key != null && key.currentContext != null) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    setState(() {
      _isSidebarClick = false;
    });
  }

  void _onRightScroll() {
    if (_isSidebarClick) return;
    if (!mounted || _categories.isEmpty || _innerCategories.isEmpty || !_rightScrollController.hasClients) return;

    int? activeIdx;
    
    try {
      final RenderBox? scrollBox = _rightScrollController.position.context.storageContext.findRenderObject() as RenderBox?;
      if (scrollBox != null && scrollBox.hasSize && scrollBox.attached) {
        final scrollGlobalY = scrollBox.localToGlobal(Offset.zero).dy;

        for (int i = 0; i < _categories.length; i++) {
          final key = _blockKeys[i];
          if (key == null) continue;

          final context = key.currentContext;
          if (context == null) continue;

          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize && box.attached) {
            final globalY = box.localToGlobal(Offset.zero).dy;
            final relativeTop = globalY - scrollGlobalY;
            final height = box.size.height;
            
            // Match standard category visibility intersections
            if (relativeTop <= 120 && relativeTop + height > 40) {
              activeIdx = i;
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating scroll positions: $e');
    }

    if (activeIdx != null && activeIdx != _activeIndex) {
      setState(() {
        _activeIndex = activeIdx!;
      });
      _scrollToLeftIndex(activeIdx);
    }
  }

  Widget _buildBanner() {
    if (_bannerImage.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        _bannerImage,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCategoryBlock(int index, List<InnerSection> sections) {
    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No items found',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((s) {
        return Padding(
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
                children: s.children.map((child) {
                  return SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 130) / 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.searchResults,
                          arguments: {
                            'query': child.name,
                            'categoryId': child.id,
                          },
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 65,
                            height: 65,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F6F8),
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              child.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            child.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4B5563),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFB5404)));
    }
    if (_categories.isEmpty) {
      return const Center(child: Text('No categories found'));
    }

    if (_innerCategories.length != _categories.length) {
      _innerCategories = List<List<InnerSection>?>.filled(_categories.length, null);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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
            
            // Split screen layout
            Expanded(
              child: Row(
                children: [
                  // Left menu sidebar
                  Container(
                    width: 86,
                    color: const Color(0xFFF5F6F8),
                    child: ListView.builder(
                      controller: _leftScrollController,
                      itemCount: _categories.length,
                      itemBuilder: (_, i) {
                        final c = _categories[i];
                        final active = i == _activeIndex;
                        return InkWell(
                          onTap: () => _handleCategoryPress(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(
                              color: active ? Colors.white : const Color(0xFFF5F6F8),
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
                  
                  // Right subcategory grid content
                  Expanded(
                    child: ListView.builder(
                      controller: _rightScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _categories.length,
                      itemBuilder: (context, i) {
                        final block = _innerCategories[i];
                        final key = _blockKeys.putIfAbsent(i, () => GlobalKey());
                        
                        // Load item lazily if null
                        if (block == null) {
                          _lazyLoadInner(i);
                          return _CategorySkeletonLoader(key: key);
                        }

                        if (i == 0) {
                          return Container(
                            key: key,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_bannerImage.isNotEmpty) ...[
                                  _buildBanner(),
                                  const SizedBox(height: 14),
                                ],
                                _buildCategoryBlock(i, block),
                              ],
                            ),
                          );
                        }

                        return Container(
                          key: key,
                          child: _buildCategoryBlock(i, block),
                        );
                      },
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

class _CategorySkeletonLoader extends StatefulWidget {
  const _CategorySkeletonLoader({super.key});

  @override
  State<_CategorySkeletonLoader> createState() => _CategorySkeletonLoaderState();
}

class _CategorySkeletonLoaderState extends State<_CategorySkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.45, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header placeholder
            Container(
              width: 110,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            // Subcategories placeholders
            Wrap(
              spacing: 6,
              runSpacing: 14,
              children: List.generate(3, (index) {
                return SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 130) / 3,
                  child: Column(
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 50,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

