class OrderDetailModel {
  final String id;
  final String orderId;
  final String? productId; // Nullable as per legacy data or if product deleted
  final String itemName;
  final String brand;
  final String unitSize;
  final String imageUrl;
  final double price;
  final int qty;
  final DateTime createdAt;
  final String? supplierName;
  final String? supplierCode;
  final String? supplierId;
  final String? supplierEmail;
  final String? supplierPhone;
  final String? supplierCompany;
  final String? supplierAddress;
  final String? supplierDl;
  final String? supplierDlExpiry;
  final String? supplierGst;

  OrderDetailModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.itemName,
    required this.brand,
    required this.unitSize,
    required this.imageUrl,
    required this.price,
    required this.qty,
    required this.createdAt,
    this.supplierName,
    this.supplierCode,
    this.supplierId,
    this.supplierEmail,
    this.supplierPhone,
    this.supplierCompany,
    this.supplierAddress,
    this.supplierDl,
    this.supplierDlExpiry,
    this.supplierGst,
  });

  factory OrderDetailModel.fromMap(Map<String, dynamic> map) {
    // Handle join with products -> suppliers
    final product = map['products'] as Map<String, dynamic>?;
    final supplier = product?['suppliers'] as Map<String, dynamic>?;

    return OrderDetailModel(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      productId: map['product_id']?.toString(),
      itemName: map['item_name'] ?? '',
      brand: map['brand'] ?? '', // This might also be in product['brand']
      unitSize: map['unit_size'] ?? '',
      imageUrl: map['image_url'] ?? product?['image_url'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      qty: (map['quantity'] as int?) ?? 1,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      supplierName: supplier?['name'],
      supplierCode: supplier?['supplier_code'],
      supplierId: supplier?['id'],
      supplierEmail: supplier?['email'],
      supplierPhone: supplier?['phone'],
      supplierCompany: supplier?['company_name'],
      supplierAddress: supplier?['company_address'],
      supplierDl: supplier?['drug_license_number'],
      supplierDlExpiry: supplier?['drug_license_expiry'],
      supplierGst: supplier?['gst_number'],
    );
  }
}
