import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:managely/View/leave_screen.dart';
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/View/home_tab.dart';
import 'package:managely/View/hr_dashboard_screen.dart';
import 'package:managely/View/notifications_screen.dart';
import 'package:managely/View/payslip_screen.dart';
import 'package:managely/View/leave_approval_screen.dart';
import 'package:managely/View/performance_monitoring_screen.dart';
import 'package:managely/View/team_directory_screen.dart';
import 'package:managely/View/assign_task_screen.dart';
import 'package:managely/View/task_management_screen.dart';
import 'package:managely/View/reports_screen.dart';
import 'package:managely/Widget/quick_actions_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String formattedDate = DateFormat('EEEE, MMMM d y').format(DateTime.now());
  bool _isScanning = false;

  // ✅ متغيرات الـ Today Status
  String _checkIn = '--:--';
  String _checkOut = '--:--';
  String _statusLabel = 'Loading...';
  String _attendanceStatus = '';
  bool _statusLoading = true;

  // ✅ Polling timer للإشعارات
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTodayStatus();
      _fetchUnreadCount();
      // Polling كل 10 ثواني
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchUnreadCount();
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ✅ جلب عدد الإشعارات غير المقروءة
  Future<void> _fetchUnreadCount() async {
    if (!mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      if (auth.token == null) return;

      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/alerts/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['count'] ?? 0;
        auth.setUnreadCount(count is int ? count : int.tryParse('$count') ?? 0);
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  // ✅ جلب بيانات الحضور
  Future<void> _fetchTodayStatus() async {
    if (!mounted) return;
    setState(() => _statusLoading = true);

    try {
      final token = context.read<AuthProvider>().token;

      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/attendance/today-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _checkIn = data['check_in'] ?? '--:--';
          _checkOut = data['check_out'] ?? '--:--';
          _statusLabel = data['label'] ?? 'Unknown';
          _attendanceStatus = data['status'] ?? '';
          _statusLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _statusLabel = 'Failed to load';
          _statusLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLabel = 'Connection error';
        _statusLoading = false;
      });
    }
  }

  // ✅ لون الـ status badge
  Color get _statusColor {
    switch (_attendanceStatus.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'leave':
        return Colors.blue;
      case 'absent':
      case 'not_checked_in':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _openQrScanner() async {
    print("OPEN SCANNER CLICKED");

    if (!mounted) return;

    try {
      final qrToken = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
      );

      print("QR RESULT: $qrToken");

      if (qrToken == null) {
        print("QR SCAN CANCELLED");
        return;
      }

      setState(() => _isScanning = true);

      Position? position;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        print("LOCATION PERMISSION: $permission");

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        } else {
          print("LOCATION NOT GRANTED");
        }
      } catch (e) {
        print("LOCATION ERROR: $e");
      }

      final token = context.read<AuthProvider>().token;

      final response = await http.post(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'token': qrToken,
          'lat': position?.latitude,
          'lng': position?.longitude,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showMessage(data['message'] ?? 'Done!', isError: false);
        // ✅ refresh الـ status بعد الـ scan
        await _fetchTodayStatus();
      } else {
        _showMessage(data['message'] ?? 'Something went wrong', isError: true);
      }
    } catch (e) {
      print("GENERAL ERROR: $e");

      if (!mounted) return;
      _showMessage('Connection error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHr = context.watch<AuthProvider>().isHr;
    final isSupervisor = context.watch<AuthProvider>().isSupervisor;
    // ✅ عدد الإشعارات غير المقروءة
    final unreadCount = context.watch<AuthProvider>().unreadNotifications;

    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= HEADER =================
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Managly",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // ✅ Notification icon + Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: IconButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                            // ✅ refresh count بعد الرجوع
                            _fetchUnreadCount();
                          },
                          icon: const Icon(
                            Icons.notifications_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ================= SCAN QR CARD =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Scan QR for Attendance",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isScanning ? null : _openQrScanner,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xff3b82f6), Color(0xff2563eb)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _isScanning
                              ? const Column(
                                  children: [
                                    LoadingWidget(),
                                    SizedBox(height: 15),
                                    Text(
                                      "Processing...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 15),
                                    Text(
                                      "Tap to Scan QR",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Tap to check in or check out",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            // ================= STATUS CARD =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _statusLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: LoadingWidget(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Today's Status",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel,
                                    style: TextStyle(
                                      color: _statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xffdcfce7),
                                  child: Icon(
                                    Icons.login_rounded,
                                    size: 18,
                                    color: _checkIn == '--:--'
                                        ? Colors.grey
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Check-in Time",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _checkIn,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(),
                            ),

                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xffffedd5),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                    color: _checkOut == '--:--'
                                        ? Colors.grey
                                        : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Check-out Time",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _checkOut,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _fetchTodayStatus,
                                icon: const Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: Color(0xff2563eb),
                                ),
                                label: const Text(
                                  'Refresh',
                                  style: TextStyle(
                                    color: Color(0xff2563eb),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ================= QUICK ACTIONS =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Actions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 15),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                    children: [
                      QuickActionButton(
                        icon: Icons.calendar_today,
                        label: "Request Leave",
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomeTap(
                                initialIndex: (!isHr && !isSupervisor) ? 3 : 2,
                              ),
                            ),
                          );
                        },
                      ),
                      QuickActionButton(
                        icon: Icons.receipt_long,
                        label: "View Payslips",
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatslipScreen(),
                            ),
                          );
                        },
                      ),
                      if (!isHr && !isSupervisor)
                        QuickActionButton(
                          icon: Icons.task,
                          label: "Tasks",
                          color: Colors.purple,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomeTap(initialIndex: 2),
                              ),
                            );
                          },
                        ),
                      if (isHr || isSupervisor) ...[
                        QuickActionButton(
                          icon: Icons.dashboard_rounded,
                          label: isHr ? "HR Overview" : "My Dashboard",
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HrDashboardScreen(),
                              ),
                            );
                          },
                        ),
                        QuickActionButton(
                          icon: Icons.bar_chart_rounded,
                          label: "Performance",
                          color: Colors.teal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PerformanceMonitoringScreen(),
                              ),
                            );
                          },
                        ),
                        if (isSupervisor)
                          QuickActionButton(
                            icon: Icons.people_alt_rounded,
                            label: "My Team",
                            color: const Color(0xff3b82f6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TeamDirectoryScreen(),
                                ),
                              );
                            },
                          ),
                        QuickActionButton(
                          icon: Icons.how_to_reg_rounded,
                          label: "Leave Approvals",
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LeaveApprovalScreen(),
                              ),
                            );
                          },
                        ),
                        if (isHr)
                          QuickActionButton(
                            icon: Icons.assessment_rounded,
                            label: "Reports",
                            color: Colors.pink,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ReportsScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                      if (isSupervisor) ...[
                        QuickActionButton(
                          icon: Icons.assignment_ind,
                          label: "Assign Task",
                          color: Colors.deepOrange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AssignTaskScreen(),
                              ),
                            );
                          },
                        ),
                        QuickActionButton(
                          icon: Icons.task_alt_rounded,
                          label: "Task Management",
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TaskManagementScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── QR Scanner Screen ─────────────────────────────────────────────────────────

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Point camera at QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
