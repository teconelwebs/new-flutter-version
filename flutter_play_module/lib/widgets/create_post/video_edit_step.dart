import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:video_player/video_player.dart';

import '../../models/music_track.dart';
import '../../models/upload_draft.dart';
import '../../services/reels_api.dart';
import '../../utils/format_time.dart';
import 'music_picker_sheet.dart';
import 'music_trim_control.dart';
import 'trim_range_control.dart';
import 'video_audio_sync.dart';

// ─────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────
const _kBg = Color(0xFF0F0F0F);
const _kSurface = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF2C2C2C);
const _kPurple = Color(0xFF7B4FFF);
const _kPurple2 = Color(0xFF9B6FFF);
const _kPurpleText = Color(0xFFB494FF);
const _kWhite = Colors.white;
/// Shared height for Trim / Music / Reset panels (max; shrinks on small screens).
const _kEditPanelHeight = 152.0;
/// Fixed chrome below video — keeps controls aligned on every screen size.
const _kProgressBarHeight = 3.0;

// ─────────────────────────────────────────────
// Active edit tab enum
// ─────────────────────────────────────────────
enum _EditTab { trimVideo, editMusic, reset }

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────
class VideoEditStep extends StatefulWidget {
  final UploadDraft draft;
  final ReelsApi api;
  final VoidCallback onBack;
  final Future<void> Function(UploadDraft) onNext;

