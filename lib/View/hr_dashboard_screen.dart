import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  bool _isLoading = true;
  String _error = '';

  int _totalEmployees = 0;
  int _presentToday = 0;
  int _onLeaveToday = 0;
  int _pendingLeavesCount = 0;
  List<dynamic> _pendingLeaves = [];
  Map<String, dynamic> _performance = {};

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      final isHr = authProvider.isHr;
      final isSupervisor = authProvider.isSupervisor;

      if (isHr) {
        // HR DATA
        final response = await http.get(
          Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/dashboard'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        );
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final data = body['data'];
          setState(() {
            _totalEmployees = data['total_employees'] ?? 0;
            _presentToday = data['present_today'] ?? 0;
            _onLeaveToday = data['on_leave_today'] ?? 0;
            _pendingLeaves = data['pending_supervisor_leaves'] ?? [];
            _performance = data['performance_distribution'] ?? {};
            _isLoading = false;
          });
        } else {
          throw Exception(body['message'] ?? 'Something went wrong');
        }
      } else if (isSupervisor) {
        // SUPERVISOR DATA
        // 1. Fetch Supervisor specific dashboard for basic stats & attendance
        final supResponse = await http.get(
          Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/web-supervisor-dashboard'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        );

        if (supResponse.statusCode != 200) {
          throw Exception('Failed to load supervisor dashboard');
        }
        final supData = jsonDecode(supResponse.body);

        // 2. Fetch performance to calculate distribution locally
        final perfResponse = await http.get(
          Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/performance'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        );

        if (perfResponse.statusCode != 200) {
          throw Exception('Failed to load performance data');
        }
        final perfData = jsonDecode(perfResponse.body);

        // Compute local stats
        int totalEmp = supData['stats']?['team_size'] ?? 0;
        int presentToday = supData['stats']?['present_today'] ?? 0;
        int onLeaveToday = supData['stats']?['on_leave_today'] ?? 0;
        int pendingLeavesCnt = supData['stats']?['pending_leaves'] ?? 0;

        // Filter recent leaves to only show pending (so accepted/rejected disappear)
        List<dynamic> recent = supData['recent_leaves'] ?? [];
        List<dynamic> pendingOnly = recent
            .where((l) => l['status'] == 'pending')
            .toList();

        // Calculate performance distribution
        await authProvider.fetchProfileIfNeeded();
        final supervisorDept = authProvider.userProfile?['department'];

        List<dynamic> allEmployees = perfData['data'] ?? [];
        final deptEmployees = allEmployees
            .where((e) => e['department_name'] == supervisorDept)
            .toList();

        Map<String, dynamic> perfDist = {
          'excellent': 0,
          'good': 0,
          'average': 0,
          'needs_improvement': 0,
        };

        for (var emp in deptEmployees) {
          final rating =
              emp['rating']?.toString().toLowerCase() ?? 'needs_improvement';
          // normalize rating keys
          if (rating.contains('excellent'))
            perfDist['excellent'] = (perfDist['excellent'] ?? 0) + 1;
          else if (rating.contains('good'))
            perfDist['good'] = (perfDist['good'] ?? 0) + 1;
          else if (rating.contains('average'))
            perfDist['average'] = (perfDist['average'] ?? 0) + 1;
          else
            perfDist['needs_improvement'] =
                (perfDist['needs_improvement'] ?? 0) + 1;
        }

        setState(() {
          _totalEmployees = totalEmp;
          _presentToday = presentToday;
          _onLeaveToday = onLeaveToday;
          _pendingLeavesCount = pendingLeavesCnt;
          _pendingLeaves = pendingOnly;
          _performance = perfDist;
          _isLoading = false;
        });
      } else {
        throw Exception("Not authorized");
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Please try again.';
        _isLoading = false;
      });
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
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return date;
    }
  }

  int get _totalPerf =>
      (_performance['excellent'] ?? 0) +
      (_performance['good'] ?? 0) +
      (_performance['average'] ?? 0) +
      (_performance['needs_improvement'] ?? 0);

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
                      Text(
                        context.read<AuthProvider>().isHr
                            ? "HR Dashboard"
                            : "My Dashboard",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.read<AuthProvider>().isHr
                            ? "Organization overview"
                            : "Department overview",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
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
                      onPressed: _fetchDashboard,
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
              /// OVERVIEW CARDS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _OverviewCardWide(
                      label: 'Total Employees',
                      value: '$_totalEmployees',
                      icon: Icons.people_rounded,
                      color: const Color(0xff3b82f6),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewCard(
                            label: 'Present Today',
                            value: '$_presentToday',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xff10b981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OverviewCard(
                            label: context.read<AuthProvider>().isHr
                                ? 'On Leave Today'
                                : 'Pending Leaves',
                            value: context.read<AuthProvider>().isHr
                                ? '$_onLeaveToday'
                                : '$_pendingLeavesCount',
                            icon: context.read<AuthProvider>().isHr
                                ? Icons.hourglass_empty_rounded
                                : Icons.pending_actions_rounded,
                            color: const Color(0xfff59e0b),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// ATTENDANCE SUMMARY
              const _SectionTitle(title: 'Attendance Summary'),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      _AttendanceRow(
                        label: 'Present',
                        value: _presentToday,
                        total: _totalEmployees,
                        color: const Color(0xff10b981),
                      ),
                      const SizedBox(height: 12),
                      _AttendanceRow(
                        label: 'Absent',
                        value: _totalEmployees - _presentToday - _onLeaveToday,
                        total: _totalEmployees,
                        color: const Color(0xffef4444),
                      ),
                      const SizedBox(height: 12),
                      _AttendanceRow(
                        label: 'On Leave',
                        value: _onLeaveToday,
                        total: _totalEmployees,
                        color: const Color(0xfff59e0b),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// PENDING LEAVE REQUESTS
              const _SectionTitle(title: 'Pending Leave Requests'),
              const SizedBox(height: 10),

              if (_pendingLeaves.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'No pending leave requests.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._pendingLeaves.map((l) {
                  final name =
                      '${l['first_name'] ?? ''} ${l['last_name'] ?? ''}';
                  final dept = l['dep_name'] ?? '';
                  final type = l['leave_type'] ?? '';
                  final start = _formatDate(l['start_date']);
                  final end = _formatDate(l['end_date']);
                  final dateStr = l['start_date'] == l['end_date']
                      ? start
                      : '$start - $end';

                  return _PendingLeaveCard(
                    name: name,
                    department: dept,
                    type: type,
                    date: dateStr,
                  );
                }),

              const SizedBox(height: 24),

              /// PERFORMANCE DISTRIBUTION
              const _SectionTitle(title: 'Performance Distribution'),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      _PerformanceDistRow(
                        label: 'Excellent',
                        count: _performance['excellent'] ?? 0,
                        total: _totalPerf == 0 ? 1 : _totalPerf,
                        color: const Color(0xff10b981),
                        icon: Icons.star_rounded,
                      ),
                      const Divider(height: 20),
                      _PerformanceDistRow(
                        label: 'Good',
                        count: _performance['good'] ?? 0,
                        total: _totalPerf == 0 ? 1 : _totalPerf,
                        color: const Color(0xff3b82f6),
                        icon: Icons.thumb_up_rounded,
                      ),
                      const Divider(height: 20),
                      _PerformanceDistRow(
                        label: 'Average',
                        count: _performance['average'] ?? 0,
                        total: _totalPerf == 0 ? 1 : _totalPerf,
                        color: const Color(0xfff59e0b),
                        icon: Icons.remove_circle_outline_rounded,
                      ),
                      const Divider(height: 20),
                      _PerformanceDistRow(
                        label: 'Needs Improvement',
                        count: _performance['needs_improvement'] ?? 0,
                        total: _totalPerf == 0 ? 1 : _totalPerf,
                        color: const Color(0xffef4444),
                        icon: Icons.warning_rounded,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Overview Card Wide ────────────────────────────────────────────────────────

class _OverviewCardWide extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewCardWide({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Overview Card ─────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Attendance Row ────────────────────────────────────────────────────────────

class _AttendanceRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _AttendanceRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total == 0 ? 1 : total;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '$value / $total',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value / safeTotal,
          backgroundColor: Colors.grey.shade200,
          color: color,
          borderRadius: BorderRadius.circular(10),
          minHeight: 6,
        ),
      ],
    );
  }
}

// ── Pending Leave Card ────────────────────────────────────────────────────────

class _PendingLeaveCard extends StatelessWidget {
  final String name;
  final String department;
  final String type;
  final String date;

  const _PendingLeaveCard({
    required this.name,
    required this.department,
    required this.type,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    department,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    date,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                type,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Performance Distribution Row ──────────────────────────────────────────────

class _PerformanceDistRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _PerformanceDistRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (count / total * 100).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '$count employees  ($percent%)',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: count / total,
          backgroundColor: Colors.grey.shade200,
          color: color,
          borderRadius: BorderRadius.circular(10),
          minHeight: 6,
        ),
      ],
    );
  }
}
