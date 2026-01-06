import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider_fixed.dart';
import 'package:groupsharing/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/theme.dart';
import 'dart:async';
import 'dart:developer' as developer;

class LoginScreenFixed extends StatefulWidget {
  const LoginScreenFixed({super.key});

  @override
  State<LoginScreenFixed> createState() => _LoginScreenFixedState();
}

class _LoginScreenFixedState extends State<LoginScreenFixed> {
  bool _isLoading = false;
  Timer? _timeoutTimer;
  Timer? _loadingResetTimer;
  
  // Maximum time to wait for login before forcing reset
  static const Duration _maxLoadingTime = Duration(seconds: 45);
  static const Duration _navigationTimeout = Duration(seconds: 10);

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _loadingResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;

    try {
      developer.log('[LOGIN_FIXED] Starting Google Sign-In process...');
      
      // Set loading state
      setState(() => _isLoading = true);
      
      // Start timeout timer to force reset loading state
      _startLoadingTimeoutTimer();
      
      final authProvider = Provider.of<AuthProviderFixed>(context, listen: false);
      
      // Attempt sign in with timeout
      final result = await _signInWithTimeout(authProvider);
      
      if (!mounted) return;

      if (result.success) {
        developer.log('[LOGIN_FIXED] Sign-in successful, navigating...');
        
        // Cancel timeout timer since we succeeded
        _timeoutTimer?.cancel();
        
        // Sync location in background (don't block navigation)
        _syncLocationInBackground();
        
        // Navigate immediately - don't wait for background operations
        _navigateToMainScreen();
        
      } else {
        _handleSignInError(result.error);
      }
      
    } catch (e, stack) {
      developer.log('[LOGIN_FIXED] Sign-in exception: $e');
      developer.log('[LOGIN_FIXED] Stack trace: $stack');
      
      if (mounted) {
        _handleSignInError('An unexpected error occurred. Please try again.');
      }
      
    } finally {
      // Always reset loading state
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _timeoutTimer?.cancel();
      _loadingResetTimer?.cancel();
    }
  }

  /// Sign in with additional timeout protection
  Future<AuthResult> _signInWithTimeout(AuthProviderFixed authProvider) async {
    try {
      // Add extra timeout layer
      return await authProvider.signInWithGoogle().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          developer.log('[LOGIN_FIXED] Sign-in operation timed out');
          return AuthResult(success: false, error: 'Sign-in timed out. Please try again.');
        },
      );
    } catch (e) {
      developer.log('[LOGIN_FIXED] Timeout wrapper error: $e');
      return AuthResult(success: false, error: e.toString());
    }
  }

  /// Start timer to force reset loading state if it gets stuck
  void _startLoadingTimeoutTimer() {
    _loadingResetTimer?.cancel();
    _loadingResetTimer = Timer(_maxLoadingTime, () {
      if (mounted && _isLoading) {
        developer.log('[LOGIN_FIXED] Force resetting loading state due to timeout');
        setState(() => _isLoading = false);
        
        // Also reset auth provider loading state
        final authProvider = Provider.of<AuthProviderFixed>(context, listen: false);
        authProvider.forceResetLoadingState();
        
        _showTimeoutError();
      }
    });
  }

  /// Handle sign-in errors with proper user feedback
  void _handleSignInError(String? error) {
    developer.log('[LOGIN_FIXED] Handling sign-in error: $error');
    
    if (error == 'SIGN_IN_CANCELLED') {
      // User cancelled - don't show error
      return;
    }
    
    String userMessage = 'Failed to sign in. Please try again.';
    
    if (error?.toLowerCase().contains('network') == true) {
      userMessage = 'Network error. Please check your connection and try again.';
    } else if (error?.toLowerCase().contains('timeout') == true) {
      userMessage = 'Sign-in timed out. Please try again.';
    } else if (error?.toLowerCase().contains('account-exists') == true) {
      userMessage = 'An account already exists with a different sign-in method.';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _handleGoogleSignIn,
          ),
        ),
      );
    }
  }

  /// Show timeout error with recovery options
  void _showTimeoutError() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sign-in Timeout'),
        content: const Text(
          'The sign-in process is taking longer than expected. This might be due to a slow network connection.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleGoogleSignIn();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Sync location in background without blocking navigation
  void _syncLocationInBackground() {
    Future.microtask(() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          developer.log('[LOGIN_FIXED] Syncing location in background...');
          await LocationService().syncLocationOnAppStartOrLogin(user.uid);
          developer.log('[LOGIN_FIXED] Location sync completed');
        }
      } catch (e) {
        developer.log('[LOGIN_FIXED] Background location sync error: $e');
        // Don't show error to user - this is background operation
      }
    });
  }

  /// Navigate to main screen with timeout protection
  void _navigateToMainScreen() {
    if (!mounted) return;
    
    try {
      developer.log('[LOGIN_FIXED] Navigating to main screen...');
      
      // Add timeout for navigation
      _timeoutTimer = Timer(_navigationTimeout, () {
        if (mounted) {
          developer.log('[LOGIN_FIXED] Navigation timeout - forcing navigation');
          _forceNavigation();
        }
      });
      
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
      ).then((_) {
        _timeoutTimer?.cancel();
        developer.log('[LOGIN_FIXED] Navigation completed successfully');
      }).catchError((e) {
        developer.log('[LOGIN_FIXED] Navigation error: $e');
        _timeoutTimer?.cancel();
        _forceNavigation();
      });
      
    } catch (e) {
      developer.log('[LOGIN_FIXED] Navigation exception: $e');
      _forceNavigation();
    }
  }

  /// Force navigation as last resort
  void _forceNavigation() {
    if (!mounted) return;
    
    try {
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      developer.log('[LOGIN_FIXED] Force navigation failed: $e');
      // Show error and reset state
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.lightBlue.shade50,
              Colors.white,
            ],
            stops: const [0.1, 0.9],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildHeader(),
                const Spacer(flex: 3),
                _buildGoogleSignInButton(),
                const Spacer(flex: 1),
                _buildTermsText(),
                const SizedBox(height: 20),
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
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/applogo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'GroupSharing',
          style: GoogleFonts.pacifico(
            fontSize: 40,
            color: AppColors.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share expenses, split bills, and manage group finances with ease.',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return Consumer<AuthProviderFixed>(
      builder: (context, authProvider, child) {
        final isProviderLoading = authProvider.isLoading;
        final isAnyLoading = _isLoading || isProviderLoading;
        
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isAnyLoading ? null : _handleGoogleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: isAnyLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_translate, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTermsText() {
    return Text(
      'By continuing, you agree to our Terms and Conditions and Privacy Policy',
      textAlign: TextAlign.center,
      style: GoogleFonts.roboto(
        color: Colors.grey[600],
        fontSize: 12,
      ),
    );
  }
}