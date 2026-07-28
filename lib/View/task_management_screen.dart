import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _allTasks = [];
  String _selectedFilter = 'All';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _filters = ['All', 'Pending', 'In Progress', 'Completed', 'Overdue'];

  static const String _baseUrl = 'https://subfusiform-joni-holmic.ngrok-free.dev/api';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAllTasks());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllTasks() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final token = context.read<AuthProvider>().token;
      final response = await http.get(
        Uri.parse('$_baseUrl/tasks/supervisor'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawList;

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          rawList = decoded['data'] as List<dynamic>;
        } else {
          rawList = [];
        }

        setState(() {
          _allTasks = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      } else {
        setState(() {
          _error = 'Failed to load tasks (${response.statusCode})';
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _normalizeStatus(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (s == 'progress' || s == 'in_progress' || s == 'in progress') return 'in_progress';
    if (s == 'completed' || s == 'done') return 'completed';
    if (s == 'overdue') return 'overdue';
    return 'pending';
  }

  List<Map<String, dynamic>> get _filteredTasks {
    if (_selectedFilter == 'All') return _allTasks;
    final map = {
      'Pending': 'pending',
      'In Progress': 'in_progress',
      'Completed': 'completed',
      'Overdue': 'overdue',
    };
    final target = map[_selectedFilter] ?? 'pending';
    return _allTasks
        .where((t) => _normalizeStatus(t['status'] as String?) == target)
        .toList();
  }

  int _countByStatus(String normalizedStatus) =>
      _allTasks.where((t) => _normalizeStatus(t['status'] as String?) == normalizedStatus).length;

  String _formatDate(String? raw) {
    if (raw == null) return '--';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  // ── Status styling ───────────────────────────────────────────────────────────

  Color _statusColor(String normalized) {
    switch (normalized) {
      case 'in_progress':
        return const Color(0xff3b82f6);
      case 'completed':
        return const Color(0xff10b981);
      case 'overdue':
        return const Color(0xffef4444);
      default:
        return const Color(0xfff59e0b);
    }
  }

  IconData _statusIcon(String normalized) {
    switch (normalized) {
      case 'in_progress':
        return Icons.autorenew_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'overdue':
        return Icons.error_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String _statusLabel(String normalized) {
    switch (normalized) {
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Pending';
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : _error.isNotEmpty
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Monitor all team tasks in one place",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Refresh button
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    child: IconButton(
                      onPressed: _fetchAllTasks,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      tooltip: 'Refresh',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Back button
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
            ],
          ),
          if (!_isLoading && _error.isEmpty) ...[
            const SizedBox(height: 20),
            _buildStatsSummary(),
          ],
        ],
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────────────────────

  Widget _buildStatsSummary() {
    final stats = [
      _StatItem(
        label: 'Total',
        value: _allTasks.length,
        color: Colors.white,
        bgColor: Colors.white24,
      ),
      _StatItem(
        label: 'Pending',
        value: _countByStatus('pending'),
        color: const Color(0xfffde68a),
        bgColor: const Color(0x33fde68a),
      ),
      _StatItem(
        label: 'Active',
        value: _countByStatus('in_progress'),
        color: const Color(0xff93c5fd),
        bgColor: const Color(0x3393c5fd),
      ),
      _StatItem(
        label: 'Done',
        value: _countByStatus('completed'),
        color: const Color(0xff6ee7b7),
        bgColor: const Color(0x336ee7b7),
      ),
      _StatItem(
        label: 'Overdue',
        value: _countByStatus('overdue'),
        color: const Color(0xfffca5a5),
        bgColor: const Color(0x33fca5a5),
      ),
    ];

    return Row(
      children: stats
          .map(
            (s) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: s.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '${s.value}',
                      style: TextStyle(
                        color: s.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: TextStyle(
                        color: s.color.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Content ──────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final filtered = _filteredTasks;
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildTaskCard(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final selected = f == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xff2563eb) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0xff2563eb).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff64748b),
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Task Card ────────────────────────────────────────────────────────────────

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final normalized = _normalizeStatus(task['status'] as String?);
    final color = _statusColor(normalized);
    final icon = _statusIcon(normalized);
    final label = _statusLabel(normalized);
    final title = task['title'] as String? ?? 'Untitled';
    final description = task['description'] as String?;
    final firstName = task['first_name'] as String? ?? '';
    final lastName = task['last_name'] as String? ?? '';
    final assigneeName = '$firstName $lastName'.trim().isEmpty
        ? 'Unknown'
        : '$firstName $lastName'.trim();
    final employeeId = task['assigned_to'] ?? task['user_id'];
    final assigneeDisplay = employeeId != null ? '$assigneeName (ID: $employeeId)' : assigneeName;
    final dueDate = _formatDate(task['due_date'] as String?);

    return GestureDetector(
      onTap: () => _showTaskDetails(task, normalized, color, icon, label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + title + status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1e293b),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff64748b),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),

            // Bottom row: assignee + due date
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xff94a3b8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assigneeDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xff94a3b8)),
                const SizedBox(width: 4),
                Text(
                  dueDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── API Actions ──────────────────────────────────────────────────────────────
  Future<void> _updateTaskStatus(int taskId, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final token = context.read<AuthProvider>().token;
      final response = await http.patch(
        Uri.parse('$_baseUrl/tasks/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task status updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAllTasks();
      } else {
        final data = jsonDecode(response.body);
        final message = data['message'] ?? 'Failed to update task status';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTask(int taskId) async {
    final token = context.read<AuthProvider>().token;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Task', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xff64748b))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      // Close details bottom sheet first
      Navigator.pop(context);
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/tasks/$taskId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAllTasks();
      } else {
        final data = jsonDecode(response.body);
        final message = data['message'] ?? 'Failed to delete task';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // ── Task detail bottom sheet ──────────────────────────────────────────────────

  void _showTaskDetails(
    Map<String, dynamic> task,
    String normalized,
    Color color,
    IconData icon,
    String label,
  ) {
    final title = task['title'] as String? ?? 'Untitled';
    final description = task['description'] as String?;
    final firstName = task['first_name'] as String? ?? '';
    final lastName = task['last_name'] as String? ?? '';
    final assigneeName = '$firstName $lastName'.trim().isEmpty
        ? 'Unknown'
        : '$firstName $lastName'.trim();
    final employeeId = task['assigned_to'] ?? task['user_id'];
    final assigneeDisplay = employeeId != null ? '$assigneeName (ID: $employeeId)' : assigneeName;
    final dueDate = _formatDate(task['due_date'] as String?);
    final createdAt = _formatDate(task['created_at'] as String?);

    final rawId = task['task_id'] ?? task['id'];
    final taskId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xff3b82f6),
                        const Color(0xff2563eb),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Details
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (description != null && description.isNotEmpty) ...[
                        const _SectionTitle(title: 'Description'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xff334155),
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const _SectionTitle(title: 'Task Info'),
                      _buildDetailTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Assigned To',
                        value: assigneeDisplay,
                      ),
                      _buildDetailTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'Assigned On',
                        value: createdAt,
                      ),
                      _buildDetailTile(
                        icon: Icons.schedule_rounded,
                        label: 'Due Date',
                        value: dueDate,
                        valueColor: normalized == 'overdue' ? Colors.red : null,
                      ),
                      _buildDetailTile(
                        icon: Icons.info_outline_rounded,
                        label: 'Current Status',
                        value: label,
                        valueColor: color,
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: 'Change Status'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xffe2e8f0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: normalized == 'overdue' ? 'pending' : normalized,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xff2563eb)),
                            items: ['pending', 'in_progress', 'completed'].map((statusKey) {
                              return DropdownMenuItem<String>(
                                value: statusKey,
                                child: Row(
                                  children: [
                                    Icon(_statusIcon(statusKey), color: _statusColor(statusKey), size: 18),
                                    const SizedBox(width: 10),
                                    Text(_statusLabel(statusKey), style: TextStyle(color: _statusColor(statusKey), fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newStatus) {
                              if (newStatus != null && newStatus != normalized) {
                                if (taskId != null) {
                                  Navigator.pop(context); // close bottom sheet
                                  _updateTaskStatus(taskId, newStatus);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // Actions (Delete & Close)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Row(
                    children: [
                      // Delete Button (Fixed size icon button to prevent text wrapping on smaller devices)
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xffef4444),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (taskId != null) {
                              _deleteTask(taskId);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                          tooltip: 'Delete Task',
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Close Button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff2563eb),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xff3b82f6)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xff94a3b8)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xff1e293b),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff64748b), fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchAllTasks,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2563eb),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xff2563eb).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: Color(0xff2563eb),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All'
                ? 'No tasks found'
                : 'No $_selectedFilter tasks',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff1e293b),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tasks assigned to your team will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xff94a3b8)),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final int value;
  final Color color;
  final Color bgColor;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Color(0xff2563eb),
        ),
      ),
    );
  }
}
