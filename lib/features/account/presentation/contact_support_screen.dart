import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/utils/safe_insets.dart';
import '../data/account_api_service.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _api = AccountApiService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  final Map<String, String> _errors = {};
  bool _loading = false;

  int _captchaNum1 = 0;
  int _captchaNum2 = 0;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    final rand = Random();
    setState(() {
      _captchaNum1 = rand.nextInt(9) + 1; // 1 to 9
      _captchaNum2 = rand.nextInt(9) + 1; // 1 to 9
      _captchaCtrl.clear();
      _errors.remove('captcha');
    });
  }

  bool _validate() {
    _errors.clear();

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final message = _msgCtrl.text.trim();
    final captchaAnswer = _captchaCtrl.text.trim();

    if (name.isEmpty) {
      _errors['name'] = 'Please enter your name';
    }

    if (email.isEmpty) {
      _errors['email'] = 'Email is required';
    } else {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        _errors['email'] = 'Enter a valid email address';
      }
    }

    if (phone.isEmpty) {
      _errors['phone'] = 'Phone number is required';
    } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      _errors['phone'] = 'Enter a valid phone number';
    }

    if (message.isEmpty) {
      _errors['message'] = 'Please enter your message';
    } else if (message.length > 150) {
      _errors['message'] = 'Message cannot exceed 150 characters';
    }

    final correctCaptcha = _captchaNum1 + _captchaNum2;
    final userCaptcha = int.tryParse(captchaAnswer);
    if (userCaptcha == null || userCaptcha != correctCaptcha) {
      _errors['captcha'] = 'Please enter the correct sum';
    }

    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);

    try {
      final success = await _api.submitContactForm(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
      );

      setState(() => _loading = false);

      if (success) {
        _nameCtrl.clear();
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _msgCtrl.clear();
        _captchaCtrl.clear();
        _errors.clear();
        _generateCaptcha();

        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to send. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Message Submitted Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Our support team will contact you soon. Your submission has been received and we\'ll get back to you as quickly as possible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFB5404),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Contact Support',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: systemBottomInset(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Get in Touch',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'We\'re here to help. Fill in the form and our team will get back to you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Support Illustration
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: Image.asset(
                  'assets/images/contact_support.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.support_agent_rounded, size: 64, color: Color(0xFFCCCCCC)),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Form container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(
                    label: 'Full Name',
                    placeholder: 'Enter your full name',
                    controller: _nameCtrl,
                    errorKey: 'name',
                  ),
                  _buildField(
                    label: 'Email',
                    placeholder: 'Enter your email address',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    errorKey: 'email',
                  ),
                  _buildField(
                    label: 'Phone Number',
                    placeholder: 'Enter your phone number',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    errorKey: 'phone',
                  ),
                  _buildField(
                    label: 'Message',
                    placeholder: 'Write your message...',
                    controller: _msgCtrl,
                    multiline: true,
                    errorKey: 'message',
                  ),

                  // Captcha Field
                  _buildCaptchaField(),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFB5404),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Send Message',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool multiline = false,
    required String errorKey,
  }) {
    final error = _errors[errorKey];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: error != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                width: error != null ? 1.0 : 0.5,
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: multiline ? 4 : 1,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: Color(0xFF888888), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptchaField() {
    final error = _errors['captcha'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter the sum of:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          ),
          child: Center(
            child: Text(
              '$_captchaNum1 + $_captchaNum2 = ?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: error != null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
              width: error != null ? 1.0 : 0.5,
            ),
          ),
          child: TextField(
            controller: _captchaCtrl,
            keyboardType: TextInputType.number,
            maxLength: 2,
            buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => null,
            decoration: const InputDecoration(
              hintText: 'Enter answer',
              hintStyle: TextStyle(color: Color(0xFF888888), fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
          ),
        ],
        const SizedBox(height: 6),
        InkWell(
          onTap: _generateCaptcha,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Color(0xFFFB5404), size: 16),
                SizedBox(width: 4),
                Text(
                  'Refresh',
                  style: TextStyle(
                    color: Color(0xFFFB5404),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
