import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/comprehensive_permission_service.dart';

/// Comprehensive Permission Screen that ensures ALL necessary permissions are granted
/// Keeps asking until user grants all permissions required for background location
class ComprehensivePermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;
  
  const ComprehensivePermissionScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<ComprehensivePermissionScreen> createState() => _ComprehensivePermissionScreenState();
}

class _ComprehensivePermissionScreenState extends State<ComprehensivePermissionScreen>
    with TickerProviderStateMixin {
  
  bool _isRequestingPermissions = false;
  bool _allPermissionsGranted = false;
  Map<String, bool> _permissionStatus = {};
  String _currentStep = 'Checking permissions...';
  int _currentStepIndex = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  final List<Map<String, dynamic>> _permissionSteps = [
    {
      'title': '📍 Location Access',
      'description': 'Allow location access to share your location with family',
      'icon': Icons.location_on,
      'color': Colors.blue,
    },
    {
      'title': '🔄 Background Location',
      'description': 'Enable "Always" location for sharing when app is closed',
      'icon': Icons.my_location,
      'color': Colors.green,
    },
    {
      'title': '🔋 Battery Optimization',
      'description': 'Disable battery optimization for reliable location sharing',
      'icon': Icons.battery_full,
      'color': Colors.orange,
    },
    {
      'title': '🚀 Auto-Start Permission',
      'description': 'Allow app to restart after device reboot',
      'icon': Icons.restart_alt,
      'color': Colors.purple,
    },
    {
      'title': '🔔 Notifications',
      'description': 'Enable notifications for location sharing status',
      'icon': Icons.notifications,
      'color': Colors.red,
    },
    {
      'title': '📱 App Settings',
      'description': 'Configure iOS background app refresh',
      'icon': Icons.settings,
      'color': Colors.teal,
    },
  ];
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _checkInitialPermissions();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  Future<void> _checkInitialPermissions() async {
    setState(() {
      _currentStep = 'Checking current permissions...';
    });
    
    final status = await ComprehensivePermissionService.getDetailedPermissionStatus();
    
    setState(() {
      _allPermissionsGranted = status['allGranted'] ?? false;
      _permissionStatus = Map<String, bool>.from(status['permissions'] ?? {});
    });
    
    if (_allPermissionsGranted) {
      _showSuccessAndContinue();
    } else {
      setState(() {
        _currentStep = 'Some permissions are missing. Let\'s fix that!';
      });
    }
  }
  
  Future<void> _requestAllPermissions() async {
    if (_isRequestingPermissions) return;
    
    setState(() {
      _isRequestingPermissions = true;
      _currentStep = 'Requesting permissions...';
      _currentStepIndex = 0;
    });
    
    _progressController.forward();
    
    try {
      final granted = await ComprehensivePermissionService.requestAllPermissions();
      
      if (granted) {
        setState(() {
          _allPermissionsGranted = true;
          _currentStep = 'All permissions granted! 🎉';
        });
        _showSuccessAndContinue();
      } else {
        setState(() {
          _currentStep = 'Some permissions still need attention. Let\'s try again!';
        });
        
        // Update permission status
        final status = await ComprehensivePermissionService.getDetailedPermissionStatus();
        setState(() {
          _permissionStatus = Map<String, bool>.from(status['permissions'] ?? {});
        });
      }
    } catch (e) {
      setState(() {
        _currentStep = 'Error requesting permissions: $e';
      });
    } finally {
      setState(() {
        _isRequestingPermissions = false;
      });
      _progressController.reset();
    }
  }
  
  void _showSuccessAndContinue() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onPermissionsGranted();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildProgressIndicator(),
                const SizedBox(height: 32),
                Expanded(child: _buildPermissionsList()),
                const SizedBox(height: 24),
                _buildActionButton(),
                const SizedBox(height: 16),
                _buildStatusText(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.security,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Permission Setup',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We need a few permissions to make location sharing work like Life360 and Google Maps',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }
  
  Widget _buildProgressIndicator() {
    final grantedCount = _permissionStatus.values.where((granted) => granted).length;
    final totalCount = _permissionSteps.length;
    final progress = totalCount > 0 ? grantedCount / totalCount : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '$grantedCount / $totalCount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : Colors.blue,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPermissionsList() {
    return ListView.builder(
      itemCount: _permissionSteps.length,
      itemBuilder: (context, index) {
        final step = _permissionSteps[index];
        final isGranted = _getPermissionStatus(index);
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildPermissionCard(step, isGranted, index),
        );
      },
    );
  }
  
  bool _getPermissionStatus(int index) {
    switch (index) {
      case 0: return _permissionStatus['location_basic'] ?? false;
      case 1: return _permissionStatus['location_background'] ?? false;
      case 2: return _permissionStatus['battery_optimization'] ?? false;
      case 3: return _permissionStatus['auto_start'] ?? false;
      case 4: return _permissionStatus['notifications'] ?? false;
      case 5: return _permissionStatus['ios_background_refresh'] ?? false;
      default: return false;
    }
  }
  
  Widget _buildPermissionCard(Map<String, dynamic> step, bool isGranted, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted ? Colors.green.withValues(alpha: 0.1) : step['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isGranted ? Icons.check_circle : step['icon'],
              color: isGranted ? Colors.green : step['color'],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isGranted ? Colors.green[700] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Granted',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton() {
    if (_allPermissionsGranted) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.green, Colors.teal],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'All Set! Starting App...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return GestureDetector(
      onTap: _isRequestingPermissions ? null : _requestAllPermissions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: _isRequestingPermissions
              ? LinearGradient(
                  colors: [Colors.grey[400]!, Colors.grey[500]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (_isRequestingPermissions ? Colors.grey : Colors.blue).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isRequestingPermissions
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Requesting Permissions...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Grant All Permissions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  Widget _buildStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_currentStep),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _allPermissionsGranted ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _allPermissionsGranted ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _allPermissionsGranted ? Icons.check_circle : Icons.info,
              color: _allPermissionsGranted ? Colors.green : Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _currentStep,
                style: TextStyle(
                  fontSize: 14,
                  color: _allPermissionsGranted ? Colors.green[700] : Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}