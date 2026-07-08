import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';

class DeleteAccountHelpScreen extends StatefulWidget {
  const DeleteAccountHelpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<DeleteAccountHelpScreen> createState() => _DeleteAccountHelpScreenState();
}

class _DeleteAccountHelpScreenState extends State<DeleteAccountHelpScreen> {
  int? _expandedId;

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      id: 1,
      icon: Icons.inventory_2_outlined,
      question: "Having trouble with an order?",
      answer: "Our support team can resolve most order issues within 24 hours. Reach out via Help & Support and we'll make it right.",
    ),
    _FaqItem(
      id: 2,
      icon: Icons.star_outline_rounded,
      question: "Unhappy with a product quality?",
      answer: "We offer hassle-free returns and full refunds within 7 days of delivery. No questions asked.",
    ),
    _FaqItem(
      id: 3,
      icon: Icons.notifications_none_rounded,
      question: "Too many notifications or emails?",
      answer: "You can easily customize or turn off notifications anytime from your app Settings.",
    ),
    _FaqItem(
      id: 4,
      icon: Icons.shield_outlined,
      question: "Privacy or security concerns?",
      answer: "Your data is fully encrypted and never sold. Visit our Privacy Policy or contact us for specific concerns.",
    ),
    _FaqItem(
      id: 5,
      icon: Icons.account_balance_wallet_outlined,
      question: "Payment or refund issues?",
      answer: "Refunds are processed within 5–7 business days to your original payment method. Our team can expedite this for you.",
    ),
  ];

  void _toggleFaq(int id) {
    setState(() {
      _expandedId = _expandedId == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Delete my account',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Empathy Banner
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
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1AFB5404),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    size: 36,
                    color: Color(0xFFFB5404),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Before you leave...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We're genuinely sorry you're considering this. We'd love to help you fix whatever isn't working so you don't have to leave.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Can we help you with any of these?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          // FAQ Cards
          ..._faqs.map((faq) {
            final isExpanded = _expandedId == faq.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isExpanded ? const Color(0xFFFFFAF7) : Colors.white,
                border: Border.all(
                  color: isExpanded ? const Color(0xFFFB5404) : const Color(0xFFE5E5E5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey(faq.id),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (_) => _toggleFaq(faq.id),
                  title: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(faq.icon, size: 20, color: const Color(0xFFFB5404)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          faq.question,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFAAAAAA),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(46, 0, 14, 14),
                      child: Text(
                        faq.answer,
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
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
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
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.deleteAccountReason,
                      arguments: {'phone': widget.phone},
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFB5404),
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
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.id,
    required this.icon,
    required this.question,
    required this.answer,
  });

  final int id;
  final IconData icon;
  final String question;
  final String answer;
}
