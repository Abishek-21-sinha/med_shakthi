// This file kept for backwards compatibility.
// The actual UI and logic now live in ChangePasswordPage.
export 'change_password_page.dart';

import 'package:flutter/material.dart';
import 'change_password_page.dart';

/// Shown when the user opens the Supabase password-reset email link.
/// Delegates to [ChangePasswordPage] with [isRecoveryFlow] = true.
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChangePasswordPage(isRecoveryFlow: true);
  }
}
