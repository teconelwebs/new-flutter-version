import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

/// Let ExoPlayer share the Android audio session with [AudioPlayer] music overlay.
final createPostVideoOptions = VideoPlayerOptions(mixWithOthers: true);

/// Video timeline drives music — single source of truth for audio sync.
class VideoAudioSync {
  static const _driftThresholdMs = 450;
  static const _driftCheckIntervalMs = 2500;
  static const _scrubThrottleMs = 35;

  static bool _globalContextReady = false;

  final AudioPlayer audioPlayer;
  String? _loadedUrl;
  bool _cachedIsPlaying = false;
  int _lastDriftCheckAt = 0;
  int _operationGen = 0;
  Timer? _scrubThrottle;
  bool _previewMode = false;
  bool _scrubbing = false;
  int? _pendingScrubMs;
  double _pendingScrubVolume = 1.0;
  DateTime? _lastScrubSeekAt;

  VideoAudioSync(this.audioPlayer);

  static AudioContext get _audioContext => AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.duckOthers,
          },
        ),
      );

  /// One global audio session for all players — safe to call many times.
  static Future<void> ensureGlobalAudioContext() async {
    if (_globalContextReady) return;
    await AudioPlayer.global.setAudioContext(_audioContext);
    _globalContextReady = true;
  }

  Future<void> _bindPlayerContext() async {
    await ensureGlobalAudioContext();
    await audioPlayer.setAudioContext(_audioContext);
  }

  Future<void> configureAudioContext() => ensureGlobalAudioContext();

  Future<void> bindPlayer() => _bindPlayerContext();

  static Future<void> bindSharedPlayer(AudioPlayer player) async {
    await ensureGlobalAudioContext();
    await player.setAudioContext(_audioContext);
  }

  bool isSourceLoaded(String url) => _loadedUrl == url;

  /// Music picker previews on the shared player without going through [prepareSource].
  /// Adopt that load so we don't stop/reload right before synced playback.
  void adoptLoadedSource(String url) {
    _cancelScrubTimer();
    _loadedUrl = url;
    _previewMode = false;
    _scrubbing = false;
  }

  Future<bool> _waitForSourceReady({int maxAttempts = 50}) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 40));
      }
      try {
        final duration = await audioPlayer.getDuration();
        if (duration != null && duration > Duration.zero) return true;
        final state = audioPlayer.state;
        if (state == PlayerState.playing || state == PlayerState.paused) {
          final pos = await audioPlayer.getCurrentPosition();
          if (pos != null) return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> prepareSource(String url, {bool force = false}) async {
    if (!force && _loadedUrl == url) return;
    _cancelScrubTimer();
    _operationGen++;

    await _bindPlayerContext();

    final state = audioPlayer.state;
    if (state == PlayerState.playing || state == PlayerState.paused) {
      await audioPlayer.stop();
    }
    await audioPlayer.setReleaseMode(ReleaseMode.stop);
    await audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await audioPlayer.setSource(UrlSource(url));
    _loadedUrl = url;
    _previewMode = false;
    _scrubbing = false;
    await _waitForSourceReady();
  }

  void _cancelScrubTimer() {
    _scrubThrottle?.cancel();
    _scrubThrottle = null;
    _pendingScrubMs = null;
  }

  void cancelScheduledPreview() {
    _cancelScrubTimer();
    if (!_scrubbing) {
      _operationGen++;
    }
    _previewMode = false;
    _scrubbing = false;
  }

  void beginMusicScrub() {
    _cancelScrubTimer();
    _previewMode = true;
    _scrubbing = true;
    _lastScrubSeekAt = null;
  }

  void endMusicScrub() {
    _cancelScrubTimer();
    _scrubbing = false;
    _previewMode = false;
  }

  Future<void> haltPlayback() async {
    _cancelScrubTimer();
    _scrubbing = false;
    _previewMode = false;
    _operationGen++;
    _cachedIsPlaying = false;
    if (audioPlayer.state == PlayerState.playing) {
      await audioPlayer.pause();
    }
  }

  /// Reliable start after seek — handles paused, stopped, and silent-resume cases.
  Future<void> _startAudioAt(int positionMs, {double volume = 1.0}) async {
    final url = _loadedUrl;
    if (url == null) return;

    await _bindPlayerContext();
    await audioPlayer.setVolume(volume);

    final state = audioPlayer.state;
    if (state == PlayerState.playing) {
      await audioPlayer.pause();
    }

    await audioPlayer.seek(Duration(milliseconds: positionMs));

    if (state == PlayerState.stopped || state == PlayerState.completed) {
      await audioPlayer.play(UrlSource(url));
      await audioPlayer.seek(Duration(milliseconds: positionMs));
    } else {
      await audioPlayer.resume();
    }

    if (audioPlayer.state != PlayerState.playing) {
      await Future.delayed(const Duration(milliseconds: 50));
      await audioPlayer.resume();
    }
    if (audioPlayer.state != PlayerState.playing) {
      await audioPlayer.play(UrlSource(url));
      await audioPlayer.seek(Duration(milliseconds: positionMs));
    }
    await audioPlayer.setVolume(volume);
  }

  /// ExoPlayer steals Android audio route when [video.play] runs even at volume 0.
  /// Player may still report [PlayerState.playing] while output is silent — hard restart.
  Future<void> _assertAudibleAfterVideoStart(int positionMs, {double volume = 1.0}) async {
    final url = _loadedUrl;
    if (url == null) return;

    await Future.delayed(const Duration(milliseconds: 70));
    await _bindPlayerContext();

    try {
      await audioPlayer.stop();
      await audioPlayer.setReleaseMode(ReleaseMode.stop);
      await audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await audioPlayer.setSource(UrlSource(url));
      await _waitForSourceReady(maxAttempts: 30);
      await audioPlayer.setVolume(volume);
      await audioPlayer.seek(Duration(milliseconds: positionMs));
      await audioPlayer.resume();
      if (audioPlayer.state != PlayerState.playing) {
        await audioPlayer.play(UrlSource(url));
        await audioPlayer.seek(Duration(milliseconds: positionMs));
      }
      await audioPlayer.setVolume(volume);
    } catch (_) {}
  }

  /// Instant waveform scrub — seek without pause/resume cycle.
  void scrubMusicTo(int positionMs, {double volume = 1.0, bool immediate = false}) {
    if (_loadedUrl == null) return;
    _previewMode = true;
    _pendingScrubMs = positionMs;
    _pendingScrubVolume = volume;

    final now = DateTime.now();
    final sinceLast = _lastScrubSeekAt == null
        ? _scrubThrottleMs
        : now.difference(_lastScrubSeekAt!).inMilliseconds;

    _scrubThrottle?.cancel();
    if (immediate || sinceLast >= _scrubThrottleMs) {
      unawaited(_executeScrubSeek());
    } else {
      _scrubThrottle = Timer(
        Duration(milliseconds: _scrubThrottleMs - sinceLast),
        () => unawaited(_executeScrubSeek()),
      );
    }
  }

  Future<void> _executeScrubSeek() async {
    final ms = _pendingScrubMs;
    if (ms == null || _loadedUrl == null) return;

    _lastScrubSeekAt = DateTime.now();
    try {
      await _startAudioAt(ms, volume: _pendingScrubVolume);
      _cachedIsPlaying = true;
    } catch (_) {}
  }

  Future<void> syncToVideoTimeline({
    required int videoElapsedMs,
    required int trimStartMs,
    required int trimEndMs,
    required bool shouldPlay,
    double volume = 1.0,
  }) async {
    if (_loadedUrl == null || _previewMode) return;

    _cachedIsPlaying = shouldPlay;
    final targetAudioPos = _audioPosForVideo(
      videoElapsedMs: videoElapsedMs,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
    );

    try {
      if (shouldPlay) {
        if (audioPlayer.state != PlayerState.playing) {
          await _startAudioAt(targetAudioPos, volume: volume);
        } else {
          final current = await audioPlayer.getCurrentPosition();
          if (current != null &&
              (current.inMilliseconds - targetAudioPos).abs() > _driftThresholdMs) {
            await audioPlayer.seek(Duration(milliseconds: targetAudioPos));
          }
        }
      } else if (audioPlayer.state == PlayerState.playing) {
        await audioPlayer.pause();
      }
    } catch (_) {}
  }

  Future<void> correctDriftIfNeeded({
    required int videoElapsedMs,
    required int trimStartMs,
    required int trimEndMs,
  }) async {
    if (_loadedUrl == null || !_cachedIsPlaying || _previewMode) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDriftCheckAt < _driftCheckIntervalMs) return;
    _lastDriftCheckAt = now;

    if (audioPlayer.state != PlayerState.playing) return;

    final targetAudioPos = _audioPosForVideo(
      videoElapsedMs: videoElapsedMs,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
    );

    try {
      final current = await audioPlayer.getCurrentPosition();
      if (current == null) return;
      if ((current.inMilliseconds - targetAudioPos).abs() > _driftThresholdMs) {
        await audioPlayer.seek(Duration(milliseconds: targetAudioPos));
      }
    } catch (_) {}
  }

  Future<void> playTogether({
    required VideoPlayerController video,
    required String musicUrl,
    required int videoStartMs,
    required int musicStartMs,
    required int musicEndMs,
    bool sourceReady = false,
    double musicVolume = 1.0,
  }) async {
    endMusicScrub();
    _previewMode = false;
    final token = ++_operationGen;

    await ensureGlobalAudioContext();

    if (!sourceReady) {
      await prepareSource(musicUrl);
    } else {
      if (audioPlayer.state == PlayerState.playing) {
        await audioPlayer.pause();
      }
      await _waitForSourceReady();
    }
    if (token != _operationGen) return;

    _cachedIsPlaying = false;

    try {
      await video.seekTo(Duration(milliseconds: videoStartMs));
      if (token != _operationGen) return;

      // Music first (with focus), then muted video — avoids ExoPlayer stealing output.
      await _startAudioAt(musicStartMs, volume: musicVolume);
      if (token != _operationGen) return;

      await video.play();
      if (token != _operationGen) return;

      await _assertAudibleAfterVideoStart(musicStartMs, volume: musicVolume);
      if (token != _operationGen) return;

      _cachedIsPlaying = true;
    } catch (_) {}
  }

  Future<void> loopTogether({
    required VideoPlayerController video,
    required int videoStartMs,
    required int musicStartMs,
    required int musicEndMs,
    double musicVolume = 1.0,
  }) async {
    if (_previewMode) return;
    _cachedIsPlaying = false;

    try {
      await ensureGlobalAudioContext();
      if (audioPlayer.state == PlayerState.playing) {
        await audioPlayer.pause();
      }
      await video.seekTo(Duration(milliseconds: videoStartMs));
      await _startAudioAt(musicStartMs, volume: musicVolume);
      await video.play();
      await _assertAudibleAfterVideoStart(musicStartMs, volume: musicVolume);
      _cachedIsPlaying = true;
    } catch (_) {}
  }

  int _audioPosForVideo({
    required int videoElapsedMs,
    required int trimStartMs,
    required int trimEndMs,
  }) {
    final clipDuration = (trimEndMs - trimStartMs).clamp(1, 1 << 30);
    final clampedElapsed = videoElapsedMs.clamp(0, clipDuration);
    return trimStartMs + clampedElapsed;
  }
}
