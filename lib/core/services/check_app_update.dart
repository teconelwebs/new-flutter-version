import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

bool _hasCheckedUpdate = false;

/// Compare two version strings (e.g., "1.0.6" vs "1.0.5")
/// Returns true if version1 > version2
bool _compareVersions(String version1, String version2) {
  if (version1.isEmpty || version2.isEmpty) return false;

  final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  final maxLen = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
  for (var i = 0; i < maxLen; i++) {
    final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
    final v2Part = i < v2Parts.length ? v2Parts[i] : 0;

    if (v1Part > v2Part) return true;
    if (v1Part < v2Part) return false;
  }

  return false;
}

/// Check if app update is available from Play Store / App Store
Future<void> checkAppUpdate(BuildContext context) async {
  if (_hasCheckedUpdate) return;
  _hasCheckedUpdate = true;

  try {
    // 1. Get current version and build number using package_info_plus
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    // 2. Fetch latest version configurations from API
    final response = await http.get(
      Uri.parse('https://admin.welfog.com/api/app-version/'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final String apiVersion = (data['version'] ?? '').toString();
    final int apiVersionCode = int.tryParse((data['versionCode'] ?? '0').toString()) ?? 0;
    final bool forceUpdate = data['forceUpdate'] == true;
    final String apiPlayStoreUrl = (data['playStoreUrl'] ?? '').toString();
    final String apiIosVersion = (data['iosVersion'] ?? '').toString();
    final int apiIosBuild = int.tryParse((data['iosBuild'] ?? '0').toString()) ?? 0;
    final String apiAppStoreUrl = (data['appStoreUrl'] ?? '').toString();

    bool needsUpdate = false;

    // 3. Platform specific version check logic
    if (Platform.isIOS) {
      final targetVersion = apiIosVersion.isNotEmpty ? apiIosVersion : apiVersion;
      final targetBuild = apiIosBuild > 0 ? apiIosBuild : apiVersionCode;

      final isOlderVersion = _compareVersions(targetVersion, currentVersion);
      final isNewerVersion = _compareVersions(currentVersion, targetVersion);
      final isOlderBuild = currentBuild < targetBuild;

      // Show popup if current version < iosVersion OR (versions match && current build < iosBuild)
      if (isOlderVersion || (!isNewerVersion && isOlderBuild)) {
        needsUpdate = true;
      }
    } else if (Platform.isAndroid) {
      final versionNeedsUpdate = _compareVersions(apiVersion, currentVersion);
      final codeNeedsUpdate = apiVersionCode > currentBuild;
      needsUpdate = versionNeedsUpdate || codeNeedsUpdate;
    }

    if (needsUpdate && context.mounted) {
      final playStoreUrl = apiPlayStoreUrl.isNotEmpty
          ? apiPlayStoreUrl
          : 'https://play.google.com/store/apps/details?id=com.parm27.welfog';
      final appStoreUrl = apiAppStoreUrl.isNotEmpty
          ? apiAppStoreUrl
          : 'https://apps.apple.com/us/app/welfog/id6760458301';

      final finalUrl = Platform.isIOS ? appStoreUrl : playStoreUrl;

      // Show custom premium update modal dialog
      showDialog(
        context: context,
        barrierDismissible: !forceUpdate,
        builder: (dialogContext) {
          return PopScope(
            canPop: !forceUpdate,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 10,
              backgroundColor: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFF3E0),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.system_update_outlined,
                          size: 44,
                          color: Color(0xFFFB5204),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      forceUpdate ? 'Update Required' : 'Update Available',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    Text(
                      forceUpdate
                          ? "We've upgraded the app experience. Please install the latest version to continue."
                          : "A redesigned app experience is ready for you. Update now to enjoy the latest improvements and features.",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Features List (Optional for regular update)
                    if (!forceUpdate) ...[
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Bug fixes & improvements',
                              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Enhanced performance',
                              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Buttons
                    Row(
                      children: [
                        if (!forceUpdate) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE0E0E0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Later',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final uri = Uri.parse(finalUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFB5204), Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFB5204).withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_downward, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Update Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  } catch (e) {
    debugPrint('checkAppUpdate failed: $e');
  }
}
