import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/supplier/inventory/ui/add_product_page.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:med_shakthi/src/features/supplier/inventory/ui/supplier_product_details_page.dart';

class SupplierCategoryPage extends StatefulWidget {
  const SupplierCategoryPage({super.key});

  @override
  State<SupplierCategoryPage> createState() => _SupplierCategoryPageState();
}

class _SupplierCategoryPageState extends State<SupplierCategoryPage> {
  final Color themeColor = const Color(0xFF6AA39B);
  final SupabaseClient supabase = Supabase.instance.client;

  int selectedCategoryIndex = 0;
  bool sidebarVisible = true;

  String? selectedSubCategory;
  bool loadingProducts = false;
  bool loadingCustomCats = false;

  List<Map<String, dynamic>> products = [];
  List<String> customCategories = [];

  /// 🔹 STATIC CATEGORIES (unchanged UI)
  final List<Map<String, dynamic>> baseCategories = [
    {
      "name": "Medicines",
      "icon": Icons.medication_rounded,
      "items": ["Tablets", "Syrups", "Capsules", "Injections", "Pain Relief"],
    },
    {
      "name": "Supplements",
      "icon": Icons.healing_rounded,
      "items": ["Protein", "Vitamins", "Omega 3", "Weight Gain", "Immunity"],
    },
    {
      "name": "Personal Care",
      "icon": Icons.face_retouching_natural_rounded,
      "items": ["Skin Care", "Hair Care", "Body Care", "Cosmetics"],
    },
    {
      "name": "Baby Care",
      "icon": Icons.child_care_rounded,
      "items": ["Diapers", "Baby Food", "Baby Lotion", "Baby Soap"],
    },
    {
      "name": "Devices",
      "icon": Icons.medical_services_rounded,
      "items": ["BP Monitor", "Thermometer", "Glucometer", "Nebulizer"],
    },
  ];

  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    fetchCustomCategories();
  }

  /// 🔥 FETCH CUSTOM CATEGORIES FOR "OTHER"
  Future<void> fetchCustomCategories() async {
    setState(() => loadingCustomCats = true);

    final response = await supabase
        .from('products')
        .select('custom_category')
        .eq('category', 'other')
        .not('custom_category', 'is', null);

    final set = <String>{};
    for (final row in response) {
      set.add(row['custom_category']);
    }

    setState(() {
      customCategories = set.toList();

      categories = [
        ...baseCategories,
        {
          "name": "Other",
          "icon": Icons.category_outlined,
          "items": customCategories,
        },
      ];

      loadingCustomCats = false;
    });
  }

  /// 🔥 FETCH PRODUCTS (NORMAL + OTHER) - SHOW ALL PRODUCTS
  Future<void> fetchProducts({
    required String category,
    required String subCategory,
  }) async {
    setState(() {
      loadingProducts = true;
      products.clear();
    });

    try {
      late final List response;

      if (category.toLowerCase() == 'other') {
        response = await supabase
            .from('products')
            .select('*, suppliers(name, supplier_code, id)')
            .eq('category', 'other')
            .eq('custom_category', subCategory)
            .limit(50);
      } else {
        response = await supabase
            .from('products')
            .select('*, suppliers(name, supplier_code, id)')
            .ilike('category', category)
            .ilike('sub_category', subCategory)
            .limit(50);
      }

      setState(() {
        products = List<Map<String, dynamic>>.from(response);
        loadingProducts = false;
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
      setState(() => loadingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadingCustomCats) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedCategory = categories[selectedCategoryIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
        title: Text(
          "Categories",
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
      ),
      body: Row(
        children: [
          /// 🔹 SIDEBAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: sidebarVisible ? 110 : 0,
            color: Theme.of(context).cardColor,
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = index == selectedCategoryIndex;

                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedCategoryIndex = index;
                      selectedSubCategory = null;
                      products.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? themeColor.withValues(alpha: 0.12)
                          : Theme.of(context).cardColor,
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? themeColor : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          cat["icon"],
                          color: isSelected ? themeColor : Colors.grey,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat["name"],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /// 🔹 CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedSubCategory == null
                        ? selectedCategory["name"]
                        : "${selectedCategory["name"]} → $selectedSubCategory",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: loadingProducts
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.builder(
                            itemCount: selectedSubCategory == null
                                ? (selectedCategory["items"] as List).length
                                : products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 1.2,
                                ),
                            itemBuilder: (context, i) {
                              if (selectedSubCategory == null) {
                                final itemName =
                                    (selectedCategory["items"] as List)[i];
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedSubCategory = itemName;
                                    });
                                    fetchProducts(
                                      category: selectedCategory["name"],
                                      subCategory: itemName,
                                    );
                                  },
                                  child: _buildTile(
                                    title: itemName,
                                    icon: getSubCategoryIcon(itemName),
                                  ),
                                );
                              } else {
                                final product = products[i];
                                return InkWell(
                                  onTap: () {
                                    // Navigate to ProductPage to VIEW product (not edit)
                                    // Convert Map to Product model
                                    final productModel = Product(
                                      id: product['id'],
                                      name: product['name'],
                                      image: product['image_url'] ?? '',
                                      price:
                                          (product['price'] as num?)
                                              ?.toDouble() ??
                                          0.0,
                                      category: product['category'] ?? '',
                                      rating:
                                          (product['rating'] as num?)
                                              ?.toDouble() ??
                                          0.0,
                                      supplierName:
                                          product['suppliers']?['name'],
                                      supplierCode:
                                          product['suppliers']?['supplier_code'],
                                      supplierId: product['supplier_id'],
                                    );

                                    // Navigate to SupplierProductDetailsPage to VIEW product
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SupplierProductDetailsPage(
                                              product: productModel,
                                            ),
                                      ),
                                    );
                                  },
                                  onLongPress: () {
                                    // Long press to edit
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddProductPage(product: product),
                                      ),
                                    );
                                  },
                                  child: _buildTile(
                                    title: product['name'],
                                    subtitle: "₹${product['price'] ?? '--'}",
                                    icon: getSubCategoryIcon(
                                      product['sub_category'] ?? "",
                                    ),
                                    imageUrl: product['image_url'],
                                  ),
                                );
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String title,
    String? subtitle,
    required IconData icon,
    String? imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(
        14,
      ), // Reduced padding if image is present? No, keep consistent.
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(icon, size: 30, color: themeColor);
                  },
                ),
              ),
            )
          else
            Icon(icon, size: 30, color: themeColor),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