  const VideoEditStep({
    super.key,
    required this.draft,
    required this.api,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<VideoEditStep> createState() => _VideoEditStepState();
}

class _VideoEditStepState extends State<VideoEditStep> with TickerProviderStateMixin {
  late UploadDraft _draft;

  VideoPlayerController? _videoController;
  final ScreenshotController _screenshotController = ScreenshotController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final VideoAudioSync _sync = VideoAudioSync(_audioPlayer);

  bool _videoReady = false;
  bool _generatingCover = false;
  bool _isVideoTrimming = false;
  bool _isMusicTrimming = false;
  bool _isLooping = false;
  bool _isStartingPlayback = false;
  bool _coverGenerated = false;
  bool _muted = false;
  bool _isProcessingNext = false;

  int _coverScrubMs = 0;
  int _musicDurationMs = 0;

  _EditTab _activeTab = _EditTab.trimVideo;

  // Volume state
  double _musicVolume = 1.0;
  double _originalVolume = 1.0; // video/original audio; muted when music overlay is added

  // Playback progress for timeline scrubber
  int _playPositionMs = 0;
  int _musicPlayheadMs = 0;
  bool _showMusicPlayhead = false;
  Timer? _progressTimer;

  // Animation for play button overlay
  late final AnimationController _playFadeCtrl;
  late final Animation<double> _playFadeAnim;
  bool _showPlayOverlay = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _coverScrubMs = _draft.videoStartMs;
    _musicVolume = _draft.musicVolume;
    _originalVolume = _draft.originalVolume;
    _restoreMusicFromDraft();

    _playFadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _playFadeAnim = CurvedAnimation(parent: _playFadeCtrl, curve: Curves.easeOut);

    // Audio context MUST be configured before any audio operation.
    // _initVideo is chained after so audio session is always ready first.
    // catchError ensures video always initialises even if setAudioContext()
    // fails (e.g. on some Android versions when launched from React Native).
    _sync.configureAudioContext()
        .then((_) => _sync.bindPlayer())
        .then((_) => _initVideo())
        .catchError((_) => _initVideo());
  }

  /// Rebuild local music UI state from draft (e.g. after Next → Back).
  void _restoreMusicFromDraft() {
    final music = _draft.music;
    if (music == null) return;
    _musicDurationMs = music.durationMs > 0 ? music.durationMs : 180000;
    _activeTab = _EditTab.editMusic;
    _normalizeMusicTrim();
  }

  // ── Video init ──────────────────────────────
  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(
      _draft.videoFile,
      videoPlayerOptions: createPostVideoOptions,
    );
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      final durationMs = controller.value.duration.inMilliseconds;
      if (_draft.videoDurationMs <= 0 && durationMs > 0) {
        _draft.videoEndMs = durationMs.clamp(UploadDraft.minVideoMs, UploadDraft.maxVideoMs);
      }
      _coverScrubMs = _draft.videoStartMs;
      await controller.seekTo(Duration(milliseconds: _draft.videoStartMs));
      await controller.setLooping(false);
      await _applyVideoVolume();
      _attachVideoLoop(controller);
      setState(() => _videoReady = true);
      _startProgressTimer();

      if (_draft.music != null) {
        await _sync.prepareSource(_draft.music!.url);
        await _startSyncedPlayback();
      } else {
        // Generate cover before playback — playing first caused a visible restart
        // when cover capture seeked back to trim start.
        if (!_coverGenerated) {
          await _generateCoverAt(_coverScrubMs, resumePlayback: false);
          _coverGenerated = true;
        }
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  // ── Progress timer for the timeline indicator ──
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _tickProgress();
    });
  }

  void _tickProgress() {
    if (!mounted) return;
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    final pos = c.value.position.inMilliseconds;
    var playhead = _musicPlayheadMs;
    var showPlayhead = _showMusicPlayhead;

    if (_draft.music != null && _activeTab == _EditTab.editMusic) {
      if (_isMusicTrimming) {
        _audioPlayer.getCurrentPosition().then((audioPos) {
          if (!mounted || !_isMusicTrimming) return;
          final ph = audioPos == null
              ? 0
              : (audioPos.inMilliseconds - _draft.musicStartMs).clamp(0, _videoClipMs);
          if (ph != _musicPlayheadMs || !_showMusicPlayhead) {
            setState(() {
              _musicPlayheadMs = ph;
              _showMusicPlayhead = true;
            });
          }
        });
      } else if (c.value.isPlaying || _audioPlayer.state == PlayerState.playing) {
        playhead = (pos - _draft.videoStartMs).clamp(0, _videoClipMs);
        showPlayhead = true;
      } else {
        showPlayhead = false;
      }
    } else {
      showPlayhead = false;
    }

    if (pos != _playPositionMs ||
        playhead != _musicPlayheadMs ||
        showPlayhead != _showMusicPlayhead) {
      setState(() {
        _playPositionMs = pos;
        _musicPlayheadMs = playhead;
        _showMusicPlayhead = showPlayhead;
      });
    }
  }

  // ── Video loop listener ─────────────────────
  void _attachVideoLoop(VideoPlayerController controller) {
    controller.removeListener(_onVideoTick);
    controller.addListener(_onVideoTick);
  }

  void _onVideoTick() {
    if (_isVideoTrimming || _isMusicTrimming || _isLooping || _isStartingPlayback) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final pos = controller.value.position.inMilliseconds;
    final hasMusic = _draft.music != null;
    final videoElapsed = (pos - _draft.videoStartMs).clamp(0, _videoClipMs);

    if (pos >= _draft.videoEndMs - 100) {
      _isLooping = true;
      if (hasMusic) {
        _sync
            .loopTogether(
              video: controller,
              videoStartMs: _draft.videoStartMs,
              musicStartMs: _draft.musicStartMs,
              musicEndMs: _draft.musicEndMs,
              musicVolume: _muted ? 0.0 : _musicVolume,
            )
            .whenComplete(() => _isLooping = false);
      } else {
        controller.seekTo(Duration(milliseconds: _draft.videoStartMs)).then((_) {
          controller.play();
          _isLooping = false;
        });
      }
      return;
    }

    if (pos < _draft.videoStartMs) {
      controller.seekTo(Duration(milliseconds: _draft.videoStartMs));
      return;
    }

    if (!hasMusic) return;

    final isVideoPlaying = controller.value.isPlaying && !_generatingCover;
    if (isVideoPlaying) {
      if (_audioPlayer.state != PlayerState.playing) {
        _sync.syncToVideoTimeline(
          videoElapsedMs: videoElapsed,
          trimStartMs: _draft.musicStartMs,
          trimEndMs: _draft.musicEndMs,
          shouldPlay: true,
          volume: _muted ? 0.0 : _musicVolume,
        );
      } else {
        _sync.correctDriftIfNeeded(
          videoElapsedMs: videoElapsed,
          trimStartMs: _draft.musicStartMs,
          trimEndMs: _draft.musicEndMs,
        );
      }
    } else if (_audioPlayer.state == PlayerState.playing) {
      _sync.syncToVideoTimeline(
        videoElapsedMs: videoElapsed,
        trimStartMs: _draft.musicStartMs,
        trimEndMs: _draft.musicEndMs,
        shouldPlay: false,
      );
    }
  }

  Future<void> _handleBackPress() async {
    if (_isProcessingNext) return;

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline_rounded, color: Color(0xFFfb5204), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'If you go back now, your trim, music, and cover changes will be lost.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      side: const BorderSide(color: Color(0xFF111827), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Continue Editing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFdc2626),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Discard',
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (discard != true || !mounted) return;
    _progressTimer?.cancel();
    await _haltSyncedPlayback();
    widget.onBack();
  }

  // ── Playback helpers ────────────────────────
  Future<void> _applyVideoVolume() async {
    final volume = _muted ? 0.0 : _originalVolume;
    await _videoController?.setVolume(volume);
  }

  Future<void> _haltSyncedPlayback() async {
    final controller = _videoController;
    if (controller == null) return;
    await _sync.haltPlayback();
    await controller.pause();
    await controller.seekTo(Duration(milliseconds: _draft.videoStartMs));
  }

  Future<void> _startSyncedPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final music = _draft.music;
    if (music == null) {
      await _applyVideoVolume();
      await controller.seekTo(Duration(milliseconds: _draft.videoStartMs));
      await controller.play();
      if (mounted) setState(() {});
      return;
    }

    await _applyVideoVolume();
    final musicVol = _muted ? 0.0 : _musicVolume;
    await _audioPlayer.setVolume(musicVol);

    _isStartingPlayback = true;
    try {
      await _sync.playTogether(
        video: controller,
        musicUrl: music.url,
        videoStartMs: _draft.videoStartMs,
        musicStartMs: _draft.musicStartMs,
        musicEndMs: _draft.musicEndMs,
        sourceReady: _sync.isSourceLoaded(music.url),
        musicVolume: musicVol,
      );
    } finally {
      _isStartingPlayback = false;
    }
    if (!controller.value.isPlaying) {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  // ── Play / pause toggle ─────────────────────
  Future<void> _togglePlayback() async {
    HapticFeedback.lightImpact();
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await _haltSyncedPlayback();
    } else {
      await _startSyncedPlayback();
    }
    _showPlayOverlayBriefly();
    setState(() {});
  }

  void _showPlayOverlayBriefly() {
    _showPlayOverlay = true;
    _playFadeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _playFadeCtrl.reverse().then((_) {
        if (mounted) setState(() => _showPlayOverlay = false);
      });
    });
  }

  // ── Mute / unmute original video audio ─────
  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    _muted = !_muted;
    await _applyVideoVolume();
    if (_draft.music != null) {
      await _audioPlayer.setVolume(_muted ? 0 : _musicVolume);
    }
    setState(() {});
  }

  // ── Cover ───────────────────────────────────
  Future<void> _generateCoverAt(int timeMs, {bool resumePlayback = true}) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final wasPlaying = controller.value.isPlaying;
    setState(() => _generatingCover = true);
    try {
      await controller.seekTo(Duration(milliseconds: timeMs.clamp(0, _draft.effectiveDurationMs)));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final bytes = await _screenshotController.capture();
      if (!mounted || bytes == null) {
        setState(() => _generatingCover = false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes, flush: true);
      setState(() {
        _draft.coverPath = file.path;
        _generatingCover = false;
      });
      if (resumePlayback && (wasPlaying || _draft.music != null)) {
        await controller.seekTo(Duration(milliseconds: _draft.videoStartMs));
        await _startSyncedPlayback();
      }
    } catch (_) {
      if (mounted) setState(() => _generatingCover = false);
    }
  }

  Future<void> _removeMusic() async {
    HapticFeedback.mediumImpact();
    await _videoController?.pause();
    await _sync.haltPlayback();
    await _audioPlayer.stop();
    setState(() {
      _draft.music = null;
      _musicDurationMs = 0;
      _draft.musicStartMs = 0;
      _draft.musicEndMs = 0;
      _musicVolume = 1.0;
      _originalVolume = 1.0;
      _draft.musicVolume = 1.0;
      _draft.originalVolume = 1.0;
    });
    await _applyVideoVolume();
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(Duration(milliseconds: _draft.videoStartMs));
      await controller.play();
    }
  }

  void _applyDefaultMusicVolumes() {
    _musicVolume = 1.0;
    _originalVolume = 0.0;
    _draft.musicVolume = 1.0;
    _draft.originalVolume = 0.0;
  }

  // ── Music ───────────────────────────────────
  Future<void> _pickMusic() async {
    HapticFeedback.mediumImpact();
    await _haltSyncedPlayback();
    if (!mounted) return;
    final result = await MusicPickerSheet.show(
      context,
      widget.api,
      selected: _draft.music,
      sharedPlayer: _audioPlayer,
    );
    if (!mounted) return;
    if (result == null) {
      if (_draft.music != null) {
        await _startSyncedPlayback();
      } else {
        await _videoController?.play();
      }
      return;
    }
    if (result.removeMusic) {
      await _removeMusic();
      return;
    }
    final picked = result.track;
    if (picked == null) {
      if (_draft.music != null) {
        await _startSyncedPlayback();
      } else {
        await _videoController?.play();
      }
      return;
    }
    await _applyMusicSelection(picked, audioPrimed: result.audioPrimed);
  }

  Future<void> _applyMusicSelection(MusicTrack picked, {required bool audioPrimed}) async {
    setState(() {
      _draft.music = picked;
      _musicDurationMs = picked.durationMs > 0 ? picked.durationMs : 180000;
      _draft.musicStartMs = 0;
      _normalizeMusicTrim();
      _applyDefaultMusicVolumes();
      _activeTab = _EditTab.editMusic;
    });

    // Picker previews on the shared player directly; adopt that load instead of
    // force-reloading (which races on first pick and leaves video paused).
    // Pause picker preview so synced start owns playback (avoids resume/focus race).
    if (_audioPlayer.state == PlayerState.playing) {
      await _audioPlayer.pause();
    }

    if (audioPrimed && !_sync.isSourceLoaded(picked.url)) {
      _sync.adoptLoadedSource(picked.url);
    } else if (!_sync.isSourceLoaded(picked.url)) {
      await _sync.prepareSource(picked.url, force: true);
    }

    await _startSyncedPlayback();
    if (mounted) setState(() {});
  }

  // ── Music math ──────────────────────────────
  int get _videoClipMs =>
      (_draft.videoEndMs - _draft.videoStartMs).clamp(UploadDraft.minVideoMs, UploadDraft.maxVideoMs);

  int _fixedMusicWindowMs() => _videoClipMs.clamp(UploadDraft.minVideoMs, _musicDurationMs);

  int _clipMusicEnd(int startMs) {
    final window = _fixedMusicWindowMs();
    return (startMs + window).clamp(startMs + UploadDraft.minVideoMs, _musicDurationMs);
  }

  int _maxMusicStartMs() => (_musicDurationMs - _fixedMusicWindowMs()).clamp(0, _musicDurationMs);

  void _normalizeMusicTrim() {
    _draft.musicStartMs = _draft.musicStartMs.clamp(0, _maxMusicStartMs());
    _draft.musicEndMs = _clipMusicEnd(_draft.musicStartMs);
  }

  // ── Trim callbacks ──────────────────────────
  void _onVideoTrimDragStart() {
    _isVideoTrimming = true;
    _sync.haltPlayback();
    _videoController?.pause();
  }

  void _onVideoTrimChanged(({int start, int end}) range) {
    setState(() {
      _draft.videoStartMs = range.start;
      _draft.videoEndMs = range.end;
      if (_draft.music != null) _normalizeMusicTrim();
      _coverScrubMs = range.start;
    });
    // Only seek to show the frame — no play, no cover during drag
    _videoController?.seekTo(Duration(milliseconds: range.start));
  }

  Future<void> _onVideoTrimDragEnd() async {
    _isVideoTrimming = false;
    if (_draft.music == null) {
      await _generateCoverAt(_coverScrubMs, resumePlayback: false);
    }
    await _startSyncedPlayback();
  }

  void _onMusicTrimDragStart() {
    _isMusicTrimming = true;
    _videoController?.pause();
    _sync.beginMusicScrub();
    setState(() {
      _musicPlayheadMs = 0;
      _showMusicPlayhead = true;
    });
    _sync.scrubMusicTo(
      _draft.musicStartMs,
      volume: _muted ? 0 : _musicVolume,
      immediate: true,
    );
  }

  void _onMusicTrimChanged(int startMs) {
    final clamped = startMs.clamp(0, _maxMusicStartMs());
    setState(() {
      _draft.musicStartMs = clamped;
      _draft.musicEndMs = _clipMusicEnd(clamped);
      _musicPlayheadMs = 0;
      _showMusicPlayhead = true;
      _playPositionMs = _draft.videoStartMs;
    });
    _videoController?.seekTo(Duration(milliseconds: _draft.videoStartMs));
    _sync.scrubMusicTo(
      clamped,
      volume: _muted ? 0 : _musicVolume,
      immediate: true,
    );
  }

  Future<void> _onMusicTrimDragEnd() async {
    _isMusicTrimming = false;
    _sync.endMusicScrub();
    await _sync.haltPlayback();
    await _videoController?.seekTo(Duration(milliseconds: _draft.videoStartMs));
    setState(() {
      _musicPlayheadMs = 0;
      _playPositionMs = _draft.videoStartMs;
    });
    await _startSyncedPlayback();
  }

  // ── Reset ───────────────────────────────────
  Future<void> _resetAll() async {
    HapticFeedback.mediumImpact();
    await _haltSyncedPlayback();
    setState(() {
      _draft.videoStartMs = 0;
      _draft.videoEndMs = _draft.effectiveDurationMs.clamp(UploadDraft.minVideoMs, UploadDraft.maxVideoMs);
      _draft.music = null;
      _musicDurationMs = 0;
      _draft.musicStartMs = 0;
      _draft.musicEndMs = 0;
      _draft.coverPath = null;
      _coverGenerated = false;
      _coverScrubMs = 0;
      _activeTab = _EditTab.trimVideo;
    });
    _musicVolume = 1.0;
    _originalVolume = 1.0;
    _draft.musicVolume = 1.0;
    _draft.originalVolume = 1.0;
    await _applyVideoVolume();
    await _startSyncedPlayback();
  }

  void _syncDraftVolumes() {
    _draft.musicVolume = _musicVolume;
    _draft.originalVolume = _originalVolume;
  }

  // ── Apply ───────────────────────────────────
  Future<void> _onApply() async {
    if (_isProcessingNext) return;
    HapticFeedback.heavyImpact();
    setState(() => _isProcessingNext = true);
    try {
      await _haltSyncedPlayback();
      _syncDraftVolumes();
      await widget.onNext(_draft);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare preview. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingNext = false);
    }
  }

  // ── Cover picker sheet ─────────────────────
  // ignore: unused_element
  Future<void> _showCoverPicker() async {
    final mainController = _videoController;
    if (mainController == null || !mainController.value.isInitialized) return;
    await mainController.pause();
    final sheetController = VideoPlayerController.file(
      _draft.videoFile,
      videoPlayerOptions: createPostVideoOptions,
    );
    var scrub = _coverScrubMs.clamp(_draft.videoStartMs, _draft.videoEndMs);

    try {
      await sheetController.initialize();
      await sheetController.seekTo(Duration(milliseconds: scrub));
      await sheetController.pause();
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: _kBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final screenH = MediaQuery.sizeOf(context).height;
              final previewH = screenH * 0.28;
              final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Select Cover',
                        style: TextStyle(
                          color: _kWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: previewH,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColoredBox(
                            color: Colors.black,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: sheetController.value.size.width > 0
                                    ? sheetController.value.size.width
                                    : 1080,
                                height: sheetController.value.size.height > 0
                                    ? sheetController.value.size.height
                                    : 1920,
                                child: VideoPlayer(sheetController),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          activeTrackColor: _kPurple,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: _kPurple2,
                        ),
                        child: Slider(
                          value: scrub.toDouble(),
                          min: _draft.videoStartMs.toDouble(),
                          max: _draft.videoEndMs.toDouble(),
                          onChanged: (v) async {
                            scrub = v.round();
                            setModalState(() {});
                            await sheetController.seekTo(Duration(milliseconds: scrub));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatMillis(_draft.videoStartMs),
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            Text(
                              formatMillis(scrub),
                              style: const TextStyle(
                                color: _kPurpleText,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              formatMillis(_draft.videoEndMs),
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: _PurpleButton(
                          onPressed: _generatingCover
                              ? null
                              : () async {
                                  setState(() => _coverScrubMs = scrub);
                                  await mainController
                                      .seekTo(Duration(milliseconds: scrub));
                                  await _generateCoverAt(scrub);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                          label: _generatingCover ? 'Saving…' : 'Use this frame',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      await sheetController.dispose();
      if (mounted) {
        if (_draft.music != null) {
          await _startSyncedPlayback();
        } else {
          await mainController.seekTo(Duration(milliseconds: _coverScrubMs));
          await mainController.play();
        }
      }
    }
  }

  // ── Tab panel content ───────────────────────
  Widget _buildTabPanel(double panelHeight) {
    switch (_activeTab) {
      case _EditTab.trimVideo:
        return TrimRangeControl(
          title: 'Trim Video',
          icon: Icons.content_cut_rounded,
          durationMs: _draft.effectiveDurationMs,
          startMs: _draft.videoStartMs,
          endMs: _draft.videoEndMs,
          maxClipMs: UploadDraft.maxVideoMs,
          onDragStart: _onVideoTrimDragStart,
          onChanged: _onVideoTrimChanged,
          onDragEnd: _onVideoTrimDragEnd,
          dark: true,
          compact: true,
          panelHeight: panelHeight,
        );

      case _EditTab.editMusic:
        if (_draft.music == null) {
          return _MusicSelectPanel(
            panelHeight: panelHeight,
            onSelect: _pickMusic,
          );
        }
        return MusicTrimControl(
          trackTitle: _draft.music!.title,
          trackArtist: _draft.music!.artist,
          musicDurationMs: _musicDurationMs,
          videoClipMs: _videoClipMs,
          startMs: _draft.musicStartMs,
          playheadMs: _showMusicPlayhead ? _musicPlayheadMs : null,
          onDragStart: _onMusicTrimDragStart,
          onDragEnd: () => _onMusicTrimDragEnd(),
          onStartChanged: _onMusicTrimChanged,
          onChange: _pickMusic,
          onRemove: _removeMusic,
          compact: true,
          panelHeight: panelHeight,
        );

      case _EditTab.reset:
        return _ResetCard(onReset: _resetAll, panelHeight: panelHeight);
    }
  }

  // ── Dispose ─────────────────────────────────
  @override
  void dispose() {
    _progressTimer?.cancel();
    _sync.cancelScheduledPreview();
    _playFadeCtrl.dispose();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final isPlaying = controller?.value.isPlaying ?? false;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelHeight = (constraints.maxHeight * 0.21).clamp(128.0, _kEditPanelHeight);

          return Stack(
            children: [
              Scaffold(
                backgroundColor: _kBg,
                body: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: _buildVideoPreview(controller, isPlaying),
                      ),
                    ),
                    _VideoProgressBar(
                      startMs: _draft.videoStartMs,
                      endMs: _draft.videoEndMs,
                      positionMs: _playPositionMs,
                      visible: _videoReady,
                    ),
                    const SizedBox(height: 6),
                    _buildControlTabs(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14, 4, 14, bottomSafe + 6),
                      child: SizedBox(
                        height: panelHeight,
                        child: _buildTabPanel(panelHeight),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isProcessingNext)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.68),
                      child: const Center(
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            color: _kPurple2,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Video preview ────────────────────────────
  Widget _buildVideoPreview(
    VideoPlayerController? controller,
    bool isPlaying,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: ColoredBox(
              color: Colors.black,
              child: _videoReady && controller != null
                  ? Screenshot(
                      controller: _screenshotController,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: controller.value.size.width > 0
                              ? controller.value.size.width
                              : 1080,
                          height: controller.value.size.height > 0
                              ? controller.value.size.height
                              : 1920,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2),
                    ),
            ),
          ),

          // Top bar: back + time (left), mute (right)
          Positioned(
            top: 4,
            left: 8,
            right: 8,
            child: Row(
              children: [
                _VideoOverlayIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  onTap: _handleBackPress,
                ),
                const SizedBox(width: 8),
                if (_videoReady && controller != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${formatMillis(_playPositionMs)} / ${formatMillis(_draft.videoEndMs)}',
                      style: const TextStyle(
                        color: _kWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                if (_videoReady) ...[
                  _VideoOverlayIconButton(
                    icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 18,
                    onTap: _toggleMute,
                  ),
                  const SizedBox(width: 6),
                  _VideoNextButton(
                    onTap: _isProcessingNext ? null : _onApply,
                  ),
                ],
              ],
            ),
          ),

          // Play/Pause overlay
          if (_showPlayOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _playFadeAnim,
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: _kWhite,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
    );
  }

  // ── Control tabs bar ─────────────────────────
  Widget _buildControlTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _TabButton(
            icon: Icons.content_cut_rounded,
            label: 'Trim Videos',
            active: _activeTab == _EditTab.trimVideo,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeTab = _EditTab.trimVideo);
            },
          ),
          const SizedBox(width: 8),
          _TabButton(
            icon: Icons.music_note_rounded,
            label: 'Edit Music',
            active: _activeTab == _EditTab.editMusic,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeTab = _EditTab.editMusic);
            },
          ),
          const SizedBox(width: 8),
          _TabButton(
            icon: Icons.refresh_rounded,
            label: 'Reset',
            active: _activeTab == _EditTab.reset,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeTab = _EditTab.reset);
            },
          ),
        ],
      ),
    );
  }

  // ── Apply bar ────────────────────────────────
}

