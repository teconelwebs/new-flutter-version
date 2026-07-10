import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, List<dynamic>> _groupedNotifications = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  String _formatMonthHeader(String key) {
    try {
      final parts = key.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final monthInt = int.parse(parts[1]);
        const monthNames = [
          "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
          "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
        ];
        if (monthInt >= 1 && monthInt <= 12) {
          return "${monthNames[monthInt - 1]} $year";
        }
      }
      return key.toUpperCase();
    } catch (e) {
      return key.toUpperCase();
    }
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "";
    try {
      final now = DateTime.now();
      // Replace space with T to make it ISO parseable
      final formatted = dateString.replaceAll(' ', 'T');
      final postDate = DateTime.parse(formatted);
      final diff = now.difference(postDate);

      if (diff.inSeconds < 60) return "now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";

      // Formatted date fallbacks
      return "${postDate.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][postDate.month - 1]}";
    } catch (_) {
      return "";
    }
  }

  Future<void> _fetchNotifications() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString("user_id");
      if (userId == null || userId.isEmpty) {
        userId = "1167"; // Fallback to test ID
      }

      final uri = Uri.parse("https://welfogapi.welfog.com/api/notifications?user_id=$userId");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200 && data['notificationsByMonth'] != null) {
          final rawGrouped = data['notificationsByMonth'] as Map<String, dynamic>;
          final Map<String, List<dynamic>> parsedGrouped = {};

          rawGrouped.forEach((key, val) {
            if (val is List) {
              final List<dynamic> monthData = [];
              for (var record in val) {
                if (record is Map && record['data'] is Map) {
                  final recordData = record['data'] as Map;
                  if (recordData['order'] is List) {
                    monthData.addAll(recordData['order']);
                  }
                }
              }

              if (monthData.isNotEmpty) {
                // Sort by date descending
                monthData.sort((a, b) {
                  try {
                    final dateA = DateTime.parse(a['date'].toString().replaceAll(' ', 'T'));
                    final dateB = DateTime.parse(b['date'].toString().replaceAll(' ', 'T'));
                    return dateB.compareTo(dateA);
                  } catch (_) {
                    return 0;
                  }
                });
                parsedGrouped[_formatMonthHeader(key)] = monthData;
              }
            }
          });

          setState(() {
            _groupedNotifications = parsedGrouped;
          });
        } else {
          setState(() {
            _groupedNotifications = {};
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching notifications list: $e");
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _handleNotificationClick(Map<String, dynamic> item) async {
    final bool isUnread = item['view'] == 0 || item['view'] == '0';
    final String notificationId = item['id']?.toString() ?? '';

    if (isUnread && notificationId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        String? userId = prefs.getString("user_id");
        if (userId == null || userId.isEmpty) {
          userId = "1167";
        }
        
        // Mark as read API
        final markUri = Uri.parse(
          "https://welfogapi.welfog.com/api/notifications/mark-read?user_id=$userId&id=$notificationId",
        );
        await http.get(markUri);

        // Update state locally
        setState(() {
          item['view'] = 1;
        });
      } catch (e) {
        debugPrint("Error marking notification as read: $e");
      }
    }

    // Navigate to Order Details
    if (mounted && notificationId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.orderDetails,
        arguments: {'oid': notificationId},
      );
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
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFB5404),
        onRefresh: () async {
          setState(() {
            _isRefreshing = true;
          });
          await _fetchNotifications();
        },
        child: _isLoading
            ? const AppLoader.page()
            : _groupedNotifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 150),
                      Center(
                        child: Text(
                          "No notifications found",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _groupedNotifications.keys.length,
                    itemBuilder: (context, monthIndex) {
                      final monthHeader = _groupedNotifications.keys.elementAt(monthIndex);
                      final items = _groupedNotifications[monthHeader] ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month Header
                          Container(
                            width: double.infinity,
                            color: const Color(0xFFF9F9F9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthHeader,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF666666),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          // Notifications in this Month
                          ...items.map((item) {
                            if (item is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }
                            final bool isUnread = item['view'] == 0 || item['view'] == '0';

                            return InkWell(
                              onTap: () => _handleNotificationClick(item),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isUnread ? const Color(0xFFFFF9F5) : Colors.white,
                                  border: const Border(
                                    bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Order",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          _getTimeAgo(item['date']?.toString()),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF999999),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['message']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF444444),
                                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Order ID: ${item['id'] ?? ''}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF888888),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}
