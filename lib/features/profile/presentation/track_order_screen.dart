import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_routes.dart';

class TrackOrderScreen extends StatefulWidget {
  final String oid;

  const TrackOrderScreen({super.key, required this.oid});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final ScrollController _dropdownScrollController = ScrollController();
  List<dynamic> _orders = [];
  dynamic _selectedOrder;
  bool _loadingOrders = true;
  bool _dropdownOpen = false;
  String _searchQuery = "";
  
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loadingMore = false;

  Map<String, dynamic>? _trackingData;
  bool _trackingLoading = false;
  String _trackingError = "";

  @override
  void initState() {
    super.initState();
    _fetchOrders(page: 1);
    _dropdownScrollController.addListener(() {
      if (!_dropdownScrollController.hasClients) return;
      if (_dropdownScrollController.position.pixels >= _dropdownScrollController.position.maxScrollExtent - 100) {
        if (!_loadingMore && _currentPage < _totalPages) {
          _fetchOrders(page: _currentPage + 1, append: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _dropdownScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({int page = 1, bool append = false}) async {
    if (mounted) {
      setState(() {
        if (append) {
          _loadingMore = true;
        } else {
          _loadingOrders = true;
        }
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final url = 'https://welfogapi.welfog.com/api/v2/order_list/$userId?user_id=$userId&page=$page';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final newItems = data['data'] as List? ?? [];
          final meta = data['meta'] as Map? ?? {};
          final lastPage = int.tryParse(meta['last_page']?.toString() ?? '1') ?? 1;

          if (mounted) {
            setState(() {
              _totalPages = lastPage;
              _currentPage = page;
              if (append) {
                _orders.addAll(newItems);
              } else {
                _orders = newItems;
              }

              // Auto-select initial order if passed
              if (widget.oid.isNotEmpty && _selectedOrder == null) {
                final found = _orders.firstWhere(
                  (o) => o != null && o['oid']?.toString() == widget.oid,
                  orElse: () => null,
                );
                if (found != null) {
                  _selectedOrder = found;
                  _fetchTrackingData(widget.oid);
                } else if (page < lastPage) {
                  // Fetch next page to search for it
                  _fetchOrders(page: page + 1, append: true);
                }
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching orders list: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingOrders = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchTrackingData(String orderId) async {
    if (mounted) {
      setState(() {
        _trackingLoading = true;
        _trackingError = "";
        _trackingData = null;
      });
    }

    try {
      const url = 'https://welfogapi.welfog.com/api/onedelivery/welfog_track';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': orderId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          if (data['ShipmentData'] != null && data['ShipmentData'] is List && (data['ShipmentData'] as List).isNotEmpty) {
            final shipment = data['ShipmentData'][0]['Shipment'];
            if (mounted) {
              setState(() {
                _trackingData = {
                  'type': 'shipment',
                  'data': shipment,
                };
              });
            }
          } else if (data['order_id'] != null) {
            if (mounted) {
              setState(() {
                _trackingData = {
                  'type': 'simple',
                  'data': data,
                };
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _trackingError = "Tracking code is not generated yet.";
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching tracking data: $e');
      if (mounted) {
        setState(() {
          _trackingError = "Failed to fetch tracking details.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _trackingLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (_) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? "").toLowerCase();
    if (s == 'hold') return Colors.blue;
    if (s.contains('deliver')) return const Color(0xFF22C55E);
    if (s.contains('cancel') || s.contains('fail')) return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }

  List<dynamic> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;
    final query = _searchQuery.toLowerCase();
    return _orders.where((o) {
      final oidMatch = o['oid']?.toString().contains(query) ?? false;
      final dateMatch = o['date']?.toString().toLowerCase().contains(query) ?? false;
      final totalMatch = o['grand_total']?.toString().contains(query) ?? false;
      return oidMatch || dateMatch || totalMatch;
    }).toList();
  }

  void _handleOrderSelect(dynamic order) {
    setState(() {
      _selectedOrder = order;
      _dropdownOpen = false;
      _searchQuery = "";
    });
    if (order['oid'] != null) {
      _fetchTrackingData(order['oid'].toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Track Order',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loadingOrders && _orders.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFB5404)),
            )
          : Column(
              children: [
                // Order Selector Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _selectedOrder != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order ${_selectedOrder!['oid']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_formatDate(_selectedOrder!['date'])} • ₹${_selectedOrder!['grand_total']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Select an order',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Choose an order to track',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          Icon(
                            _dropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Expanded Dropdown List
                if (_dropdownOpen)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Column(
                      children: [
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search orders by ID, date, or amount',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                          ),
                        ),
                        // List
                        Expanded(
                          child: ListView.builder(
                            controller: _dropdownScrollController,
                            itemCount: _filteredOrders.length + (_currentPage < _totalPages ? 1 : 0),
                            itemBuilder: (context, idx) {
                              if (idx == _filteredOrders.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFB5404)),
                                  ),
                                );
                              }

                              final item = _filteredOrders[idx];
                              final isSelected = _selectedOrder?['oid'] == item['oid'];

                              return ListTile(
                                tileColor: isSelected ? const Color(0xFFF0F7FF) : null,
                                title: Text(
                                  '#${item['oid']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${_formatDate(item['date'])} • ₹${item['grand_total']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(item['delivery_status']).withAlpha(26),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (item['delivery_status'] ?? '').toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(item['delivery_status']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                                onTap: () => _handleOrderSelect(item),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Details View
                Expanded(
                  child: _dropdownOpen
                      ? const SizedBox.shrink()
                      : _selectedOrder == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Choose an order to track',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _fetchTrackingData(_selectedOrder!['oid'].toString()),
                              color: const Color(0xFFFB5404),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Order Details Card
                                    _buildOrderInfoCard(),
                                    const SizedBox(height: 16),

                                    // Tracking Loader or details
                                    if (_trackingLoading)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 24.0),
                                          child: CircularProgressIndicator(color: Color(0xFFFB5404)),
                                        ),
                                      )
                                    else if (_trackingError.isNotEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                                          child: Text(
                                            _trackingError,
                                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                                          ),
                                        ),
                                      )
                                    else if (_trackingData != null)
                                      _buildTrackingView(),

                                    // Help & Support Card
                                    const SizedBox(height: 16),
                                    _buildHelpCard(),
                                  ],
                                ),
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Information',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoGridCell('ORDER ID', _selectedOrder!['oid']?.toString() ?? '', Icons.receipt_long_outlined),
                _buildInfoGridCell('ORDER DATE', _formatDate(_selectedOrder!['date']?.toString()), Icons.calendar_today_outlined),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoGridCell('TOTAL AMOUNT', '₹${_selectedOrder!['grand_total']}', Icons.currency_rupee_outlined),
                _buildInfoGridCell(
                  'STATUS',
                  (_selectedOrder!['delivery_status'] ?? '').toUpperCase(),
                  Icons.local_shipping_outlined,
                  color: _getStatusColor(_selectedOrder!['delivery_status']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGridCell(String label, String value, IconData icon, {Color? color}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? const Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingView() {
    final type = _trackingData!['type'];
    final data = _trackingData!['data'];

    if (type == 'shipment') {
      final scans = data['Scans'] as List? ?? [];
      final status = data['Status']?['Status']?.toString() ?? 'N/A';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shipment Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: Colors.blue.shade600, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Tracking Information',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTrackTextCell('AWB NUMBER', data['AWB']?.toString() ?? 'N/A'),
                      _buildTrackTextCell('CURRENT STATUS', status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTrackTextCell('LAST LOCATION', data['Status']?['StatusLocation'] ?? data['Origin'] ?? 'N/A'),
                      _buildTrackTextCell('LAST UPDATE', _formatDate(data['Status']?['StatusDateTime'])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTrackTextCell('ORIGIN', data['Origin']?.toString() ?? 'N/A'),
                      _buildTrackTextCell('DESTINATION', data['Destination']?.toString() ?? 'N/A'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Timeline scans
          if (scans.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracking Timeline',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Complete journey of your order',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: List.generate(scans.length, (idx) {
                        final scan = scans[idx];
                        final scanDetail = scan['ScanDetail'] ?? scan;
                        final isLast = idx == scans.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isLast ? Colors.blue.shade600 : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 50,
                                    color: Colors.grey.shade200,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    scanDetail['Scan'] ?? 'Update',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(scanDetail['ScanDateTime']),
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        scanDetail['ScannedLocation'] ?? 'N/A',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  if (scanDetail['Instructions'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        scanDetail['Instructions'],
                                        style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 11),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else {
      // Simple status flow
      final orderStatusDetail = data['order_status_detail'];
      final orderFlow = Map<String, dynamic>.from(orderStatusDetail?['order_status']?['order_flow'] as Map? ?? {});
      final isReturn = orderStatusDetail?['return_meta']?['is_return'] == true;

      List<MapEntry<String, dynamic>> finalSteps = [];
      if (isReturn) {
        final courierReturn = orderStatusDetail?['order_status']?['courier_return'];
        final customerReturn = orderStatusDetail?['order_status']?['customer_return'];
        final returnMeta = orderStatusDetail?['return_meta'];

        finalSteps = orderFlow.entries
            .where((e) => e.key != 'cancelled' && e.value?['status'] == true)
            .map((e) => MapEntry<String, dynamic>(e.key.toString(), e.value))
            .toList();

        final isCourier = returnMeta?['return_by'] == 'courier';
        final returnSteps = isCourier
            ? [
                MapEntry<String, dynamic>('return_requested', courierReturn?['requested']),
                MapEntry<String, dynamic>('return_completed', courierReturn?['completed']),
              ]
            : [
                MapEntry<String, dynamic>('return_requested', customerReturn?['requested']),
                MapEntry<String, dynamic>('return_completed', customerReturn?['completed']),
              ];
        for (var step in returnSteps) {
          if (step.value != null) {
            finalSteps.add(step);
          }
        }
      } else {
        final allEntries = orderFlow.entries
            .map((e) => MapEntry<String, dynamic>(e.key.toString(), e.value))
            .toList();
        final cancelledEntry = allEntries.firstWhere(
          (e) => e.key == 'cancelled' && e.value?['status'] == true,
          orElse: () => const MapEntry<String, dynamic>('', null),
        );

        if (cancelledEntry.key.isNotEmpty) {
          for (var entry in allEntries) {
            if (entry.key == 'cancelled') {
              finalSteps.add(entry);
              break;
            }
            if (entry.value?['status'] == true) {
              finalSteps.add(entry);
            }
          }
        } else {
          finalSteps = allEntries.where((e) => e.key != 'cancelled').toList();
        }
      }

      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_outlined, color: Colors.blue.shade600, size: 18),
                  const SizedBox(width: 8),
                  const Text('Order Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTrackTextCell('PAYMENT STATUS', data['payment_status'] ?? 'N/A'),
                  _buildTrackTextCell(
                    'PAYMENT TYPE',
                    data['payment_type'] ?? data['status']?.toString().toUpperCase() ?? 'N/A',
                    color: _getStatusColor(data['status'] ?? _selectedOrder?['delivery_status']),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTrackTextCell('TRACKING CODE', data['tracking_code'] ?? 'N/A'),
                  _buildTrackTextCell('EXPECTED DELIVERY', _getExpectedDeliveryDate(data)),
                ],
              ),
              const SizedBox(height: 16),

              // PRODUCT block wrapper matching screenshot
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCT',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              'https://d1f02fefkbso7w.cloudfront.net/${data['product_img']}',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            data['product_title']?.toString() ?? 'N/A',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Timeline Header Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Order Timeline',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),

              // Timeline Steps
              Column(
                children: List.generate(finalSteps.length, (idx) {
                  final key = finalSteps[idx].key.toString();
                  final val = finalSteps[idx].value;
                  final isLast = idx == finalSteps.length - 1;

                  final isActive = val?['status'] == true;
                  final isCancelledStep = key == 'cancelled';
                  final isReturnStep = key.contains('return');

                  Color dotColor = Colors.grey.shade300;
                  if (isCancelledStep) {
                    dotColor = Colors.red;
                  } else if (isReturnStep) {
                    dotColor = isActive ? Colors.orange : Colors.orange.shade100;
                  } else if (isActive) {
                    dotColor = Colors.green;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 60,
                              color: dotColor,
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          elevation: 0,
                          color: isActive ? Colors.white : const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isActive ? Colors.grey.shade200 : Colors.grey.shade100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  val?['title']?.toString() ?? key.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isCancelledStep ? Colors.red : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  val?['date'] != null ? _formatDate(val['date']) : 'Pending',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTrackTextCell(String label, String value, {Color? color}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black87),
          ),
        ],
      ),
    );
  }

  String _getExpectedDeliveryDate(Map<String, dynamic> data) {
    try {
      DateTime? baseDate;
      if (data['order_date'] != null) {
        baseDate = DateTime.tryParse(data['order_date']);
      } else if (_selectedOrder?['date'] != null) {
        baseDate = DateTime.tryParse(_selectedOrder!['date']);
      }

      if (baseDate == null) return "N/A";

      DateTime deliveryDate = baseDate.add(const Duration(days: 7));
      if (data['expected_delivery'] != null) {
        final expDel = data['expected_delivery'];
        if (expDel is num) {
          deliveryDate = baseDate.add(Duration(minutes: expDel.toInt()));
        } else if (expDel is String) {
          final parsed = DateTime.tryParse(expDel);
          if (parsed != null) deliveryDate = parsed;
        }
      }

      return _formatDate(deliveryDate.toIso8601String());
    } catch (_) {
      return "N/A";
    }
  }

  Widget _buildHelpCard() {
    return InkWell(
      onTap: () {
        // Navigate to Help & Support fallback route
        Navigator.of(context).pushNamed(AppRoutes.profile);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.headset_mic_outlined, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help & Support',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Get instant help with your order',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
