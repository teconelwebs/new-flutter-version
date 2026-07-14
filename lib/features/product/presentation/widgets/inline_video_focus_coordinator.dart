import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Picks at most one product-card video to play based on on-screen visibility.
///
/// Cards report a visibility score; the highest score above [minVisibleFraction]
/// becomes active. Everyone else should pause.
class InlineVideoFocusCoordinator extends ChangeNotifier {
  InlineVideoFocusCoordinator._();
  static final InlineVideoFocusCoordinator instance =
      InlineVideoFocusCoordinator._();

  static const double minVisibleFraction = 0.35;

  final Map<String, double> _scores = {};
  String? _activeId;

  String? get activeId => _activeId;

  bool isActive(String id) => _activeId == id;

  void report(String id, double score) {
    final clamped = score.clamp(0.0, 1.0);
    if ((_scores[id] ?? -1) == clamped) return;
    _scores[id] = clamped;
    _recompute();
  }

  void unregister(String id) {
    if (!_scores.containsKey(id)) return;
    _scores.remove(id);
    if (_activeId == id) _activeId = null;
    _recompute();
  }

  void _recompute() {
    String? bestId;
    var bestScore = minVisibleFraction;

    _scores.forEach((id, score) {
      if (score > bestScore) {
        bestScore = score;
        bestId = id;
      }
    });

    if (bestId != _activeId) {
      _activeId = bestId;
      notifyListeners();
    }
  }
}

/// Measures how much of [child] is visible and reports to [InlineVideoFocusCoordinator].
class FocusTrackedVideo extends StatefulWidget {
  const FocusTrackedVideo({
    super.key,
    required this.videoId,
    required this.builder,
  });

  final String videoId;
  final Widget Function(BuildContext context, bool isActive) builder;

  @override
  State<FocusTrackedVideo> createState() => _FocusTrackedVideoState();
}

class _FocusTrackedVideoState extends State<FocusTrackedVideo> {
  final _coordinator = InlineVideoFocusCoordinator.instance;
  ScrollPosition? _scrollPosition;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _coordinator.addListener(_onCoordinatorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachAndMeasure());
  }

  @override
  void didUpdateWidget(FocusTrackedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _coordinator.unregister(oldWidget.videoId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reattachScrollListener();
  }

  void _reattachScrollListener() {
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(next, _scrollPosition)) return;
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    _scrollPosition?.removeListener(_measure);
    _scrollPosition = next;
    _scrollPosition?.addListener(_measure);
    _scrollPosition?.isScrollingNotifier.addListener(_onScrollActivity);
  }

  void _attachAndMeasure() {
    if (!mounted) return;
    _reattachScrollListener();
    _measure();
  }

  void _onScrollActivity() {
    // Keep measuring while fling/drag is active.
    _measure();
  }

  void _onCoordinatorChanged() {
    final active = _coordinator.isActive(widget.videoId);
    if (active != _isActive && mounted) {
      setState(() => _isActive = active);
    }
  }

  void _measure() {
    if (!mounted) return;

    void run() {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) {
        _coordinator.report(widget.videoId, 0);
        return;
      }

      final size = box.size;
      if (size.height <= 0 || size.width <= 0) {
        _coordinator.report(widget.videoId, 0);
        return;
      }

      final topLeft = box.localToGlobal(Offset.zero);
      final screen = MediaQuery.sizeOf(context);
      final viewPadding = MediaQuery.viewPaddingOf(context);

      final visibleTop = viewPadding.top;
      final visibleBottom = screen.height - viewPadding.bottom;

      final cardTop = topLeft.dy;
      final cardBottom = topLeft.dy + size.height;

      final overlapTop = cardTop < visibleTop ? visibleTop : cardTop;
      final overlapBottom =
          cardBottom > visibleBottom ? visibleBottom : cardBottom;
      final visibleHeight =
          (overlapBottom - overlapTop).clamp(0.0, size.height);
      final fraction = visibleHeight / size.height;

      // Prefer cards closer to the vertical center of the viewport.
      final cardCenterY = cardTop + size.height / 2;
      final viewportCenterY = (visibleTop + visibleBottom) / 2;
      final maxDistance = (visibleBottom - visibleTop) / 2;
      final centerBias = maxDistance <= 0
          ? 1.0
          : (1.0 -
                  ((cardCenterY - viewportCenterY).abs() / maxDistance)
                      .clamp(0.0, 1.0))
              .clamp(0.0, 1.0);

      final score = fraction * (0.65 + 0.35 * centerBias);
      _coordinator.report(widget.videoId, score);
    }

    // Avoid layout-phase setState issues from notifyListeners.
    SchedulerBinding.instance.scheduleFrameCallback((_) => run());
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    _scrollPosition?.removeListener(_measure);
    _coordinator.removeListener(_onCoordinatorChanged);
    _coordinator.unregister(widget.videoId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isActive);
  }
}
