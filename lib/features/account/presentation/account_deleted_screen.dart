import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';
import '../data/account_api_service.dart';

class AccountDeletedScreen extends StatefulWidget {
  const AccountDeletedScreen({
    super.key,
    required this.phone,
    this.deletedDate,
  });

  final String phone;
  final String? deletedDate;

  @override
  State<AccountDeletedScreen> createState() => _AccountDeletedScreenState();
}

class _AccountDeletedScreenState extends State<AccountDeletedScreen> {
  final _api = AccountApiService();
  bool _isReactivating = false;
  
  // Math captcha state
  String _captchaQuestion = '';
  int _captchaAnswer = 0;
  final _captchaController = TextEditingController();
  String? _captchaError;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  @override
  void dispose() {
    _captchaController.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    final rand = Random();
    final a = rand.nextInt(9) + 1; // 1 to 9
    final b = rand.nextInt(9) + 1; // 1 to 9
    
    if (rand.nextBool()) {
      _captchaQuestion = '$a  +  $b';
      _captchaAnswer = a + b;
    } else {
      final hi = max(a, b);
      final lo = min(a, b);
      _captchaQuestion = '$hi  -  $lo';
      _captchaAnswer = hi - lo;
    }
    _captchaController.clear();
    _captchaError = null;
  }

  String _formatDeletedDate(String? iso) {
    try {
      final date = iso != null ? DateTime.parse(iso) : DateTime.now();
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return 'Today';
    }
  }

  Future<void> _handleReactivate() async {
    final input = _captchaController.text.trim();
    final userAnswer = int.tryParse(input);

    if (userAnswer == null) {
      setState(() {
        _captchaError = 'Please enter a valid number.';
      });
      return;
    }

    if (userAnswer != _captchaAnswer) {
      setState(() {
        _captchaError = 'Incorrect answer. A new question has been generated.';
        _generateCaptcha();
      });
      return;
    }

    // Passed Captcha!
    setState(() {
      _captchaError = null;
      _isReactivating = true;
    });

    try {
      final success = await _api.reactivateAccount(widget.phone);
      if (!success) {
        throw Exception('Reactivation failed');
      }

      if (mounted) {
        // Close modal
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account Activated! Welcome back! Please log in.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset full history and go to login
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isReactivating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reactivate your account. Please try again.'),
          ),
        );
      }
    }
  }

  void _showCaptchaSheet() {
    _generateCaptcha();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Confirm Reactivation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        if (!_isReactivating)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please solve this simple equation to reactivate your account:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Math problem display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Text(
                        '$_captchaQuestion = ?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFB5404),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Textfield for answer
                    TextField(
                      controller: _captchaController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter answer',
                        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
                        errorText: _captchaError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) {
                        setModalState(() {
                          _captchaError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isReactivating
                          ? null
                          : () async {
                              setModalState(() {
                                _isReactivating = true;
                              });
                              await _handleReactivate();
                              if (mounted && !_isReactivating) {
                                setModalState(() {});
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFB5404),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _isReactivating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Reactivate Account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
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
  }

  @override
  Widget build(BuildContext context) {
    final deletionDateStr = _formatDeletedDate(widget.deletedDate);
    final double screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Scrollbar(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(
                minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Illustration with decoration dots
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Decorator dots
                        Positioned(
                          top: 10,
                          left: 14,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEDD5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 12,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEDD5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 18,
                          left: 20,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEDD5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 18,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEDD5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Outer Circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFED7AA),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            // Inner Circle
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFB5404),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x4DFB5404),
                                    offset: Offset(0, 6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_remove_outlined,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your account is deleted',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Deleted on $deletionDateStr',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Your Welfog account and all associated data have been permanently removed. We're sorry to see you go.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color(0xFFF0F0F0),
                  ),
                  const SizedBox(height: 20),
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 22,
                          color: Color(0xFFFB5404),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Changed your mind? '
                            '${widget.phone.isNotEmpty ? 'Account: +91 ${widget.phone}. ' : ''}'
                            'You can reactivate within 30 days — tap the button below to begin.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF666666),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Reactivate Button
                  FilledButton.icon(
                    onPressed: widget.phone.isNotEmpty ? _showCaptchaSheet : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFB5404),
                      disabledBackgroundColor: const Color(0xFFFFD4C2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                      elevation: 4,
                      shadowColor: const Color(0xFFFB5404),
                    ),
                    icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                    label: const Text(
                      'Reactivate My Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Continue to Login Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text(
                      'Continue to Login',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
