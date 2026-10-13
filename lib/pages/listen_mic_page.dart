import 'package:flutter/material.dart';

class ListenMicPage extends StatelessWidget {
  const ListenMicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> voiceAlerts = [
      {'title': 'Suspicious Whisper', 'time': '10:45 PM', 'risk': 85},
      {'title': 'Loud Argument', 'time': '08:20 PM', 'risk': 60},
      {'title': 'Glass Breaking', 'time': '02:15 AM', 'risk': 95},
      {'title': 'Unknown Voice', 'time': '04:30 PM', 'risk': 30},
      {'title': 'Crying Sound', 'time': '01:10 AM', 'risk': 75},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Suspect Voice Detection')),
      body: ListView.builder(
        itemCount: voiceAlerts.length,
        itemBuilder: (context, index) {
          final alert = voiceAlerts[index];
          final int risk = alert['risk'];
          Color riskColor = risk > 70 ? Colors.red : (risk > 40 ? Colors.orange : Colors.green);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.graphic_eq, color: Colors.blue),
              ),
              title: Text(alert['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Time: ${alert['time']}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Risk Score',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Text(
                    '$risk%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: riskColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
