import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' as play;

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../data/account_api_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _api = AccountApiService();
  bool _loading = true;
  AccountUser? _user;

  final List<_MenuItem> _menu = const [
    _MenuItem(
      keyName: 'profile',
      label: 'Profile',
      subtitle: 'View & Manage',
      icon: Icons.person,
      tint: Color(0xFFE11D48),
      bg: Color(0xFFFFE4E6),
    ),
    _MenuItem(
      keyName: 'orders',
      label: 'Orders',
      subtitle: 'Track & Orders',
      icon: Icons.shopping_bag_outlined,
      tint: Color(0xFF0D9488),
      bg: Color(0xFFCCFBF1),
    ),
    _MenuItem(
      keyName: 'addresses',
      label: 'Address',
      subtitle: 'City & State',
      icon: Icons.location_on_outlined,
      tint: Color(0xFF4F46E5),
      bg: Color(0xFFE0E7FF),
    ),
    _MenuItem(
      keyName: 'wishlist',
      label: 'Wishlist',
      subtitle: 'Saved Items',
      icon: Icons.favorite_border_rounded,
      tint: Color(0xFFDB2777),
      bg: Color(0xFFFCE7F3),
    ),
    _MenuItem(
      keyName: 'playProfile',
      label: 'Play Profile',
      subtitle: 'Video & Plays',
      icon: Icons.play_circle_outline,
      tint: Color(0xFF0EA5E9),
      bg: Color(0xFFE0F2FE),
    ),
    _MenuItem(
      keyName: 'help',
      label: 'Help Center',
      subtitle: 'Instant Help',
      icon: Icons.headset_mic_outlined,
      tint: Color(0xFFD97706),
      bg: Color(0xFFFEF3C7),
    ),
    _MenuItem(
      keyName: 'settings',
      label: 'Settings',
      subtitle: 'Privacy',
      icon: Icons.settings_outlined,
      tint: Color(0xFF111827),
      bg: Color(0xFFFAF9F6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final u = await _api.fetchUser();
      if (!mounted) return;
      setState(() => _user = u);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await SessionStore.clearLogin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _onMenuTap(_MenuItem item) {
    switch (item.keyName) {
      case 'profile':
        Navigator.of(context).pushNamed(AppRoutes.profile);
        return;
      case 'playProfile':
        _openPlayRoute(play.AppRoutes.myProfile);
        return;
      case 'addresses':
      case 'orders':
      case 'wishlist':
      case 'help':
      case 'settings':
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.label} screen coming next')),
        );
    }
  }

  Future<void> _openPlayRoute(String routeName) async {
    final routeWithSession = await _buildPlayRouteWithSession(routeName);
    final route = play.AppRoutes.onGenerateRoute(
      RouteSettings(name: routeWithSession),
    );
    if (route == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Play module route unavailable')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(route);
  }

  Future<String> _buildPlayRouteWithSession(String routeName) async {
    return play.PlayProfileHelper.buildAuthenticatedRoute(routeName);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final name = (_user?.name ?? 'User').trim();
    final phone = (_user?.phone ?? '').trim();
    final initials = name.isEmpty
        ? 'U'
        : name
            .split(' ')
            .where((s) => s.trim().isNotEmpty)
            .take(2)
            .map((s) => s.trim()[0].toUpperCase())
            .join();

    final double screenWidth = MediaQuery.of(context).size.width;
    // Calculate aspect ratio dynamically based on screen size to prevent text truncation
    final double childAspectRatio = screenWidth < 360 ? 2.3 : (screenWidth < 400 ? 2.65 : 2.9);

    return SafeArea(
      top: true,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'User' : name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: const TextStyle(color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage profile, orders, addresses and wishlist',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _menu.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (_, i) {
                final m = _menu[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _onMenuTap(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF3F4F6)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: m.bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(m.icon, size: 16, color: m.tint),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                m.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                m.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFFC7C7C7),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openPlayRoute(play.AppRoutes.search),
              icon: const Icon(Icons.search_rounded, color: Color(0xFFFB5404)),
              label: const Text(
                'Search Welfog Videos',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
              label: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.keyName,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.bg,
  });

  final String keyName;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color bg;
}
