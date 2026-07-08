import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/storage/session_store.dart';
import '../data/account_api_service.dart';

class DeleteAccountReasonScreen extends StatefulWidget {
  const DeleteAccountReasonScreen({super.key, required this.phone});

  final String phone;

  @override
  State<DeleteAccountReasonScreen> createState() => _DeleteAccountReasonScreenState();
}

class _DeleteAccountReasonScreenState extends State<DeleteAccountReasonScreen> {
  final _api = AccountApiService();
  String? _selectedReasonId;
  final _otherController = TextEditingController();
  bool _isDeleting = false;

  final List<_ReasonItem> _reasons = const [
    _ReasonItem(id: '1', icon: Icons.phone_android_outlined, label: "I found a better shopping app"),
    _ReasonItem(id: '2', icon: Icons.directions_bike_outlined, label: "Issues with orders or delivery"),
    _ReasonItem(id: '3', icon: Icons.sentiment_dissatisfied_rounded, label: "Unhappy with product quality"),
    _ReasonItem(id: '4', icon: Icons.shield_outlined, label: "Privacy or security concerns"),
    _ReasonItem(id: '5', icon: Icons.notifications_off_outlined, label: "Too many notifications or emails"),
    _ReasonItem(id: '6', icon: Icons.shopping_cart_outlined, label: "I don't shop online anymore"),
    _ReasonItem(id: 'other', icon: Icons.edit_note_outlined, label: "Other (please specify)"),
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _isContinueEnabled {
    if (_selectedReasonId == null) return false;
    if (_selectedReasonId == 'other') {
      return _otherController.text.trim().isNotEmpty;
    }
    return true;
  }

  String get _deleteReason {
    if (_selectedReasonId == 'other') {
      return _otherController.text.trim();
    }
    final matched = _reasons.firstWhere((r) => r.id == _selectedReasonId);
    return matched.label;
  }

  Future<void> _handleConfirmDelete() async {
    setState(() => _isDeleting = true);
    try {
      final success = await _api.deleteAccount(_deleteReason);
      if (!success) {
        throw Exception('Delete account failed');
      }

      // Wiping local session and caches
      await SessionStore.clearLogin();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      // Close confirmation dialog
      Navigator.of(context).pop();
      // Reset navigation and go to AccountDeletedScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.accountDeleted,
        (_) => false,
        arguments: {
          'phone': widget.phone,
          'deleted_date': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isDeleting = false);
        // Close confirmation dialog
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account. Please try again.')),
        );
      }
    }
  }

  void _showFinalConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isDeleting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 40,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Are you sure?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You are about to permanently delete your Welfog account. All your orders, addresses, and wishlist data will be gone forever.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isDeleting
                        ? null
                        : () async {
                            setDialogState(() => _isDeleting = true);
                            await _handleConfirmDelete();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Yes, Delete My Account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isDeleting ? null : () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text(
                      'No, Keep My Account',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Delete Account',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFEEEEEE),
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Apology Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFFED7AA), width: 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sentiment_dissatisfied_outlined,
                          size: 32,
                          color: Color(0xFFFB5404),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "We're sorry to see you go",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Why do you want to delete your account?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Your honest feedback helps us improve Welfog for everyone.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Reasons list
                ..._reasons.map((reason) {
                  final isSelected = _selectedReasonId == reason.id;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedReasonId = reason.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFFAF7) : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFB5404) : const Color(0xFFE5E5E5),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFFAF7) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              reason.icon,
                              size: 20,
                              color: isSelected ? const Color(0xFFFB5404) : const Color(0xFF888888),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              reason.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFFFB5404) : const Color(0xFF333333),
                              ),
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFB5404) : const Color(0xFFCCCCCC),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFB5404),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Other Free-Text Input
                if (_selectedReasonId == 'other') ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: _otherController,
                          maxLines: 4,
                          maxLength: 200,
                          buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => null,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Tell us your reason...',
                            hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${_otherController.text.length}/200',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Footer
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isContinueEnabled ? _showFinalConfirmationDialog : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFB5404),
                        disabledBackgroundColor: const Color(0xFFFFD4C2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonItem {
  const _ReasonItem({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}
