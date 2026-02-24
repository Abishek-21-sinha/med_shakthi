import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/profile/presentation/screens/privacy_policy_screen.dart';
import 'supplier_faq_screen.dart';
import 'supplier_notifications_page.dart';
import 'supplier_account_settings_page.dart';

class SupplierProfileScreen extends StatefulWidget {
  const SupplierProfileScreen({super.key});

  @override
  State<SupplierProfileScreen> createState() => _SupplierProfileScreenState();
}

class _SupplierProfileScreenState extends State<SupplierProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  File? _profileImageFile;
  String? _profileImageUrl;

  String _companyName = 'Supplier';
  String _ownerName = '';
  String _email = '';
  String _status = 'Verified';
  String _supplierCode = '';

  @override
  void initState() {
    super.initState();
    _fetchSupplierData();
  }

  Future<void> _fetchSupplierData() async {
    setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user != null) {
      setState(() => _email = user.email ?? '');
      try {
        final data = await supabase
            .from('suppliers')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (data != null && mounted) {
          setState(() {
            _companyName = data['company_name'] ?? 'Supplier';
            _ownerName = data['name'] ?? '';
            _status = data['verification_status'] ?? 'Pending';
            _supplierCode = data['supplier_code'] ?? '';
            _profileImageUrl = data['profile_image_url'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Error fetching supplier profile: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: const Color(0xFF4C8077),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (croppedFile == null) return;

    setState(() {
      _profileImageFile = File(croppedFile.path);
      _isUploadingAvatar = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final rawBytes = await croppedFile.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 256,
        minHeight: 256,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final storagePath = '${user.id}/supplier_avatar.jpg';
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(storagePath);
      final cacheBustedUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('suppliers')
          .update({'profile_image_url': cacheBustedUrl})
          .eq('user_id', user.id);

      if (mounted) {
        setState(() => _profileImageUrl = cacheBustedUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Color(0xFF4C8077),
          ),
        );
      }
    } catch (e) {
      debugPrint('Supplier avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = const Color(0xFF4C8077);
    final isApproved = _status == 'APPROVED' || _status == 'Verified';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Gradient Header ─────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF1E3530), const Color(0xFF152926)]
                            : [
                                const Color(0xFF4C8077),
                                const Color(0xFF2D5C54),
                              ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: Column(
                          children: [
                            // Top row
                            Row(
                              children: [
                                Text(
                                  'Supplier Profile',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                                const Spacer(),
                                // Settings shortcut
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings_outlined,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {
                                    final updated = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SupplierAccountSettingsPage(),
                                      ),
                                    );
                                    if (updated == true) _fetchSupplierData();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Avatar + info row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar
                                GestureDetector(
                                  onTap: _isUploadingAvatar
                                      ? null
                                      : _pickProfileImage,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: _isUploadingAvatar
                                              ? Container(
                                                  color: Colors.white24,
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                                )
                                              : _profileImageFile != null
                                              ? Image.file(
                                                  _profileImageFile!,
                                                  fit: BoxFit.cover,
                                                )
                                              : (_profileImageUrl != null &&
                                                    _profileImageUrl!
                                                        .isNotEmpty)
                                              ? Image.network(
                                                  _profileImageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, _) =>
                                                      _avatarPlaceholder(
                                                        primary,
                                                      ),
                                                )
                                              : _avatarPlaceholder(primary),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: primary,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _companyName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (_ownerName.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _ownerName,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      if (_email.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _email,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      // Status badge
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isApproved
                                                  ? Colors.green.withValues(
                                                      alpha: 0.25,
                                                    )
                                                  : Colors.orange.withValues(
                                                      alpha: 0.25,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isApproved
                                                    ? Colors.green.withValues(
                                                        alpha: 0.5,
                                                      )
                                                    : Colors.orange.withValues(
                                                        alpha: 0.5,
                                                      ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isApproved
                                                      ? Icons.verified_rounded
                                                      : Icons.pending_outlined,
                                                  size: 13,
                                                  color: isApproved
                                                      ? Colors.greenAccent
                                                      : Colors.orange,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _status,
                                                  style: TextStyle(
                                                    color: isApproved
                                                        ? Colors.greenAccent
                                                        : Colors.orange,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_supplierCode.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '# $_supplierCode',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Menu Sections ────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Business
                        _sectionLabel('Business'),
                        const SizedBox(height: 10),
                        _MenuCard(
                          items: [
                            _MenuItem(
                              icon: Icons.settings_outlined,
                              label: 'Account Settings',
                              subtitle: 'Edit business details & address',
                              color: Colors.blue,
                              onTap: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SupplierAccountSettingsPage(),
                                  ),
                                );
                                if (updated == true) _fetchSupplierData();
                              },
                            ),
                            _MenuItem(
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              subtitle: 'Order alerts & updates',
                              color: Colors.orange,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SupplierNotificationsPage(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Support & Legal
                        _sectionLabel('Support & Legal'),
                        const SizedBox(height: 10),
                        _MenuCard(
                          items: [
                            _MenuItem(
                              icon: Icons.help_outline_rounded,
                              label: 'Help & FAQ',
                              subtitle: 'Frequently asked questions',
                              color: Colors.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SupplierFaqScreen(),
                                ),
                              ),
                            ),
                            _MenuItem(
                              icon: Icons.privacy_tip_outlined,
                              label: 'Privacy Policy',
                              subtitle: 'Terms and data usage',
                              color: Colors.indigo,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Logout
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _avatarPlaceholder(Color color) {
    return Container(
      color: color.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          _companyName.isNotEmpty ? _companyName[0].toUpperCase() : 'S',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
}

/* ─────────────── Menu Card ─────────────── */

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(i == 0 ? 16 : 0),
                  topRight: Radius.circular(i == 0 ? 16 : 0),
                  bottomLeft: Radius.circular(i == items.length - 1 ? 16 : 0),
                  bottomRight: Radius.circular(i == items.length - 1 ? 16 : 0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 20, color: item.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 68,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
            ],
          );
        }),
      ),
    );
  }
}
