import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      
      // Attempt sign in
      final result = await authProvider.signInWithGoogle();
      
      if (!mounted) return;

      if (result.success) {
        // Navigate to main screen on success
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );
        }
      } else {
        // Handle specific error cases
        String errorMessage = 'Failed to sign in. Please try again.';
        
        if (result.error == 'SIGN_IN_CANCELLED') {
          // User cancelled - don't show error
          return;
        } else if (result.error?.toLowerCase().contains('network') == true) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (result.error?.toLowerCase().contains('account-exists') == true) {
          errorMessage = 'An account already exists with a different sign-in method.';
        }
        // Show the actual error for debugging
        debugPrint('Google Sign-In error: \\${result.error}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Google Sign-In Exception: \\${e.toString()}');
      debugPrint('Stack trace: \\${stack.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // A subtle gradient background for a modern feel.
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
                // App Title and Subtitle
                _buildHeader(),
                const Spacer(flex: 3),
                // Google Sign-In Button
                _buildGoogleSignInButton(),
                const Spacer(flex: 1),
                // Terms and Conditions
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: _isLoading
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
                  // Using a placeholder for Google icon.
                  // For a real app, consider using the `font_awesome_flutter` package
                  // or an image asset for the Google logo.
                  const Icon(Icons.g_translate, color: Colors.blue), // Placeholder icon
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

