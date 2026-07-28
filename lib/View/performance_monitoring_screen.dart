import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PerformanceMonitoringScreen extends StatefulWidget {
  const PerformanceMonitoringScreen({super.key});

  @override
  State<PerformanceMonitoringScreen> createState() =>
      _PerformanceMonitoringScreenState();
}

class _PerformanceMonitoringScreenState
    extends State<PerformanceMonitoringScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedDepartment = 'All';

  bool _isLoading = true;
  String _error = '';
  List<dynamic> _employees = [];

  final List<String> _filters = [
    'All',
    'Excellent',
    'Good',
    'Average',
    'Needs Improvement',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  Future<void> _fetchPerformance() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final response = await http.get(
        Uri.parse('https://subfusiform-joni-holmic.ngrok-free.dev/api/performance'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        List<dynamic> loadedEmployees = body['data'] ?? [];

        // ✅ If supervisor, filter by their department
        if (authProvider.isSupervisor) {
          await authProvider.fetchProfileIfNeeded();
          final userProfile = authProvider.userProfile;
          if (userProfile != null) {
            final supervisorDept = userProfile['department'];
            loadedEmployees = loadedEmployees.where((e) {
              return e['department_name'] == supervisorDept;
            }).toList();
          }
        }

        setState(() {
          _employees = loadedEmployees;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = body['message'] ?? 'Something went wrong';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  List<String> get _departments {
    final deps =
        _employees.map((e) => e['department_name'].toString()).toSet().toList()
          ..sort();
    return ['All', ...deps];
  }

  List<dynamic> get _filtered {
    return _employees.where((e) {
      final name = e['name'].toString().toLowerCase();
      final dept = e['department_name'].toString().toLowerCase();
      final rating = e['rating'].toString();

      final matchSearch =
          name.contains(_searchQuery.toLowerCase()) ||
          dept.contains(_searchQuery.toLowerCase());
      final matchFilter = _selectedFilter == 'All' || rating == _selectedFilter;
      final matchDept =
          _selectedDepartment == 'All' ||
          e['department_name'] == _selectedDepartment;

      return matchSearch && matchFilter && matchDept;
    }).toList()..sort((a, b) {
      final aScore = (a['scores']['final_score'] as num).toDouble();
      final bScore = (b['scores']['final_score'] as num).toDouble();
      return bScore.compareTo(aScore);
    });
  }

  Color _ratingColor(String rating) {
    switch (rating) {
      case 'Excellent':
        return const Color(0xff10b981);
      case 'Good':
        return const Color(0xff3b82f6);
      case 'Average':
        return const Color(0xfff59e0b);
      default:
        return const Color(0xffef4444);
    }
  }

  IconData _ratingIcon(String rating) {
    switch (rating) {
      case 'Excellent':
        return Icons.star_rounded;
      case 'Good':
        return Icons.thumb_up_rounded;
      case 'Average':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Future<void> _generatePdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdf = pw.Document();
      final headers = [
        'Employee',
        'Tasks',
        'Attendance',
        'Final Score',
        'Rating',
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              pw.Text(
                'Team Performance Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#111827'),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#1f2937'),
                    ),
                    children: headers.map((header) {
                      pw.TextAlign align = pw.TextAlign.center;
                      if (header == 'Employee') align = pw.TextAlign.left;
                      if (header == 'Rating') align = pw.TextAlign.right;

                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        child: pw.Text(
                          header,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: align,
                        ),
                      );
                    }).toList(),
                  ),
                  ..._filtered.asMap().entries.map((entry) {
                    final e = entry.value;
                    final rating = e['rating'].toString().toUpperCase();
                    final scores = e['scores'];
                    final taskScore = scores['task_performance'].toString();
                    final attendanceScore = scores['attendance_performance']
                        .toString();
                    final finalScoreNum = (scores['final_score'] as num)
                        .toDouble();
                    final finalScoreStr = finalScoreNum == finalScoreNum.toInt()
                        ? finalScoreNum.toInt().toString()
                        : finalScoreNum.toStringAsFixed(1);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColor.fromHex('#f3f4f6'),
                            width: 1,
                          ),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                e['name'].toString(),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#374151'),
                                  fontSize: 13,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                e['department_name'].toString(),
                                style: pw.TextStyle(
                                  color: PdfColor.fromHex('#9ca3af'),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          child: pw.Text(
                            '$taskScore%',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#6b7280'),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          child: pw.Text(
                            '$attendanceScore%',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#10b981'),
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          child: pw.Text(
                            '$finalScoreStr%',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 15,
                              color: PdfColor.fromHex('#111827'),
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          child: pw.Text(
                            rating,
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColor.fromHex('#4b5563'),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      await Printing.sharePdf(bytes: bytes, filename: 'preformance_report.pdf');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and ready to share!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download PDF. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

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
                bottom: 24,
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
                              "Performance Monitoring",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Based on attendance & task delivery",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            child: IconButton(
                              onPressed: _generatePdf,
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search by name or department...',
                        hintStyle: TextStyle(color: Colors.white60),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.white70),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

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
                      onPressed: _fetchPerformance,
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
              /// FILTER CHIPS — Rating
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final selected = _selectedFilter == _filters[i];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedFilter = _filters[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xff2563eb)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
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

              const SizedBox(height: 10),

              /// DEPARTMENT DROPDOWN
              if (!context.watch<AuthProvider>().isSupervisor) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedDepartment,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xff2563eb),
                        ),
                        items: _departments
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedDepartment = val!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} employees',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              /// LIST
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: filtered.map((e) {
                    final rating = e['rating'].toString();
                    final color = _ratingColor(rating);
                    final icon = _ratingIcon(rating);
                    final scores = e['scores'];
                    final stats = e['stats'];
                    final finalScore = (scores['final_score'] as num)
                        .toDouble();

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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e['name'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      e['department_name'].toString(),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      rating,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${finalScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          LinearProgressIndicator(
                            value: finalScore / 100,
                            backgroundColor: Colors.grey.shade200,
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            minHeight: 6,
                          ),

                          const Divider(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: _MiniStat(
                                  label: 'Attendance',
                                  value: scores['attendance_performance']
                                      .toString(),
                                  sub:
                                      '${stats['present_days']}/${stats['present_days'] + stats['absent_days']} days',
                                  color: const Color(0xff10b981),
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.shade200,
                              ),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Tasks On Time',
                                  value: scores['task_performance'].toString(),
                                  sub:
                                      '${stats['completed_tasks']}/${stats['completed_tasks'] + stats['overdue_tasks']} tasks',
                                  color: const Color(0xff3b82f6),
                                  icon: Icons.task_alt_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
