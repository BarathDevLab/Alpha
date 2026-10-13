import 'package:flutter/material.dart';

class SocialMediaReportPage extends StatelessWidget {
  const SocialMediaReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> events = [
      {'id': 'Reel #9921', 'duration': '45 mins', 'mood': 'Depressive pattern detected'},
      {'id': 'Video #3321', 'duration': '12 mins', 'mood': 'Anxiety indicators'},
      {'id': 'Post #1123', 'duration': '5 mins', 'mood': 'Neutral'},
      {'id': 'Reel #5541', 'duration': '1h 20m', 'mood': 'High isolation risk'},
      {'id': 'Story #8812', 'duration': '30 mins', 'mood': 'Negative sentiment'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Social Media Monitoring')),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          bool isNegative = event['mood'] != 'Neutral';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event['id']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Icon(
                        isNegative ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isNegative ? Colors.red : Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Duration: ${event['duration']}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isNegative ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 18,
                          color: isNegative ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event['mood']!,
                            style: TextStyle(
                              color: isNegative ? Colors.red[700] : Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
