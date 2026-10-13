import 'package:flutter/material.dart';

class FingerprintPage extends StatelessWidget {
  const FingerprintPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> alerts = [
      {'id': 'FP-8821', 'time': '2025-11-19 10:30 AM', 'level': 'High'},
      {'id': 'FP-9932', 'time': '2025-11-18 02:15 PM', 'level': 'Medium'},
      {'id': 'FP-1102', 'time': '2025-11-18 09:00 AM', 'level': 'Low'},
      {'id': 'FP-4451', 'time': '2025-11-17 06:45 PM', 'level': 'High'},
      {'id': 'FP-3321', 'time': '2025-11-16 11:20 AM', 'level': 'Medium'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint Alerts')),
      body: ListView.builder(
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          Color levelColor = Colors.green;
          if (alert['level'] == 'High') levelColor = Colors.red;
          if (alert['level'] == 'Medium') levelColor = Colors.orange;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: levelColor.withOpacity(0.1),
                child: Icon(Icons.fingerprint, color: levelColor),
              ),
              title: Text('ID: ${alert['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Time: ${alert['time']}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  alert['level']!,
                  style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
