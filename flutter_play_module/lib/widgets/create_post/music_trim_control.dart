import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/format_time.dart';

/// Instagram-style: selection window fixed in center, waveform scrolls under it.
class MusicTrimControl extends StatefulWidget {
  final String? trackTitle;
  final String? trackArtist;
  final int musicDurationMs;
  final int videoClipMs;
  final int startMs;
  final int? playheadMs;
  final ValueChanged<int> onStartChanged;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onRemove;
  final VoidCallback? onChange;
  final bool compact;
  final double? panelHeight;

  const MusicTrimControl({
    super.key,
    this.trackTitle,
    this.trackArtist,
    required this.musicDurationMs,
    required this.videoClipMs,
    required this.startMs,
    this.playheadMs,
    required this.onStartChanged,
    this.onDragStart,
    this.onDragEnd,
    this.onRemove,
    this.onChange,
    this.compact = false,
    this.panelHeight,
  });

  @override
  State<MusicTrimControl> createState() => _MusicTrimControlState();
}

class _MusicTrimControlState extends State<MusicTrimControl> {
  static const _barCount = 80;
  late final List<double> _peaks;

  @override
  void initState() {
    super.initState();
    // Deterministic natural-looking waveform
    _peaks = List.generate(_barCount, (i) {
      final t = i / _barCount;
      final v = 0.28 +
          0.38 * (math.sin(t * 38.0) * math.sin(t * 11.0)).abs() +
          0.20 * (math.sin(t * 73.0)).abs() +
          0.14 * (math.sin(t * 19.0)).abs();
      return v.clamp(0.10, 0.96);
    });
  }

  int get _windowMs => widget.videoClipMs.clamp(1, widget.musicDurationMs);
  int get _maxStartMs =>
      (widget.musicDurationMs - _windowMs).clamp(0, widget.musicDurationMs);
  int get _safeStart => widget.startMs.clamp(0, _maxStartMs);

  @override
  Widget build(BuildContext context) {
    if (widget.musicDurationMs <= 0 || _windowMs <= 0) {
      return const SizedBox.shrink();
    }

    final pad = widget.compact ? 12.0 : 14.0;
    const waveH = 44.0;

    final panel = Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_outlined,
                  size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trackTitle?.isNotEmpty == true
                          ? widget.trackTitle!
                          : 'Trim Music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: widget.compact ? 13.0 : 14.0,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.trackArtist?.isNotEmpty == true)
                      Text(
                        widget.trackArtist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Clip duration
              Text(
                formatMillis(_windowMs),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              // Total music duration
              Text(
                ' / ${formatMillis(widget.musicDurationMs)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildWaveform(waveH: waveH),
          const SizedBox(height: 6),
          if (widget.onRemove != null || widget.onChange != null)
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Drag to select',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onChange != null)
                  _MusicPanelAction(
                    label: 'Change',
                    onTap: widget.onChange!,
                  ),
                if (widget.onRemove != null) ...[
                  const SizedBox(width: 6),
                  _MusicPanelAction(
                    label: 'Remove',
                    onTap: widget.onRemove!,
                    danger: true,
                  ),
                ],
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drag_indicator_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.28)),
                const SizedBox(width: 4),
                Text(
                  'Drag to select',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    if (widget.panelHeight != null) {
      return SizedBox(height: widget.panelHeight, child: panel);
    }
    return panel;
  }

  Widget _buildWaveform({required double waveH}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackW = constraints.maxWidth;
        final pxPerMs = trackW / widget.musicDurationMs;

        final rawWindowW = _windowMs * pxPerMs;
        final windowW = rawWindowW.clamp(40.0, trackW * 0.62);
        final selLeft = (trackW - windowW) / 2;
        final playhead = widget.playheadMs;
        final showPlayhead = playhead != null && playhead >= 0 && _windowMs > 0;
        final playheadLeft = showPlayhead
            ? selLeft + (playhead.clamp(0, _windowMs) / _windowMs) * windowW
            : 0.0;

        return GestureDetector(
          onHorizontalDragStart: (_) => widget.onDragStart?.call(),
          onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
          onHorizontalDragUpdate: (d) {
            if (_maxStartMs <= 0) return;
            final msPerPx = widget.musicDurationMs / trackW;
            final next =
                (_safeStart - d.delta.dx * msPerPx).round().clamp(0, _maxStartMs);
            widget.onStartChanged(next);
          },
          child: SizedBox(
            height: waveH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Container(color: const Color(0xFF0D0D0D)),
                  CustomPaint(
                    size: Size(trackW, waveH),
                    painter: _ScrollingWaveformPainter(
                      peaks: _peaks,
                      musicDurationMs: widget.musicDurationMs,
                      startMs: _safeStart,
                      selLeft: selLeft,
                      windowW: windowW,
                      trackW: trackW,
                    ),
                  ),
                  Positioned(
                    left: selLeft,
                    width: windowW,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                  if (showPlayhead)
                    Positioned(
                      left: playheadLeft.clamp(selLeft + 1, selLeft + windowW - 2) - 1,
                      width: 2,
                      top: 2,
                      bottom: 2,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFfb5204),
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFfb5204).withValues(alpha: 0.55),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: selLeft + 1,
                    width: 4,
                    top: waveH * 0.25,
                    height: waveH * 0.50,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: selLeft + windowW - 5,
                    width: 4,
                    top: waveH * 0.25,
                    height: waveH * 0.50,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MusicPanelAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MusicPanelAction({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: danger
                ? Colors.redAccent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: danger
                  ? Colors.redAccent.withValues(alpha: 0.45)
                  : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: danger ? Colors.redAccent : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Scrolling waveform — only bars inside selection box are bright
// ─────────────────────────────────────────────
class _ScrollingWaveformPainter extends CustomPainter {
  final List<double> peaks;
  final int musicDurationMs;
  final int startMs;
  final double selLeft;
  final double windowW;
  final double trackW;

  static final _dimColor = Colors.white.withValues(alpha: 0.18);
  static final _brightColor = Colors.white.withValues(alpha: 0.92);

  _ScrollingWaveformPainter({
    required this.peaks,
    required this.musicDurationMs,
    required this.startMs,
    required this.selLeft,
    required this.windowW,
    required this.trackW,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = peaks.length;
    if (count == 0 || musicDurationMs <= 0) return;

    final pxPerMs = trackW / musicDurationMs;
    final waveLeft = selLeft - startMs * pxPerMs;
    final pitch = trackW / count;
    final barW = (pitch * 0.56).clamp(1.5, 3.5);
    final barOffset = (pitch - barW) / 2;
    final selRight = selLeft + windowW;

    for (var i = 0; i < count; i++) {
      final x = waveLeft + i * pitch + barOffset;
      if (x + barW < 0 || x > size.width) continue;

      final barCenter = x + barW / 2;
      final inSelection = barCenter >= selLeft && barCenter <= selRight;

      final h = (peaks[i] * (size.height - 6)).clamp(3.0, size.height - 4.0);
      final paint = Paint()..color = inSelection ? _brightColor : _dimColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, barW, h),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollingWaveformPainter old) =>
      old.peaks != peaks ||
      old.musicDurationMs != musicDurationMs ||
      old.startMs != startMs ||
      old.selLeft != selLeft ||
      old.windowW != windowW ||
      old.trackW != trackW;
}
