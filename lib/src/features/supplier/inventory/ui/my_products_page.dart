import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_product_page.dart';

import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'supplier_product_details_page.dart';

class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage> {
  final supabase = Supabase.instance.client;

  Future<void> _deleteProduct(String productId) async {
    try {
      await supabase.from('products').delete().eq('id', productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product deleted successfully")),
        );
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting product: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          "My Products",
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<String?>(
        // 1. First fetch the supplier code for the current user
        future: _fetchSupplierCode(),
        builder: (context, supplierCodeSnapshot) {
          if (supplierCodeSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final supplierCode = supplierCodeSnapshot.data;

          if (supplierCode == null) {
            return const Center(
              child: Text("Could not identify supplier account."),
            );
          }

          // 2. Then fetch products for this supplier
          return FutureBuilder<List<dynamic>>(
            future: supabase
                .from('products')
                .select()
                .eq('supplier_code', supplierCode) // FILTER BY SUPPLIER CODE
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final products = snapshot.data ?? [];

              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "You haven't added any products yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddProductPage(),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        child: const Text("Add Your First Product"),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = products[index];
                  return _buildProductCard(p);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String?> _fetchSupplierCode() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await supabase
          .from('suppliers')
          .select('supplier_code')
          .eq('user_id', user.id)
          .maybeSingle();
      return data?['supplier_code'];
    } catch (e) {
      debugPrint("Error fetching supplier code: $e");
      return null;
    }
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final imageUrl = p['image_url'];
    final productName = p['name'] ?? "Unnamed Product";
    final category = p['category'] ?? "No Category";
    final price = p['price']?.toString() ?? "0.00";

    return InkWell(
      onTap: () {
        final productModel = Product.fromMap(p);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierProductDetailsPage(product: productModel),
          ),
        ).then((deleted) {
          if (deleted == true) {
            setState(() {});
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 70,
                width: 70,
                child: SmartProductImage(
                  imageUrl: imageUrl,
                  category: p['sub_category'] ?? p['category'] ?? '',
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹$price",
                    style: const TextStyle(
                      color: Color(0xFF4CA6A8),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddProductPage(product: p),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Delete Product"),
                        content: const Text(
                          "Are you sure you want to delete this product?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _deleteProduct(p['id']);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
