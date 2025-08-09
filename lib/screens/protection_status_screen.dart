import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/protection_service.dart';

class ProtectionStatusScreen extends StatefulWidget {
  const ProtectionStatusScreen({super.key});

  @override
  State<ProtectionStatusScreen> createState() => _ProtectionStatusScreenState();
}

class _ProtectionStatusScreenState extends State<ProtectionStatusScreen> {
  bool _loading = true;
  Map<String, dynamic>? _status;
  bool _ackAutostart = false;
  bool _ackForceStop = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await ProtectionService.getOptimizationStatus();
    final ackAuto = await ProtectionService.getAckAutostart();
    final ackForce = await ProtectionService.getAckForceStop();
    setState(() {
      _status = status;
      _ackAutostart = ackAuto;
      _ackForceStop = ackForce;
      _loading = false;
    });
  }

  Future<void> _requestBatteryExemption() async {
    await ProtectionService.requestDisableBatteryOptimization();
    await _load();
  }

  Future<void> _requestOemAutostart() async {
    await ProtectionService.requestOemAutostart();
    await _load();
  }

  Future<void> _openBackgroundPermission() async {
    await ProtectionService.openBackgroundAppPermission();
    await _load();
  }

  Widget _buildStatusTile({required String title, required bool ok, String? subtitle}) {
    return ListTile(
      leading: Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Protection Status')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'To keep location sharing reliable in the background, please review these protections.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('Status', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const Divider(height: 1),
                        _buildStatusTile(
                          title: 'Battery optimization disabled',
                          ok: (_status?['batteryOptimizationDisabled'] as bool?) ?? false,
                        ),
                        _buildStatusTile(
                          title: 'Autostart allowed',
                          ok: (_status?['autoStartEnabled'] as bool?) ?? false,
                        ),
                        _buildStatusTile(
                          title: 'Background run allowed',
                          ok: (_status?['backgroundAppEnabled'] as bool?) ?? false,
                        ),
                        ListTile(
                          title: const Text('Manufacturer'),
                          subtitle: Text('${_status?['deviceManufacturer'] ?? 'unknown'}'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('Actions', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.battery_alert),
                          title: const Text('Disable battery optimization for this app'),
                          subtitle: const Text('Recommended for reliable background location updates.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _requestBatteryExemption,
                        ),
                        ListTile(
                          leading: const Icon(Icons.play_circle_fill),
                          title: const Text('Enable autostart / background run'),
                          subtitle: const Text('Device/OEM specific setting to allow background starts.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _requestOemAutostart,
                        ),
                        ListTile(
                          leading: const Icon(Icons.settings_applications),
                          title: const Text('Open background app settings'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openBackgroundPermission,
                        ),
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Learn more at dontkillmyapp.com'),
                          onTap: ProtectionService.openOemGuide,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('Important behavior', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const Divider(height: 1),
                        CheckboxListTile(
                          value: _ackForceStop,
                          onChanged: (v) async {
                            await ProtectionService.setAckForceStop(v ?? false);
                            setState(() => _ackForceStop = v ?? false);
                          },
                          title: const Text('I understand: if the app is force-stopped, alarms and receivers are disabled until next manual open.'),
                        ),
                        CheckboxListTile(
                          value: _ackAutostart,
                          onChanged: (v) async {
                            await ProtectionService.setAckAutostart(v ?? false);
                            setState(() => _ackAutostart = v ?? false);
                          },
                          title: const Text('I enabled autostart/background run for this app (where applicable).'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
