import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class ProductRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch all products (Real-time stream or simple future)
  Future<List<Product>> getProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select(
            '*, suppliers(name, supplier_code, id), product_reviews(rating)',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false); // Newest first

      // --- DEBUG PRINT ---
      // This will show up in your "Run" tab. Check if it's empty [].
      debugPrint('📦 Supabase Raw Data: $response');

      // Convert the List<dynamic> from Supabase into List<Product>
      // We use the helper method from your product model (ensure it exists)
      return (response as List).map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      // Return empty list on error (or handle it better in production)
      debugPrint('❌ Error fetching products: $e');
      return [];
    }
  }

  // --- NEW: Fetch products for a specific Supplier ---
  Future<List<Product>> getSupplierProducts(String supplierCode) async {
    try {
      final response = await _supabase
          .from('products')
          .select(
            '*, suppliers(name, supplier_code, id), product_reviews(rating)',
          )
          .eq('supplier_code', supplierCode) // Filter by supplier
          .order('created_at', ascending: false);

      return (response as List).map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching supplier products: $e');
      return [];
    }
  }

  // --- Delete a product and its storage image ---
  Future<void> deleteProduct(String productId) async {
    try {
      // 1. Fetch the product's image_url before deleting
      final product = await _supabase
          .from('products')
          .select('image_url')
          .eq('id', productId)
          .maybeSingle();

      // 2. Delete the image from storage if it exists
      final imageUrl = product?['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(imageUrl);
          final segments = uri.pathSegments;
          const bucket = 'product-images';
          final bucketIndex = segments.indexOf(bucket);
          if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
            final filePath = segments.sublist(bucketIndex + 1).join('/');
            await _supabase.storage.from(bucket).remove([filePath]);
          }
        } catch (storageError) {
          // Log but don't block the DB delete
          debugPrint(
            '⚠️ Could not delete product image from storage: $storageError',
          );
        }
      }

      // 3. Delete the product record
      await _supabase.from('products').delete().eq('id', productId);
    } catch (e) {
      debugPrint('❌ Error deleting product: $e');
      rethrow;
    }
  }
}
