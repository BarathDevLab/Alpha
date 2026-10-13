// lib/screens/permission_recovery.dart
//
// Shown when RECORD_AUDIO is denied or revoked mid-run.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionRecoveryScreen extends StatelessWidget {
  final String permissionName;
  final VoidCallback? onRecovered;

  const PermissionRecoveryScreen({
    super.key,
    this.permissionName = 'Microphone',
    this.onRecovered,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mic_off_outlined, size: 40, color: Color(0xFFB26A00)),
              ),
              const SizedBox(height: 24),
              Text(
                '$permissionName permission required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sound Guard needs the $permissionName permission to detect safety signals. '
                'No audio is stored or uploaded — all processing happens on your device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  await openAppSettings();
                  // The user returning from settings triggers onRecovered
                  // in the parent widget via AppLifecycleListener.
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open app settings'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Continue without Sound Guard'),
              ),
              const SizedBox(height: 32),
              const Text(
                'Your privacy settings and Mind Guard are not affected.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
