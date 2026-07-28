import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/Widget/leave_balance_widget.dart';
import 'package:managely/Widget/leave_history_card.dart';
import 'package:file_picker/file_picker.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => LeaveScreenState();
}

class LeaveScreenState extends State<LeaveScreen> {
  double _annual = 0;
  double _sick = 0;
  double _casual = 0;

  List<dynamic> _history = [];

  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // ✅ بيجيب البيانات أول ما الصفحة تفتح
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLeaveData();
    });
  }

  Future<void> _fetchLeaveData() async {
    // ✅ check mounted قبل أي setState
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final token = context.read<AuthProvider>().token;

      if (token == null) {
        if (!mounted) return;
        setState(() {
          _error = "Unauthorized user";
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/leave-history'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      // ✅ check mounted بعد الـ await
      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final history = data['leave_history'] ?? [];
        final balance = data['leave_balance'] ?? {};

        double annualRemaining = (balance['annual'] ?? 0).toDouble();

        double sickRemaining = (balance['sick'] ?? 0).toDouble();

        double casualRemaining = (balance['casual'] ?? 0).toDouble();

        // ✅ check mounted قبل setState
        if (!mounted) return;
        setState(() {
          _annual = annualRemaining;
          _sick = sickRemaining;
          _casual = casualRemaining;
          _history = history;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
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

  Future<void> _submitLeaveRequest(
    String leaveType,
    String startDate,
    String endDate,
    String reason, {
    File? attachment,
  }) async {
    try {
      final token = context.read<AuthProvider>().token;

      http.Response response;

      if (leaveType == 'sick' && attachment != null) {
        // multipart request with file
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/leave-request'),
        );
        req.headers['Authorization'] = 'Bearer $token';
        req.headers['Accept'] = 'application/json';
        req.headers['ngrok-skip-browser-warning'] = 'true';
        req.fields['leave_type'] = leaveType;
        req.fields['start_date'] = startDate;
        req.fields['end_date'] = endDate;
        req.fields['reason'] = reason;
        req.files.add(
          await http.MultipartFile.fromPath('sick_pdf', attachment.path),
        );
        final streamed = await req.send();
        response = await http.Response.fromStream(streamed);
      } else {
        response = await http.post(
          Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/leave-request'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode({
            'leave_type': leaveType,
            'start_date': startDate,
            'end_date': endDate,
            'reason': reason,
          }),
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchLeaveData();
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to submit request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatDateStr(String date) {
    try {
      return _formatDate(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }

  String _toApiDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _showNewLeaveRequest() {
    final reasonController = TextEditingController();
    String? selectedType;
    DateTimeRange? selectedRange;
    File? pickedFile;
    String? pickedFileName;
    final leaveTypes = ['casual', 'sick', 'annual'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff3b82f6), Color(0xff2563eb)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'New Leave Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xff2563eb),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xfff3f4f6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text('Select leave type'),
                            value: selectedType,
                            items: leaveTypes
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(_capitalize(t)),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedType = val),
                          ),
                        ),
                      ),
                      // ── Medical Report (Sick Leave only) ─────────────
                      if (selectedType == 'sick') ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Medical Report',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xff2563eb),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final result = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                            );
                            if (result != null &&
                                result.files.single.path != null) {
                              setDialogState(() {
                                pickedFile = File(result.files.single.path!);
                                pickedFileName = result.files.single.name;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: pickedFile != null
                                  ? const Color(0xffe8f5e9)
                                  : const Color(0xfff3f4f6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: pickedFile != null
                                    ? const Color(0xff10b981)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: pickedFile != null
                                        ? const Color(0xff10b981)
                                        : const Color(0xff2563eb),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    pickedFile != null
                                        ? Icons.check_rounded
                                        : Icons.attach_file_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pickedFile != null
                                            ? 'File attached'
                                            : 'Attach medical report',
                                        style: TextStyle(
                                          color: pickedFile != null
                                              ? const Color(0xff10b981)
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (pickedFileName != null)
                                        Text(
                                          pickedFileName!,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      else
                                        const Text(
                                          'PDF or Image (optional)',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (pickedFile != null)
                                  GestureDetector(
                                    onTap: () => setDialogState(() {
                                      pickedFile = null;
                                      pickedFileName = null;
                                    }),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Date Range',

                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xff2563eb),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xff2563eb),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedRange = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xfff3f4f6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.date_range_rounded,
                                color: Color(0xff2563eb),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                selectedRange == null
                                    ? 'Select date range'
                                    : '${_formatDate(selectedRange!.start)}  →  ${_formatDate(selectedRange!.end)}',
                                style: TextStyle(
                                  color: selectedRange == null
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reason',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xff2563eb),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write your reason here...',
                          filled: true,
                          fillColor: const Color(0xfff3f4f6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xff2563eb)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff2563eb),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedType == null || selectedRange == null)
                            return;
                          Navigator.pop(context);
                          _submitLeaveRequest(
                            selectedType!,
                            _toApiDate(selectedRange!.start),
                            _toApiDate(selectedRange!.end),
                            reasonController.text,
                            attachment: pickedFile,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2563eb),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
    );
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
                    "Leave Requests",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Manage your leave applications",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2563eb),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _showNewLeaveRequest,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "New Leave Request",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
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
                      onPressed: _fetchLeaveData,
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Leave Balance",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LeaveBalanceCard(
                title: "Annual Leave",
                used: 21 - _annual.toInt(),
                total: 21,
              ),
              LeaveBalanceCard(
                title: "Sick Leave",
                used: 10 - _sick.toInt(),
                total: 10,
              ),

              LeaveBalanceCard(
                title: "Casual Leave",
                used: 5 - _casual.toInt(),
                total: 5,
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Request History",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'No leave requests yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._history.map((r) {
                  final start = _formatDateStr(r['start_date']);
                  final end = _formatDateStr(r['end_date']);
                  final dateStr = r['start_date'] == r['end_date']
                      ? start
                      : '$start - $end';
                  final days = (double.tryParse(r['duration'].toString()) ?? 1)
                      .toInt();
                  final status = _capitalize(r['status'] ?? 'pending');

                  return LeaveHistoryCard(
                    title: _capitalize(r['leave_type'] ?? ''),
                    date: dateStr,
                    applied: start,
                    duration: '$days ${days == 1 ? 'day' : 'days'}',
                    status: status,
                    statusColor: _statusColor(r['status'] ?? 'pending'),
                    reason: r['reason'],
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
