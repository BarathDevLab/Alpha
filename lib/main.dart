import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'channels.dart';
import 'ml/mind_classifier.dart';
import 'models/alert_event.dart';
import 'screens/mind_alert.dart';
import 'screens/permission_recovery.dart';

// ── FCM background handler (top-level) ───────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// ── Notification plugin instance ──────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Firebase (optional if google-services.json is present)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase not configured yet: $e');
  }

  // Local notifications (persistent monitoring banner)
  await _localNotif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Pre-load ML model
  await MindClassifier.instance.load();

  runApp(const SafeSenseApp());
}

// ═════════════════════════════════════════════════════════════════════════════
class SafeSenseApp extends StatefulWidget {
  const SafeSenseApp({super.key});
  @override
  State<SafeSenseApp> createState() => _SafeSenseAppState();
}

class _SafeSenseAppState extends State<SafeSenseApp> {
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('onboarded') == true) {
      setState(() => _onboarded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    FlutterNativeSplash.remove();
    return MaterialApp(
      title: 'SafeSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF126A72)),
        scaffoldBackgroundColor: const Color(0xFFF7FAF9),
      ),
      home: _onboarded
          ? const SafeSenseShell()
          : ConsentPage(
              onContinue: (bool mind, bool sound) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarded', true);
                await prefs.setBool('consent_mind', mind);
                await prefs.setBool('consent_sound', sound);
                setState(() => _onboarded = true);
              },
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CONSENT PAGE
// ═════════════════════════════════════════════════════════════════════════════
class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key, required this.onContinue});
  final void Function(bool mind, bool sound) onContinue;
  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool adult = false, mind = false, sound = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF126A72),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 28),
              Text('Safety, on your terms.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text(
                  'SafeSense looks for wellbeing and sound safety signals on this device. '
                  'It is not a medical service and cannot diagnose or guarantee safety.'),
              const SizedBox(height: 20),
              const InfoCard(
                icon: Icons.visibility_off_outlined,
                title: 'What we never share',
                body: 'Raw text, app names, screenshots and audio never leave your device. '
                    'Contacts only receive a risk level you choose to share.',
              ),
              const SizedBox(height: 12),
              const InfoCard(
                icon: Icons.delete_outline,
                title: 'You stay in control',
                body: 'Stop monitoring in one tap, revoke consent any time, and delete history.',
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                value: mind,
                onChanged: (v) => setState(() => mind = v),
                title: const Text('Mind Guard'),
                subtitle: const Text('On-device wellbeing signals from approved sources only.'),
              ),
              SwitchListTile.adaptive(
                value: sound,
                onChanged: (v) => setState(() => sound = v),
                title: const Text('Sound Guard'),
                subtitle: const Text('On-device sound anomaly signals. Speech frames are discarded.'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: adult,
                onChanged: (v) => setState(() => adult = v ?? false),
                title: const Text('I am 18 or older and consent to the selected purposes.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: adult && (mind || sound)
                    ? () => widget.onContinue(mind, sound)
                    : null,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Continue with selected protections'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Minors require verified parental consent and are not eligible for this demo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SHELL — navigation + channel wiring
// ═════════════════════════════════════════════════════════════════════════════
class SafeSenseShell extends StatefulWidget {
  const SafeSenseShell({super.key});
  @override
  State<SafeSenseShell> createState() => _SafeSenseShellState();
}

class _SafeSenseShellState extends State<SafeSenseShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _mind = false, _sound = false;
  bool _cleared = false;
  final List<AlertEvent> _events = [];

  StreamSubscription<AlertEvent>? _soundSub;
  StreamSubscription<Map<String, dynamic>>? _textSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefsAndStart();
    _subscribeSoundEvents();
    _subscribeTextEvents();
  }

  // ── Preferences + service start ───────────────────────────────────────────

  Future<void> _loadPrefsAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final consentMind = prefs.getBool('consent_mind') ?? false;
    final consentSound = prefs.getBool('consent_sound') ?? false;
    setState(() { _mind = consentMind; _sound = consentSound; });

    if (consentSound) await _enableSound(true);
    if (consentMind) await _enableMind(true);
  }

  Future<void> _enableSound(bool on) async {
    if (on) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const PermissionRecoveryScreen(),
          ));
        }
        return;
      }
      await ChannelBridge.instance.startSound();
      _showPersistentNotification('Sound Guard active', 'Listening for safety signals. Speech is discarded.');
    } else {
      await ChannelBridge.instance.stopSound();
      _cancelPersistentNotification(1001);
    }
    setState(() => _sound = on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_sound', on);
  }

  Future<void> _enableMind(bool on) async {
    if (on) {
      await ChannelBridge.instance.startMind();
    } else {
      await ChannelBridge.instance.stopMind();
    }
    setState(() => _mind = on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_mind', on);
  }

  // ── Event subscriptions ───────────────────────────────────────────────────

  void _subscribeSoundEvents() {
    _soundSub = ChannelBridge.instance.soundStream.listen((event) {
      setState(() => _events.insert(0, event));
    }, onError: (_) {
      // permission revoked mid-run
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const PermissionRecoveryScreen(),
        ));
        setState(() => _sound = false);
      }
    });
  }

  void _subscribeTextEvents() {
    _textSub = ChannelBridge.instance.textStream.listen((raw) async {
      final text = raw['text'] as String? ?? '';
      if (text.isEmpty) return;

      final result = MindClassifier.instance.classify(text);
      if (result.risk == MindRisk.safe) return;

      final event = AlertEvent(
        id: raw['id'] as String,
        type: 'mind',
        label: result.label,
        level: result.risk == MindRisk.high ? 3 : 2,
        confidence: result.probability,
        ts: DateTime.parse(raw['ts'] as String),
      );
      setState(() => _events.insert(0, event));

      if (mounted) await showMindAlert(context, event);
    });
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> _showPersistentNotification(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'safesense_persistent', 'SafeSense monitoring',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _localNotif.show(1001, title, body, details);
  }

  Future<void> _cancelPersistentNotification(int id) async {
    await _localNotif.cancel(id);
  }

  // ── App lifecycle — re-check permission ───────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sound) {
      Permission.microphone.status.then((s) {
        if (!s.isGranted && mounted) {
          setState(() => _sound = false);
          ChannelBridge.instance.stopSound();
        }
      });
    }
  }

  @override
  void dispose() {
    _soundSub?.cancel();
    _textSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Stop all monitoring ───────────────────────────────────────────────────

  Future<void> _stopAll() async {
    await _enableSound(false);
    await _enableMind(false);
    await _cancelPersistentNotification(1001);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(mind: _mind, sound: _sound, events: _events),
      Guards(
        mind: _mind,
        sound: _sound,
        onMind: (v) => _enableMind(v),
        onSound: (v) => _enableSound(v),
      ),
      History(
        events: _events,
        cleared: _cleared,
        onDelete: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('event_log');
          setState(() { _events.clear(); _cleared = true; });
        },
      ),
      Settings(onStop: _stopAll),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Guards'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DASHBOARD
// ═════════════════════════════════════════════════════════════════════════════
class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.mind, required this.sound, required this.events});
  final bool mind, sound;
  final List<AlertEvent> events;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF126A72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SafeSense', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Private safety signals, on your device'),
                ],
              )),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(children: [
                Icon(Icons.lock_outline, color: Color(0xFF126A72)),
                SizedBox(width: 12),
                Expanded(child: Text('Monitoring is visible and owner-controlled. No raw text or audio is stored.')),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Today at a glance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Metric(icon: Icons.psychology_outlined, title: 'Mind Guard', value: mind ? 'Steady' : 'Paused', active: mind)),
              const SizedBox(width: 12),
              Expanded(child: Metric(icon: Icons.graphic_eq, title: 'Sound Guard', value: sound ? 'Listening' : 'Paused', active: sound)),
            ]),
            const SizedBox(height: 24),
            Text('Gentle check-in', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  events.isEmpty ? 'No urgent signal right now' : 'Recent signal detected',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 6),
                const Text('Signals are trend-based. A single message, meme, lyric, or loud sound will not trigger an alert.'),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SupportSheet(),
                  ),
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Open support options'),
                ),
              ]),
            )),
            const SizedBox(height: 24),
            if (events.isNotEmpty) ...[
              Text('Recent alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...events.take(5).map((e) => _AlertTile(event: e)),
            ] else ...[
              const Activity(icon: Icons.check_circle_outline, title: 'Daily safety check completed', sub: 'No data was shared', color: Color(0xFF16803C)),
              const Activity(icon: Icons.volume_off_outlined, title: 'Speech frame discarded', sub: 'Audio was not processed or retained', color: Color(0xFF126A72)),
            ],
          ],
        ),
      );
}

