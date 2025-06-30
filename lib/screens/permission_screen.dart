import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/permission_manager.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;
  
  const PermissionScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _permissionsGranted = false;
  String _currentStep = 'Checking permissions...';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkPermissions();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _currentStep = 'Checking permissions...';
    });

    try {
      final granted = await PermissionManager.areAllPermissionsGranted();
      
      if (granted) {
        setState(() {
          _permissionsGranted = true;
          _currentStep = 'All permissions granted!';
          _isLoading = false;
        });
        
        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 1500));
        widget.onPermissionsGranted();
      } else {
        setState(() {
          _isLoading = false;
          _currentStep = 'Permissions required';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentStep = 'Error checking permissions';
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _currentStep = 'Requesting permissions...';
    });

    try {
      final granted = await PermissionManager.requestAllPermissions(context);
      
      if (granted) {
        setState(() {
          _permissionsGranted = true;
          _currentStep = 'All permissions granted!';
        });
        
        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 1500));
        widget.onPermissionsGranted();
      } else {
        setState(() {
          _currentStep = 'Some permissions are missing';
        });
        
        // Show option to retry or exit
        await _showRetryDialog();
      }
    } catch (e) {
      setState(() {
        _currentStep = 'Error requesting permissions';
      });
      
      await _showErrorDialog();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showRetryDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.warning,
            text: 'Permissions Required',
            iconColor: Colors.orange,
          ),
          content: const ResponsiveDialogContent(
            text: 'This app requires all permissions to function properly.\n\n'
                'Without these permissions, you cannot use location sharing features.\n\n'
                'Would you like to try again or exit the app?',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Exit App',
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
            ),
            ResponsiveDialogButton(
              text: 'Try Again',
              onPressed: () {
                Navigator.of(context).pop();
                _requestPermissions();
              },
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showErrorDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ResponsiveDialog(
          barrierDismissible: false,
          title: const ResponsiveDialogTitle(
            icon: Icons.error,
            text: 'Permission Error',
            iconColor: Colors.red,
          ),
          content: const ResponsiveDialogContent(
            text: 'There was an error requesting permissions.\n\n'
                'Please try again or restart the app.',
          ),
          actions: [
            ResponsiveDialogButton(
              text: 'Exit App',
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
            ),
            ResponsiveDialogButton(
              text: 'Retry',
              onPressed: () {
                Navigator.of(context).pop();
                _checkPermissions();
              },
              isPrimary: true,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    
    // Pure ratio-based calculations
    final basePadding = screenSize.shortestSide * 0.04;  // 4% of shortest side
    final sectionSpacing = screenSize.height * 0.04;     // 4% of screen height
    final topSpacing = screenSize.height * 0.03;         // 3% of screen height
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(basePadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - (basePadding * 2),
                ),
                child: Column(
                  children: [
                    SizedBox(height: topSpacing),
                    
                    // App Logo and Title
                    _buildHeader(),
                    
                    SizedBox(height: sectionSpacing),
                    
                    // Permission Requirements
                    _buildPermissionRequirements(),
                    
                    SizedBox(height: sectionSpacing),
                    
                    // Status and Action Button
                    _buildStatusAndAction(),
                    
                    SizedBox(height: topSpacing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final screenSize = MediaQuery.of(context).size;
    
    // Pure ratio-based calculations
    final logoSize = screenSize.shortestSide * 0.22;      // 22% of shortest side
    final logoRadius = screenSize.shortestSide * 0.06;    // 6% of shortest side
    final iconSize = screenSize.shortestSide * 0.12;      // 12% of shortest side
    final titleSpacing = screenSize.height * 0.02;        // 2% of screen height
    final subtitleSpacing = screenSize.height * 0.01;     // 1% of screen height
    final titleFontSize = screenSize.shortestSide * 0.06; // 6% of shortest side
    final subtitleFontSize = screenSize.shortestSide * 0.035; // 3.5% of shortest side
    
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(logoRadius),
            border: Border.all(color: Colors.blue.shade200, width: 2),
          ),
          child: Icon(
            Icons.family_restroom,
            size: iconSize,
            color: Colors.blue.shade600,
          ),
        ),
        SizedBox(height: titleSpacing),
        Text(
          'GroupSharing',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
            fontSize: titleFontSize,
          ),
        ),
        SizedBox(height: subtitleSpacing),
        Text(
          'Family Location Sharing',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade600,
            fontSize: subtitleFontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRequirements() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.blue.shade600),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: Text(
                  'Required Permissions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 20),
          
          _buildPermissionItem(
            Icons.location_on,
            'Location Access',
            'Share your location with family members',
            Colors.green,
          ),
          
          _buildPermissionItem(
            Icons.location_history,
            'Background Location',
            'Continue sharing even when app is closed',
            Colors.orange,
          ),
          
          _buildPermissionItem(
            Icons.notifications,
            'Notifications',
            'Receive proximity alerts and updates',
            Colors.blue,
          ),
          
          _buildPermissionItem(
            Icons.battery_saver,
            'Battery Optimization',
            'Ensure reliable background operation',
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description, Color color) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 32 : 40,
            height: isSmallScreen ? 32 : 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 16 : 20),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 1 : 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndAction() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    
    return Column(
      children: [
        // Status Text
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 16, 
            vertical: isSmallScreen ? 8 : 12
          ),
          decoration: BoxDecoration(
            color: _permissionsGranted 
                ? Colors.green.shade50 
                : _isLoading 
                    ? Colors.blue.shade50 
                    : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _permissionsGranted 
                  ? Colors.green.shade200 
                  : _isLoading 
                      ? Colors.blue.shade200 
                      : Colors.orange.shade200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                SizedBox(
                  width: isSmallScreen ? 14 : 16,
                  height: isSmallScreen ? 14 : 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                )
              else
                Icon(
                  _permissionsGranted ? Icons.check_circle : Icons.info,
                  color: _permissionsGranted 
                      ? Colors.green.shade600 
                      : Colors.orange.shade600,
                  size: isSmallScreen ? 14 : 16,
                ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Flexible(
                child: Text(
                  _currentStep,
                  style: TextStyle(
                    color: _permissionsGranted 
                        ? Colors.green.shade700 
                        : _isLoading 
                            ? Colors.blue.shade700 
                            : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 16 : 24),
        
        // Action Button
        if (!_permissionsGranted && !_isLoading)
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 48 : 56,
            child: ElevatedButton(
              onPressed: _requestPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: isSmallScreen ? 18 : 20),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Grant Permissions',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        if (!_permissionsGranted && !_isLoading)
          SizedBox(height: isSmallScreen ? 12 : 16),
        
        if (!_permissionsGranted && !_isLoading)
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: Text(
              'Exit App',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        
        // Privacy Note
        if (!_permissionsGranted)
          Container(
            margin: EdgeInsets.only(top: isSmallScreen ? 16 : 24),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.privacy_tip, 
                  color: Colors.blue.shade600, 
                  size: isSmallScreen ? 16 : 20
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    'Your privacy is protected. Location data is only shared with family members you choose.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: isSmallScreen ? 10 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}