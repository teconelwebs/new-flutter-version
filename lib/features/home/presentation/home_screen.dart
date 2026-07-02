import 'package:flutter/material.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../account/presentation/account_screen.dart';
import '../../../core/constants/app_routes.dart';
import '../../category/presentation/category_screen.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../product/data/models/product_item.dart';
import '../../search/presentation/search_screen.dart';
import '../data/home_api_service.dart';
import '../data/home_models.dart';
import 'widgets/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = AppRoutes.home;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  static const int _playTabIndex = 2;
  final HomeApiService _homeApi = HomeApiService();
  late Future<HomeBundle> _bundleFuture;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _homeApi.fetchHomeBundle();
  }

  void _openPlay() {
    Navigator.of(context).pushNamed(play.AppRoutes.reels);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _HomeTab(
            bundleFuture: _bundleFuture,
            onRefresh: () async {
              setState(() {
                _bundleFuture = _homeApi.fetchHomeBundle();
              });
              await _bundleFuture;
            },
            onSearch: () {
            Navigator.of(context).pushNamed(SearchScreen.routeName);
            },
          ),
          const CategoryScreen(embedded: true),
          const SizedBox.shrink(),
          const CartScreen(embedded: true),
          const AccountScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          if (index == _playTabIndex) {
            _openPlay();
            return;
          }
          setState(() => _tabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Category',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle_fill_rounded),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.onSearch,
    required this.bundleFuture,
    required this.onRefresh,
  });

  final VoidCallback onSearch;
  final Future<HomeBundle> bundleFuture;
  final Future<void> Function() onRefresh;

  ProductItem _toProductItem(HomeProduct p, int index) {
    const fallbackColors = [
      Color(0xFFFFD9D9),
      Color(0xFFDDF4FF),
      Color(0xFFE8FFE1),
      Color(0xFFFFF0CC),
      Color(0xFFF3E8FF),
    ];
    return ProductItem(
      id: p.id.toString(),
      title: p.name,
      subtitle: p.brand.isEmpty ? 'Fast delivery' : p.brand,
      price: p.price,
      rating: p.rating,
      color: fallbackColors[index % fallbackColors.length],
      imageUrl: p.image,
      slug: p.slug,
      brand: p.brand,
      durationMinutes: p.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: FutureBuilder<HomeBundle>(
        future: bundleFuture,
        builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load home data'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final bundle = snap.data!;
        final dealList = bundle.todayDeals.take(10).toList();
        final sections = bundle.sections.take(4).toList();
        final promo = [...bundle.banner1, ...bundle.banner2].take(3).toList();

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeader(
                  city: bundle.city,
                  pincode: bundle.pincode,
                  onSearchTap: onSearch,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: BannerCarousel(items: bundle.mobileSlider),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ProductStrip(
                    title: 'Today Deals',
                    products: dealList,
                    onProductTap: (p) {
                      Navigator.of(context).pushNamed(
                        AppRoutes.product,
                        arguments: _toProductItem(p, 0),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Column(
                    children: promo
                        .map(
                          (b) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                b.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              ...sections.map(
                (s) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ProductStrip(
                      title: s.name,
                      products: s.products.take(10).toList(),
                      onProductTap: (p) {
                        Navigator.of(context).pushNamed(
                          AppRoutes.product,
                          arguments: _toProductItem(p, s.products.indexOf(p)),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
        },
      ),
    );
  }
}

