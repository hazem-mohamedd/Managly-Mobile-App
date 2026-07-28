import 'package:flutter/material.dart';

class AttendanceCard extends StatelessWidget {
  final String date;
  final String day;
  final String status;
  final Color statusColor;
  final String? inTime;
  final String? outTime;
  final String? duration;

  const AttendanceCard({
    super.key,
    required this.date,
    required this.day,
    required this.status,
    required this.statusColor,
    this.inTime,
    this.outTime,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    bool showTimes = inTime != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            /// TOP ROW
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.blue),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(day, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor)),
                ),
              ],
            ),

            if (showTimes) ...[
              const Divider(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.login, color: Colors.green, size: 18),
                      const SizedBox(width: 5),
                      Text("In: $inTime"),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.orange, size: 18),
                      const SizedBox(width: 5),
                      Text("Out: $outTime"),
                    ],
                  ),
                  Text(
                    duration!,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
