import 'package:flutter/material.dart';
import '../services/emergency_location_fix_service.dart';
import '../screens/debug/background_location_fix_screen.dart';

/// Emergency Fix Button Widget
/// 
/// Shows a floating emergency fix button when background location is not working
class EmergencyFixButton extends StatefulWidget {
  final bool showButton;
  
  const EmergencyFixButton({
    super.key,
    required this.showButton,
  });

  @override
  State<EmergencyFixButton> createState() => _EmergencyFixButtonState();
}

class _EmergencyFixButtonState extends State<EmergencyFixButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start pulsing when button should be shown
    if (widget.showButton) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EmergencyFixButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showButton && !oldWidget.showButton) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.showButton && oldWidget.showButton) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showButton) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      right: 16,
      child: AnimatedScale(
        scale: widget.showButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: FloatingActionButton.extended(
                onPressed: () => _showEmergencyFixDialog(context),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.build_circle, size: 20),
                label: const Text(
                  'FIX NOW',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                heroTag: 'emergency_fix',
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEmergencyFixDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Background Location Not Working'),
          ],
        ),
        content: const Text(
          'Your background location service appears to be not working. '
          'This is usually caused by aggressive battery optimization settings.\n\n'
          'Would you like to apply emergency fixes now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyEmergencyFixes(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Fix Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackgroundLocationFixScreen(),
                ),
              );
            },
            child: const Text('Diagnose'),
          ),
        ],
      ),
    );
  }

  void _applyEmergencyFixes(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Applying emergency fixes...'),
          ],
        ),
      ),
    );

    try {
      // Apply emergency fixes
      final result = await EmergencyLocationFixService.applyEmergencyFixes();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show results
        _showFixResults(context, result);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying fixes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFixResults(BuildContext context, EmergencyFixResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.warning,
              color: result.success ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Fix Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.getSummary()),
              
              if (result.manualSteps.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Manual Steps Required:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...result.manualSteps.take(3).map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $step', style: const TextStyle(fontSize: 12)),
                )),
                if (result.manualSteps.length > 3)
                  Text('... and ${result.manualSteps.length - 3} more steps'),
              ],
            ],
          ),
        ),
        actions: [
          if (result.manualSteps.isNotEmpty)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await EmergencyLocationFixService.openDeviceSettings();
              },
              child: const Text('Open Settings'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackgroundLocationFixScreen(),
                ),
              );
            },
            child: const Text('Full Diagnosis'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}