class _AlertTile extends StatelessWidget {
  final AlertEvent event;
  const _AlertTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.level == 3
        ? const Color(0xFFB00020)
        : event.level == 2
            ? const Color(0xFFB26A00)
            : const Color(0xFF126A72);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(event.type == 'sound' ? Icons.graphic_eq : Icons.psychology_outlined, color: color),
        ),
        title: Text(event.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(event.ts.toLocal().toString().substring(0, 16)),
        trailing: Text(event.levelLabel, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GUARDS
// ═════════════════════════════════════════════════════════════════════════════
class Guards extends StatelessWidget {
  const Guards({super.key, required this.mind, required this.sound, required this.onMind, required this.onSound});
  final bool mind, sound;
  final Future<void> Function(bool) onMind, onSound;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Your guards', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Turn either guard off at any time. Pausing stops new monitoring immediately.'),
            const SizedBox(height: 20),
            GuardCard(
              icon: Icons.psychology_outlined,
              title: 'Mind Guard',
              enabled: mind,
              onChanged: onMind,
              details: const [
                'Approved sources only (Chrome, Notes)',
                'Passwords, OTPs and secure screens are skipped',
                'Risk uses trends — not one message',
              ],
            ),
            const SizedBox(height: 14),
            GuardCard(
              icon: Icons.graphic_eq,
              title: 'Sound Guard',
              enabled: sound,
              onChanged: onSound,
              details: const [
                'Speech is discarded before processing',
                'Multi-frame and loudness checks reduce false alarms',
                'Sound levels are approximate, not calibrated dB',
              ],
            ),
            const SizedBox(height: 22),
            const InfoCard(
              icon: Icons.info_outline,
              title: 'Privacy guarantee',
              body: 'No audio or text is uploaded. Only an alert level reaches the backend if you confirm.',
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// HISTORY
// ═════════════════════════════════════════════════════════════════════════════
class History extends StatelessWidget {
  const History({super.key, required this.events, required this.cleared, required this.onDelete});
  final List<AlertEvent> events;
  final bool cleared;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Shared history', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: (cleared || events.isEmpty) ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete all'),
              ),
            ]),
            const Text('Review exactly what was shared. Raw content is never shown or retained.'),
            const SizedBox(height: 20),
            if (cleared || events.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(children: [
                    Icon(Icons.delete_sweep_outlined, size: 42),
                    SizedBox(height: 8),
                    Text('History deleted'),
                    Text('There are no local events to show.'),
                  ]),
                ),
              )
            else
              ...events.map((e) => HistoryEvent(
                level: e.levelLabel,
                title: e.label,
                detail: e.type == 'sound'
                    ? 'Sound anomaly — level only sent to backend'
                    : 'Wellbeing trend — level only sent if you confirmed',
                time: e.ts.toLocal().toString().substring(0, 16),
              )),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SETTINGS
