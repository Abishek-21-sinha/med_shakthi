import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'add_product_page.dart';

class SupplierProductDetailsPage extends StatefulWidget {
  final Product product;

  const SupplierProductDetailsPage({super.key, required this.product});

  @override
  State<SupplierProductDetailsPage> createState() =>
      _SupplierProductDetailsPageState();
}

class _SupplierProductDetailsPageState
    extends State<SupplierProductDetailsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final supplier = await supabase
          .from('suppliers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted && supplier != null) {
        setState(() {
          _isOwner = widget.product.supplierId == supplier['id'];
        });
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product"),
        content: const Text("Are you sure you want to delete this product?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('products').delete().eq('id', widget.product.id);
      if (mounted) {
        showCustomSnackBar(context, "Product deleted successfully");
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.code == '23503') {
          showCustomSnackBar(
            context,
            "Cannot delete product: It is already part of an existing order.",
            isError: true,
          );
        } else {
          showCustomSnackBar(
            context,
            "Database error: ${e.message}",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          "Error deleting product: $e",
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEdit() async {
    final productMap = widget.product.toMap();
    productMap['image_url'] = widget.product.image;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProductPage(product: productMap)),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onEdit: _navigateToEdit,
              onDelete: _deleteProduct,
              isOwner: _isOwner,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ProductImageCard(product: widget.product),
                    const SizedBox(height: 16),
                    _ProductInfoSection(product: widget.product),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isOwner
          ? _BottomAction(onEdit: _navigateToEdit)
          : null,
    );
  }
}

/* ---------------- TOP BAR ---------------- */

class _TopBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isOwner;

  const _TopBar({
    required this.onEdit,
    required this.onDelete,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 16),
            ),
          ),
          const Spacer(),
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ] else ...[
            Icon(Icons.share, color: Theme.of(context).iconTheme.color),
          ],
        ],
      ),
    );
  }
}

/* ---------------- IMAGE CARD ---------------- */

class _ProductImageCard extends StatelessWidget {
  final Product product;

  const _ProductImageCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SmartProductImage(
        imageUrl: product.image,
        category: product.category,
        height: 230,
        fit: BoxFit.contain,
        borderRadius: 0,
      ),
    );
  }
}

/* ---------------- PRODUCT INFO ---------------- */

class _ProductInfoSection extends StatelessWidget {
  final Product product;

  const _ProductInfoSection({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            product.category,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text("${product.rating}"),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "₹${product.price}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!product.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "HIDDEN",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (product.stockQuantity <= 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "OUT OF STOCK",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                )
              else
                Text(
                  "Stock Available: ${product.stockQuantity}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Product Description",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            "No description available.", // Placeholder
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/* ---------------- BOTTOM ACTION ---------------- */

class _BottomAction extends StatelessWidget {
  final VoidCallback onEdit;

  const _BottomAction({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ElevatedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit),
        label: const Text("Edit Product"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
