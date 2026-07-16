import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_loader.dart';
import '../../product/data/models/product_item.dart';

class OrdersScreen extends StatefulWidget {
  static const routeName = AppRoutes.orders;

  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _orders = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextPageUrl;
  bool _isFetching = false; // Prevents race conditions

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _scrollController.addListener(() {
      // Trigger fetch earlier (when user is within 400px from the bottom) for fluid load times
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        if (!_isFetching && _nextPageUrl != null) {
          _fetchOrders(url: _nextPageUrl, append: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({String? url, bool append = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (mounted) {
      setState(() {
        if (append) {
          _loadingMore = true;
        } else {
          _loading = true;
          _orders.clear(); // Clear list on initial load or refresh for fresh UI state
          _nextPageUrl = null;
        }
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userId = prefs.getString('user_id');

      if (accessToken == null || userId == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadingMore = false;
          });
        }
        return;
      }

      final endpoint = url ?? 'https://welfogapi.welfog.com/api/v2/purchase-history/$userId';
      Uri uri = Uri.parse(endpoint);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      if (!queryParams.containsKey('user_id')) {
        queryParams['user_id'] = userId;
      }
      uri = uri.replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );



      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isResultTrue = data['result'] == true ||
            data['result']?.toString() == 'true' ||
            data['result'] == 1 ||
            data['result'] == '1';

        if (isResultTrue || data['data'] != null) {
          final List newOrders = data['data'] as List? ?? [];
          final meta = data['meta'] as Map? ?? {};
          final List links = meta['links'] as List? ?? [];
          
          String? next;
          for (var link in links) {
            final label = link['label']?.toString() ?? '';
            if (label.contains('Next')) {
              next = link['url']?.toString();
              break;
            }
          }

          if (mounted) {
            setState(() {
              _nextPageUrl = next;
              if (append) {
                _orders.addAll(newOrders);
              } else {
                _orders = newOrders;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      _isFetching = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  String cleanPrice(dynamic val) {
    if (val == null) return '0';
    return val.toString().replaceAll(RegExp(r'Rs|RS|₹', caseSensitive: false), '').trim();
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  bool _isReviewWindowOpen(String? dateString) {
    if (dateString == null || dateString.isEmpty) return false;
    try {
      final targetDate = DateTime.parse(dateString);
      final today = DateTime.now();
      final difference = today.difference(targetDate);
      return difference.inDays <= 30;
    } catch (_) {
      return false;
    }
  }

  void _openReviewModal(Map<String, dynamic> order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _ReviewSubmitDialog(
          order: order,
          onSuccess: (updatedReview) {
            setState(() {
              final index = _orders.indexWhere((o) => o['oid'] == order['oid']);
              if (index != -1) {
                final updatedOrder = Map<String, dynamic>.from(_orders[index]);
                updatedOrder['review'] = updatedReview;
                _orders[index] = updatedOrder;
              }
            });
          },
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrders(),
        color: const Color(0xFFFB5404),
        child: _loading
            ? const AppLoader.page()
            : _orders.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80.0, left: 24, right: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 100,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No Orders Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Looks like you haven\'t placed any orders yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 180,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFB5404),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                                },
                                child: const Text(
                                  'Start Shopping',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length + (_nextPageUrl != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _orders.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: _loadingMore
                                ? const AppLoader.button(color: Color(0xFFFB5404))
                                : const SizedBox.shrink(),
                          ),
                        );
                      }

                      final order = _orders[index] as Map<String, dynamic>;
                      final statusStr = order['current_order_status']?.toString() ??
                          order['delivery_status_string']?.toString() ??
                          '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Header (Order ID & Status)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order ${order['oid']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    statusStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F766E), // Teal color
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 2. Middle Row (Product image & details)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final targetSlug = (order['slug'] ?? order['product_slug'] ?? order['product_id'] ?? '').toString();
                                      if (targetSlug.isNotEmpty) {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.product,
                                          arguments: ProductItem(
                                            id: (order['product_id'] ?? '').toString(),
                                            title: order['product_title']?.toString() ?? '',
                                            subtitle: '',
                                            price: double.tryParse(order['grand_total']?.toString() ?? '0') ?? 0.0,
                                            rating: 0.0,
                                            color: Colors.transparent,
                                            imageUrl: order['product_img']?.toString() ?? '',
                                            slug: targetSlug,
                                          ),
                                        );
                                      }
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        'https://d1f02fefkbso7w.cloudfront.net/${order['product_img']}',
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade100,
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order['product_title']?.toString() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF4B5563),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: ${formatDate(order['date']?.toString())}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${cleanPrice(order['grand_total'])}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2.5. Product Rating Row
                              if (['delivered', 'completed'].contains(order['current_order_status']?.toString().toLowerCase().trim())) ...[
                                () {
                                  final hasReview = order['review'] != null && order['review']['rating'] != null;
                                  final canReview = _isReviewWindowOpen(order['date']?.toString());
                                  if (!canReview && !hasReview) return const SizedBox.shrink();

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: InkWell(
                                      onTap: canReview ? () => _openReviewModal(order) : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200, width: 0.8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  hasReview
                                                      ? (canReview ? "Your Rating (Tap to change)" : "Your Rating (Locked)")
                                                      : "Rate this product",
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Row(
                                                  children: List.generate(5, (index) {
                                                    final starNum = index + 1;
                                                    final double userRating = double.tryParse(order['review']?['rating']?.toString() ?? '0') ?? 0.0;
                                                    final isStarred = starNum <= userRating;
                                                    return Icon(
                                                      isStarred ? Icons.star : Icons.star_border,
                                                      size: 20,
                                                      color: (canReview || hasReview) ? const Color(0xFFFFB800) : Colors.grey.shade400,
                                                    );
                                                  }),
                                                ),
                                              ],
                                            ),
                                            if (!canReview && hasReview) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                "Reviews cannot be edited after 30 days of purchase.",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }(),
                              ],

                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              const SizedBox(height: 12),

                              // 3. Bottom Action Buttons Row
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.trackOrder,
                                          arguments: {
                                            'oid': order['oid'],
                                            'order': order,
                                          },
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1F2937),
                                        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Track',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await Navigator.pushNamed(
                                          context,
                                          AppRoutes.orderDetails,
                                          arguments: {
                                            'oid': order['oid'],
                                            'initialRefundStatus': order['current_order_status'],
                                          },
                                        );
                                        _fetchOrders();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1F2937),
                                        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'View Details',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  final int currentStep;

  const StepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['Ordered', 'Shipped', 'Out for Delivery', 'Delivered'];
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Background line
        Positioned(
          top: 12,
          left: 40,
          right: 40,
          child: Container(
            height: 3,
            color: Colors.grey.shade200,
          ),
        ),
        // Progress line
        if (currentStep > 1)
          Positioned(
            top: 12,
            left: 40,
            right: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (currentStep - 1) / (steps.length - 1),
                child: Container(
                  height: 3,
                  color: const Color(0xFFFB5404),
                ),
              ),
            ),
          ),
        // Circles & Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (index) {
            final step = index + 1;
            final bool completed = step < currentStep;
            final bool active = step == currentStep;

            Color circleColor = Colors.grey.shade200;
            if (completed) circleColor = const Color(0xFF10B981);
            if (active) circleColor = const Color(0xFFFB5404);

            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        completed ? Icons.check : Icons.circle,
                        size: completed ? 12 : 6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: active
                          ? const Color(0xFFFB5404)
                          : (completed ? const Color(0xFF10B981) : Colors.grey.shade400),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ReviewSubmitDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(Map<String, dynamic>) onSuccess;

  const _ReviewSubmitDialog({
    required this.order,
    required this.onSuccess,
  });

  @override
  State<_ReviewSubmitDialog> createState() => _ReviewSubmitDialogState();
}

class _ReviewSubmitDialogState extends State<_ReviewSubmitDialog> {
  int _currentRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.order['review'] != null) {
      final double rVal = double.tryParse(widget.order['review']['rating']?.toString() ?? '0') ?? 0.0;
      _currentRating = rVal.toInt();
      _commentController.text = widget.order['review']['comment']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_currentRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one star.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final userIdStr = prefs.getString('user_id') ?? '';
      final accessToken = prefs.getString('access_token') ?? '';

      if (userIdStr.isEmpty || accessToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login session expired.')),
        );
        return;
      }

      final dynamic userId = int.tryParse(userIdStr) ?? userIdStr;
      final dynamic orderId = int.tryParse(widget.order['oid']?.toString() ?? '') ?? widget.order['oid'];
      final dynamic productId = int.tryParse(widget.order['product_id']?.toString() ?? '') ?? widget.order['product_id'];

      final payload = {
        'user_id': userId,
        'order_id': orderId,
        'product_id': productId,
        'rating': _currentRating,
        'comment': _commentController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('https://welfogapi.welfog.com/api/v2/reviews/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSuccess({
          'rating': _currentRating,
          'comment': _commentController.text.trim(),
        });
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review submitted successfully!')),
          );
        }
      } else {
        throw 'Server returned status: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Review Submit Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save your review. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.order['review'] != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? 'Update Review' : 'Rate Product',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  return IconButton(
                    onPressed: () {
                      setState(() => _currentRating = starNum);
                    },
                    icon: Icon(
                      starNum <= _currentRating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: const Color(0xFFFFB800),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write your comments here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFB5404)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFB5404),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: _submitting
                        ? const AppLoader.button()
                        : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
