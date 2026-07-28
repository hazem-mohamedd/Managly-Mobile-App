import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/Widget/tasks_card_widget.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _isLoading = true;
  String _error = '';
  List tasks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isHr && !authProvider.isSupervisor) {
        _fetchTasks();
      }
    });
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final token = context.read<AuthProvider>().token;

      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/my-tasks'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          tasks = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load tasks';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTaskStatus(int id, TaskStatus status) async {
    final token = context.read<AuthProvider>().token;

    String statusString;

    switch (status) {
      case TaskStatus.inProgress:
        statusString = "progress";
        break;
      case TaskStatus.completed:
      case TaskStatus.overdue:
        statusString = "completed";
        break;
      default:
        return;
    }

    try {
      final response = await http.patch(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/tasks/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'status': statusString}),
      );

      // Silent update — no SnackBar shown
    } catch (e) {
      print("UPDATE ERROR: $e");
    }
  }

  TaskStatus _mapStatus(String status) {
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'progress':
      case 'in progress':
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'pinding':
      case 'pending':
      default:
        return TaskStatus.pending;
    }
  }

  DateTime _parseDate(String date) {
    return DateTime.parse(date);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isHr = authProvider.isHr;
    final isSupervisor = authProvider.isSupervisor;

    if (isHr || isSupervisor) {
      return const Scaffold(
        backgroundColor: Color(0xfff3f4f6),
        body: Center(
          child: Text(
            "Not Authorized to view tasks",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

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
                    "Tasks",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "The tasks you are assigned",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const LoadingWidget()
            else if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red))
            else if (tasks.isEmpty)
              const Text('No tasks found', style: TextStyle(color: Colors.grey))
            else
              Column(
                children: tasks.map((task) {
                  return TaskCard(
                    title: task['title'] ?? '',
                    details: task['description'],
                    assignedTime: _parseDate(task['created_at']),
                    deadline: _parseDate(task['due_date']),
                    initialStatus: _mapStatus(task['status']),
                    onStatusChanged: (newStatus) {
                      _updateTaskStatus(task['task_id'], newStatus);
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
