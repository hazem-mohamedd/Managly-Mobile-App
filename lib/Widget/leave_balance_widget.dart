import 'package:flutter/material.dart';

class LeaveBalanceCard extends StatelessWidget {
  final String title;
  final int used;
  final int total;

  const LeaveBalanceCard({
    super.key,
    required this.title,
    required this.used,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final int remaining = (total - used).clamp(0, total);

    double progress = 0;

    if (total > 0) {
      progress = (remaining / total).clamp(0.0, 1.0);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(title), Text("${total - used} /$total")],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xff2563eb),
            ),
          ],
        ),
      ),
    );
  }
}
