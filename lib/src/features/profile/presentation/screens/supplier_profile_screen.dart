import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../features/profile/presentation/screens/privacy_policy_screen.dart';
import 'supplier_faq_screen.dart';
import 'supplier_notifications_page.dart';
import 'supplier_account_settings_page.dart';
import 'package:image_cropper/image_cropper.dart';

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

  // Read-only / Status fields
  String _companyName = 'Supplier';
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
      setState(() {
        _email = user.email ?? '';
      });

      try {
        final data = await supabase
            .from('suppliers')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _companyName = data['company_name'] ?? 'Supplier';
            _status = data['verification_status'] ?? 'Pending';
            _supplierCode = data['supplier_code'] ?? '';

            // Profile image
            _profileImageUrl = data['profile_image_url'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Error fetching profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final ext = croppedFile.path.split('.').last.toLowerCase();
      final fileName = '${user.id}/supplier_avatar.$ext';

      await Supabase.instance.client.storage
          .from('avatars')
          .upload(
            fileName,
            File(croppedFile.path),
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      final cacheBustedUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Save URL to suppliers table
      await Supabase.instance.client
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 1. Header Profile Card (Existing UI)
                  _buildProfileHeader(),
                  const SizedBox(height: 32),

                  // 2. Account Actions
                  _buildSectionTitle("Settings"),
                  _buildMenuOption(
                    Icons.settings,
                    "Account Settings",
                    () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupplierAccountSettingsPage(),
                        ),
                      );
                      if (updated == true) {
                        _fetchSupplierData(); // Refresh if updated
                      }
                    },
                  ),
                  _buildMenuOption(Icons.privacy_tip, "Privacy Policy", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  }),
                  _buildMenuOption(Icons.notifications, "Notifications", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupplierNotificationsPage(),
                      ),
                    );
                  }),
                  _buildMenuOption(Icons.help, "Help & Support", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupplierFaqScreen(),
                      ),
                    );
                  }),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Logout",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingAvatar ? null : _pickProfileImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(
                    0xFF4C8077,
                  ).withValues(alpha: 0.1),
                  backgroundImage: _profileImageFile != null
                      ? FileImage(_profileImageFile!) as ImageProvider
                      : (_profileImageUrl != null &&
                                _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!)
                            : null),
                  child:
                      (_profileImageFile == null &&
                          (_profileImageUrl == null ||
                              _profileImageUrl!.isEmpty))
                      ? Text(
                          _companyName.isNotEmpty
                              ? _companyName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4C8077),
                          ),
                        )
                      : null,
                ),
                if (_isUploadingAvatar)
                  const Positioned.fill(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.black38,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF4C8077),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _companyName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(_email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _status == 'APPROVED' || _status == 'Verified'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Status: $_status",
              style: TextStyle(
                color: _status == 'APPROVED' || _status == 'Verified'
                    ? Colors.green
                    : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_supplierCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Code: $_supplierCode",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4C8077).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF4C8077), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
  }
}
