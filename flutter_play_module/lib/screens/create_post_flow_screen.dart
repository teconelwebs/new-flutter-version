import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/upload_draft.dart';
import '../models/user_profile.dart';
import '../services/video_compress_service.dart';
import '../utils/format_time.dart';
import '../utils/play_session.dart';
import '../widgets/create_post/video_audio_sync.dart';
import '../widgets/create_post/video_edit_step.dart';

enum _CreateStep { picking, editing, posting }

class CreatePostFlowScreen extends StatefulWidget {
  final UserProfile profile;

  const CreatePostFlowScreen({super.key, required this.profile});

  @override
  State<CreatePostFlowScreen> createState() => _CreatePostFlowScreenState();
}

class _CreatePostFlowScreenState extends State<CreatePostFlowScreen> {
  _CreateStep _step = _CreateStep.picking;
  UploadDraft? _draft;
  bool _picking = false;
  bool _compressing = false;
  double _compressProgress = 0;
  final _captionController = TextEditingController();
  bool _submitting = false;
  double _uploadProgress = 0;
  String _uploadPhase = 'uploading';
  VideoPlayerController? _previewController;
  final AudioPlayer _previewAudio = AudioPlayer();
  late final VideoAudioSync _previewSync = VideoAudioSync(_previewAudio);
  bool _previewPlaying = false;
  bool _previewLooping = false;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    _previewAudio.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      if (!isMp4VideoPath(picked.path, mimeType: picked.mimeType)) {
        _showSnack('Only MP4 videos are supported. Please select an MP4 file.');
        return;
      }

      final file = File(picked.path);
      final probe = VideoPlayerController.file(file);
      await probe.initialize();
      final durationMs = probe.value.duration.inMilliseconds;
      await probe.dispose();

      if (durationMs < UploadDraft.minVideoMs) {
        _showSnack('Video must be at least 1 second long.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _compressing = true;
        _compressProgress = 0;
      });

      final compressedFile = await VideoCompressService.compressForUpload(
        file,
        onProgress: (p) {
          if (mounted) setState(() => _compressProgress = p);
        },
      );

      if (!mounted) return;

      final readyFile = compressedFile;
      final readyProbe = VideoPlayerController.file(readyFile);
      await readyProbe.initialize();
      final readyDurationMs = readyProbe.value.duration.inMilliseconds;
      final readyWidth = readyProbe.value.size.width.round();
      final readyHeight = readyProbe.value.size.height.round();
      await readyProbe.dispose();

