import 'package:flutter/material.dart';

import '../../models/upload_draft.dart';
import '../../utils/format_time.dart';

class TrimRangeControl extends StatelessWidget {
  final String title;
  final IconData icon;
  final int durationMs;
  final int startMs;
  final int endMs;
  final int maxClipMs;
  final bool dark;
  final bool compact;
  final double? panelHeight;
  final ValueChanged<({int start, int end})> onChanged;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const TrimRangeControl({
    super.key,
    required this.title,
    required this.icon,
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.maxClipMs,
    required this.onChanged,
    this.dark = false,
    this.compact = false,
    this.panelHeight,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (durationMs <= 0) return const SizedBox.shrink();
    final safeDuration = durationMs.clamp(1, 1 << 30);
    final startFrac = (startMs / safeDuration).clamp(0.0, 1.0);
    final endFrac = (endMs / safeDuration).clamp(startFrac, 1.0);
    final clipMs = endMs - startMs;
    const accent = Color(0xFFfb5204);
    final pad = compact ? 12.0 : 14.0;
    final gap = compact ? 12.0 : 14.0;
    final titleSize = compact ? 14.0 : 15.0;
    final thumbRadius = compact ? 9.0 : 10.0;

    final panel = Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: dark ? Colors.white : accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: titleSize,
                  color: dark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              Text(
                formatMillis(clipMs),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : accent,
                ),
              ),
              Text(
                ' / ${formatMillis(maxClipMs)} max',
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white54 : const Color(0xFF888888),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          if (panelHeight != null)
            Expanded(
              child: Center(
                child: _buildSlider(
                  context,
                  accent: accent,
                  dark: dark,
                  thumbRadius: thumbRadius,
                  compact: compact,
                  startFrac: startFrac,
                  endFrac: endFrac,
                  safeDuration: safeDuration,
                ),
              ),
            )
          else
            _buildSlider(
              context,
              accent: accent,
              dark: dark,
              thumbRadius: thumbRadius,
              compact: compact,
              startFrac: startFrac,
              endFrac: endFrac,
              safeDuration: safeDuration,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMillis(startMs),
                style: TextStyle(fontSize: 12, color: dark ? Colors.white60 : const Color(0xFF666666)),
              ),
              Text(
                formatMillis(endMs),
                style: TextStyle(fontSize: 12, color: dark ? Colors.white60 : const Color(0xFF666666)),
              ),
            ],
          ),
        ],
      ),
    );

    if (panelHeight != null) {
      return SizedBox(height: panelHeight, child: panel);
    }
    return panel;
  }

  Widget _buildSlider(
    BuildContext context, {
    required Color accent,
    required bool dark,
    required double thumbRadius,
    required bool compact,
    required double startFrac,
    required double endFrac,
    required int safeDuration,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: compact ? 4 : 4,
        rangeThumbShape: RoundRangeSliderThumbShape(enabledThumbRadius: thumbRadius),
        overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 14 : 16),
        activeTrackColor: accent,
        inactiveTrackColor: dark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E5E5),
        thumbColor: accent,
        rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(),
      ),
      child: RangeSlider(
        values: RangeValues(startFrac, endFrac),
        onChangeStart: onDragStart == null ? null : (_) => onDragStart!(),
        onChangeEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
        onChanged: (values) {
          var start = (values.start * safeDuration).round();
          var end = (values.end * safeDuration).round();
          if (end - start > maxClipMs) {
            if (values.end > endFrac) {
              end = start + maxClipMs;
            } else {
              start = end - maxClipMs;
            }
          }
          start = start.clamp(0, safeDuration - UploadDraft.minVideoMs);
          end = end.clamp(start + UploadDraft.minVideoMs, safeDuration);
          if (end - start > maxClipMs) {
            end = (start + maxClipMs).clamp(start + UploadDraft.minVideoMs, safeDuration);
          }
          onChanged((start: start, end: end));
        },
      ),
    );
  }
}
