import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' show appRouteObserver;

class InlineProductVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? placeholderUrl;
  final bool autoPlay;
  final bool loop;
  final bool initialMuted;

  /// When false, video stays paused (used for focus-based play in grids).
  /// Defaults to true so gallery / standalone usages keep autoplay.
  final bool isActive;

  /// Progress bar, play/pause, and mute controls.
  /// Suggested product cards pass false.
  final bool showControls;

  const InlineProductVideoPlayer({
    super.key,
    required this.videoUrl,
    this.placeholderUrl,
    this.autoPlay = true,
    this.loop = true,
    this.initialMuted = false,
    this.isActive = true,
    this.showControls = true,
  });

  @override
  State<InlineProductVideoPlayer> createState() =>
      _InlineProductVideoPlayerState();
}

class _InlineProductVideoPlayerState extends State<InlineProductVideoPlayer>
    with RouteAware, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _showControls = false;
  bool _userPaused = false;
  String? _errorMessage;
  bool _routeSubscribed = false;
  bool _routeVisible = true;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialMuted;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkControllerState();
    });
  }

  void _checkControllerState() {
    final shouldBeRunning = widget.isActive && _routeVisible && _appActive;

    if (shouldBeRunning) {
      if (_controller == null) {
        _initializeController();
      } else if (_isInitialized) {
        _syncPlayback();
      }
    } else {
      if (_controller != null) {
        _disposeController();
      }
    }
  }

  void _initializeController() {
    if (_controller != null) return;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _controller = controller;
      controller.initialize().then((_) {
        if (!mounted || _controller != controller) {
          controller.dispose();
          return;
        }
        setState(() {
          _isInitialized = true;
          controller.setVolume(_isMuted ? 0.0 : 1.0);
          controller.setLooping(widget.loop);
        });
        _syncPlayback();
      }).catchError((error) {
        if (mounted && _controller == controller) {
          setState(() {
            _errorMessage = 'Failed to load video';
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize player';
      });
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    if (controller != null) {
      controller.dispose();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(InlineProductVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      // Clear manual pause when card leaves focus so it can autoplay again later.
      if (!widget.isActive) {
        _userPaused = false;
      } else {
        // Clear error and trigger retry if it becomes active/visible
        if (_errorMessage != null) {
          _errorMessage = null;
        }
      }
      _checkControllerState();
    } else if (oldWidget.autoPlay != widget.autoPlay) {
      _syncPlayback();
    }
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _errorMessage = null;
      _userPaused = false;
      _checkControllerState();
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    final shouldPlay =
        widget.autoPlay && widget.isActive && !_userPaused && _routeVisible && _appActive;
    if (shouldPlay) {
      if (!controller.value.isPlaying) {
        controller.play();
        if (mounted) setState(() {});
      }
    } else {
      if (controller.value.isPlaying) {
        controller.pause();
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        appRouteObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextActive = state == AppLifecycleState.resumed;
    if (nextActive != _appActive) {
      _appActive = nextActive;
      _checkControllerState();
    }
  }

  @override
  void didPushNext() {
    if (mounted) {
      setState(() {
        _routeVisible = false;
      });
      _checkControllerState();
    }
  }

  @override
  void didPopNext() {
    if (mounted) {
      setState(() {
        _routeVisible = true;
      });
      _checkControllerState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _disposeController();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        _userPaused = true;
        controller.pause();
      } else {
        _userPaused = false;
        if (widget.isActive && _routeVisible && _appActive) {
          controller.play();
        }
      }
    });
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _errorMessage = null;
          });
          _checkControllerState();
        },
        child: Container(
          color: const Color(0xFFF3F4F6),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    color: Color(0xFFFB5404), size: 36),
                const SizedBox(height: 8),
                Text(
                  '${_errorMessage!}. Tap to retry.',
                  style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !_isInitialized) {
      if (widget.placeholderUrl != null && widget.placeholderUrl!.isNotEmpty) {
        return Image.network(
          widget.placeholderUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF3F4F6),
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined, size: 26),
            ),
          ),
        );
      }
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB5404)),
          ),
        ),
      );
    }

    final video = Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 1
            : controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );

    if (!widget.showControls) {
      return video;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          video,
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Container(
                color: const Color(0x33000000),
                child: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0x80000000),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0x80000000),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFFB5404),
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}
