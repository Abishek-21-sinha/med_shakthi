import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model_supabase.dart';

/// Banner Service for Supabase
///
/// Handles all banner operations using Supabase PostgreSQL and Storage

class BannerServiceSupabase {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _bannersTable = 'banners';
  static const String _storageBucket = 'banner-images';

  // Create a new banner
  Future<String> createBanner({
    required String title,
    required String subtitle,
    required XFile imageFile,
    required String supplierId,
    required String category,
    required DateTime startDate,
    required DateTime endDate,
    required bool active,
    String? supplierName,
  }) async {
    try {
      // Upload image to Supabase Storage
      final imageUrl = await _uploadBannerImage(imageFile, supplierId);

      // Create banner record
      final bannerData = {
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'supplier_id': supplierId,
        'category': category,
        'active': active,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'supplier_name': supplierName,
      };

      final response = await _supabase
          .from(_bannersTable)
          .insert(bannerData)
          .select()
          .single();

      return response['id'].toString();
    } catch (e) {
      throw Exception('Failed to create banner: $e');
    }
  }

  // Upload banner image to Supabase Storage
  Future<String> _uploadBannerImage(XFile imageFile, String supplierId) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$supplierId.jpg';
      final filePath = '$supplierId/$fileName';

      // Read file as bytes for web compatibility
      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(filePath, bytes);

      final publicUrl = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Get active banners (real-time stream)
  Stream<List<SupabaseBannerModel>> getActiveBannersStream() {
    return _supabase.from(_bannersTable).stream(primaryKey: ['id']).map((data) {
      // RLS policy already filters by date (start_date <= NOW and end_date >= NOW)
      // We only need to check active status and sort
      return data
          .map((json) => SupabaseBannerModel.fromJson(json))
          .where((banner) => banner.active)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // Get banners by supplier (for supplier dashboard)
  Stream<List<SupabaseBannerModel>> getSupplierBannersStream(
    String supplierId,
  ) {
    return _supabase.from(_bannersTable).stream(primaryKey: ['id']).map((data) {
      // RLS policy already ensures suppliers only see their own banners
      return data.map((json) => SupabaseBannerModel.fromJson(json)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // Get active banners (one-time fetch)
  Future<List<SupabaseBannerModel>> getActiveBanners() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from(_bannersTable)
          .select()
          .eq('active', true)
          .lte('start_date', now)
          .gte('end_date', now)
          .order('end_date', ascending: true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupabaseBannerModel.fromJson(json))
          .where((banner) => banner.isValid)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch banners: $e');
    }
  }

  // Update banner with all details (including optional image)
  Future<void> updateBannerDetails({
    required String bannerId,
    required String title,
    required String subtitle,
    XFile? imageFile,
    required String category,
    required DateTime startDate,
    required DateTime endDate,
    required bool active,
    required String currentImageUrl,
    required String supplierId,
  }) async {
    try {
      String imageUrl = currentImageUrl;

      if (imageFile != null) {
        // Upload new image
        imageUrl = await _uploadBannerImage(imageFile, supplierId);
      }

      final updates = {
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'category': category,
        'active': active,
        'start_date': startDate.toUtc().toIso8601String(),
        'end_date': endDate.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await updateBanner(bannerId, updates);
    } catch (e) {
      throw Exception('Failed to update banner: $e');
    }
  }

  // Update banner
  Future<void> updateBanner(
    String bannerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase.from(_bannersTable).update(updates).eq('id', bannerId);
    } catch (e) {
      throw Exception('Failed to update banner: $e');
    }
  }

  // Toggle banner active status
  Future<void> toggleBannerStatus(String bannerId, bool active) async {
    try {
      await _supabase
          .from(_bannersTable)
          .update({'active': active})
          .eq('id', bannerId);
    } catch (e) {
      throw Exception('Failed to toggle banner status: $e');
    }
  }

  // Delete banner
  Future<void> deleteBanner(String bannerId, String imageUrl) async {
    try {
      // Extract file path from public URL
      if (imageUrl.isNotEmpty) {
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf(_storageBucket);
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

          // Delete image from storage
          await _supabase.storage.from(_storageBucket).remove([filePath]);
        }
      }

      // Delete banner record
      await _supabase.from(_bannersTable).delete().eq('id', bannerId);
    } catch (e) {
      throw Exception('Failed to delete banner: $e');
    }
  }

  // Auto-disable expired banners (run periodically via Edge Function or cron)
  Future<void> disableExpiredBanners() async {
    try {
      final now = DateTime.now().toIso8601String();

      await _supabase
          .from(_bannersTable)
          .update({'active': false})
          .eq('active', true)
          .lt('end_date', now);
    } catch (e) {
      throw Exception('Failed to disable expired banners: $e');
    }
  }

  // Get banners by category
  Stream<List<SupabaseBannerModel>> getBannersByCategory(String category) {
    return _supabase.from(_bannersTable).stream(primaryKey: ['id']).map((data) {
      final now = DateTime.now();
      return data
          .map((json) => SupabaseBannerModel.fromJson(json))
          .where(
            (banner) =>
                banner.category == category &&
                banner.active &&
                banner.startDate.isBefore(now) &&
                banner.endDate.isAfter(now),
          )
          .toList();
    });
  }

  // Get banner by ID
  Future<SupabaseBannerModel?> getBannerById(String bannerId) async {
    try {
      final response = await _supabase
          .from(_bannersTable)
          .select()
          .eq('id', bannerId)
          .single();

      return SupabaseBannerModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
