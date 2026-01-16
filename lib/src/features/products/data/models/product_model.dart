class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double rating;
  final String image;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.image,
  });

  // --- ADDED THIS METHOD ---
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'General',
      // FIX: Handle both String ("200.00") and Number (200.00) formats
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      // Default rating to 0.0 if null or missing
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      // Map 'image_url' from database to 'image' in app
      image: json['image_url'] ?? '',
    );
  }
}