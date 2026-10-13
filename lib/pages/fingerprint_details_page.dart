import 'package:flutter/material.dart';

class FingerprintDetailsPage extends StatelessWidget {
  const FingerprintDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> fingerprintData = [
      {'name': 'Thumb (Right)', 'temp': '98.6°F', 'status': 'Normal', 'owner': 'Alex Doe'},
      {'name': 'Index (Right)', 'temp': '98.4°F', 'status': 'Normal', 'owner': 'Alex Doe'},
      {'name': 'Thumb (Left)', 'temp': '99.1°F', 'status': 'Elevated', 'owner': 'Sarah Smith'},
      {'name': 'Index (Left)', 'temp': '98.5°F', 'status': 'Normal', 'owner': 'Sarah Smith'},
      {'name': 'Middle (Right)', 'temp': '98.6°F', 'status': 'Normal', 'owner': 'Mike Johnson'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Details'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: fingerprintData.length,
        itemBuilder: (context, index) {
          final item = fingerprintData[index];
          final isElevated = item['status'] == 'Elevated';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isElevated ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint, 
                  color: isElevated ? Colors.orange : Colors.blue
                ),
              ),
              title: Text(
                item['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Owner: ${item['owner']}'),
                  Text('Status: ${item['status']}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thermostat, 
                    size: 16, 
                    color: isElevated ? Colors.orange : Colors.grey
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item['temp']!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isElevated ? Colors.orange : Colors.black87,
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
