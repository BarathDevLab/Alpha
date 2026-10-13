// lib/screens/mind_alert.dart
//
// Mind alert UI:
//   Medium risk → soft nudge card (bottom sheet)
//   High risk   → full-screen support sheet with Tele-MANAS 14416 + 112
//                 + optional contact alert after confirmation

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/alert_event.dart';

/// Show the appropriate alert UI based on risk level.
Future<void> showMindAlert(BuildContext context, AlertEvent event) async {
  if (event.level >= 3) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HighRiskScreen(event: event),
      ),
    );
  } else if (event.level == 2) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MediumNudgeSheet(event: event),
    );
  }
}

// ── Medium: soft nudge ────────────────────────────────────────────────────────

class MediumNudgeSheet extends StatelessWidget {
  final AlertEvent event;
  const MediumNudgeSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.favorite_border, color: Color(0xFF126A72)),
              const SizedBox(width: 10),
              Text('A gentle check-in',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            const Text(
              'We noticed a trend that sometimes goes alongside difficult feelings. '
              'This isn\'t a diagnosis — you know yourself best.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('I\'m doing fine'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SupportSheet(),
                );
              },
              icon: const Icon(Icons.phone_outlined),
              label: const Text('I\'d like support options'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── High risk: full-screen support ────────────────────────────────────────────

class HighRiskScreen extends StatefulWidget {
  final AlertEvent event;
  const HighRiskScreen({super.key, required this.event});

  @override
  State<HighRiskScreen> createState() => _HighRiskScreenState();
}

class _HighRiskScreenState extends State<HighRiskScreen> {
  bool _alertSent = false;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDADA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: Color(0xFFB00020), size: 48),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You matter. Help is here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'We noticed repeated signals that sometimes appear during a difficult time. '
              'Please consider reaching out to someone right now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _helpTile(
              context,
              icon: Icons.phone,
              color: const Color(0xFFB00020),
              title: 'Emergency — 112',
              subtitle: 'Immediate danger? Call now.',
            ),
            const SizedBox(height: 12),
            _helpTile(
              context,
              icon: Icons.support_agent,
              color: const Color(0xFF126A72),
              title: 'Tele-MANAS — 14416',
              subtitle: 'Free mental health helpline, 24×7.',
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),
            if (!_alertSent) ...[
              Text(
                'Alert a trusted contact?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'They will receive only: "Check in on [you]." No message content is shared.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sending ? null : _sendContactAlert,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Sending…' : 'Yes, alert my contact'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ] else ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF16803C)),
                  SizedBox(width: 8),
                  Text('Contact alerted — level only, no text shared.'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I\'m safe right now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpTile(BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Future<void> _sendContactAlert() async {
    setState(() => _sending = true);
    try {
      await http.post(
        Uri.parse('http://10.0.2.2:3000/events'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': widget.event.id,
          'type': 'mind',
          'label': 'high-risk',
          'level': widget.event.level,
          'confidence': widget.event.confidence,
          'ts': widget.event.ts.toIso8601String(),
          // No text, no audio
        }),
      );
      if (mounted) setState(() { _alertSent = true; _sending = false; });
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ── Reusable support sheet ────────────────────────────────────────────────────

class SupportSheet extends StatelessWidget {
  const SupportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 22),
            const Text('You deserve support',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'If you may be in immediate danger, call 112 in India. '
              'For mental-health support, Tele-MANAS: 14416. '
              'This app cannot contact anyone without your confirmation.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.phone_outlined),
              label: const Text('I will call for help'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("I'm safe right now"),
            ),
          ],
        ),
      ),
    );
  }
}
