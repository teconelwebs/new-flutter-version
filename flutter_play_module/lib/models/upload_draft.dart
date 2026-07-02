import 'dart:io';

import 'music_track.dart';

class UploadDraft {
  final File videoFile;
  final int videoDurationMs;
  final int videoWidth;
  final int videoHeight;

  String? coverPath;
  MusicTrack? music;
  int videoStartMs;
  int videoEndMs;
  int musicStartMs;
  int musicEndMs;
  String caption;
  double musicVolume;
  double originalVolume;

  UploadDraft({
    required this.videoFile,
    required this.videoDurationMs,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.coverPath,
    this.music,
    this.videoStartMs = 0,
    int? videoEndMs,
    this.musicStartMs = 0,
    this.musicEndMs = 0,
    this.caption = '',
    this.musicVolume = 1.0,
    this.originalVolume = 1.0,
  }) : videoEndMs = videoEndMs ?? videoDurationMs.clamp(0, UploadDraft.maxVideoMs);

  static const maxVideoMs = 45000;
  static const minVideoMs = 1000;
  static const maxCaptionLength = 500;

  int get effectiveDurationMs => videoDurationMs > 0 ? videoDurationMs : videoEndMs;

  int get clipDurationMs => (videoEndMs - videoStartMs).clamp(minVideoMs, maxVideoMs);

  String get musicId => music?.id ?? '';
}