IconData getSubCategoryIcon(String subCategory) {
  switch (subCategory) {
    // Medicines
    case "Tablets":
      return Icons.local_pharmacy;
    case "Syrups":
      return Icons.liquor;
    case "Capsules":
      return Icons.medication;
    case "Injections":
      return Icons.vaccines;
    case "Pain Relief":
      return Icons.healing;

    // Supplements
    case "Protein":
      return Icons.fitness_center;
    case "Vitamins":
      return Icons.local_pharmacy;
    case "Omega 3":
      return Icons.water_drop;
    case "Weight Gain":
      return Icons.monitor_weight;
    case "Immunity":
      return Icons.shield;

    // Personal Care
    case "Skin Care":
      return Icons.face;
    case "Hair Care":
      return Icons.content_cut;
    case "Body Care":
      return Icons.spa;
    case "Cosmetics":
      return Icons.brush;

    // Baby Care
    case "Diapers":
      return Icons.child_care;
    case "Baby Food":
      return Icons.rice_bowl;
    case "Baby Lotion":
      return Icons.clean_hands;
    case "Baby Soap":
      return Icons.soap;

    // Devices
    case "BP Monitor":
      return Icons.monitor_heart;
    case "Thermometer":
      return Icons.thermostat;
    case "Glucometer":
      return Icons.bloodtype;
    case "Nebulizer":
      return Icons.air;

    default:
      return Icons.category_outlined;
  }
}
