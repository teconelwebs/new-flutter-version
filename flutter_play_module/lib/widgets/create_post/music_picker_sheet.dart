import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../models/music_track.dart';
import '../../services/reels_api.dart';
import '../../utils/format_time.dart';
import 'video_audio_sync.dart';

class MusicPickerResult {
  final MusicTrack? track;
  final bool removeMusic;
  final bool audioPrimed;

  const MusicPickerResult({
    this.track,
    this.removeMusic = false,
    this.audioPrimed = false,
  });
}

class MusicPickerSheet extends StatefulWidget {
  final ReelsApi api;
  final MusicTrack? selected;
  final AudioPlayer? sharedPlayer;

  const MusicPickerSheet({
    super.key,
    required this.api,
    this.selected,
    this.sharedPlayer,
  });

  static Future<MusicPickerResult?> show(
    BuildContext context,
    ReelsApi api, {
    MusicTrack? selected,
    AudioPlayer? sharedPlayer,
  }) {
    return showModalBottomSheet<MusicPickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPickerSheet(
        api: api,
        selected: selected,
        sharedPlayer: sharedPlayer,
      ),
    );
  }

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  AudioPlayer? _ownedPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;
  final _tracks = <MusicTrack>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _query = '';
  MusicTrack? _previewTrack;
  bool _previewLoading = false;
  bool _previewPlaying = false;
  bool _previewReady = false;
  int _loadToken = 0;
  bool _confirmed = false;

  AudioPlayer get _player => widget.sharedPlayer ?? _ownedPlayer!;

  bool get _usesSharedPlayer => widget.sharedPlayer != null;

  @override
  void initState() {
    super.initState();
    if (!_usesSharedPlayer) {
      _ownedPlayer = AudioPlayer();
    } else {
      unawaited(VideoAudioSync.bindSharedPlayer(_player));
    }
    _scrollController.addListener(_onScroll);
    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _previewPlaying = state == PlayerState.playing);
    });
    _load(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _playerStateSub?.cancel();
    if (!_usesSharedPlayer) {
      _ownedPlayer?.dispose();
    } else if (!_confirmed) {
      _player.stop();
    }
    super.dispose();
  }

  Future<void> _load({required int page, String? query}) async {
    final q = query ?? _query;
    if (page == 1) {
      setState(() {
        _loading = true;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await widget.api.fetchMusic(page: page, query: q);
      if (!mounted) return;
      setState(() {
        _query = q;
        _page = page;
        if (page == 1) {
          _tracks
            ..clear()
            ..addAll(result.items);
        } else {
          final existing = _tracks.map((t) => t.id).toSet();
          _tracks.addAll(result.items.where((t) => !existing.contains(t.id)));
        }
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 120) {
      _load(page: _page + 1);
    }
  }

  Future<void> _onQuerySubmit(String value) async {
    await _load(page: 1, query: value.trim());
  }

  Future<void> _previewSong(MusicTrack track) async {
    final token = ++_loadToken;
    setState(() {
      _previewTrack = track;
      _previewLoading = true;
      _previewReady = false;
      _previewPlaying = false;
    });

    try {
      await VideoAudioSync.ensureGlobalAudioContext();
      await VideoAudioSync.bindSharedPlayer(_player);
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setSource(UrlSource(track.url));
      if (!mounted || token != _loadToken) return;
      await _player.resume();
      if (!mounted || token != _loadToken) return;
      setState(() {
        _previewLoading = false;
        _previewReady = true;
        _previewPlaying = true;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _previewLoading = false;
        _previewReady = false;
        _previewPlaying = false;
      });
    }
  }

  Future<void> _togglePreviewPlayback() async {
    if (_previewTrack == null || _previewLoading) return;
    if (_previewPlaying) {
      await _player.pause();
      return;
    }
    if (_previewReady) {
      await _player.resume();
      return;
    }
    await _previewSong(_previewTrack!);
  }

  Future<void> _confirmSelection() async {
    final track = _previewTrack;
    if (track == null) return;
    if (!_previewReady) {
      await _previewSong(track);
      if (!mounted || _previewTrack?.id != track.id || !_previewReady) return;
    }
    _confirmed = true;
    await _player.pause();
    if (!mounted) return;
    Navigator.pop(
      context,
      MusicPickerResult(track: track, audioPrimed: _usesSharedPlayer && _previewReady),
    );
  }

  String _trackDurationLabel(MusicTrack track) {
    if (track.durationMs <= 0) return '';
    return formatMillis(track.durationMs);
  }

  String? _trackSubtitle(MusicTrack track) {
    final duration = _trackDurationLabel(track);
    final parts = <String>[];
    if (track.artist.isNotEmpty) parts.add(track.artist);
    if (duration.isNotEmpty) parts.add(duration);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String _previewSubtitle(MusicTrack track, {required bool loading, required bool ready}) {
    if (loading) return 'Loading...';
    final duration = _trackDurationLabel(track);
    final parts = <String>[];
    if (track.artist.isNotEmpty) {
      parts.add(track.artist);
    } else if (!ready) {
      parts.add('Tap play to preview');
    }
    if (duration.isNotEmpty) parts.add(duration);
    return parts.isEmpty ? 'Tap play to preview' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final previewHeight = _previewTrack != null ? 78.0 : 0.0;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      margin: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select a Song',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: _onQuerySubmit,
              onChanged: (v) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (!mounted || _searchController.text != v) return;
                  _onQuerySubmit(v);
                });
              },
            ),
          ),
          if (widget.selected != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.music_off_rounded, color: Colors.white54),
              title: const Text('Remove music', style: TextStyle(color: Colors.white70)),
              onTap: () async {
                _confirmed = true;
                await _player.stop();
                if (!context.mounted) return;
                Navigator.pop(context, const MusicPickerResult(removeMusic: true));
              },
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFfb5204)))
                : _tracks.isEmpty
                    ? const Center(
                        child: Text('No songs found', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 12 + previewHeight),
                        itemCount: _tracks.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _tracks.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(color: Color(0xFFfb5204), strokeWidth: 2),
                              ),
                            );
                          }
                          final track = _tracks[index];
                          final isPreview = _previewTrack?.id == track.id;
                          final isSelected = widget.selected?.id == track.id;
                          final durationLabel = _trackDurationLabel(track);
                          final subtitle = _trackSubtitle(track);
                          return ListTile(
                            leading: _MusicThumb(track: track),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isPreview || isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            subtitle: subtitle != null
                                ? Text(
                                    subtitle,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (durationLabel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      durationLabel,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (isPreview)
                                  const Icon(Icons.graphic_eq_rounded, color: Color(0xFFfb5204))
                                else if (isSelected)
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFFfb5204))
                                else
                                  const Icon(Icons.play_circle_outline_rounded, color: Colors.white38),
                              ],
                            ),
                            onTap: () => _previewSong(track),
                          );
                        },
                      ),
          ),
          if (_previewTrack != null)
            Container(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Color(0xFF2E2E2E))),
              ),
              child: Row(
                children: [
                  _MusicThumb(track: _previewTrack!, size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _previewTrack!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          _previewSubtitle(
                            _previewTrack!,
                            loading: _previewLoading,
                            ready: _previewReady,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _previewLoading ? null : _togglePreviewPlayback,
                    icon: _previewLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            _previewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _previewReady ? _confirmSelection : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFfb5204),
                      disabledBackgroundColor: const Color(0xFF444444),
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MusicThumb extends StatelessWidget {
  final MusicTrack track;
  final double size;

  const _MusicThumb({required this.track, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final url = track.coverUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note_rounded, color: const Color(0xFF1DB954), size: size * 0.5),
    );
  }
}
