import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/main.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'package:med_shakthi/src/core/widgets/app_logo.dart';

import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  // SupabaseClient supabase = Supabase.instance.client; // Removed as per import change
  final SupabaseClient supabase = Supabase.instance.client;
  static const String _countryCode = '+91';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _isFormValid = false; // Track form validity

  @override
  void initState() {
    super.initState();
    // Add listeners to check validity on every change
    _nameController.addListener(_checkFormValidity);
    _emailController.addListener(_checkFormValidity);
    _phoneController.addListener(_checkFormValidity);
    _passwordController.addListener(_checkFormValidity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1A1A1A), const Color(0xFF121212)]
                : [const Color(0xFFEAF4F2), const Color(0xFFF6FBFA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF6AA39B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Center(child: AppLogo(size: 100)),

                  const SizedBox(height: 40),

                  // _label('Full Name'), // Replaced by label in _buildTextField
                  _buildTextField(
                    _nameController,
                    'Full Name',
                    Icons.person_outline,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your name'
                        : null,
                  ),

                  // const SizedBox(height: 20), // Padding handled by _buildTextField

                  // _label('Email'), // Replaced by label in _buildTextField
                  _buildTextField(
                    _emailController,
                    'Email',
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter valid email',
                  ),

                  // const SizedBox(height: 20), // Padding handled by _buildTextField

                  // _label('Phone Number'), // Replaced by label in _buildTextField
                  _buildTextField(
                    _phoneController,
                    'Phone Number',
                    Icons.phone_outlined,
                    prefixText: '$_countryCode ',
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ], // Added for strict phone formatting
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter phone number';
                      }
                      if (value.length != 10) {
                        return 'Enter valid 10-digit number';
                      }
                      return null;
                    },
                  ),

                  // const SizedBox(height: 20), // Padding handled by _buildTextField

                  // _label('Password'), // Replaced by label in _buildTextField
                  _buildTextField(
                    _passwordController,
                    'Password',
                    Icons.lock_outline,
                    isPassword: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF6AA39B),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) => value != null && value.length >= 6
                        ? null
                        : 'Minimum 6 characters',
                  ),

                  const SizedBox(height: 20),

                  /// Terms & Conditions
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        activeColor: const Color(0xFF6AA39B),
                        onChanged: (value) {
                          setState(() {
                            _acceptTerms = value ?? false;
                            _checkFormValidity();
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'I agree to the Terms and Conditions & Privacy Policy',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: _isFormValid
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6AA39B,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton(
                        onPressed: _isFormValid ? _onSignupPressed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFormValid
                              ? const Color(0xFF6AA39B)
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0, // Handled by Container for smoothness
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  /// Login Redirect
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: const Color(0xFF6AA39B),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _checkFormValidity() {
    final isValid =
        _nameController.text.isNotEmpty &&
        _emailController.text.contains('@') &&
        _phoneController.text.length == 10 &&
        _passwordController.text.length >= 6 &&
        _acceptTerms;

    if (isValid != _isFormValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      showCustomSnackBar(
        context,
        'Please accept terms & conditions',
        isError: true,
      );
      return;
    }

    RootRouter.suppressAuthRedirect = true;
    setState(() => _isLoading = true);

    try {
      final fullName = _nameController.text.trim();
      final phone = '$_countryCode${_phoneController.text.trim()}';
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      AuthResponse? authResponse;
      bool isLogin = false;

      try {
        // 🔐 Step 1: Supabase Auth Signup
        authResponse = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': fullName, 'phone': phone},
        );
      } on AuthException catch (e) {
        // Handle "User already registered" by attempting login
        if (e.message.contains('already registered') || e.statusCode == '400') {
          try {
            // Attempt to login to "reactivate" or verify ownership
            final loginResponse = await supabase.auth.signInWithPassword(
              email: email,
              password: password,
            );
            if (loginResponse.user != null) {
              authResponse = loginResponse;
              isLogin = true; // Mark as login recovery
            } else {
              rethrow; // Login failed, rethrow original signup error
            }
          } catch (_) {
            // If login fails (wrong password), throw original "already registered"
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Signup failed. Try again.');
      }

      // ✅ User profile created automatically via DB trigger (handle_new_user)
      // which runs as SECURITY DEFINER and picks up full_name + phone from
      // raw_user_meta_data passed in signUp() above.
      // No manual upsert needed — avoids RLS 42501 when email confirmation
      // is enabled (session is null until email is verified).

      if (!mounted) return;

      // ✅ Success
      if (isLogin) {
        // If we just logged them in, skip "Signup Success" dialog and go straight to dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Signup Successful'),
            content: const Text(
              'Your account has been created successfully!\n\nPlease check your email to verify your account before logging in.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  // Pop back to RootRouter, which will evaluate AuthGate
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error: $e', isError: true);
    } finally {
      RootRouter.suppressAuthRedirect = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    Widget? suffixIcon,
    String? prefixText,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        autovalidateMode: AutovalidateMode
            .onUserInteraction, // PROMPT: Enable Real-time Error Highlights (Phone, etc.)
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          counterText: '', // Hide default counter
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }
}
