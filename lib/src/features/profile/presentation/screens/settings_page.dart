import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:med_shakthi/src/core/theme/theme_provider.dart';
import 'privacy_policy_screen.dart';
import 'package:med_shakthi/src/features/auth/presentation/screens/change_password_page.dart';
import 'package:med_shakthi/src/features/cart/data/cart_data.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primary = const Color(0xFF6AA39B);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Section: App Preferences ────────────────────────
          _sectionLabel('App Preferences'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _ToggleTile(
                icon: Icons.notifications_outlined,
                iconColor: Colors.orange,
                title: 'Notifications',
                subtitle: 'Push notifications for orders & offers',
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
              const _Divider(),
              _ToggleTile(
                icon: Icons.dark_mode_outlined,
                iconColor: Colors.indigo,
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                value: isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Section: Account & Security ─────────────────────
          _sectionLabel('Account & Security'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _NavTile(
                icon: Icons.lock_reset_outlined,
                iconColor: Colors.blue,
                title: 'Change Password',
                subtitle: 'Update your login password',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Section: Legal ───────────────────────────────────
          _sectionLabel('Legal & Info'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _NavTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: Colors.teal,
                title: 'Privacy Policy',
                subtitle: 'How we use your data',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              const _Divider(),
              _NavTile(
                icon: Icons.info_outline_rounded,
                iconColor: primary,
                title: 'About App',
                subtitle: 'Version & developer info',
                onTap: _showAboutDialog,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Section: Danger Zone ──────────────────────────────
          _sectionLabel('Danger Zone'),
          const SizedBox(height: 10),
          _SettingsCard(
            isDanger: true,
            children: [
              _NavTile(
                icon: Icons.delete_forever_outlined,
                iconColor: Colors.redAccent,
                title: 'Delete Account',
                subtitle: 'Permanently remove your account and data',
                onTap: _handleDeleteAccount,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action cannot be undone. All your data, orders, and preferences will be permanently deleted.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty) {
      if (!mounted) return;
      final cartData = context.read<CartData>();
      try {
        final user = supabase.auth.currentUser;
        if (user != null && user.email != null) {
          await supabase.auth.signInWithPassword(
            email: user.email!,
            password: passwordController.text,
          );
          final deleteRes = await supabase.rpc('delete_current_user_debug');
          if (deleteRes['success'] == false) {
            throw Exception('Deletion failed: ${deleteRes['error']}');
          }
          cartData.clearLocalStateOnly();
          await supabase.auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  Future<void> _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.local_pharmacy_rounded, color: Color(0xFF6AA39B)),
            SizedBox(width: 10),
            Text('About App', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Med Shakthi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${packageInfo.version} (${packageInfo.buildNumber})',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'A Flutter-based pharmacy platform connecting suppliers and customers.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Developed by: Flutter Interns @ UptoSkills',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF6AA39B))),
          ),
        ],
      ),
    );
  }
}

/* ─────────────── Settings Card ─────────────── */

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDanger;

  const _SettingsCard({required this.children, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDanger
            ? Colors.redAccent.withValues(alpha: 0.04)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDanger
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.15))
            : null,
        boxShadow: isDanger
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
    );
  }
}

/* ─────────────── Toggle Tile ─────────────── */

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6AA39B),
            activeTrackColor: const Color(0xFF6AA39B).withValues(alpha: 0.4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

/* ─────────────── Nav Tile ─────────────── */

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive ? Colors.redAccent : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDestructive
                          ? Colors.redAccent.withValues(alpha: 0.7)
                          : Theme.of(context).textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: isDestructive
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
