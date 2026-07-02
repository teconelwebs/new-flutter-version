import 'package:flutter/material.dart';

import '../models/play_launch_context.dart';
import '../screens/create_post_flow_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/follow_list_screen.dart';
import '../screens/my_profile_screen.dart';
import '../screens/other_profile_screen.dart';
import '../models/profile_reels_route_args.dart';
import '../screens/profile_reels_screen.dart';
import '../screens/reels_screen.dart';
import '../screens/search_screen.dart';
import '../services/reels_api.dart';
import '../models/user_profile.dart';
import '../widgets/profile_widgets.dart';
import 'play_session.dart';
import 'flutter_nav.dart';

class AppRoutes {
  static const reels = '/reels';
  static const myProfile = '/profile/me';
  static const otherProfile = '/profile/user';
  static const editProfile = '/profile/edit';
  static const followList = '/profile/follow';
  static const profileReels = '/profile/reels';
  static const search = '/search';
  static const createPost = '/profile/create-post';

  static ReelsScreen _reelsScreen({String initialReelId = ''}) {
    return ReelsScreen(initialReelId: initialReelId);
  }

  static String normalizeInitialRoute(String initialRouteName) {
    if (initialRouteName.isEmpty || initialRouteName == '/') {
      return reels;
    }
    return initialRouteName;
  }

  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRouteName) {
    final name = normalizeInitialRoute(initialRouteName);
    final route = onGenerateRoute(RouteSettings(name: name));
    if (route != null) return [route];
    final fallback = onGenerateRoute(RouteSettings(name: reels));
    return fallback != null ? [fallback] : [];
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? reels;
    final normalizedName = name.startsWith('http')
        ? name
        : (name.startsWith('/') ? name : '/$name');
    // final uri = Uri.tryParse(name.startsWith('/') ? name : '/$name');
    final uri = Uri.tryParse(normalizedName);
    if (uri == null) return null;
    final path = uri.path;

    if (path.startsWith('/api/plays/r/')) {
      final reelId = _initialReelIdFromUri(uri);
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => _wrapSession(
          settings,
          _reelsScreen(initialReelId: reelId),
        ),
      );
    }

    // Profile short link: https://api.welfog.com/api/plays/p/{slug}
    if (path.startsWith('/api/plays/p/')) {
      final profileSlug = path.replaceFirst('/api/plays/p/', '').split('/').first;
      if (profileSlug.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(child: OtherProfileScreen(userId: profileSlug)),
          ),
        );
      }
    }

    // Profile redirect target: https://api.welfog.com/api/plays/dl/profile/{userid}
    if (path.startsWith('/api/plays/dl/profile/')) {
      final profileId =
          path.replaceFirst('/api/plays/dl/profile/', '').split('/').first;
      if (profileId.isNotEmpty) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(child: OtherProfileScreen(userId: profileId)),
          ),
        );
      }
    }

    if (path.startsWith('/OtheruserProfile/')) {
      final profileId =
          path.replaceAll('/OtheruserProfile/', ''); 
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => _wrapSession(
          settings,
          profileScreenWrapper(child: OtherProfileScreen(userId: profileId)),
        ),
      );
    }

    switch (uri.path) {
      case reels:
        final initialReelId = uri.queryParameters['initialReelId'] ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            _reelsScreen(initialReelId: initialReelId),
          ),
        );
      case myProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(child: const MyProfileScreen()),
          ),
        );
      case otherProfile:
        final userId = uri.queryParameters['id'] ??
            (settings.arguments is Map
                ? (settings.arguments as Map)['userId']?.toString()
                : null) ??
            '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(child: OtherProfileScreen(userId: userId)),
          ),
        );
      case editProfile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(child: const EditProfileScreen()),
          ),
        );
      case followList:
        final type = uri.queryParameters['type'] ?? 'followers';
        final userid = uri.queryParameters['userid'] ?? '';
        final isOwn = uri.queryParameters['own'] == '1';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(
              child: FollowListScreen(
                type: type,
                profileUserId: userid,
                isOwnProfile: isOwn,
              ),
            ),
          ),
        );
      case profileReels:
        final profileId = uri.queryParameters['profileId'] ?? '';
        final reelId = uri.queryParameters['reelId'] ?? '';
        final gridIndexRaw = uri.queryParameters['gridIndex'];
        final gridIndex =
            gridIndexRaw == null ? null : int.tryParse(gridIndexRaw);
        final args = settings.arguments;
        final seedReelIds =
            args is ProfileReelsRouteArgs ? args.seedReelIds : const <String>[];
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            ProfileReelsScreen(
              profileMongoId: profileId,
              initialReelId: reelId,
              gridIndexHint: gridIndex,
              seedReelIds: seedReelIds,
            ),
          ),
        );
      case search:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(settings, const SearchScreen()),
        );
      case createPost:
        final profileId = uri.queryParameters['profileId'] ?? '';
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            profileScreenWrapper(
                child: _CreatePostRouteLoader(profileId: profileId)),
          ),
        );
      default:
        final initialReelId = uri.queryParameters['initialReelId'] ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => _wrapSession(
            settings,
            _reelsScreen(initialReelId: initialReelId),
          ),
        );
    }
  }

  static bool _isRootLaunch(RouteSettings settings) {
    final uri = _routeUri(settings);
    if (uri == null) return false;
    final qp = uri.queryParameters;
    if (qp.containsKey('userId') || qp.containsKey('deviceId')) return true;
    if ((qp['initialReelId'] ?? '').trim().isNotEmpty) return true;
    final path = uri.path;
    if (path.startsWith('/api/plays/r/') || path.startsWith('/api/plays/p/')) {
      return true;
    }
    if (path.startsWith('/api/plays/dl/profile/')) return true;
    if (path == otherProfile && (qp['id'] ?? '').trim().isNotEmpty) return true;
    return false;
  }

  static Uri? _routeUri(RouteSettings settings) {
    final name = settings.name ?? reels;
    final normalizedName = name.startsWith('http')
        ? name
        : (name.startsWith('/') ? name : '/$name');
    return Uri.tryParse(normalizedName);
  }

  static String _shareUserIdFromUri(Uri? uri) {
    if (uri == null) return '';
    final fromQuery = uri.queryParameters['shareUserId'] ?? '';
    if (fromQuery.isNotEmpty) return fromQuery;
    final path = uri.path;
    if (!path.startsWith('/api/plays/r/')) return '';
    final segment = path.replaceFirst('/api/plays/r/', '').split('/').first;
    final match = RegExp(r'^([0-9a-fA-F]{24})-(\d+)$').firstMatch(segment);
    return match?.group(2) ?? '';
  }

  static String _initialReelIdFromUri(Uri? uri) {
    if (uri == null) return '';
    final fromQuery = uri.queryParameters['initialReelId'] ?? '';
    if (fromQuery.isNotEmpty) return fromQuery;
    final path = uri.path;
    if (!path.startsWith('/api/plays/r/')) return '';
    final segment = path.replaceFirst('/api/plays/r/', '').split('/').first;
    final match = RegExp(r'^([0-9a-fA-F]{24})-\d+$').firstMatch(segment);
    return match?.group(1) ?? '';
  }

  static Widget _wrapSession(RouteSettings settings, Widget child) {
    if (_isRootLaunch(settings)) {
      final api = _apiFromSettings(settings);
      final launchContext = _launchContextFromSettings(settings);
      return PlaySessionScope(
        initialViewerId: api.viewerId,
        deviceId: api.deviceId,
        shareUserId: api.shareUserId,
        launchContext: launchContext,
        child: child,
      );
    }
    return wrapWithActivePlaySession(child);
  }

  static PlayLaunchContext _launchContextFromSettings(RouteSettings settings) {
    return PlayLaunchContext.fromQuery(_routeUri(settings)?.queryParameters ?? const {});
  }

  static ReelsApi _apiFromSettings(RouteSettings settings) {
    final args = settings.arguments;
    if (args is ReelsApi) return args;

    final uri = _routeUri(settings);
    final viewerId = uri?.queryParameters['userId'] ?? '';
    final deviceId = uri?.queryParameters['deviceId'] ?? '';
    final shareUserId = _shareUserIdFromUri(uri);
    final mainUserId = uri?.queryParameters['mainUserId'] ?? '';

    if (args is Map) {
      return ReelsApi(
        viewerId: args['userId']?.toString() ?? viewerId,
        deviceId: args['deviceId']?.toString() ?? deviceId,
        shareUserId: args['shareUserId']?.toString() ?? shareUserId,
        mainUserId: args['mainUserId']?.toString() ?? mainUserId,
      );
    }

    return ReelsApi(
      viewerId: viewerId.isNotEmpty ? viewerId : 'guest',
      deviceId: deviceId,
      shareUserId: shareUserId,
      mainUserId: mainUserId,
    );
  }

  static Future<void> openProfile(BuildContext context, String targetUserId) {
    final api = PlaySession.apiOf(context);
    if (targetUserId.isEmpty) return Future.value();
    if (targetUserId == api.viewerId) {
      return Navigator.pushNamed(context, myProfile).then((_) {});
    }
    return Navigator.pushNamed(
      context,
      '$otherProfile?id=${Uri.encodeComponent(targetUserId)}',
    ).then((_) {});
  }
}

class _CreatePostRouteLoader extends StatefulWidget {
  final String profileId;

  const _CreatePostRouteLoader({required this.profileId});

  @override
  State<_CreatePostRouteLoader> createState() => _CreatePostRouteLoaderState();
}

class _CreatePostRouteLoaderState extends State<_CreatePostRouteLoader> {
  UserProfile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _profile == null && _error == null) {
      _load();
    }
  }

  Future<void> _load() async {
    final api = PlaySession.apiOf(context);
    try {
      final id = widget.profileId.isNotEmpty ? widget.profileId : api.viewerId;
      final profile = await api.fetchUserProfile(id);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CreatePostSkeleton();
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Post')),
        body: Center(child: Text(_error ?? 'Profile not found')),
      );
    }
    return CreatePostFlowScreen(profile: _profile!);
  }
}