// ─────────────────────────────────────────────
// Next pill on video overlay
// ─────────────────────────────────────────────
class _VideoNextButton extends StatelessWidget {
  final Future<void> Function()? onTap;

  const _VideoNextButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kPurple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Next',
                style: TextStyle(
                  color: _kWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.arrow_forward_rounded, color: _kWhite, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Video overlay icon button (back / mute)
// ─────────────────────────────────────────────
class _VideoOverlayIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _VideoOverlayIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: _kWhite, size: size),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Thin video progress bar
// ─────────────────────────────────────────────
class _VideoProgressBar extends StatelessWidget {
  final int startMs;
  final int endMs;
  final int positionMs;
  final bool visible;

  const _VideoProgressBar({
    required this.startMs,
    required this.endMs,
    required this.positionMs,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    final clipMs = (endMs - startMs).clamp(1, 1 << 30);
    final progress = visible ? ((positionMs - startMs) / clipMs).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: _kProgressBarHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.white12),
          if (visible)
            FractionallySizedBox(
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_kPurple, _kPurple2]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab button
// ─────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? _kPurple.withValues(alpha: 0.18) : _kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? _kPurple : _kBorder,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? _kPurple2 : Colors.white54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? _kPurpleText : Colors.white54,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Purple gradient button
// ─────────────────────────────────────────────
class _PurpleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const _PurpleButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(colors: [_kPurple, _kPurple2]),
          color: disabled ? const Color(0xFF333333) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: _kPurple.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: disabled ? Colors.white38 : _kWhite,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Music select panel (no track chosen yet)
// ─────────────────────────────────────────────
class _MusicSelectPanel extends StatelessWidget {
  final double panelHeight;
  final VoidCallback onSelect;

  const _MusicSelectPanel({
    required this.panelHeight,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: panelHeight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.music_note_outlined, size: 16, color: Colors.white),
                SizedBox(width: 7),
                Text(
                  'Trim Music',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSelect,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: _kPurple2.withValues(alpha: 0.9),
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select Music',
                          style: TextStyle(
                            color: _kPurpleText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reset card
// ─────────────────────────────────────────────
class _ResetCard extends StatelessWidget {
  final VoidCallback onReset;
  final double panelHeight;

  const _ResetCard({required this.onReset, required this.panelHeight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: panelHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'This will remove all trims and music.\nYour original video stays safe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
