import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'login_page.dart';

class ChangePasswordPage extends StatefulWidget {
  /// Set to true when called from the forgot-password email flow
  /// (user already has a recovery session). Set to false when called
  /// from profile settings by a logged-in user (no re-auth needed).
  final bool isRecoveryFlow;

  const ChangePasswordPage({super.key, this.isRecoveryFlow = false});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      // For recovery flow (from email link), skip re-authentication
      if (!widget.isRecoveryFlow) {
        // Re-authenticate with current password first
        final user = supabase.auth.currentUser;
        if (user?.email == null) {
          _show('Unable to verify identity. Please log in again.');
          return;
        }
        await supabase.auth.signInWithPassword(
          email: user!.email!,
          password: _currentController.text.trim(),
        );
      }

      await supabase.auth.updateUser(
        UserAttributes(password: _newController.text.trim()),
      );

      if (!mounted) return;

      // If recovery flow, sign out and go to login
      if (widget.isRecoveryFlow) {
        await supabase.auth.signOut();
        if (!mounted) return;
        showCustomSnackBar(context, 'Password updated! Please log in.');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      } else {
        showCustomSnackBar(context, 'Password changed successfully!');
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String msg) {
    if (!mounted) return;
    showCustomSnackBar(context, msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isRecoveryFlow ? 'Reset Password' : 'Change Password',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isRecoveryFlow
                      ? 'Set your new password below.'
                      : 'Enter your current password then choose a new one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Current password (only for logged-in change)
                if (!widget.isRecoveryFlow) ...[
                  TextFormField(
                    controller: _currentController,
                    obscureText: !_showCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showCurrent = !_showCurrent),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter current password'
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // New password
                TextFormField(
                  controller: _newController,
                  obscureText: !_showNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNew ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _showNew = !_showNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new password';
                    if (v.length < 6) return 'Must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Confirm password
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirm ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Confirm your new password';
                    }
                    if (v != _newController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: _loading ? null : _changePassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.isRecoveryFlow
                              ? 'Update Password'
                              : 'Change Password',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
