import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:managely/Auth/auth_provider.dart';
import 'package:managely/Widget/loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:managely/Widget/payslip_card_widget.dart';

class PatslipScreen extends StatefulWidget {
  const PatslipScreen({super.key});

  @override
  State<PatslipScreen> createState() => _PatslipScreenState();
}

class _PatslipScreenState extends State<PatslipScreen> {
  // API URL
  final String baseUrl = "https://subfusiform-joni-holmic.ngrok-free.dev/api/my-payslip";

  Future<Map<String, dynamic>> fetchPayslip(String token) async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      print("PAYSLIP STATUS: ${response.statusCode}");
      print("PAYSLIP BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded['data'] != null) {
          return decoded['data'];
        } else {
          throw Exception('no salary');
        }
      } else if (response.statusCode == 404) {
        throw Exception('no salary');
      } else {
        throw Exception('erorr server');
      }
    } catch (e) {
      throw Exception('connection error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String? userToken = authProvider.token;

    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),
      body: userToken == null
          ? const Center(child: Text("يرجى تسجيل الدخول أولاً"))
          : FutureBuilder<Map<String, dynamic>>(
              future: fetchPayslip(userToken),
              builder: (context, snapshot) {
                // loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // return Center(child: CircularProgressIndicator());
                  return Center(child: LoadingWidget());
                }

                // error
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 50,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 10),
                        Text("${snapshot.error}"),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text("إعادة المحاولة"),
                        ),
                      ],
                    ),
                  );
                }

                // no data
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text("لا توجد بيانات"));
                }

                final data = snapshot.data!;
                final financials = data['financials'] ?? {};

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      /// HEADER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                          top: 60,
                          left: 10,
                          bottom: 30,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xff3b82f6), Color(0xff2563eb)],
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
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  "Payslip",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 50),
                              child: Text(
                                "${data['month_name'] ?? ''} ${data['year'] ?? ''}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      /// PAYSLIP CARD
                      PayslipCard(
                        basicSalary:
                            financials['base_salary']?.toString() ?? "0",
                        overtime: financials['overtime']?.toString() ?? "0",
                        totalDeductions:
                            financials['deductions']?.toString() ?? "0",
                        netSalary: financials['net_total']?.toString() ?? "0",
                      ),

                      const SizedBox(height: 20),

                      /// SALARY CALCULATION (PRETTY UI)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xfff3f4f6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "How Your Salary is Calculated",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1f2937),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Step 1
                              _buildStepRow(
                                stepNumber: "1",
                                stepColorBg: const Color(0xfffef2f2),
                                stepColorText: const Color(0xffef4444),
                                title: "Deductions",
                                description: "Calculated based on absence and late minutes.",
                                formula: "(Absent Days × Daily Rate) + (Late Minutes × Minute Rate)",
                                formulaColorBg: const Color(0xfff9fafb),
                                formulaColorText: const Color(0xff374151),
                                isBoldFormula: false,
                              ),
                              const SizedBox(height: 20),

                              // Step 2
                              _buildStepRow(
                                stepNumber: "2",
                                stepColorBg: const Color(0xfffef9c3),
                                stepColorText: const Color(0xffca8a04),
                                title: "Overtime Earnings",
                                description: "Extra income calculated from additional working hours.",
                                formula: "(Overtime Minutes × Minute Rate) × Multiplier",
                                formulaColorBg: const Color(0xfff9fafb),
                                formulaColorText: const Color(0xff374151),
                                isBoldFormula: false,
                              ),
                              const SizedBox(height: 20),

                              // Step 3
                              _buildStepRow(
                                stepNumber: "3",
                                stepColorBg: const Color(0xffecfdf5),
                                stepColorText: const Color(0xff059669),
                                title: "Net Salary",
                                description: "Final salary after adding overtime and subtracting deductions.",
                                formula: "(Base Salary + Overtime) − Deductions",
                                formulaColorBg: const Color(0xffecfdf5),
                                formulaColorText: const Color(0xff047857),
                                isBoldFormula: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// EXTRA INFO
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xfff3f4f6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Additional Calculation Info",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1f2937),
                                ),
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 500;
                                  final children = [
                                    _buildInfoCard(
                                      title: "Daily Rate",
                                      subtitle: "How much you earn per working day",
                                      formula: "Base Salary ÷ 30",
                                      bgColor: const Color(0xffeff6ff),
                                      borderColor: const Color(0xffdbeafe),
                                      textColor: const Color(0xff1d4ed8),
                                      subtextColor: const Color(0xff2563eb),
                                      isBoldFormula: false,
                                    ),
                                    _buildInfoCard(
                                      title: "Minute Rate",
                                      subtitle: "How much each minute of work is worth",
                                      formula: "Daily Rate ÷ required working hours ÷ 60",
                                      bgColor: const Color(0xfffaf5ff),
                                      borderColor: const Color(0xfff3e8ff),
                                      textColor: const Color(0xff7e22ce),
                                      subtextColor: const Color(0xff9333ea),
                                      isBoldFormula: false,
                                    ),
                                    _buildInfoCard(
                                      title: "Overtime Multiplier",
                                      subtitle: "Extra reward factor for overtime",
                                      formula: "1.5 ×",
                                      bgColor: const Color(0xffecfdf5),
                                      borderColor: const Color(0xffd1fae5),
                                      textColor: const Color(0xff047857),
                                      subtextColor: const Color(0xff059669),
                                      isBoldFormula: true,
                                    ),
                                  ];

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: children[0]),
                                        const SizedBox(width: 12),
                                        Expanded(child: children[1]),
                                        const SizedBox(width: 12),
                                        Expanded(child: children[2]),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        children[0],
                                        const SizedBox(height: 12),
                                        children[1],
                                        const SizedBox(height: 12),
                                        children[2],
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required Color stepColorBg,
    required Color stepColorText,
    required String title,
    required String description,
    required String formula,
    required Color formulaColorBg,
    required Color formulaColorText,
    required bool isBoldFormula,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: stepColorBg,
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: TextStyle(
              color: stepColorText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff374151),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff6b7280),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: formulaColorBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formula,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: formulaColorText,
                    fontWeight: isBoldFormula ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required String formula,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required bool isBoldFormula,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formula,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: textColor,
                fontWeight: isBoldFormula ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
