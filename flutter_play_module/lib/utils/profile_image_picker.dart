import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'profile_theme.dart';

/// Pick from gallery then open native-style square crop (like Expo/RN EditProfile).
Future<File?> pickAndCropProfileImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 100,
  );
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    maxWidth: 1024,
    maxHeight: 1024,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 85,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop Photo',
        toolbarColor: ProfileColors.primary,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: ProfileColors.primary,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: 'Crop Photo',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
    ],
  );

  if (cropped == null) return null;
  final file = File(cropped.path);
  if (!await file.exists()) return null;
  return file;
}
