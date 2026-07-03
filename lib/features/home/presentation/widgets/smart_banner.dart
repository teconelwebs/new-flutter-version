import 'package:flutter/material.dart';
import 'shimmer_placeholder.dart';

class SmartBanner extends StatefulWidget {
  final String? uri;
  final bool isApiLoading;
  final VoidCallback? onPress;
  final BoxFit resizeMode;
  final void Function(double width, double height)? onImageSize;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const SmartBanner({
    super.key,
    this.uri,
    this.isApiLoading = false,
    this.onPress,
    this.resizeMode = BoxFit.fill,
    this.onImageSize,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<SmartBanner> createState() => _SmartBannerState();
}

class _SmartBannerState extends State<SmartBanner> {
  String? _loadedUri;

  @override
  Widget build(BuildContext context) {
    final bool showShimmer = widget.isApiLoading || widget.uri == null || _loadedUri != widget.uri;

    return GestureDetector(
      onTap: (widget.uri != null && !showShimmer) ? widget.onPress : null,
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: widget.borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 1. Shimmer Placeholder
            if (showShimmer)
              Positioned.fill(
                child: ShimmerPlaceholder(
                  borderRadius: widget.borderRadius,
                  shimmerColors: const [Color(0xFFEBEBEB), Color(0xFFD4D4D4), Color(0xFFEBEBEB)],
                ),
              ),

            // 2. Image loader and dimension checks
            if (widget.uri != null)
              Opacity(
                opacity: showShimmer ? 0.0 : 1.0,
                child: Image.network(
                  widget.uri!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: widget.resizeMode,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 28)),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      // Trigger callback when loading completes successfully
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _loadedUri != widget.uri) {
                          setState(() {
                            _loadedUri = widget.uri;
                          });
                          // Fetch natural dimensions of the image
                          _resolveImageDimensions(widget.uri!);
                        }
                      });
                      return child;
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Resolve natural image dimensions
  void _resolveImageDimensions(String url) {
    if (widget.onImageSize == null) return;
    
    final Image image = Image.network(url);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          widget.onImageSize!(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        }
      }),
    );
  }
}
