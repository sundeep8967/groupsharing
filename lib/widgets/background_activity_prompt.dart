import 'package:flutter/material.dart';
import 'dart:io';
import '../services/background_activity_service.dart';
import '../services/battery_optimization_service.dart';

class BackgroundActivityPrompt extends StatefulWidget {
  final bool showAsCard;
  final VoidCallback? onSetupComplete;
  
  const BackgroundActivityPrompt({
    super.key,
    this.showAsCard = true,
    this.onSetupComplete,
  });

  @override
  State<BackgroundActivityPrompt> createState() => _BackgroundActivityPromptState();
}

class _BackgroundActivityPromptState extends State<BackgroundActivityPrompt> {
  bool _isLoading = true;
  bool _isBackgroundActivityEnabled = false;
  Map<String, String> _deviceInfo = {};

  @override
  void initState() {
    super.initState();
    _checkBackgroundActivityStatus();
  }

  Future<void> _checkBackgroundActivityStatus() async {
    if (!Platform.isAndroid) {
      setState(() {
        _isBackgroundActivityEnabled = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final isEnabled = await BackgroundActivityService.isBackgroundActivityEnabled();
      final deviceInfo = await BackgroundActivityService.getDeviceInfo();
      
      setState(() {
        _isBackgroundActivityEnabled = isEnabled;
        _deviceInfo = deviceInfo;
        _isLoading = false;
      });
      
      if (isEnabled && widget.onSetupComplete != null) {
        widget.onSetupComplete!();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openBackgroundActivitySetup() async {
    await Navigator.of(context).pushNamed('/background-activity-setup');
    // Recheck status after returning from setup
    await _checkBackgroundActivityStatus();
  }

  Future<void> _quickSetup() async {
    try {
      await BatteryOptimizationService.showBackgroundActivitySetupDialog(context);
      // Recheck status after dialog
      await Future.delayed(const Duration(seconds: 1));
      await _checkBackgroundActivityStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isBackgroundActivityEnabled) {
      return const SizedBox.shrink(); // Don't show anything if already enabled
    }

    final manufacturer = _deviceInfo['manufacturer'] ?? 'your device';
    final content = _buildPromptContent(manufacturer);

    if (widget.showAsCard) {
      return Card(
        margin: const EdgeInsets.all(16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: content,
      );
    } else {
      return content;
    }
  }

  Widget _buildPromptContent(String manufacturer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: widget.showAsCard ? null : BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.showAsCard 
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings_applications,
                  color: widget.showAsCard ? Colors.orange : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Background Activity Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: widget.showAsCard ? null : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Setup required for ${manufacturer.toUpperCase()} devices',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.showAsCard 
                            ? Colors.grey.shade600 
                            : Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your device needs special configuration to allow background location sharing. '
            'This ensures the app works reliably even when closed.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: widget.showAsCard ? null : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _quickSetup,
                  icon: Icon(
                    Icons.flash_on,
                    size: 18,
                    color: widget.showAsCard ? Colors.orange : Colors.white,
                  ),
                  label: Text(
                    'Quick Setup',
                    style: TextStyle(
                      color: widget.showAsCard ? Colors.orange : Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: widget.showAsCard ? Colors.orange : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openBackgroundActivitySetup,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Full Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.showAsCard ? Colors.orange : Colors.white,
                    foregroundColor: widget.showAsCard ? Colors.white : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact version of the background activity prompt for use in app bars or small spaces
class BackgroundActivityBanner extends StatefulWidget {
  const BackgroundActivityBanner({super.key});

  @override
  State<BackgroundActivityBanner> createState() => _BackgroundActivityBannerState();
}

class _BackgroundActivityBannerState extends State<BackgroundActivityBanner> {
  bool _isBackgroundActivityEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!Platform.isAndroid) {
      setState(() {
        _isBackgroundActivityEnabled = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final isEnabled = await BackgroundActivityService.isBackgroundActivityEnabled();
      setState(() {
        _isBackgroundActivityEnabled = isEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isBackgroundActivityEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Background activity setup required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/background-activity-setup');
            },
            child: const Text(
              'Setup',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}