class Product {
  final String id; //  uuid string
  final String name;
  final String category;
  final double price;
  final double rating;
  final String image;
  final String? description;

  // Supplier information
  final String? supplierName;
  final String? supplierCode;
  final String? supplierId;

  // Extra fields needed for edit mode
  final String? genericName;
  final String? brand;
  final String? sku;
  final String? unitSize;
  final String? expiryDate;
  final String? subCategory;
  final String? customCategory;
  final String? customSubCategory;

  // Stock Management (Phase 4)
  final int stockQuantity;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.image,
    this.description,
    this.supplierName,
    this.supplierCode,
    this.supplierId,
    this.genericName,
    this.brand,
    this.sku,
    this.unitSize,
    this.expiryDate,
    this.subCategory,
    this.customCategory,
    this.customSubCategory,
    this.stockQuantity = 0,
    this.isActive = true,
  });

  // Supabase Map -> Product
  factory Product.fromMap(Map<String, dynamic> map) {
    // Handle nested supplier data from join
    final supplierData = map['suppliers'] as Map<String, dynamic>?;

    // Calculate average rating from nested product_reviews if available
    final reviews = map['product_reviews'] as List<dynamic>?;
    double calculatedRating = 0.0;
    if (reviews != null && reviews.isNotEmpty) {
      final total = reviews.fold(
        0.0,
        (sum, item) => sum + ((item['rating'] as num?)?.toDouble() ?? 0.0),
      );
      calculatedRating = total / reviews.length;
    } else {
      calculatedRating = (map['rating'] as num?)?.toDouble() ?? 0.0;
    }

    return Product(
      id: map['id'].toString(), //  UUID safe
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      rating: calculatedRating,
      image: map['image_url'] ?? '',
      description: map['description'] as String?,
      supplierName: supplierData?['name'] as String?,
      supplierCode: supplierData?['supplier_code'] as String?,
      supplierId: supplierData?['id'] as String?,
      genericName: map['generic_name'] as String?,
      brand: map['brand'] as String?,
      sku: map['sku'] as String?,
      unitSize: map['unit_size'] as String?,
      expiryDate: map['expiry_date']?.toString(),
      subCategory: map['sub_category'] as String?,
      customCategory: map['custom_category'] as String?,
      customSubCategory: map['custom_sub_category'] as String?,
      stockQuantity: map['stock_quantity'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  // Alias for fromMap to support standard JSON decoding
  factory Product.fromJson(Map<String, dynamic> json) => Product.fromMap(json);

  //  Product -> Map for passing to edit page (all DB fields)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'rating': rating,
      'image_url': image,
      'description': description,
      'generic_name': genericName,
      'brand': brand,
      'sku': sku,
      'unit_size': unitSize,
      'expiry_date': expiryDate,
      'sub_category': subCategory,
      'custom_category': customCategory,
      'custom_sub_category': customSubCategory,
      'supplier_code': supplierCode,
      'stock_quantity': stockQuantity,
      'is_active': isActive,
    };
  }
}
