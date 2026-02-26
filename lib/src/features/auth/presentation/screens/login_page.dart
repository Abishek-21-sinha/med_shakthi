import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:med_shakthi/src/core/widgets/app_logo.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'package:med_shakthi/src/features/auth/presentation/screens/role_selection_page.dart';

import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _resendLoading = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _onResendEmailPressed() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showCustomSnackBar(
        context,
        'Enter your valid email address above first.',
        isError: true,
      );
      return;
    }
    setState(() => _resendLoading = true);
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      showCustomSnackBar(
        context,
        'If this email is registered, a verification link has been sent.',
      );
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Could not resend: $e', isError: true);
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null) {
        await supabase
            .from('suppliers')
            .select()
            .eq('user_id', res.user!.id)
            .maybeSingle();

        if (!mounted) return;

        if (!mounted) return;

        showCustomSnackBar(context, 'Login successful');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('email not confirmed')) {
        showCustomSnackBar(
          context,
          'Please verify your email address to log in.',
          isError: true,
        );
      } else {
        showCustomSnackBar(context, e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Login',
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

                  _label('Email'),
                  _textField(
                    controller: _emailController,
                    hint: 'emailaddress@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter valid email',
                  ),

                  const SizedBox(height: 20),

                  _label('Password'),
                  _textField(
                    controller: _passwordController,
                    hint: 'Password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
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

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onLoginPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6AA39B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RoleSelectionPage(),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: Color(0xFF6AA39B),
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

                  // ── Resend verification email ──────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive a verification email?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 40,
                          child: _resendCooldown > 0
                              ? Text(
                                  'Resend available in ${_resendCooldown}s',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6AA39B),
                                  ),
                                )
                              : OutlinedButton.icon(
                                  onPressed: _resendLoading
                                      ? null
                                      : _onResendEmailPressed,
                                  icon: _resendLoading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF6AA39B),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.mark_email_unread_outlined,
                                          size: 16,
                                        ),
                                  label: const Text(
                                    'Resend Verification Email',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF6AA39B),
                                    side: const BorderSide(
                                      color: Color(0xFF6AA39B),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                        ),
                      ],
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
