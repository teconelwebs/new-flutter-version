import 'dart:async';

import 'package:flutter/material.dart';

import '../models/profile_post.dart';
import '../utils/format_count.dart';
import '../utils/profile_theme.dart';
import '../utils/profile_thumbnail_cache.dart';

// ─────────────────────────────────────────────
// Skeleton / shimmer placeholders
// ─────────────────────────────────────────────
class ProfileSkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxShape shape;

  const ProfileSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<ProfileSkeletonBox> createState() => _ProfileSkeletonBoxState();
}

class _ProfileSkeletonBoxState extends State<ProfileSkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = 0.28 + (_pulse.value * 0.22);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle ? null : widget.borderRadius,
            color: Color.lerp(const Color(0xFFE8E8E8), const Color(0xFFF5F5F5), t),
          ),
        );
      },
    );
  }
}

class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tileW = (MediaQuery.sizeOf(context).width - 2) / 3;
    final tileH = tileW * 1.5;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileSkeletonBox(width: 86, height: 86, shape: BoxShape.circle),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileSkeletonBox(
                      width: 150,
                      height: 14,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 8),
                    ProfileSkeletonBox(
                      width: 110,
                      height: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ProfileSkeletonBox(
                            height: 36,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ProfileSkeletonBox(
                            height: 36,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
              (_) => Column(
                children: [
                  ProfileSkeletonBox(
                    width: 28,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  ProfileSkeletonBox(
                    width: 52,
                    height: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 1,
          runSpacing: 1,
          children: List.generate(
            9,
            (_) => ProfileSkeletonBox(width: tileW, height: tileH),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class EditProfileSkeleton extends StatelessWidget {
  const EditProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPad + 6, 16, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFfb5204), Color(0xFFFFB347)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileSkeletonBox(
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(19),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const ProfileSkeletonBox(width: 72, height: 72, shape: BoxShape.circle),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileSkeletonBox(
                          width: 140,
                          height: 16,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 8),
                        ProfileSkeletonBox(
                          width: 100,
                          height: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileSkeletonBox(
                        width: 36,
                        height: 36,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileSkeletonBox(
                              width: 130,
                              height: 14,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(height: 6),
                            ProfileSkeletonBox(
                              width: 160,
                              height: 10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...List.generate(5, (i) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < 4 ? 8 : 0),
                      child: Row(
                        children: [
                          ProfileSkeletonBox(
                            width: 40,
                            height: 40,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProfileSkeletonBox(
                                  width: 72,
                                  height: 10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 6),
                                ProfileSkeletonBox(
                                  width: double.infinity,
                                  height: 14,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 22),
                  const ProfileSkeletonBox(
                    width: double.infinity,
                    height: 50,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FollowListSkeleton extends StatelessWidget {
  const FollowListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ProfileSkeletonBox(width: 48, height: 48, shape: BoxShape.circle),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileSkeletonBox(
                    width: 120,
                    height: 14,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  SizedBox(height: 6),
                  ProfileSkeletonBox(
                    width: 80,
                    height: 10,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ],
              ),
            ),
            ProfileSkeletonBox(
              width: 36,
              height: 36,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePostSkeleton extends StatelessWidget {
  const CreatePostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: ProfileSkeletonBox(
          width: 88,
          height: 16,
          borderRadius: BorderRadius.circular(6),
        ),
        leading: ProfileSkeletonBox(
          width: 28,
          height: 28,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProfileSkeletonBox(
                width: 96,
                height: 96,
                borderRadius: BorderRadius.circular(28),
              ),
              const SizedBox(height: 24),
              ProfileSkeletonBox(
                width: 180,
                height: 22,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 12),
              ProfileSkeletonBox(
                width: 260,
                height: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 6),
              ProfileSkeletonBox(
                width: 220,
                height: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 28),
              const ProfileSkeletonBox(
                width: double.infinity,
                height: 50,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchVideoGridSkeleton extends StatelessWidget {
  final int itemCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const SearchVideoGridSkeleton({
    super.key,
    this.itemCount = 9,
    this.shrinkWrap = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ??
          (shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 2 / 3,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const ProfileSkeletonBox(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
  }
}

class SearchAccountRowsSkeleton extends StatelessWidget {
  final int count;

  const SearchAccountRowsSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: List.generate(count, (i) {
          final isLast = i == count - 1;
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    ProfileSkeletonBox(width: 44, height: 44, shape: BoxShape.circle),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProfileSkeletonBox(
                            width: 120,
                            height: 13,
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          SizedBox(height: 6),
                          ProfileSkeletonBox(
                            width: 84,
                            height: 10,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ],
                      ),
                    ),
                    ProfileSkeletonBox(
                      width: 14,
                      height: 14,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 64, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }
}

class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              ProfileSkeletonBox(
                width: 18,
                height: 18,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 6),
              ProfileSkeletonBox(
                width: 72,
                height: 14,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        ),
        SearchAccountRowsSkeleton(count: 4),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              ProfileSkeletonBox(
                width: 18,
                height: 18,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              SizedBox(width: 6),
              ProfileSkeletonBox(
                width: 56,
                height: 14,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SearchVideoGridSkeleton(itemCount: 6),
        ),
        SizedBox(height: 24),
      ],
    );
  }
}

class ProfileThumbnailSkeleton extends StatelessWidget {
  final double width;
  final double height;

  const ProfileThumbnailSkeleton({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSkeletonBox(width: width, height: height);
  }
}

class _ProfileThumbnailImage extends StatefulWidget {
  final String? url;
  final double width;
  final double height;

  const _ProfileThumbnailImage({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  State<_ProfileThumbnailImage> createState() => _ProfileThumbnailImageState();
}

class _ProfileThumbnailImageState extends State<_ProfileThumbnailImage> {
  static const _maxRetries = 3;
  int _attempt = 0;
  Timer? _retryTimer;
  bool _retryScheduled = false;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ProfileThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _attempt = 0;
      _retryScheduled = false;
    }
  }

  String? get _normalizedUrl {
    final raw = widget.url?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  void _scheduleRetry() {
    if (_retryScheduled || _attempt >= _maxRetries) return;
    _retryScheduled = true;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: 250 * (_attempt + 1)), () {
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryScheduled = false;
      });
    });
  }

  Widget _placeholder({bool loading = false}) {
    if (loading) {
      return ProfileThumbnailSkeleton(width: widget.width, height: widget.height);
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFE5E5E5),
      alignment: Alignment.center,
      child: const Icon(Icons.videocam_outlined, color: Color(0xFFB0B0B0), size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _normalizedUrl;
    if (url == null) return _placeholder();

    final provider = ProfileThumbnailCache.thumbnailProvider(
      url,
      widget.width,
      MediaQuery.devicePixelRatioOf(context),
    );

    return Image(
      image: provider,
      key: ValueKey('$url-$_attempt'),
      fit: BoxFit.cover,
      width: widget.width,
      height: widget.height,
      alignment: Alignment.center,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) return child;
        return _placeholder(loading: true);
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleRetry());
        return _placeholder();
      },
    );
  }
}

class ProfilePostTile extends StatelessWidget {
  final ProfilePost post;
  final VoidCallback onTap;
  final bool showOwnerActions;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final double? tileWidth;
  final double? tileHeight;

  const ProfilePostTile({
    super.key,
    required this.post,
    required this.onTap,
    this.showOwnerActions = false,
    this.onRetry,
    this.onCancel,
    this.tileWidth,
    this.tileHeight,
  });

  Widget _statusOverlay({
    required List<Widget> children,
    double opacity = 0.72,
  }) {
    return Container(
      color: Colors.black.withValues(alpha: opacity),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = tileWidth ?? (MediaQuery.sizeOf(context).width - 2) / 3;
    final height = tileHeight ?? width * 1.5;
    final thumb = post.thumbnailUrl;

    return GestureDetector(
      onTap: post.isPlayable ? onTap : null,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null && thumb.isNotEmpty)
              _ProfileThumbnailImage(url: thumb, width: width, height: height)
            else
              ProfileThumbnailSkeleton(width: width, height: height),
            if (post.isPreparing)
              _statusOverlay(
                opacity: 0.62,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Preparing play...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showOwnerActions && onCancel != null) ...[
                    const SizedBox(height: 6),
                    _FailedActionChip(
                      label: 'Cancel',
                      filled: false,
                      onTap: onCancel,
                    ),
                  ],
                ],
              ),
            if (post.isStalePreparing)
              _statusOverlay(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                  const SizedBox(height: 4),
                  const Text(
                    'Processing stalled',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showOwnerActions) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FailedActionChip(
                          label: 'Retry',
                          filled: true,
                          onTap: onRetry,
                        ),
                        const SizedBox(width: 4),
                        _FailedActionChip(
                          label: 'Cancel',
                          filled: false,
                          onTap: onCancel,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            if (post.isFailed)
              _statusOverlay(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload failed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showOwnerActions) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FailedActionChip(
                          label: 'Retry',
                          filled: true,
                          onTap: onRetry,
                        ),
                        const SizedBox(width: 4),
                        _FailedActionChip(
                          label: 'Cancel',
                          filled: false,
                          onTap: onCancel,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            if (post.isPlayable)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        formatCount(post.views),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FailedActionChip extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _FailedActionChip({
    required this.label,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFFfb5204) : Colors.white24,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingUploadAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;

  const _PendingUploadAction({
    required this.label,
    this.onTap,
    this.primary = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: ProfileColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? const Color(0xFFDC2626) : ProfileColors.textSecondary,
        side: BorderSide(
          color: destructive ? const Color(0xFFFECACA) : ProfileColors.border,
        ),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class _PendingUploadCard extends StatelessWidget {
  final ProfilePost post;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const _PendingUploadCard({
    required this.post,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isFailed = post.isFailed || post.isStalePreparing;
    final isPreparing = post.isPreparing;

    late final Color accent;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (isFailed) {
      accent = const Color(0xFFDC2626);
      icon = Icons.error_outline_rounded;
      title = post.isStalePreparing ? 'Processing stalled' : 'Upload failed';
      subtitle = post.error?.trim().isNotEmpty == true
          ? post.error!.trim()
          : 'Something went wrong. You can retry or remove this upload.';
    } else if (isPreparing) {
      accent = ProfileColors.primary;
      icon = Icons.hourglass_top_rounded;
      title = 'Preparing your play';
      subtitle = 'Your video is being processed. This usually takes a few minutes.';
    } else {
      accent = ProfileColors.textMuted;
      icon = Icons.videocam_outlined;
      title = 'Upload pending';
      subtitle = 'Waiting to finish processing.';
    }

    final thumb = post.thumbnailUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 68,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null && thumb.isNotEmpty)
                      _ProfileThumbnailImage(url: thumb, width: 68, height: 90)
                    else
                      const ColoredBox(color: Color(0xFFF3F4F6)),
                    Container(
                      color: Colors.black.withValues(alpha: 0.28),
                      alignment: Alignment.center,
                      child: isPreparing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(icon, color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ProfileColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: ProfileColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (isFailed && onRetry != null)
                        _PendingUploadAction(
                          label: 'Retry upload',
                          primary: true,
                          onTap: onRetry,
                        ),
                      if (onCancel != null)
                        _PendingUploadAction(
                          label: isFailed ? 'Remove' : 'Cancel',
                          destructive: isFailed,
                          onTap: onCancel,
                        ),
                    ],
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

class ProfilePendingPostsSection extends StatelessWidget {
  final List<ProfilePost> posts;
  final void Function(ProfilePost post)? onRetryFailed;
  final void Function(ProfilePost post)? onCancelFailed;
  final void Function(ProfilePost post)? onCancelPreparing;
  final void Function(ProfilePost post)? onRetryStale;

  const ProfilePendingPostsSection({
    super.key,
    required this.posts,
    this.onRetryFailed,
    this.onCancelFailed,
    this.onCancelPreparing,
    this.onRetryStale,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ProfileColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: ProfileColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending uploads',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ProfileColors.textPrimary,
                      ),
                    ),
                    Text(
                      posts.length == 1
                          ? '1 video finishing up'
                          : '${posts.length} videos finishing up',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ProfileColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${posts.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ProfileColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...posts.map((post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PendingUploadCard(
                post: post,
                onRetry: post.isStalePreparing
                    ? (onRetryStale == null ? null : () => onRetryStale!(post))
                    : (onRetryFailed == null ? null : () => onRetryFailed!(post)),
                onCancel: post.isPreparing && !post.isStalePreparing
                    ? (onCancelPreparing == null ? null : () => onCancelPreparing!(post))
                    : (onCancelFailed == null ? null : () => onCancelFailed!(post)),
              ),
            );
          }),
          const Divider(height: 16, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }
}

class ProfilePostsSliverGrid extends StatelessWidget {
  final List<ProfilePost> posts;
  final void Function(ProfilePost post, int index) onPostTap;
  final bool loadingMore;
  final bool loadingInitial;
  final bool showOwnerActions;
  final void Function(ProfilePost post)? onRetryFailed;
  final void Function(ProfilePost post)? onCancelFailed;
  final void Function(ProfilePost post)? onCancelPreparing;
  final void Function(ProfilePost post)? onRetryStale;

  const ProfilePostsSliverGrid({
    super.key,
    required this.posts,
    required this.onPostTap,
    this.loadingMore = false,
    this.loadingInitial = false,
    this.showOwnerActions = false,
    this.onRetryFailed,
    this.onCancelFailed,
    this.onCancelPreparing,
    this.onRetryStale,
  });

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 1,
    mainAxisSpacing: 1,
    childAspectRatio: 2 / 3,
  );

  @override
  Widget build(BuildContext context) {
    final tileW = (MediaQuery.sizeOf(context).width - 2) / 3;
    final tileH = tileW * 1.5;

    if (loadingInitial) {
      return SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, __) => ProfileSkeletonBox(width: tileW, height: tileH),
          childCount: 9,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        ),
      );
    }

    if (posts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(Icons.videocam_off_outlined, size: 48, color: Color(0xFF9CA3AF)),
              SizedBox(height: 12),
              Text('No Videos Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              SizedBox(height: 6),
              Text('This user hasn\'t posted any videos yet.', style: TextStyle(color: Color(0xFF666666))),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= posts.length) {
            return ProfileThumbnailSkeleton(width: tileW, height: tileH);
          }
          final post = posts[index];
          return ProfilePostTile(
            key: ValueKey(post.id),
            post: post,
            onTap: () => onPostTap(post, index),
            showOwnerActions: showOwnerActions,
            tileWidth: tileW,
            tileHeight: tileH,
            onRetry: post.isStalePreparing
                ? (onRetryStale == null ? null : () => onRetryStale!(post))
                : (onRetryFailed == null ? null : () => onRetryFailed!(post)),
            onCancel: post.isPreparing && !post.isStalePreparing
                ? (onCancelPreparing == null ? null : () => onCancelPreparing!(post))
                : (onCancelFailed == null ? null : () => onCancelFailed!(post)),
          );
        },
        childCount: posts.length + (loadingMore ? 3 : 0),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      ),
    );
  }
}

/// Legacy non-sliver grid — prefer [ProfilePostsSliverGrid] inside [CustomScrollView].
class ProfilePostsGrid extends StatelessWidget {
  final List<ProfilePost> posts;
  final void Function(ProfilePost post, int index) onPostTap;
  final bool loadingMore;
  final bool loadingInitial;
  final bool showOwnerActions;
  final void Function(ProfilePost post)? onRetryFailed;
  final void Function(ProfilePost post)? onCancelFailed;
  final void Function(ProfilePost post)? onCancelPreparing;
  final void Function(ProfilePost post)? onRetryStale;

  const ProfilePostsGrid({
    super.key,
    required this.posts,
    required this.onPostTap,
    this.loadingMore = false,
    this.loadingInitial = false,
    this.showOwnerActions = false,
    this.onRetryFailed,
    this.onCancelFailed,
    this.onCancelPreparing,
    this.onRetryStale,
  });

  @override
  Widget build(BuildContext context) {
    final tileW = (MediaQuery.sizeOf(context).width - 2) / 3;
    final tileH = tileW * 1.5;

    if (loadingInitial) {
      return Wrap(
        spacing: 1,
        runSpacing: 1,
        children: List.generate(
          9,
          (_) => ProfileSkeletonBox(width: tileW, height: tileH),
        ),
      );
    }

    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.videocam_off_outlined, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('No Videos Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
            SizedBox(height: 6),
            Text('This user hasn\'t posted any videos yet.', style: TextStyle(color: Color(0xFF666666))),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 2 / 3,
      ),
      itemCount: posts.length + (loadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return ProfileThumbnailSkeleton(width: tileW, height: tileH);
        }
        final post = posts[index];
        return ProfilePostTile(
          post: post,
          onTap: () => onPostTap(post, index),
          showOwnerActions: showOwnerActions,
          onRetry: post.isStalePreparing
              ? (onRetryStale == null ? null : () => onRetryStale!(post))
              : (onRetryFailed == null ? null : () => onRetryFailed!(post)),
          onCancel: post.isPreparing && !post.isStalePreparing
              ? (onCancelPreparing == null ? null : () => onCancelPreparing!(post))
              : (onCancelFailed == null ? null : () => onCancelFailed!(post)),
        );
      },
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.size = 86,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFfb5204), Color(0xFFFF8C00)]),
      ),
      padding: const EdgeInsets.all(2.5),
      child: CircleAvatar(
        radius: (size - 5) / 2,
        backgroundColor: Colors.white,
        backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? ProfileThumbnailCache.thumbnailProvider(
                imageUrl!,
                size,
                MediaQuery.devicePixelRatioOf(context),
              )
            : null,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Icon(Icons.person, size: size * 0.45, color: Colors.grey.shade600)
            : null,
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const ProfileStat({super.key, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: ProfileColors.textMuted)),
        ],
      ),
    );
  }
}