// ═════════════════════════════════════════════════════════════════════════════
class Settings extends StatelessWidget {
  const Settings({super.key, required this.onStop});
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Settings & privacy', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Setting(icon: Icons.people_outline, title: 'Trusted contact', sub: 'Pair via 6-digit code — contact receives level only'),
            const Setting(icon: Icons.language_outlined, title: 'Language', sub: 'English · Tamil coming in production'),
            const Setting(icon: Icons.battery_saver_outlined, title: 'Battery health', sub: 'Sound Guard uses ~2–4 % per hour on mid-range phones'),
            const Setting(icon: Icons.privacy_tip_outlined, title: 'Privacy controls', sub: 'Consent is granular, revocable and owner-controlled'),
            const SizedBox(height: 22),
            FilledButton.tonalIcon(
              onPressed: onStop,
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Stop all monitoring'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 12),
            const Text(
              'SafeSense is not a substitute for professional help. For emergencies, call local emergency services.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFF126A72)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(body),
            ])),
          ]),
        ),
      );
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.icon, required this.title, required this.value, required this.active});
  final IconData icon;
  final String title, value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF126A72) : Colors.grey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

class Activity extends StatelessWidget {
  const Activity({super.key, required this.icon, required this.title, required this.sub, required this.color});
  final IconData icon;
  final String title, sub;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Card(child: ListTile(leading: Icon(icon, color: color), title: Text(title), subtitle: Text(sub)));
}

class GuardCard extends StatelessWidget {
  const GuardCard({super.key, required this.icon, required this.title, required this.enabled, required this.onChanged, required this.details});
  final IconData icon;
  final String title;
  final bool enabled;
  final Future<void> Function(bool) onChanged;
  final List<String> details;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: const Color(0xFF126A72)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Switch.adaptive(value: enabled, onChanged: onChanged),
            ]),
            const Divider(),
            ...details.map((d) => Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(child: Text(d)),
              ]),
            )),
          ]),
        ),
      );
}

class HistoryEvent extends StatelessWidget {
  const HistoryEvent({super.key, required this.level, required this.title, required this.detail, required this.time});
  final String level, title, detail, time;

  @override
  Widget build(BuildContext context) {
    final color = level == 'High'
        ? const Color(0xFFB00020)
        : level == 'Medium'
            ? const Color(0xFFB26A00)
            : const Color(0xFF126A72);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.insights_outlined, color: color),
        ),
        title: Text(title),
        subtitle: Text('$detail\n$time'),
        isThreeLine: true,
        trailing: Text(level, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class Setting extends StatelessWidget {
  const Setting({super.key, required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title, sub;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF126A72)),
          title: Text(title),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}
