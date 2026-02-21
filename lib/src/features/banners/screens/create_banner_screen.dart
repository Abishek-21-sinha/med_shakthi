import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/banners/services/banner_service_supabase.dart';
import 'package:med_shakthi/src/features/banners/models/banner_model_supabase.dart';

class CreateBannerScreen extends StatefulWidget {
  final SupabaseBannerModel? existingBanner;

  const CreateBannerScreen({super.key, this.existingBanner});

  @override
  State<CreateBannerScreen> createState() => _CreateBannerScreenState();
}

class _CreateBannerScreenState extends State<CreateBannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bannerService = BannerServiceSupabase();
  final _imagePicker = ImagePicker();

  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();

  XFile? _selectedImageFile;
  String? _selectedCategory;
  final List<String> _categories = [
    'Medicines',
    'Devices',
    'Health',
    'Vitamins',
    'Baby Care',
    'Personal Care',
  ];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingBanner != null) {
      final banner = widget.existingBanner!;
      _titleController.text = banner.title;
      _subtitleController.text = banner.subtitle;
      _selectedCategory = _categories.contains(banner.category)
          ? banner.category
          : _categories.first;
      _startDate = banner.startDate;
      _endDate = banner.endDate;
      _isActive = banner.active;
    } else {
      _selectedCategory = _categories.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Capture theme values before any async gap
    final primaryColor = Theme.of(context).primaryColor;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image == null) return;

      // Crop image to 16:9 banner ratio
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner Image',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: primaryColor,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Banner Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped != null && mounted) {
        setState(() {
          _selectedImageFile = XFile(cropped.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final colorScheme = Theme.of(context).colorScheme;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _publishBanner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImageFile == null && widget.existingBanner == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (widget.existingBanner != null) {
        await _bannerService.updateBannerDetails(
          bannerId: widget.existingBanner!.id,
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          imageFile: _selectedImageFile,
          supplierId: user.id,
          category: _selectedCategory ?? 'Medicines',
          startDate: _startDate,
          endDate: _endDate,
          active: _isActive,
          currentImageUrl: widget.existingBanner!.imageUrl,
        );
      } else {
        await _bannerService.createBanner(
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          imageFile: _selectedImageFile!,
          supplierId: user.id,
          category: _selectedCategory ?? 'Medicines',
          startDate: _startDate,
          endDate: _endDate,
          active: _isActive,
          supplierName: user.userMetadata?['business_name'],
        );
      }

      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingBanner != null
                  ? 'Banner updated successfully!'
                  : 'Banner published successfully!',
            ),
            backgroundColor: colorScheme.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.existingBanner != null ? 'Edit Banner' : 'Create Banner',
        ),
        actions: [
          if (_selectedImageFile != null || widget.existingBanner != null)
            TextButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.swap_horiz, color: colorScheme.primary),
              label: Text(
                'Change',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Upload Section
                    _buildImageUploadSection(colorScheme),
                    const SizedBox(height: 24),

                    // Title Input
                    _buildInputField(
                      controller: _titleController,
                      label: 'Offer Title',
                      hint: 'e.g., LOWEST PRICES ARE LIVE',
                      colorScheme: colorScheme,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Subtitle Input
                    _buildInputField(
                      controller: _subtitleController,
                      label: 'Subtitle / Discount',
                      hint: 'Up to 60% Off',
                      colorScheme: colorScheme,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a subtitle';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Category Selector
                    _buildCategorySelector(colorScheme),
                    const SizedBox(height: 20),

                    // Date Pickers
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Start Date',
                            date: _startDate,
                            colorScheme: colorScheme,
                            onTap: () => _selectDate(context, true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDatePicker(
                            label: 'End Date',
                            date: _endDate,
                            colorScheme: colorScheme,
                            onTap: () => _selectDate(context, false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Active Toggle
                    _buildActiveToggle(colorScheme),
                    const SizedBox(height: 32),

                    // Publish Button
                    _buildPublishButton(colorScheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageUploadSection(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: _selectedImageFile != null || widget.existingBanner != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selectedImageFile != null
                    ? (kIsWeb
                          ? Image.network(
                              _selectedImageFile!.path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colorScheme.surfaceContainerHighest,
                                );
                              },
                            )
                          : Image.file(
                              File(_selectedImageFile!.path),
                              fit: BoxFit.cover,
                            ))
                    : Image.network(
                        widget.existingBanner!.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Banner Image',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '16:9 ratio recommended · Tap to select',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ColorScheme colorScheme,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCategorySelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          dropdownColor: colorScheme.surface,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          icon: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
          items: _categories.map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime date,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveToggle(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _isActive ? 'Banner is visible to users' : 'Banner is hidden',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Switch(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeThumbColor: colorScheme.primary,
            activeTrackColor: colorScheme.primary.withValues(alpha: 0.3),
            inactiveThumbColor: colorScheme.onSurface.withValues(alpha: 0.4),
            inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: _isLoading ? null : _publishBanner,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: colorScheme.onPrimary,
                strokeWidth: 2,
              ),
            )
          : Text(
              widget.existingBanner != null ? 'Update Banner' : 'Publish Offer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
    );
  }
}
