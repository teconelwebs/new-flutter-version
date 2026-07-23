import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_loader.dart';
import '../../product/data/models/product_item.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String oid;
  final String? initialRefundStatus;

  const OrderDetailsScreen({
    super.key,
    required this.oid,
    this.initialRefundStatus,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _loading = true;
  String _error = "";
  Map<String, dynamic>? _orderDetails;
  Map<String, dynamic>? _orderItems;
  Map<String, dynamic>? _refundDetails;

  // CAPTCHA and Cancellation variables
  final List<String> _cancelReasons = [
    "Incorrect delivery address",
    "Ordered by mistake",
    "Item price is too high",
    "Long delivery delays",
    "Other"
  ];
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  int _captchaNum1 = 0;
  int _captchaNum2 = 0;
  bool _isSubmittingCancel = false;

  StateSetter? _cancelModalState;

  void _showCustomPopup(String message) {
    if (!mounted) return;

    // Clear any active snackbars immediately so new one shows up instantly on repeated clicks
    ScaffoldMessenger.of(context).clearSnackBars();

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1), // 1 second duration
        margin: EdgeInsets.only(
          bottom: screenHeight - topPadding - 80,
          left: 20,
          right: 20,
        ),
        content: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: const Color(0xFF222222).withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateCancelModalState() {
    if (_cancelModalState != null) {
      _cancelModalState!(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _generateCaptcha();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    final rand = Random();
    setState(() {
      _captchaNum1 = rand.nextInt(9) + 1;
      _captchaNum2 = rand.nextInt(9) + 1;
      _captchaController.clear();
    });
  }

  Future<void> _fetchOrderDetails() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = "";
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final token = prefs.getString('access_token');

      if (userId == null || token == null) {
        if (mounted) {
          setState(() {
            _error = "User not authenticated.";
            _loading = false;
          });
        }
        return;
      }

      final headers = {'Authorization': 'Bearer $token'};
      String targetOid = widget.oid.trim();

      Future<({Map<String, dynamic>? details, Map<String, dynamic>? items, Map<String, dynamic>? refund})>
          fetchById(String oidToFetch) async {
        if (oidToFetch.isEmpty) {
          return (details: null, items: null, refund: null);
        }
        final detailsUrl =
            'https://welfogapi.welfog.com/api/v2/purchase-history-details/$oidToFetch?user_id=$userId';
        final itemsUrl =
            'https://welfogapi.welfog.com/api/v2/purchase-history-items/$oidToFetch?user_id=$userId';
        final refundUrl =
            'https://welfogapi.welfog.com/api/v2/return-request/$oidToFetch';

        final responses = await Future.wait([
          http.get(Uri.parse(detailsUrl), headers: headers),
          http.get(Uri.parse(itemsUrl), headers: headers),
          http.get(Uri.parse(refundUrl), headers: headers).catchError((_) => http.Response('{}', 404)),
        ]);

        Map<String, dynamic>? detailsData;
        Map<String, dynamic>? itemsData;
        Map<String, dynamic>? refundData;

        if (responses[0].statusCode == 200) {
          final body = jsonDecode(responses[0].body);
          if (body['data'] != null && (body['data'] as List).isNotEmpty) {
            detailsData = body['data'][0];
          }
        }

        if (responses[1].statusCode == 200) {
          final body = jsonDecode(responses[1].body);
          if (body['data'] != null && (body['data'] as List).isNotEmpty) {
            itemsData = body['data'][0];
          }
        }

        if (responses[2].statusCode == 200) {
          final body = jsonDecode(responses[2].body);
          final actualRefund = body['data'] ?? body;
          if (actualRefund != null && (actualRefund['result'] == true || actualRefund['id'] != null)) {
            refundData = actualRefund;
          }
        }

        return (details: detailsData, items: itemsData, refund: refundData);
      }

      var result = await fetchById(targetOid);

      // If initial fetch yielded no details, fallback to purchase history list to find matching or latest order
      if (result.details == null) {
        try {
          final historyUrl = 'https://welfogapi.welfog.com/api/v2/purchase-history/$userId?user_id=$userId';
          final historyRes = await http.get(Uri.parse(historyUrl), headers: headers);
          if (historyRes.statusCode == 200) {
            final body = jsonDecode(historyRes.body);
            final list = body['data'] as List? ?? [];
            if (list.isNotEmpty) {
              dynamic match;
              if (targetOid.isNotEmpty) {
                match = list.firstWhere(
                  (o) =>
                      o['id']?.toString() == targetOid ||
                      o['code']?.toString() == targetOid ||
                      o['order_code']?.toString() == targetOid ||
                      o['id']?.toString().contains(targetOid) == true ||
                      targetOid.contains(o['id']?.toString() ?? '___'),
                  orElse: () => null,
                );
              }
              match ??= list[0];

              final resolvedId = match['id']?.toString() ?? '';
              if (resolvedId.isNotEmpty && resolvedId != targetOid) {
                result = await fetchById(resolvedId);
              }
            }
          }
        } catch (err) {
          debugPrint("Error resolving order ID from history: $err");
        }
      }

      if (mounted) {
        setState(() {
          _orderDetails = result.details;
          _orderItems = result.items;
          _refundDetails = result.refund;
          _loading = false;
          if (_orderDetails == null) {
            _error = "Failed to load order details.";
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting order details: $e');
      if (mounted) {
        setState(() {
          _error = "An error occurred while fetching details.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleInvoiceDownload() async {
    final invoiceUrl = 'https://supplierservice.welfog.com/get_invoice?order_id=${widget.oid}';
    final uri = Uri.parse(invoiceUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showCustomPopup('Failed to open invoice download link: $e');
      }
    }
  }

  Future<void> _submitCancelRequest() async {
    if (_selectedReason == null) {
      _showCustomPopup('Please select a reason for cancellation.');
      return;
    }

    if (_selectedReason == "Other" && _customReasonController.text.trim().length < 5) {
      _showCustomPopup('Please briefly type your reason (min 5 chars).');
      return;
    }

    final correctAnswer = _captchaNum1 + _captchaNum2;
    final userAnswer = int.tryParse(_captchaController.text);
    if (userAnswer == null || userAnswer != correctAnswer) {
      _showCustomPopup('Please enter the correct sum to verify.');
      _generateCaptcha();
      _updateCancelModalState();
      return;
    }

    setState(() => _isSubmittingCancel = true);
    _updateCancelModalState();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return;

      final reason = _selectedReason == "Other" ? _customReasonController.text.trim() : _selectedReason;

      final response = await http.post(
        Uri.parse('https://welfogapi.welfog.com/api/v2/cancel_order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'order_id': widget.oid,
          'cancel_reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showCustomPopup('Your order has been cancelled successfully.');
          Navigator.pop(context); // Close the cancel dialog
        }
        _fetchOrderDetails(); // Refresh details screen
      } else {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Failed to cancel order.';
        if (mounted) {
          _showCustomPopup(msg);
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomPopup('Failed to cancel order. Please try again later.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCancel = false);
        _updateCancelModalState();
      }
    }
  }

  void _showCancelDialog() {
    _generateCaptcha();
    _selectedReason = null;
    _customReasonController.clear();
    _captchaController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            _cancelModalState = setModalState;
            return Padding(
              padding: EdgeInsets.only(
                top: 16.0,
                left: 16.0,
                right: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cancel Order',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Why do you want to cancel this order?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Select cancellation reason'),
                        value: _selectedReason,
                        items: _cancelReasons.map((String reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            _selectedReason = val;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_selectedReason == "Other") ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customReasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter your reason (min 5 characters)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Solve: $_captchaNum1 + $_captchaNum2 = ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _captchaController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () {
                          _generateCaptcha();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmittingCancel ? null : _submitCancelRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmittingCancel
                          ? const AppLoader.button()
                          : const Text(
                              'Confirm Cancel Order',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _cancelModalState = null;
    });
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final cleaned = dateStr.replaceAll(' ', 'T');
      final date = DateTime.parse(cleaned);
      final months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? "pm" : "am";
      final minute = date.minute.toString().padLeft(2, '0');
      return "${date.day} ${months[date.month - 1]} ${date.year} at $hour:$minute $period";
    } catch (_) {
      return dateStr;
    }
  }

  String _cleanPrice(dynamic price) {
    return price?.toString().replaceAll(RegExp(r'Rs|RS', caseSensitive: false), '').trim() ?? '0';
  }

  void _handleBack() {
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.orders);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF0F766E); // Theme Teal color restoration

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black),
            onPressed: _handleBack,
          ),
          title: const Text(
            'Order Details',
            style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: Colors.grey.shade200, height: 1),
          ),
        ),
      body: _loading
          ? const AppLoader.page()
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
              : _orderDetails == null
                  ? const Center(child: Text('No order details found.'))
                  : RefreshIndicator(
                      onRefresh: _fetchOrderDetails,
                      color: const Color(0xFFFB5404),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Order Information & Shipping Details combined card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Order Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildInfoRow('Order ID: ', _orderDetails!['id']?.toString() ?? ''),
                                  _buildInfoRow('Order date: ', _formatDateString(_orderDetails!['date'])),

                                  // Status Row
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                                        children: [
                                          const TextSpan(
                                            text: 'Status: ',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                          TextSpan(
                                            text: _orderDetails!['current_order_status']?.toString() ?? '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: _orderDetails!['current_order_status']?.toString().toLowerCase() == 'cancelled'
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF0D9488),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Refund details section alert
                                  if (_refundDetails != null) ...[
                                    const SizedBox(height: 8),
                                    _buildRefundAlertBox(),
                                  ],

                                  _buildInfoRow('Total order amount: ', '₹${_cleanPrice(_orderDetails!['grand_total'])}'),
                                  _buildInfoRow('Payment Method: ', _orderDetails!['payment_type']?.toString() ?? 'N/A'),
                                  _buildInfoRow('Payment Status: ', _orderDetails!['payment_status']?.toString() ?? 'unpaid'),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12.0),
                                    child: Divider(color: Color(0xFFE5E7EB)),
                                  ),

                                  const Text(
                                    'Shipping To',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildInfoRow('Name: ', _orderDetails!['shipping_address']?['name']?.toString() ?? 'Customer'),
                                  _buildInfoRow('Phone: ', _orderDetails!['shipping_address']?['phone']?.toString() ?? 'N/A'),

                                  Builder(
                                    builder: (context) {
                                      final addressMap = _orderDetails!['shipping_address'] as Map? ?? {};
                                      final parts = [
                                        addressMap['address'],
                                        addressMap['city'],
                                        addressMap['state'],
                                        addressMap['country']
                                      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
                                      final composite = parts.join(', ');
                                      final postal = addressMap['postal_code']?.toString() ?? '';
                                      return _buildInfoRow('Address: ', '$composite $postal');
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 2. Product Card Section
                            _buildProductCardSection(themeColor),

                            const SizedBox(height: 16),

                            // 3. Invoice Download Row (Centered full-width light container)
                            if (_orderDetails!['current_order_status']?.toString().toLowerCase() != 'cancelled') ...[
                              InkWell(
                                onTap: _handleInvoiceDownload,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward, size: 16, color: Color(0xFF0D9488)),
                                      SizedBox(width: 8),
                                      Text(
                                        'INVOICE',
                                        style: TextStyle(
                                          color: Color(0xFF0D9488),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 4. Price breakdown table
                            _buildPriceTable(),

                            // 5. Cancel Button Row
                            if (["pending", "order placed"].contains(_orderDetails!['current_order_status']?.toString().toLowerCase().trim())) ...[
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _showCancelDialog,
                                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                                  label: const Text(
                                    'Cancel Order',
                                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // 6. Non Sticky Return Box
                            if (_orderDetails!['current_order_status']?.toString().toLowerCase() == 'delivered') ...[
                              const SizedBox(height: 24),
                              _buildReturnBox(),
                            ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF4B5563)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRefundAlertBox() {
    final isBankValid = int.tryParse(_refundDetails!['isbankvalid']?.toString() ?? '') ?? 0;
    final status = _refundDetails!['refund_status']?.toString().toLowerCase() ?? '';

    if (isBankValid == 1 || status == 'failed') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFECACA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Color(0xFFDC2626), size: 20),
                SizedBox(width: 6),
                Text(
                  'Action Required: Update Bank',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your refund of ₹${_refundDetails!['refund_amount']} is pending. We couldn\'t process it due to an issue with your bank account. Please update your details.',
              style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      final isCompleted = status == 'completed';
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          border: Border.all(color: const Color(0xFFBAE6FD)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.info,
                  color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Refund Status: ${_refundDetails!['refund_status']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF0369A1),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your refund of ₹${_refundDetails!['refund_amount']} is currently ${_refundDetails!['refund_status']}.'
              '${status == 'requested' ? ' Please wait while we process the amount to your bank account.' : ''}',
              style: TextStyle(
                color: isCompleted ? const Color(0xFF166534) : const Color(0xFF0C4A6E),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildProductCardSection(Color themeColor) {
    final status = _orderDetails!['current_order_status']?.toString() ?? '';
    final isCancelled = status.toLowerCase() == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13.5, color: Colors.black87),
              children: [
                const TextSpan(text: 'Delivery Status: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                TextSpan(
                  text: status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  final targetSlug = (_orderItems?['slug'] ??
                          _orderItems?['product_slug'] ??
                          _orderDetails?['slug'] ??
                          _orderDetails?['product_slug'] ??
                          _orderDetails?['product_id'] ??
                          _orderItems?['product_id'] ??
                          '')
                      .toString();
                  if (targetSlug.isNotEmpty) {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.product,
                      arguments: ProductItem(
                        id: (_orderItems?['product_id'] ?? _orderDetails?['product_id'] ?? '').toString(),
                        title: _orderItems?['product_name']?.toString() ?? 'Product',
                        subtitle: '',
                        price: double.tryParse(_orderDetails?['grand_total']?.toString() ?? '0') ?? 0.0,
                        rating: 0.0,
                        color: Colors.transparent,
                        imageUrl: _orderDetails?['product_img']?.toString() ?? '',
                        slug: targetSlug,
                      ),
                    );
                  }
                },
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Light neutral blue-grey wrapper matching RN design
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      'https://d1f02fefkbso7w.cloudfront.net/${_orderDetails!['product_img']}',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _orderItems?['product_name']?.toString() ?? 'Product details loading...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Size: ${_orderDetails!['size'] ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                    Text(
                      'Quantity: ${_orderItems?['quantity'] ?? 1}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${_cleanPrice(_orderDetails!['grand_total'])}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTable() {
    final breakdown = [
      {'label': 'Subtotal', 'val': _orderDetails!['subtotal']},
      {'label': 'Shipping Cost', 'val': _orderDetails!['shipping_cost']},
      {'label': 'COD Cost', 'val': _orderDetails!['cod_cost']},
      {'label': 'Coupon', 'val': _orderDetails!['coupon_discount']},
      {'label': 'Total', 'val': _orderDetails!['grand_total']},
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(breakdown.length, (idx) {
          final item = breakdown[idx];
          final label = item['label']!.toString();
          final val = _cleanPrice(item['val']);
          final isTotal = label == 'Total';

          String displayPrice = '₹$val';
          if (label == 'Shipping Cost' || label == 'COD Cost') {
            displayPrice = '+ ₹$val';
          } else if (label == 'Coupon') {
            displayPrice = '- ₹$val';
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: idx % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB),
              border: Border(
                bottom: idx == breakdown.length - 1 ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey.shade200),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    displayPrice,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReturnBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: Color(0xFF78350F), fontSize: 12, height: 1.4),
          children: [
            const TextSpan(text: 'Your order was delivered on '),
            TextSpan(
              text: _formatDateString(_orderDetails!['delivery_date']),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const TextSpan(
              text: '. The return period starts from the delivery date; you can submit a return request until ',
            ),
            TextSpan(
              text: _formatDateString(_orderDetails!['return_date']),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const TextSpan(text: ' (6-day return window from delivery). To proceed, submit a return request with your details and reason.'),
          ],
        ),
      ),
    );
  }
}
