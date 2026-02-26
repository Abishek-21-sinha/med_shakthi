import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:med_shakthi/src/features/profile/presentation/screens/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/core/utils/app_constants.dart';
import 'package:med_shakthi/src/features/support/presentation/screens/support_webview_screen.dart';

import 'package:med_shakthi/src/features/checkout/presentation/screens/address_management_screen.dart';
import 'package:med_shakthi/src/features/checkout/presentation/screens/payment_method_screen.dart';
import 'package:med_shakthi/src/features/cart/data/cart_data.dart';
import '../../../orders/orders_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  File? _profileImage;
  String? _avatarUrl;

  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  String _email = "Loading...";
  String _displayName = "User";
  String _phone = "";

  //  Address fields

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    // _fetchOrders();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);

    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final metaName =
          user.userMetadata?['name'] ?? user.userMetadata?['full_name'];

      setState(() {
        _email = user.email ?? "";
        _phone = user.phone ?? "";
        _displayName =
            metaName ?? (_email.isNotEmpty ? _email.split('@')[0] : "User");
      });

      //  Fetch from users table
      final data = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _displayName = data['name'] ?? _displayName;
          _phone = data['phone'] ?? _phone;
          _avatarUrl = data['avatar_url'] as String?;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      // Clear local persistence before signing out
      context.read<CartData>().clearLocalStateOnly();
      // WE DO NOT call WishlistService.clearWishlist() here because it deletes from cloud!
      // The local state will be automatically cleared by the auth listener in WishlistService.

      await supabase.auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
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
      _profileImage = File(croppedFile.path);
      _isUploadingAvatar = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final ext = croppedFile.path.split('.').last.toLowerCase();
      final fileName = '${user.id}/avatar.$ext';

      // Upload to avatars bucket (upsert to replace existing)
      await supabase.storage
          .from('avatars')
          .upload(
            fileName,
            File(croppedFile.path),
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      // Append cache-buster so Flutter re-fetches the new image
      final cacheBustedUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      // Save URL to users table
      await supabase
          .from('users')
          .update({'avatar_url': cacheBustedUrl})
          .eq('id', user.id);

      if (mounted) {
        setState(() => _avatarUrl = cacheBustedUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile photo updated!"),
            backgroundColor: Color(0xFF4C8077),
          ),
        );
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to upload photo: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _displayName);
    // Store the full international phone number (with dial code)
    String _completePhone = _phone;
    bool _phoneValid = _phone.isNotEmpty;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              IntlPhoneField(
                initialValue: _phone.startsWith('+') ? _phone : null,
                initialCountryCode: 'IN',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  hintText: 'Enter 10-digit number',
                ),
                onChanged: (phone) {
                  setStateDialog(() {
                    _completePhone = phone.completeNumber;
                    _phoneValid = phone.isValidNumber();
                  });
                },
                onCountryChanged: (country) {
                  setStateDialog(() {
                    _phoneValid = false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      // Validate phone number
      if (_completePhone.isNotEmpty && !_phoneValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid phone number.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) return;
      try {
        await supabase
            .from('users')
            .update({
              'name': nameCtrl.text.trim(),
              'phone': _completePhone,
            })
            .eq('id', user.id);

        if (mounted) {
          setState(() {
            _displayName = nameCtrl.text.trim();
            _phone = _completePhone;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated!'),
              backgroundColor: Color(0xFF6AA39B),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final addressStore = context.watch<AddressStore>(); // Unused
    // final selected = addressStore.selectedAddress; // Unused

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Account",
          style: TextStyle(color: theme.appBarTheme.foregroundColor),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  //  PROFILE CARD
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(48),
                          onTap: _isUploadingAvatar ? null : _pickProfileImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: const Color(
                                  0xFF6AA39B,
                                ).withValues(alpha: 0.12),
                                backgroundImage: _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : (_avatarUrl != null &&
                                              _avatarUrl!.isNotEmpty
                                          ? NetworkImage(_avatarUrl!)
                                                as ImageProvider
                                          : null),
                                child:
                                    (_profileImage == null &&
                                        (_avatarUrl == null ||
                                            _avatarUrl!.isEmpty))
                                    ? Text(
                                        _displayName.isNotEmpty
                                            ? _displayName[0].toUpperCase()
                                            : "U",
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              color: const Color(0xFF6AA39B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      )
                                    : null,
                              ),
                              if (_isUploadingAvatar)
                                const Positioned.fill(
                                  child: CircleAvatar(
                                    radius: 34,
                                    backgroundColor: Colors.black38,
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(0xFF6AA39B),
                                  child: Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _displayName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _showEditProfileDialog,
                                    borderRadius: BorderRadius.circular(16),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: Color(0xFF6AA39B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.7),
                                ),
                              ),
                              if (_phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _phone,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  //  CONTENT
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const SizedBox(height: 8),

                        //  Address Section (Navigates to AddressSelectScreen)
                        _SimpleExpansionTile(
                          title: 'Address',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddressManagementScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        //  Orders Section (Navigates to OrdersPage)
                        _SimpleExpansionTile(
                          title: 'My Orders',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OrdersPage(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        //  Payment Section (Static placeholder)
                        _SimpleExpansionTile(
                          title: "Payment Methods",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PaymentMethodScreen(
                                  isCheckout: false,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        //  Settings Section
                        _SimpleExpansionTile(
                          title: 'Settings',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        //  Help & Support Section
                        _SimpleExpansionTile(
                          title: 'Help & Support',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SupportWebViewScreen(
                                  supportUrl: AppConstants.supportUrl,
                                ),
                              ),
                            );
                          },
                        ),

                        FilledButton(
                          onPressed: _handleLogout,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6AA39B),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text("Logout"),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SimpleExpansionTile extends StatelessWidget {
  const _SimpleExpansionTile({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
