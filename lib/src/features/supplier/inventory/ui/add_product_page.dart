import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductPage extends StatefulWidget {
  final Map<String, dynamic>? product; // If null, it's Add mode

  const AddProductPage({super.key, this.product});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  bool get isEditing => widget.product != null;

  final nameController = TextEditingController();
  final genericController = TextEditingController();
  final brandController = TextEditingController();
  final skuController = TextEditingController();
  final priceController = TextEditingController();
  final unitSizeController = TextEditingController();
  final supplierIdController = TextEditingController(text: 'Loading...');
  final expiryController = TextEditingController();
  final descriptionController = TextEditingController();
  final stockController = TextEditingController(text: '0');

  /// CATEGORY + SUBCATEGORY
  final customCategoryController = TextEditingController();
  final customSubCategoryController = TextEditingController();

  /// CATEGORY + SUBCATEGORY
  String category = 'Medicines';
  String subCategory = 'Tablets';

  final Map<String, List<String>> categoryMap = {
    'Medicines': ['Tablets', 'Syrups', 'Capsules', 'Injections', 'Pain Relief'],
    'Supplements': [
      'Protein',
      'Vitamins',
      'Omega 3',
      'Weight Gain',
      'Immunity',
    ],
    'Personal care': ['Skin care', 'Hair care', 'Body care', 'Cosmetics'],
    'Baby care': ['Diapers', 'Baby Food', 'Baby Lotion', 'Baby Soap'],
    'Devices': ['BP Monitor', 'Thermometer', 'Glucometer', 'Nebulizer'],
    'Other (Custom)': [],
  };

  CroppedFile? croppedFile;
  String? existingImageUrl;
  String? supplierCode;
  String? supplierId;
  bool _isLoading = false;
  String _loadingStatus = '';
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    fetchSupplierCode();
    if (isEditing) _initializeEditMode();
  }

  @override
  void dispose() {
    nameController.dispose();
    genericController.dispose();
    brandController.dispose();
    skuController.dispose();
    priceController.dispose();
    unitSizeController.dispose();
    supplierIdController.dispose();
    expiryController.dispose();
    customCategoryController.dispose();
    customSubCategoryController.dispose();
    stockController.dispose();
    super.dispose();
  }

  void _initializeEditMode() {
    final p = widget.product!;
    nameController.text = p['name'] ?? '';
    genericController.text = p['generic_name'] ?? '';
    brandController.text = p['brand'] ?? '';
    skuController.text = p['sku'] ?? '';
    priceController.text = p['price']?.toString() ?? '';
    unitSizeController.text = p['unit_size'] ?? '';
    expiryController.text = p['expiry_date'] ?? '';
    descriptionController.text = p['description'] ?? '';
    stockController.text = p['stock_quantity']?.toString() ?? '0';
    isActive = p['is_active'] ?? true;

    // Set drop-downs if valid
    final cat = p['category'];
    if (cat != null) {
      if (cat == 'other') {
        category = 'Other (Custom)';
        customCategoryController.text = p['custom_category'] ?? '';
        customSubCategoryController.text = p['custom_sub_category'] ?? '';
      } else if (categoryMap.containsKey(cat)) {
        category = cat;
        final sub = p['sub_category'];
        if (categoryMap[category]!.contains(sub)) {
          subCategory = sub;
        } else {
          subCategory = categoryMap[category]!.first;
        }
      }
    }

    existingImageUrl = p['image_url'];
  }

  Future<void> fetchSupplierCode() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('suppliers')
          .select('id, supplier_code')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          supplierId = data?['id'];
          supplierCode = data?['supplier_code'];
          supplierIdController.text = supplierCode ?? 'Unknown';
        });
      }
    } catch (e) {
      debugPrint('Error fetching supplier code: $e');
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Product Image',
          toolbarColor: const Color(0xFF4CA6A8),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF4CA6A8),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Product Image'),
      ],
    );
    if (cropped != null) {
      setState(() => croppedFile = cropped);
    }
  }

  /// Compresses and resizes image bytes before uploading.
  /// Targets max 1024px on the longer side, 80% JPEG quality.
  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 512,
      minHeight: 512,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    debugPrint(
      '📸 Compressed: ${bytes.length} → ${result.length} bytes '
      '(${((1 - result.length / bytes.length) * 100).toStringAsFixed(1)}% saved)',
    );
    return result;
  }

  /// Uses uploadBinary (reads bytes first) — same proven approach as banner service.
  /// Passing a File object with a CroppedFile path can silently fail on Android.
  Future<String?> uploadImage() async {
    if (croppedFile == null) return null;

    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    debugPrint('📸 Starting image upload: $fileName');
    debugPrint('📸 Cropped file path: ${croppedFile!.path}');

    final rawBytes = await croppedFile!.readAsBytes();
    debugPrint('📸 Original file size: ${rawBytes.length} bytes');

    // Compress before uploading
    final bytes = await _compressImage(rawBytes);
    debugPrint('📸 Upload size: ${bytes.length} bytes');

    await supabase.storage
        .from('product-images')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final url = supabase.storage.from('product-images').getPublicUrl(fileName);
    debugPrint('✅ Upload successful. Public URL: $url');
    return url;
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingStatus = croppedFile != null
          ? 'Uploading image...'
          : 'Saving product...';
    });

    try {
      // Upload image first so we surface failures before writing to DB
      final String? imageUrl;
      if (croppedFile != null) {
        imageUrl = await uploadImage();
        if (mounted) setState(() => _loadingStatus = 'Saving product...');
      } else {
        imageUrl = existingImageUrl;
      }

      final bool isCustom = category == 'Other (Custom)';

      final data = {
        'name': nameController.text.trim(),
        'generic_name': genericController.text.trim(),
        'brand': brandController.text.trim(),
        'sku': skuController.text.trim(),
        'price': double.parse(priceController.text),
        'unit_size': unitSizeController.text.trim(),
        'expiry_date': expiryController.text,
        'category': isCustom ? 'other' : category,
        'sub_category': isCustom ? null : subCategory,
        'custom_category': isCustom
            ? customCategoryController.text.trim()
            : null,
        'custom_sub_category':
            isCustom && customSubCategoryController.text.isNotEmpty
            ? customSubCategoryController.text.trim()
            : null,
        'supplier_code': supplierCode,
        'supplier_id': supplierId,
        'image_url': imageUrl,
        'description': descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        'stock_quantity': int.tryParse(stockController.text) ?? 0,
        'is_active': isActive,
      };

      if (isEditing) {
        final res = await supabase
            .from('products')
            .update(data)
            .eq('id', widget.product!['id'])
            .select();

        debugPrint('UPDATE DB RES: $res');
        if ((res as List).isEmpty) {
          throw Exception(
            'Database update failed. No rows modified (it may have been deleted, or there is an RLS permissions issue).',
          );
        }
      } else {
        await supabase.from('products').insert(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Product Updated!' : 'Product Added!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save product error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      expiryController.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Product' : 'Add New Product',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.foregroundColor,
        ),
      ),
      body: Stack(
        children: [
          // ── Form ──────────────────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _imagePicker(),
                  _input("Product Name", nameController),
                  _input("Generic Name", genericController),
                  _input("Brand", brandController),
                  Row(
                    children: [
                      Expanded(child: _input("SKU", skuController)),
                      const SizedBox(width: 10),
                      Expanded(child: _input("Unit Size", unitSizeController)),
                    ],
                  ),
                  _input(
                    "Price",
                    priceController,
                    keyboard: TextInputType.number,
                  ),
                  _input(
                    "Stock Quantity",
                    stockController,
                    keyboard: TextInputType.number,
                  ),
                  _supplierIdField(),
                  _expiryField(),
                  _categoryDropdown(),
                  if (category != 'Other (Custom)') _subCategoryDropdown(),
                  if (category == 'Other (Custom)') ...[
                    _input("Custom Category", customCategoryController),
                    _input(
                      "Custom Sub Category (optional)",
                      customSubCategoryController,
                    ),
                  ],
                  _descriptionField(),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text("Product is Active / Visible"),
                    subtitle: const Text(
                      "Turn off to hide this product from customers",
                      style: TextStyle(fontSize: 12),
                    ),
                    value: isActive,
                    activeThumbColor: const Color(0xFF4CA6A8),
                    onChanged: (val) => setState(() => isActive = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 20),
                  _submitButton(),
                ],
              ),
            ),
          ),

          // ── Upload / Save overlay ──────────────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF4CA6A8),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _loadingStatus,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please wait…',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _supplierIdField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: supplierIdController,
        readOnly: true,
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
        ),
        decoration: _inputDecoration("Supplier ID"),
      ),
    );
  }

  Widget _expiryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: expiryController,
        readOnly: true,
        onTap: pickExpiryDate,
        validator: (v) => v!.isEmpty ? 'Select expiry date' : null,
        decoration: _inputDecoration(
          "Expiry Date",
        ).copyWith(suffixIcon: const Icon(Icons.calendar_today)),
      ),
    );
  }

  Widget _categoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey(category),
        initialValue: category,
        decoration: _inputDecoration("Category"),
        items: categoryMap.keys
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          setState(() {
            category = v!;
            if (category != 'Other (Custom)' &&
                categoryMap[category]!.isNotEmpty) {
              subCategory = categoryMap[category]!.first;
            }
          });
        },
      ),
    );
  }

  Widget _subCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey(subCategory),
        initialValue: subCategory,
        decoration: _inputDecoration("Sub Category"),
        items: categoryMap[category]!
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => subCategory = v!),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CA6A8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: _isLoading ? null : saveProduct,
        child: const Text(
          'Save Product',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _imagePicker() {
    return GestureDetector(
      onTap: pickImage,
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: croppedFile != null
            // Newly picked & cropped image
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(croppedFile!.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            : existingImageUrl != null
            // Existing image from DB (edit mode)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  existingImageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stack) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
              )
            // No image yet
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Tap to add product image',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(
          context,
        ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _descriptionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: descriptionController,
        maxLines: 4,
        keyboardType: TextInputType.multiline,
        decoration: _inputDecoration(
          'Description (optional)',
        ).copyWith(alignLabelWithHint: true),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: (v) => v!.isEmpty ? 'Required' : null,
        decoration: _inputDecoration(label),
      ),
    );
  }
}
