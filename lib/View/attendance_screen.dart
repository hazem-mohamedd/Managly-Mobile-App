import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/Widget/attendance_card_widget.dart';
import 'package:managely/Widget/summary_attendance_widget.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  String _error = '';

  List<dynamic> _records = [];
  int _presentDays = 0;
  int _absentDays = 0;
  int _leaveDays = 0;
  int _lateDays = 0;

  String _selectedFilter = 'Current Month';
  final List<String> _filters = ['Current Month', 'Previous Month'];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // ✅ بيكلم الـ API الصح حسب الفلتر
  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
      _records = [];
    });

    try {
      final token = context.read<AuthProvider>().token;

      // ✅ URL مختلف حسب الفلتر
      final url = _selectedFilter == 'Current Month'
          ? 'https://subfusiform-joni-holmic.ngrok-free.dev/api/current-attendance-history'
          : 'https://subfusiform-joni-holmic.ngrok-free.dev/api/attendance-history';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final records = data['records'] as List;
        setState(() {
          _records = records;
          _presentDays = data['summary']['present_days'] ?? 0;
          _absentDays = data['summary']['absent_days'] ?? 0;
          _leaveDays = data['summary']['leave_days'] ?? 0;
          _lateDays = records
              .where((r) => r['status'].toString().toLowerCase() == 'late')
              .length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Something went wrong';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? time) {
    if (time == null) return '--:--';
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final min = parts[1];
      final period = hour < 12 ? 'AM' : 'PM';
      if (hour == 0) hour = 12;
      if (hour > 12) hour -= 12;
      return '$hour:$min $period';
    } catch (_) {
      return time;
    }
  }

  String _formatDate(String date) {
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
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return date;
    }
  }

  String _calcDuration(String? inTime, String? outTime) {
    if (inTime == null || outTime == null) return '';
    try {
      final inParts = inTime.split(':');
      final outParts = outTime.split(':');
      final inMinutes = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
      final outMinutes = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
      final diff = outMinutes - inMinutes;
      if (diff <= 0) return '';
      final h = diff ~/ 60;
      final m = diff % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    } catch (_) {
      return '';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'leave':
        return Colors.orange;
      case 'late':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'leave':
        return 'Leave';
      case 'late':
        return 'Late';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, left: 20, bottom: 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff3b82f6), Color(0xff2563eb)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attendance",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Your attendance history",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Filter Chips — فوق الـ loading عشان يتحكم في الـ fetch
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final selected = _selectedFilter == _filters[i];
                  return GestureDetector(
                    onTap: () {
                      if (_selectedFilter == _filters[i]) return;
                      setState(() => _selectedFilter = _filters[i]);
                      // ✅ كل ما تغير الفلتر يكلم الـ API الصح
                      _fetchHistory();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xff2563eb)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              LoadingWidget()
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
                      onPressed: _fetchHistory,
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
            else ...[
              /// SUMMARY CARDS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        number: '$_presentDays',
                        label: "Present",
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SummaryCard(
                        number: '$_absentDays',
                        label: "Absent",
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        number: '$_leaveDays',
                        label: "Leave",
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SummaryCard(
                        number: '$_lateDays',
                        label: "Late",
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Attendance History",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_records.length} records',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (_records.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 60,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No records for ${_selectedFilter.toLowerCase()}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ..._records.map((r) {
                  final inTime = _formatTime(r['in_time']);
                  final outTime = _formatTime(r['out_time']);
                  final duration = _calcDuration(r['in_time'], r['out_time']);
                  final hasTime = r['in_time'] != null;

                  return AttendanceCard(
                    date: _formatDate(r['date']),
                    day: r['day'],
                    status: _statusLabel(r['status']),
                    statusColor: _statusColor(r['status']),
                    inTime: hasTime ? inTime : null,
                    outTime: hasTime ? outTime : null,
                    duration: hasTime ? duration : null,
                  );
                }),

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}
