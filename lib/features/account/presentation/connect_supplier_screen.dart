import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class ConnectSupplierScreen extends StatefulWidget {
  const ConnectSupplierScreen({super.key});

  @override
  State<ConnectSupplierScreen> createState() => _ConnectSupplierScreenState();
}

class _ConnectSupplierScreenState extends State<ConnectSupplierScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();

  bool _scanned = false;
  bool _isLoading = false;
  bool? _isProfileReady;
  bool _showSuccessModal = false;
  Map<String, dynamic>? _successData;
  bool _showAlreadyConnectedPopup = false;

  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  // Cached profile details
  String? _myProfileId;
  String? _myUserName;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: -100.0, end: 60.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _checkProfileStatus();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _checkProfileStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var profileId = prefs.getString('play_profile_id') ?? '';
      var loginId = prefs.getString('loginid') ?? '';
      var userName = prefs.getString('play_profile_user_name') ?? '';
      var name = prefs.getString('play_profile_name') ?? '';

      if (profileId == 'null') profileId = '';
      if (loginId == 'null') loginId = '';

      // Trust local profile cache immediately so scanner opens
      if (profileId.isNotEmpty || loginId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isProfileReady = true;
            _myProfileId = profileId.isNotEmpty ? profileId : loginId;
            _myUserName = userName;
            _myName = name;
          });
        }
      }

      var idToCheck = profileId.isNotEmpty ? profileId : loginId;
      bool isUserAlive = false;

      // Device ID generation and headers for validation
      var deviceId = prefs.getString('x-device-id') ?? '';
      if (deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString('x-device-id', deviceId);
      }

      final headers = {
        'Content-Type': 'application/json',
        'x-device-id': deviceId,
        'x-android-id': deviceId,
        'x-ios-idfv': deviceId,
      };

      if (idToCheck.isNotEmpty) {
        try {
          final res = await http.get(
            Uri.parse('https://api.welfog.com/api/users/$idToCheck'),
            headers: headers,
          ).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data != null && data['_id'] != null) {
              isUserAlive = true;
              profileId = data['_id'].toString();
              userName = (data['username'] ?? '').toString();
              name = (data['name'] ?? userName).toString();

              await prefs.setString('play_profile_id', profileId);
              await prefs.setString('play_profile_user_name', userName);
              await prefs.setString('play_profile_name', name);
            }
          }
        } catch (_) {}
      }

      if (!isUserAlive) {
        final currentUserId = prefs.getString('user_id') ?? '';
        final token = prefs.getString('access_token') ?? '';

        if (currentUserId.isNotEmpty && token.isNotEmpty) {
          try {
            final userRes = await http.post(
              Uri.parse('https://welfogapi.welfog.com/api/v2/get-user-by-access_token'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'access_token': token, 'userId': currentUserId}),
            ).timeout(const Duration(seconds: 4));
            if (userRes.statusCode == 200) {
              final userData = jsonDecode(userRes.body);
              final mobile = userData['phone'] ?? userData['mobile'] ?? '';
              if (mobile != null && mobile.toString().isNotEmpty) {
                final mobileRes = await http.get(
                  Uri.parse('https://api.welfog.com/api/users/bymobile/$mobile'),
                  headers: headers,
                ).timeout(const Duration(seconds: 4));
                if (mobileRes.statusCode == 200) {
                  final data = jsonDecode(mobileRes.body);
                  if (data != null && (data['_id'] != null || data['id'] != null)) {
                    isUserAlive = true;
                    final recoveredId = (data['_id'] ?? data['id']).toString();
                    final recoveredUsername = (data['username'] ?? '').toString();
                    final recoveredName = (data['name'] ?? recoveredUsername).toString();

                    await prefs.setString('loginid', recoveredId);
                    await prefs.setString('play_profile_id', recoveredId);
                    await prefs.setString('play_profile_user_name', recoveredUsername);
                    await prefs.setString('play_profile_name', recoveredName);
                    await prefs.setString('cached_user_id', recoveredId);

                    profileId = recoveredId;
                    userName = recoveredUsername;
                    name = recoveredName;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          if (isUserAlive) {
            _isProfileReady = true;
            _myProfileId = profileId;
            _myUserName = userName;
            _myName = name;
          } else {
            // Keep scanner open if we have local cache, otherwise show missing screen
            if (profileId.isNotEmpty || loginId.isNotEmpty) {
              _isProfileReady = true;
            } else {
              _isProfileReady = false;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProfileReady = (_myProfileId != null && _myProfileId!.isNotEmpty);
        });
      }
    }
  }

  void _showAlreadyConnected() {
    setState(() => _showAlreadyConnectedPopup = true);
    _slideController.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showAlreadyConnectedPopup) {
        _closeAlreadyConnected();
      }
    });
  }

  void _closeAlreadyConnected() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showAlreadyConnectedPopup = false;
          _scanned = false;
        });
      }
    });
  }

  void _showCustomAlert(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _scanned = false);
              },
              child: const Text('OK', style: TextStyle(color: Color(0xFFFF6A00), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verifyPlayProfile(Map<String, dynamic> qrData) async {
    if (_myProfileId == null || _myUserName == null) {
      _showCustomAlert(
        'Profile Missing',
        'We could not find your Play Profile. Please go to the Play Profile tab and create an account.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final localName1 = prefs.getString('user_name') ?? '';
      final localName2 = prefs.getString('loginuser') ?? '';

      String safeLocalName = '';
      if (localName1.isNotEmpty && localName1.toLowerCase() != 'user' && localName1 != _myUserName) {
        safeLocalName = localName1;
      } else if (localName2.isNotEmpty && localName2.toLowerCase() != 'user' && localName2 != _myUserName) {
        safeLocalName = localName2;
      }

      final trimmedUserName = (_myUserName ?? '').trim();
      final trimmedMyName = (_myName ?? '').trim();
      final trimmedSafeLocalName = safeLocalName.trim();

      String finalNameForPayload = '';
      if (trimmedMyName.isNotEmpty && trimmedMyName != trimmedUserName) {
        finalNameForPayload = trimmedMyName;
      } else if (trimmedSafeLocalName.isNotEmpty && trimmedSafeLocalName != trimmedUserName) {
        finalNameForPayload = trimmedSafeLocalName;
      }

      // Get device headers for verify/update requests
      var deviceId = prefs.getString('x-device-id') ?? '';
      if (deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString('x-device-id', deviceId);
      }

      final headers = {
        'Content-Type': 'application/json',
        'x-device-id': deviceId,
        'x-android-id': deviceId,
        'x-ios-idfv': deviceId,
      };

      final payload = {
        'id': qrData['id'],
        'code': qrData['code'],
        'seller_id': qrData['seller_id'],
        'user_id': qrData['user_id'],
        'play_profile_id': _myProfileId,
        'play_profile_user_name': _myUserName,
        'play_profile_name': finalNameForPayload,
      };

      final response = await http.post(
        Uri.parse('https://supplier.welfog.com/api/playlinks/verify'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        if (resData != null && resData['result'] == true) {
          // Update profile links
          String userMobile = '';
          try {
            final getRes = await http.get(
              Uri.parse('https://api.welfog.com/api/users/$_myProfileId'),
              headers: headers,
            );
            if (getRes.statusCode == 200) {
              final parsedUser = jsonDecode(getRes.body);
              userMobile = (parsedUser['mobile'] ?? parsedUser['phone'] ?? '').toString();
            }
          } catch (_) {}

          if (userMobile.isEmpty) {
            final currentUserId = prefs.getString('user_id') ?? '';
            final token = prefs.getString('access_token') ?? '';
            if (currentUserId.isNotEmpty && token.isNotEmpty) {
              try {
                final userRes = await http.post(
                  Uri.parse('https://welfogapi.welfog.com/api/v2/get-user-by-access_token'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'access_token': token, 'userId': currentUserId}),
                );
                if (userRes.statusCode == 200) {
                  final uData = jsonDecode(userRes.body);
                  userMobile = (uData['phone'] ?? uData['mobile'] ?? '').toString();
                }
              } catch (_) {}
            }
          }

          final updatePayload = {
            'id': _myProfileId,
            'mobile': userMobile,
            'name': finalNameForPayload,
            'username': _myUserName,
            'seller_id': qrData['seller_id'].toString(),
            'userseller_id': qrData['user_id'].toString(),
            'isConnected': true,
          };

          await http.post(
            Uri.parse('https://api.welfog.com/api/users/'),
            headers: headers,
            body: jsonEncode(updatePayload),
          );

          await prefs.setString('frontend_is_connected', 'true');
          setState(() {
            _successData = resData['data'] ?? payload;
            _isLoading = false;
            _showSuccessModal = true;
          });
        } else {
          setState(() => _isLoading = false);
          _showCustomAlert('Connection Failed', 'Unable to connect with supplier.');
        }
      } else if (response.statusCode == 409 || response.body.contains('already linked') || response.body.contains('already connected')) {
        setState(() => _isLoading = false);
        _showAlreadyConnected();
      } else {
        setState(() => _isLoading = false);
        _showCustomAlert('Error', 'Invalid or duplicate QR scan configuration.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showCustomAlert('Error', 'Network or connection error. Please try again.');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        setState(() {
          _scanned = true;
        });
        _processQRCode(rawValue);
      }
    }
  }

  void _processQRCode(String qrCodeText) {
    try {
      final Map<String, dynamic> qrData = jsonDecode(qrCodeText);
      if (qrData['code'] == null || qrData['seller_id'] == null || qrData['user_id'] == null) {
        _showCustomAlert('Invalid QR Code', 'QR code is missing required supplier information.');
        return;
      }
      _verifyPlayProfile(qrData);
    } catch (_) {
      _showCustomAlert('Invalid QR Code', 'The scanned QR code format is invalid.');
    }
  }

  // Developer/emulator simulation mode
  void _simulateScan() {
    setState(() {
      _scanned = true;
    });
    // Sample valid QR payload for testing
    final mockQR = {
      'id': 'mock_supplier_link',
      'code': 'WELFOG_SUPPLIER_SYNC',
      'seller_id': 'supplier_101',
      'user_id': 'supplier_user_202',
    };
    _verifyPlayProfile(mockQR);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Profile missing state
    if (_isProfileReady == false) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded, size: 64, color: Colors.amber),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Action Required',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  "We couldn't find an active Play Profile linked to your account.",
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "To connect with a supplier, please ensure your Play Profile is created and loaded. You can do this from the \"Play Profile\" tab in the main menu.",
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scanner is disabled until a profile is detected.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isProfileReady == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Scanner Camera View
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 2. Custom transparent viewport viewfinder overlay
          _buildViewFinderOverlay(size),

          // 3. Header title layout
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 16, right: 16),
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.5),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Column(
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Scan a Connect Supplier QR Code',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // 4. Loading Indicators
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFF6A00)),
                      SizedBox(height: 16),
                      Text(
                        'Connecting to supplier...',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Already Connected alert banner (sliding layout)
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Positioned(
                top: _slideAnimation.value,
                left: 16,
                right: 16,
                child: child!,
              );
            },
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFFF6A00), size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Already Connected',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'This supplier is already linked with your profile',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: _closeAlreadyConnected,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Success Modal
          if (_showSuccessModal) _buildSuccessModal(),
        ],
      ),
    );
  }

  Widget _buildViewFinderOverlay(Size size) {
    const double boxSize = 250.0;
    final double horizontalPadding = (size.width - boxSize) / 2;
    final double verticalPadding = (size.height - boxSize) / 2;

    return Stack(
      children: [
        // Dark borders around viewport
        // ignore: deprecated_member_use
        Positioned(top: 0, left: 0, right: 0, height: verticalPadding, child: Container(color: Colors.black.withOpacity(0.6))),
        // ignore: deprecated_member_use
        Positioned(bottom: 0, left: 0, right: 0, height: verticalPadding, child: Container(color: Colors.black.withOpacity(0.6))),
        // ignore: deprecated_member_use
        Positioned(top: verticalPadding, left: 0, width: horizontalPadding, height: boxSize, child: Container(color: Colors.black.withOpacity(0.6))),
        // ignore: deprecated_member_use
        Positioned(top: verticalPadding, right: 0, width: horizontalPadding, height: boxSize, child: Container(color: Colors.black.withOpacity(0.6))),

        // Green Corners
        Positioned(
          top: verticalPadding - 2,
          left: horizontalPadding - 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 25, height: 4, color: const Color(0xFF00FF00)),
              Container(width: 4, height: 25, color: const Color(0xFF00FF00)),
            ],
          ),
        ),
        Positioned(
          top: verticalPadding - 2,
          right: horizontalPadding - 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(width: 25, height: 4, color: const Color(0xFF00FF00)),
              Container(width: 4, height: 25, color: const Color(0xFF00FF00)),
            ],
          ),
        ),
        Positioned(
          bottom: verticalPadding - 2,
          left: horizontalPadding - 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 4, height: 25, color: const Color(0xFF00FF00)),
              Container(width: 25, height: 4, color: const Color(0xFF00FF00)),
            ],
          ),
        ),
        Positioned(
          bottom: verticalPadding - 2,
          right: horizontalPadding - 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(width: 4, height: 25, color: const Color(0xFF00FF00)),
              Container(width: 25, height: 4, color: const Color(0xFF00FF00)),
            ],
          ),
        ),

        // Simulator/Dev Fallback Button
        if (kDebugMode)
          Positioned(
            bottom: verticalPadding - 100,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: _simulateScan,
                icon: const Icon(Icons.bug_report, color: Colors.amber),
                label: const Text('Simulate Scan (Testing Mode)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSuccessModal() {
    return Positioned.fill(
      child: Container(
        // ignore: deprecated_member_use
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Connected Successfully!',
                  style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supplier connection has been established.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_successData != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${_successData!['id'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Seller ID: ${_successData!['seller_id'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('User ID: ${_successData!['user_id'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Profile ID: ${_successData!['play_profile_id'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Profile Name: ${_successData!['play_profile_name'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Username: ${_successData!['play_profile_user_name'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showSuccessModal = false;
                        _successData = null;
                        _scanned = false;
                      });
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
