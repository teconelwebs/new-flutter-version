// lib/features/product/presentation/widgets/customer_reviews_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CustomerReviewsWidget extends StatefulWidget {
  final Map<String, dynamic> data;

  // ignore: use_super_parameters
  const CustomerReviewsWidget({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  State<CustomerReviewsWidget> createState() => _CustomerReviewsWidgetState();
}

class _CustomerReviewsWidgetState extends State<CustomerReviewsWidget> {
  List<dynamic> _reviewsList = [];
  Map<String, dynamic> _reviewStats = {
    'total_reviews': 0,
    'review_percentages': {
      'five_star_percentage': 0,
      'four_star_percentage': 0,
      'three_star_percentage': 0,
      'two_star_percentage': 0,
      'one_star_percentage': 0,
    }
  };

  int? _currentUserId;
  bool _isSubmitting = false;
  int _editRating = 0;
  final TextEditingController _editCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _fetchReviewsData();
  }

  @override
  void didUpdateWidget(CustomerReviewsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data['id'] != widget.data['id']) {
      _fetchReviewsData();
    }
  }

  @override
  void dispose() {
    _editCommentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid != null && mounted) {
      setState(() => _currentUserId = int.tryParse(uid));
    }
  }

  Future<void> _fetchReviewsData() async {
    try {
      final productId = widget.data['id'];
      if (productId == null) return;

      final uri = Uri.parse('https://welfogapi.welfog.com/api/v2/reviews/product_review/$productId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == true && mounted) {
          setState(() {
            _reviewsList = data['reviews'] as List? ?? [];
            _reviewStats = {
              'total_reviews': data['total_reviews'] ?? 0,
              'review_percentages': data['review_percentages'] ?? {},
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Reviews fetch error: $e');
    }
  }

  bool _isReviewWindowOpen(String? dateString) {
    if (dateString == null) return false;
    final date = DateTime.tryParse(dateString);
    if (date == null) return false;
    final diff = DateTime.now().difference(date);
    return diff.inDays <= 30;
  }

  Future<void> _handleUpdateReview(dynamic selectedReview) async {
    if (_editRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 star!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || _currentUserId == null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login session expired.'), backgroundColor: Colors.red),
        );
        return;
      }

      final payload = {
        'user_id': _currentUserId,
        'product_id': selectedReview?['product_id'] ?? widget.data['id'],
        'order_id': null,
        'rating': _editRating,
        'comment': _editCommentController.text,
      };

      final uri = Uri.parse('https://welfogapi.welfog.com/api/reviews/submit');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop(); // dismiss modal
        await _fetchReviewsData();
      }
    } catch (error) {
      debugPrint('Update Review Error: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showEditReviewModal(dynamic review) {
    setState(() {
      _editRating = review['rating'] ?? 0;
      _editCommentController.text = review['comment'] ?? '';
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Update Review', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _editRating = starNum);
                          setState(() => _editRating = starNum);
                        },
                        child: Icon(
                          _editRating >= starNum ? Icons.star : Icons.star_border,
                          size: 44,
                          color: const Color(0xFFFFB800),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _editCommentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      fillColor: const Color(0xFFF9FAFB),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFB5404)),
                  onPressed: _isSubmitting ? null : () => _handleUpdateReview(review),
                  child: Text(_isSubmitting ? 'Updating...' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double rVal = double.tryParse((widget.data['rating'] ?? 0).toString()) ?? 0.0;
    final percentages = _reviewStats['review_percentages'] as Map<String, dynamic>? ?? {};

    final starRatingsList = [
      {'stars': 5, 'pct': percentages['five_star_percentage'] ?? 0},
      {'stars': 4, 'pct': percentages['four_star_percentage'] ?? 0},
      {'stars': 3, 'pct': percentages['three_star_percentage'] ?? 0},
      {'stars': 2, 'pct': percentages['two_star_percentage'] ?? 0},
      {'stars': 1, 'pct': percentages['one_star_percentage'] ?? 0},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Reviews',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                rVal > 0 ? rVal.toStringAsFixed(1) : '4.3',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (idx) {
                      final double activeVal = rVal > 0 ? rVal : 4.3;
                      return Icon(
                        activeVal >= idx + 1 ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFC107),
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on ${_reviewStats['total_reviews']} reviews',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),

          // Rating Bar Charts
          ...starRatingsList.map((rating) {
            final double pct = double.tryParse(rating['pct']?.toString() ?? '0') ?? 0.0;
            final stars = rating['stars'] as int;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$stars', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(width: 2),
                        const Icon(Icons.star, color: Color(0xFF9CA3AF), size: 14),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (pct / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),

          if (_reviewsList.isNotEmpty)
            ..._reviewsList.map((item) {
              final isMyReview = _currentUserId == int.tryParse(item['user_id']?.toString() ?? '');
              final canEdit = _isReviewWindowOpen(item['created_at']?.toString());
              final double ratingVal = double.tryParse((item['rating'] ?? 0).toString()) ?? 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: NetworkImage(
                        item['avatar_original'] != null && item['avatar_original'].toString().isNotEmpty
                            ? item['avatar_original'].toString()
                            : 'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['user_name'] ?? 'User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                              ),
                              if (isMyReview && canEdit)
                                GestureDetector(
                                  onTap: () => _showEditReviewModal(item),
                                  child: const Text('Edit', style: TextStyle(color: Color(0xFFFB5404), fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: List.generate(5, (idx) {
                                  return Icon(
                                    ratingVal >= idx + 1 ? Icons.star : Icons.star_border,
                                    color: const Color(0xFFFFB800),
                                    size: 14,
                                  );
                                }),
                              ),
                              if (item['created_at'] != null)
                                Text(
                                  item['created_at'].toString().split('T')[0],
                                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['comment'] ?? '',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No reviews available yet.', style: TextStyle(color: Colors.grey))),
            ),
        ],
      ),
    );
  }
}
