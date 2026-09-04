import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language.dart';
import 'screens/disease_detection_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/weather_forecast_screen.dart';
import 'screens/expert_agriculture_screen.dart';

void main() => runApp(const KrishiRakshakApp());

class KrishiRakshakApp extends StatefulWidget {
  const KrishiRakshakApp({super.key});

  @override
  State<KrishiRakshakApp> createState() => _AppState();
}

class _AppState extends State<KrishiRakshakApp> {
  final lang = AppLanguage();

  @override
  void dispose() {
    lang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      language: lang,
      child: ValueListenableBuilder<String>(
        valueListenable: lang,
        builder: (context, _, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: tr(context, 'app'),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32),
            ),
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void languagePicker(BuildContext context) async {
    final c = LanguageScope.of(context);

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(context, 'selectLanguage'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...languages.entries.map(
              (e) => RadioListTile<String>(
                value: e.key,
                groupValue: c.value,
                title: Text(e.value),
                onChanged: (v) => Navigator.pop(s, v),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      c.value = selected;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'updated'))),
        );
      }
    }
  }

  void openDetect(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DiseaseDetectionScreen(),
      ),
    );
  }

  void openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryScreen(),
      ),
    );
  }

  void openWeather(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WeatherForecastScreen(),
      ),
    );
  }

  void openExpertAgriculture(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExpertAgricultureScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: Text(tr(context, 'app')),
        actions: [
          IconButton(
            onPressed: () => languagePicker(context),
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            tr(context, 'namaste'),
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'tagline'),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.offline_bolt_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tr(context, 'offline'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr(context, 'protection'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(
                  Icons.local_florist,
                  color: Color(0xFF2E7D32),
                ),
              ),
              title: Text(tr(context, 'disease')),
              subtitle: Text(tr(context, 'scan')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openDetect(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    Icons.agriculture_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                title: const Text('Expert Agriculture Information'),
                subtitle: const Text(
                  'Practical crop, soil, irrigation, pest and farming guidance',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openExpertAgriculture(context),
              ),
            ),
            const SizedBox(height: 10),
Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(
                  Icons.cloud_rounded,
                  color: Color(0xFF1565C0),
                ),
              ),
              title: Text(
                WeatherForecastScreen.text(
                  LanguageScope.of(context).value,
                  'title',
                ),
              ),
              subtitle: Text(
                WeatherForecastScreen.text(
                  LanguageScope.of(context).value,
                  'subtitle',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openWeather(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.history_rounded,
                color: Color(0xFF2E7D32),
              ),
              title: Text(tr(context, 'history')),
              subtitle: const Text('View previous AI predictions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openHistory(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined, color: Color(0xFF2E7D32)),
              title: Text(tr(context, 'askAI')),
              subtitle: Text(tr(context, 'aiGreeting')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.language,
                color: Color(0xFF2E7D32),
              ),
              title: Text(tr(context, 'language')),
              subtitle: Text(
                languages[LanguageScope.of(context).value]!,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => languagePicker(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) {
            openDetect(context);
          } else if (i == 2) {
            openHistory(context);
          } else if (i == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: tr(context, 'home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.camera_alt_outlined),
            selectedIcon: const Icon(Icons.camera_alt),
            label: tr(context, 'detect'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: tr(context, 'history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: tr(context, 'settings'),
          ),
        ],
      ),
    );
  }
}


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String forceOfflineKey = 'force_offline_ai';
  bool forceOffline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => forceOffline = prefs.getBool(forceOfflineKey) ?? false);
  }

  Future<void> _setOffline(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(forceOfflineKey, value);
    if (!mounted) return;
    setState(() => forceOffline = value);
  }

  void _openLanguage() {
    final c = LanguageScope.of(context);
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: languages.entries.map((e) => RadioListTile<String>(
            value: e.key,
            groupValue: c.value,
            title: Text(e.value),
            onChanged: (v) {
              if (v != null) c.value = v;
              Navigator.pop(s);
            },
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.offline_bolt_rounded, color: Color(0xFF2E7D32)),
              title: const Text('Force Offline AI'),
              subtitle: const Text('Run the 192-class TFLite model directly on the phone'),
              value: forceOffline,
              onChanged: _setOffline,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF2E7D32)),
              title: const Text('Language'),
              subtitle: Text(languages[LanguageScope.of(context).value] ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openLanguage,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.psychology, color: Color(0xFF2E7D32)),
              title: Text('AI Model'),
              subtitle: Text('192-class Krishi Rakshak TFLite model'),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const String historyKey = 'prediction_history';

  bool loading = true;
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(historyKey) ?? [];

      final loaded = <Map<String, dynamic>>[];

      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);

          if (decoded is Map) {
            loaded.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Ignore one corrupted history record.
        }
      }

      if (!mounted) return;

      setState(() {
        history = loaded;
        loading = false;
      });
    } catch (e) {
      debugPrint('HISTORY LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    if (history.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text(
          'All saved AI prediction history will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(historyKey);

    if (!mounted) return;

    setState(() {
      history.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared.')),
    );
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');

    if (parsed == null) return 'Unknown date';

    final local = parsed.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade800;
      case 'low':
        return Colors.blue.shade700;
      case 'none':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('AI Prediction History'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 80,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No AI predictions yet',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your online and offline AI predictions '
                          'will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DiseaseDetectionScreen(),
                              ),
                            ).then((_) => _loadHistory());
                          },
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Start AI Detection'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = history[index];

                      final disease =
                          item['class_name']?.toString() ?? 'Unknown';
                      final crop =
                          item['crop']?.toString() ?? 'Unknown';
                      final mode =
                          item['mode']?.toString() ?? 'UNKNOWN';
                      final severity =
                          item['severity']?.toString() ?? '';
                      final predictionId =
                          item['prediction_id']?.toString() ?? '';
                      final alert =
                          item['government_alert'] == true;

                      double confidence = 0;

                      final rawConfidence = item['confidence'];

                      if (rawConfidence is num) {
                        confidence = rawConfidence.toDouble();
                      } else {
                        confidence =
                            double.tryParse(
                              rawConfidence?.toString() ?? '',
                            ) ??
                            0;
                      }

                      final severityColor = _severityColor(severity);

                      return Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    backgroundColor:
                                        Color(0xFFE8F5E9),
                                    child: Icon(
                                      Icons.local_florist_rounded,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      disease,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mode == 'ONLINE'
                                          ? Colors.blue.shade50
                                          : Colors.green.shade50,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      mode,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: mode == 'ONLINE'
                                            ? Colors.blue.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _info(
                                      'Crop',
                                      crop,
                                      Icons.eco_rounded,
                                    ),
                                  ),
                                  Expanded(
                                    child: _info(
                                      'Confidence',
                                      '${confidence.toStringAsFixed(2)}%',
                                      Icons.speed_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: severityColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Severity: ${severity.isEmpty ? 'unknown' : severity}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: severityColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (alert) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_rounded,
                                      size: 18,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Government alert required',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                _formatDate(item['created_at']),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              if (predictionId.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'ID: $predictionId',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _info(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