      final endMs = readyDurationMs.clamp(UploadDraft.minVideoMs, UploadDraft.maxVideoMs);
      setState(() {
        _draft = UploadDraft(
          videoFile: readyFile,
          videoDurationMs: readyDurationMs,
          videoWidth: readyWidth,
          videoHeight: readyHeight,
          videoEndMs: endMs,
        );
        _step = _CreateStep.editing;
        _compressing = false;
        _compressProgress = 0;
      });
    } catch (e) {
      _showSnack('Could not load video. Please try another file.');
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
          _compressing = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _applyPreviewVolumes(UploadDraft draft) async {
    final videoVol = draft.originalVolume.clamp(0.0, 1.0);
    final musicVol = draft.musicVolume.clamp(0.0, 1.0);
    await _previewController?.setVolume(videoVol);
    if (draft.music != null) {
      await _previewAudio.setVolume(musicVol);
    }
  }

  Future<void> _startPreviewPlayback(UploadDraft draft) async {
    final controller = _previewController;
    if (controller == null || !controller.value.isInitialized) return;

    if (draft.music == null) {
      await _previewSync.haltPlayback();
      await controller.setVolume(draft.originalVolume.clamp(0.0, 1.0));
      await controller.seekTo(Duration(milliseconds: draft.videoStartMs));
      await controller.play();
      return;
    }

    try {
      await _previewSync.configureAudioContext();
    } catch (_) {}
    await _applyPreviewVolumes(draft);
    await _previewSync.prepareSource(draft.music!.url, force: true);
    final musicVol = draft.musicVolume.clamp(0.0, 1.0);
    await _previewSync.playTogether(
      video: controller,
      musicUrl: draft.music!.url,
      videoStartMs: draft.videoStartMs,
      musicStartMs: draft.musicStartMs,
      musicEndMs: draft.musicEndMs,
      sourceReady: true,
      musicVolume: musicVol,
    );
    await _applyPreviewVolumes(draft);
    if (!controller.value.isPlaying) {
      await controller.play();
    }
  }

  Future<void> _goToPosting(UploadDraft draft) async {
    _previewController?.removeListener(_onPreviewVideoTick);
    _previewController?.dispose();
    _previewController = null;
    await _previewSync.haltPlayback();
    await _previewAudio.stop();

    final controller = VideoPlayerController.file(
      draft.videoFile,
      videoPlayerOptions: createPostVideoOptions,
    );
    _previewController = controller;
    await controller.initialize();
    await controller.setLooping(false);
    controller.addListener(_onPreviewVideoTick);

    await _startPreviewPlayback(draft);

    if (!mounted) return;
    setState(() {
      _draft = draft;
      _captionController.text = draft.caption;
      _step = _CreateStep.posting;
      _previewPlaying = true;
    });
  }

  void _onPreviewVideoTick() {
    if (_previewLooping) return;
    final draft = _draft;
    final controller = _previewController;
    if (draft == null || controller == null || !controller.value.isInitialized) return;
    final pos = controller.value.position.inMilliseconds;
    if (pos >= draft.videoEndMs - 80) {
      _previewLooping = true;
      if (draft.music != null) {
        _previewSync
            .loopTogether(
              video: controller,
              videoStartMs: draft.videoStartMs,
              musicStartMs: draft.musicStartMs,
              musicEndMs: draft.musicEndMs,
              musicVolume: draft.musicVolume.clamp(0.0, 1.0),
            )
            .then((_) => _applyPreviewVolumes(draft))
            .whenComplete(() => _previewLooping = false);
      } else {
        controller.seekTo(Duration(milliseconds: draft.videoStartMs)).then((_) {
          controller.play();
          _previewLooping = false;
        });
      }
    }
  }

  Future<void> _togglePreviewPlayback() async {
    final controller = _previewController;
    final draft = _draft;
    if (controller == null || !controller.value.isInitialized || draft == null) return;
    if (_previewPlaying) {
      await _previewSync.haltPlayback();
      await controller.pause();
      setState(() => _previewPlaying = false);
      return;
    }
    await _startPreviewPlayback(draft);
    setState(() => _previewPlaying = true);
  }

  Future<void> _publish() async {
    final draft = _draft;
    if (draft == null || _submitting) return;
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      _showSnack('Please enter a caption to share your post.');
      return;
    }
    if (caption.length > UploadDraft.maxCaptionLength) {
      _showSnack('Caption is too long (max ${UploadDraft.maxCaptionLength} characters).');
      return;
    }

    final api = PlaySession.apiOf(context);
    setState(() {
      _submitting = true;
      _uploadProgress = 0;
      _uploadPhase = 'uploading';
    });

    try {
      File? thumb;
      if (draft.coverPath != null && await File(draft.coverPath!).exists()) {
        thumb = File(draft.coverPath!);
      }

      final uploadResult = await api.uploadReelFull(
        videoFile: draft.videoFile,
        thumbnailFile: thumb,
        playUserId: widget.profile.id,
        mainUserId: api.viewerId,
        username: widget.profile.username,
        caption: caption,
        videoStartMs: draft.videoStartMs,
        videoEndMs: draft.videoEndMs,
        music: draft.music,
        musicStartMs: draft.music == null ? null : draft.musicStartMs,
        musicEndMs: draft.music == null ? null : draft.musicEndMs,
        musicVolume: draft.musicVolume,
        originalVolume: draft.originalVolume,
        onProgress: (p, phase) {
          if (mounted) {
            setState(() {
              _uploadProgress = p;
              _uploadPhase = phase;
            });
          }
        },
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFfb5204).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 42,
                    color: Color(0xFFfb5204),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Post Shared!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your play is preparing on your profile.\nYou can keep browsing — we\'ll notify you when it\'s ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF666666),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFfb5204),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _backToEditing() async {
    if (_submitting) return;
    _previewController?.removeListener(_onPreviewVideoTick);
    _previewController?.dispose();
    _previewController = null;
    await _previewSync.haltPlayback();
    await _previewAudio.stop();
    final draft = _draft;
    if (draft != null) {
      draft.caption = _captionController.text;
    }
    if (mounted) setState(() => _step = _CreateStep.editing);
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _CreateStep.picking:
        return _buildPicker();
      case _CreateStep.editing:
        final draft = _draft;
        if (draft == null) return _buildPicker();
        return VideoEditStep(
          draft: draft,
          api: PlaySession.apiOf(context),
          onBack: () => setState(() {
            _step = _CreateStep.picking;
            _draft = null;
          }),
          onNext: _goToPosting,
        );
      case _CreateStep.posting:
        return _buildPosting();
    }
  }

  Widget _buildPicker() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _picking || _compressing ? null : () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfb5204), Color(0xFFFF8C00)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFfb5204).withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.video_library_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'Share your play',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Select an MP4 video from your gallery.\nMax clip length is 45 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), height: 1.45),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: (_picking || _compressing) ? null : _pickVideo,
                  icon: (_picking || _compressing)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    _compressing
                        ? 'Processing video...'
                        : _picking
                            ? 'Opening gallery...'
                            : 'Select Video',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFfb5204),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
          if (_compressing)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.movie_filter_outlined, color: Color(0xFFfb5204), size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'Processing video...',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Optimizing size for faster upload',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _compressProgress > 0 ? _compressProgress : null,
                          minHeight: 6,
                          color: const Color(0xFFfb5204),
                          backgroundColor: const Color(0xFFFFE4D6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_compressProgress * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPosting() {
    final draft = _draft;
    final controller = _previewController;
    final coverPath = draft?.coverPath;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting) return;
        _backToEditing();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Create Post', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          onPressed: _submitting ? null : _backToEditing,
        ),
      ),
      body: draft == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 160,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: (controller != null && controller.value.isInitialized)
                                      ? FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: controller.value.size.width,
                                            height: controller.value.size.height,
                                            child: VideoPlayer(controller),
                                          ),
                                        )
                                      : (coverPath != null && File(coverPath).existsSync())
                                          ? Image.file(File(coverPath), fit: BoxFit.cover)
                                          : Container(color: const Color(0xFFE5E7EB)),
                                ),
                                if (!_previewPlaying)
                                  Positioned.fill(
                                    child: Material(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _togglePreviewPlayback,
                                        child: Center(
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black.withValues(alpha: 0.55),
                                              border: Border.all(color: Colors.white70, width: 2),
                                            ),
                                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 4,
                                  right: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatMillis(draft.clipDurationMs),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: TextField(
                                controller: _captionController,
                                maxLength: UploadDraft.maxCaptionLength,
                                maxLines: null,
                                expands: true,
                                enabled: !_submitting,
                                style: const TextStyle(fontSize: 15, color: Color(0xFF111111), height: 1.45),
                                decoration: InputDecoration(
                                  hintText: 'Write a caption...',
                                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFfb5204), width: 1.5),
                                  ),
                                  counterText: '',
                                  contentPadding: const EdgeInsets.all(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 8, 15, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_captionController.text.length}/${UploadDraft.maxCaptionLength}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
                if (_submitting) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.cloud_upload_outlined,
                              color: Color(0xFFfb5204),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Uploading Video...',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            minHeight: 6,
                            color: const Color(0xFFfb5204),
                            backgroundColor: const Color(0xFFFFE4D6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(_uploadProgress * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Uploading video...',
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _submitting ? null : _publish,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFfb5204),
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: _submitting ? 0 : 2,
                        ),
                        child: Text(
                          _submitting ? 'Publishing...' : 'Share',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.3),
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
