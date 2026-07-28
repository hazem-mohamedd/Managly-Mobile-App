import 'package:flutter/material.dart';

class PayslipCard extends StatelessWidget {
  final String basicSalary;
  final String overtime;
  final String totalDeductions;
  final String netSalary;

  const PayslipCard({
    super.key,
    required this.basicSalary,
    required this.overtime,
    required this.totalDeductions,
    required this.netSalary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          /// 1. NET SALARY CARD (The Big One)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: const Color(0xffeefbf4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffd1fadf), width: 1.5),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: Color(0xff10b981),
                  size: 30,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Net Salary",
                  style: TextStyle(
                    color: Color(0xff065f46),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "EGP $netSalary",
                  style: const TextStyle(
                    color: Color(0xff064e3b),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          /// 2. BASIC SALARY & OVERTIME (Side by Side)
          Row(
            children: [
              Expanded(
                child: _buildInfoBox(
                  label: "Basic Salary",
                  amount: "EGP $basicSalary",
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xff3b82f6),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildInfoBox(
                  label: "Overtime",
                  amount: "EGP $overtime",
                  icon: Icons.access_time,
                  iconColor: const Color(0xfff59e0b),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          /// 3. TOTAL DEDUCTIONS (Bottom)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Total Deductions",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Text(
                  "- EGP $totalDeductions",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required String label,
    required String amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
