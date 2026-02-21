import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/auth/presentation/screens/change_password_page.dart';

class SupplierAccountSettingsPage extends StatefulWidget {
  const SupplierAccountSettingsPage({super.key});

  @override
  State<SupplierAccountSettingsPage> createState() =>
      _SupplierAccountSettingsPageState();
}

class _SupplierAccountSettingsPageState
    extends State<SupplierAccountSettingsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  // Controllers for editable fields
  final _companyNameController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _addressController = TextEditingController();
  final _drugLicenseController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();

  String _email = '';
  String _companyType = '';
  String _drugLicenseExpiry = '';

  @override
  void initState() {
    super.initState();
    _fetchSupplierData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _supplierNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _drugLicenseController.dispose();
    _gstController.dispose();
    _panController.dispose();
    super.dispose();
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

        if (data != null && mounted) {
          setState(() {
            _companyNameController.text = data['company_name'] ?? '';
            _supplierNameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';

            // Address
            _addressController.text = data['company_address'] ?? '';
            _cityController.text = data['city'] ?? '';
            _stateController.text = data['state'] ?? '';
            _pincodeController.text = data['pincode'] ?? '';
            _countryController.text = data['country'] ?? '';

            // Legal
            _drugLicenseController.text = data['drug_license_number'] ?? '';
            _drugLicenseExpiry = data['drug_license_expiry'] ?? '';
            _gstController.text = data['gst_number'] ?? '';
            _panController.text = data['pan_number'] ?? '';
            _companyType = data['company_type'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error fetching settings data: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('suppliers')
          .update({
            'company_name': _companyNameController.text.trim(),
            'name': _supplierNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'company_address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'state': _stateController.text.trim(),
            'pincode': _pincodeController.text.trim(),
            'country': _countryController.text.trim(),
            'drug_license_number': _drugLicenseController.text.trim(),
            'gst_number': _gstController.text.trim(),
            'pan_number': _panController.text.trim(),
          })
          .eq('user_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account settings updated successfully!'),
            backgroundColor: Color(0xFF4C8077),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Account Settings"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              color: const Color(0xFF4C8077),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      Icons.business_center,
                      "Business Details",
                    ),
                    _buildCard([
                      _buildTextField(
                        controller: _companyNameController,
                        label: "Company Name",
                        icon: Icons.storefront,
                        validator: (value) =>
                            value!.isEmpty ? 'Company name is required' : null,
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _supplierNameController,
                        label: "Owner Name",
                        icon: Icons.person_outline,
                        validator: (value) =>
                            value!.isEmpty ? 'Owner name is required' : null,
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value!.isEmpty ? 'Phone number is required' : null,
                      ),
                      const Divider(height: 1),
                      _buildReadOnlyField(
                        label: "Email",
                        value: _email,
                        icon: Icons.email_outlined,
                      ),
                    ]),
                    const SizedBox(height: 30),

                    _buildSectionHeader(Icons.location_on, "Business Address"),
                    _buildCard([
                      _buildTextField(
                        controller: _addressController,
                        label: "Full Address",
                        icon: Icons.home_outlined,
                        maxLines: 2,
                        validator: (value) =>
                            value!.isEmpty ? 'Address is required' : null,
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _cityController,
                        label: "City",
                        icon: Icons.location_city,
                      ),
                      const Divider(height: 1),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _stateController,
                              label: "State",
                              showBorder: false,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                          ),
                          Expanded(
                            child: _buildTextField(
                              controller: _pincodeController,
                              label: "Pincode",
                              keyboardType: TextInputType.number,
                              showBorder: false,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _countryController,
                        label: "Country",
                        icon: Icons.public,
                      ),
                    ]),
                    const SizedBox(height: 30),

                    _buildSectionHeader(
                      Icons.verified_user,
                      "Legal & Licenses",
                    ),
                    _buildCard([
                      _buildReadOnlyField(
                        label: "Company Type",
                        value: _companyType,
                        icon: Icons.business,
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _drugLicenseController,
                        label: "Drug License Number",
                        icon: Icons.assignment_outlined,
                      ),
                      if (_drugLicenseExpiry.isNotEmpty) ...[
                        const Divider(height: 1),
                        _buildReadOnlyField(
                          label: "License Expiry",
                          value: _drugLicenseExpiry,
                          icon: Icons.event,
                        ),
                      ],
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _gstController,
                        label: "GST Number",
                        icon: Icons.receipt_long,
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _panController,
                        label: "PAN Number",
                        icon: Icons.badge_outlined,
                      ),
                    ]),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C8077),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          _isSaving ? "Saving..." : "Save Changes",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Security Section ──────────────────────────────────
                    _buildSectionHeader(Icons.security, 'Security'),
                    _buildCard([
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordPage(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.grey[400],
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Update your login password',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4C8077)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey[400], size: 22),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "Not provided" : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool showBorder = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.grey[400], size: 22)
            : null,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: icon != null ? 0 : 16,
          vertical: 16,
        ),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4C8077)),
      ),
    );
  }
}
