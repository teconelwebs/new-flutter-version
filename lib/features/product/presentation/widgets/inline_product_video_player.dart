import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:welfog_flutter_play/welfog_flutter_play.dart' show appRouteObserver;

class InlineProductVideoPlayer extends StatefulWidget {
  final String videoUrl;
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
  late VideoPlayerController _controller;
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
    _initializeController();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initializeController() {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isInitialized = true;
            _controller.setVolume(_isMuted ? 0.0 : 1.0);
            _controller.setLooping(widget.loop);
          });
          _syncPlayback();
        }).catchError((error) {
          if (mounted) {
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

  @override
  void didUpdateWidget(InlineProductVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      // Clear manual pause when card leaves focus so it can autoplay again later.
      if (!widget.isActive) {
        _userPaused = false;
      }
      _syncPlayback();
    } else if (oldWidget.autoPlay != widget.autoPlay) {
      _syncPlayback();
    }
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.dispose();
      _isInitialized = false;
      _errorMessage = null;
      _userPaused = false;
      _initializeController();
    }
  }

  void _syncPlayback() {
    if (!_isInitialized) return;
    final shouldPlay =
        widget.autoPlay && widget.isActive && !_userPaused && _routeVisible && _appActive;
    if (shouldPlay) {
      if (!_controller.value.isPlaying) {
        _controller.play();
        if (mounted) setState(() {});
      }
    } else {
      if (_controller.value.isPlaying) {
        _controller.pause();
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
      _syncPlayback();
    }
  }

  @override
  void didPushNext() {
    if (mounted) {
      setState(() {
        _routeVisible = false;
      });
      _syncPlayback();
    }
  }

  @override
  void didPopNext() {
    if (mounted) {
      setState(() {
        _routeVisible = true;
      });
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _userPaused = true;
        _controller.pause();
      } else {
        _userPaused = false;
        if (widget.isActive && _routeVisible && _appActive) {
          _controller.play();
        }
      }
    });
  }

  void _toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 36),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
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
        aspectRatio: _controller.value.aspectRatio == 0
            ? 1
            : _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
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
                            _controller.value.isPlaying
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
              _controller,
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
