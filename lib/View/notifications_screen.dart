import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _alerts = [];
  Timer? _streamTimer;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _streamTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchAlerts(isPolling: true);
    });
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAlerts({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;

      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/alerts'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _alerts = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Something went wrong';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isPolling) {
        setState(() {
          _error = 'Connection error. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllUnreadAsRead() async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;

      if (token == null) return;

      // Get only unread alerts — backend may return int 0/1 or bool false/true
      bool isUnread(dynamic val) => val == false || val == 0;
      final unreadAlerts = _alerts
          .where((a) => isUnread(a['is_read']))
          .toList();

      if (unreadAlerts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications are already read')),
        );
        return;
      }

      // Mark each unread alert using the existing /alerts/{id}/read endpoint
      final futures = unreadAlerts.map((alert) {
        final id = alert['alert_id'];
        return http.post(
          Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/alerts/$id/read'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        );
      });

      // Wait for all requests
      await Future.wait(futures);

      if (!mounted) return;

      // Update UI state: mark all as read locally
      setState(() {
        for (var alert in _alerts) {
          alert['is_read'] = 1; // use int 1 to match backend format
        }
      });

      // Stop polling, reset badge immediately, then re-fetch real count from server
      auth.stopNotificationStream();
      auth.setUnreadCount(0);

      // Re-fetch real count from server & restart polling
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      auth.startNotificationStream();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 3),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'All notifications marked as read!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Mark read error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark notifications as read'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '';

    try {
      final d = DateTime.parse(date);

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final min = d.minute.toString().padLeft(2, '0');
      final period = d.hour < 12 ? 'AM' : 'PM';

      return '${months[d.month - 1]} ${d.day}, ${d.year}  $hour:$min $period';
    } catch (_) {
      return date;
    }
  }

  _AlertStyle _getStyle(String alertType) {
    switch (alertType) {
      case 'leave_approved':
        return _AlertStyle(
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          title: 'Leave Approved',
          subtitle: 'Your leave request has been approved.',
        );

      case 'leave_rejected':
        return _AlertStyle(
          icon: Icons.cancel_rounded,
          color: Colors.red,
          title: 'Leave Rejected',
          subtitle: 'Your leave request has been rejected.',
        );

      case 'task_assigned':
        return _AlertStyle(
          icon: Icons.task_alt_rounded,
          color: Colors.blue,
          title: 'New Task Assigned',
          subtitle: 'You have been assigned a new task.',
        );

      default:
        return _AlertStyle(
          icon: Icons.notifications_rounded,
          color: const Color(0xff2563eb),
          title: alertType.replaceAll('_', ' '),
          subtitle: '',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 30,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff3b82f6), Color(0xff2563eb)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Notifications",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Your activity history",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _markAllUnreadAsRead,
                        child: const Text(
                          'Mark As Read',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: LoadingWidget(),
              )
            else if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    Text(_error, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchAlerts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2563eb),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
            else if (_alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 60,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No notifications yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _alerts.map((a) {
                    final style = _getStyle(a['alert_type'] ?? '');
                    final date = _formatDate(a['created_at']);
                    final description = ((a['description'] ?? a['content'] ?? '')).toString().trim();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: style.color.withOpacity(.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              style.icon,
                              color: style.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  style.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else if (style.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    style.subtitle,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _AlertStyle {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _AlertStyle({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
