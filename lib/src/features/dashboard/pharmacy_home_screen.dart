import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:med_shakthi/src/features/category/category_ui.dart';
import 'package:med_shakthi/src/features/category/category_products_page.dart';
import 'package:med_shakthi/src/features/search/presentation/screens/global_search_page.dart';

import 'package:med_shakthi/src/features/products/data/repositories/product_repository.dart';
import 'package:med_shakthi/src/features/wishlist/presentation/screens/wishlist_page.dart';
import 'package:med_shakthi/src/features/wishlist/data/wishlist_service.dart';

import 'package:med_shakthi/src/features/cart/presentation/screens/cart_page.dart';
import 'package:med_shakthi/src/features/orders/orders_page.dart';
import 'package:med_shakthi/src/features/products/presentation/screens/product_page.dart';
import 'package:provider/provider.dart';

import '../profile/presentation/screens/ai_assistant_page.dart';
import '../profile/presentation/screens/profile_screen.dart';
import 'package:med_shakthi/src/features/cart/data/cart_data.dart';
import 'package:med_shakthi/src/features/cart/data/cart_item.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:med_shakthi/src/features/banners/widgets/banner_carousel.dart';
import 'package:med_shakthi/src/features/banners/widgets/static_pharmacy_banners.dart';
import '../profile/presentation/screens/qr_scanner_page.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';

/// This screen implements the "Med Shakti home page" for Retailers
class PharmacyHomeScreen extends StatefulWidget {
  const PharmacyHomeScreen({super.key});

  @override
  State<PharmacyHomeScreen> createState() => _PharmacyHomeScreenState();
}

class _PharmacyHomeScreenState extends State<PharmacyHomeScreen> {
  // State allows us to track dynamic changes, like the selected tab in the navigation bar.
  int _selectedIndex = 0;
  final ProductRepository _productRepo = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch user wishlist on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistService>().fetchWishlist();
    });
  }

  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6AA39B), Color(0xFF4C8077)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6AA39B).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Leaving so soon?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your medicines and health essentials will\nbe waiting for you!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF6AA39B)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Stay',
                            style: TextStyle(
                              color: Color(0xFF6AA39B),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF6AA39B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // If not on home tab, navigate back to home first
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        final shouldExit = await _showExitDialog();
        if (shouldExit && mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeContent(),
            const CategoryPageNew(),
            const WishlistPage(),
            const OrdersPage(),
            const AccountPage(),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiAssistantPage()),
            );
          },
          backgroundColor: const Color(0xFF5A9CA0),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildTopBar(),
            // Top Bar
            const SizedBox(height: 24),
            // Banner Carousel from Supabase
            BannerCarousel(
              fallbackWidget: const StaticPharmacyBanners(),
              onBannerTap: (category) {
                if (category.toLowerCase() == "medicines") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const CategoryProductsPage(categoryName: "Medicines"),
                    ),
                  );
                } else if (category.toLowerCase() == "lab test") {
                  // Navigate to Lab Tests (placeholder if not exists)
                  showCustomSnackBar(context, "Lab Tests coming soon");
                } else if (category.toLowerCase() == "upload rx") {
                  // Navigate to Upload Prescription (placeholder)
                  showCustomSnackBar(context, "Upload Rx coming soon");
                } else {
                  // Default fallback
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CategoryProductsPage(categoryName: category),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Categories", "See All", () {
              setState(() => _selectedIndex = 1);
            }),
            const SizedBox(height: 16),
            _buildCategoriesList(),
            const SizedBox(height: 24),
            _buildSectionTitle("Bestseller Products", "See All", () {}),
            const SizedBox(height: 16),
            // Shows Real Data from Supabase
            _buildRealBestsellersList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  /// Builds the top bar containing the Search bar and Cart button.
  Widget _buildTopBar() {
    return Row(
      children: [
        //  SEARCH BAR
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 8),

                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GlobalSearchPage(),
                        ),
                      );
                    },
                    child: Container(
                      color: Colors.transparent, // Hit test
                      child: IgnorePointer(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search medicine...",
                            hintStyle: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                //  CAMERA CLICKABLE
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QRScannerPage()),
                    );
                  },
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Theme.of(context).iconTheme.color,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        //  CART ICON WITH BADGE
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
              },
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: Theme.of(context).iconTheme.color,
                  size: 24,
                ),
              ),
            ),

            //  CART BADGE
            Consumer<CartData>(
              builder: (context, cartData, child) {
                if (cartData.items.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartData.items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Reusable section title with "See All" button
  Widget _buildSectionTitle(
    String title,
    String actionText,
    VoidCallback onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Text(
            actionText,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5A9CA0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the horizontal list of circular categories
  Widget _buildCategoriesList() {
    return SizedBox(
      height: 110, // Increased from 100
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Placeholder for categories, you can map real data here later
          _buildCategoryItem(Icons.medication, "Medicines", Colors.blue[100]!),
          const SizedBox(width: 20),
          _buildCategoryItem(
            Icons.medical_services,
            "Devices",
            Colors.purple[100]!,
          ),
          const SizedBox(width: 20),
          _buildCategoryItem(Icons.favorite, "Health", Colors.red[100]!),
          const SizedBox(width: 20),
          _buildCategoryItem(Icons.wb_sunny, "Vitamins", Colors.orange[100]!),
          const SizedBox(width: 20),
          _buildCategoryItem(Icons.spa, "Care", Colors.green[100]!),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        // Navigate to CategoryProductsPage when Medicines is tapped
        if (label == "Medicines" ||
            label == "Health" ||
            label == "Vitamins" ||
            label == "Care") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryProductsPage(categoryName: label),
            ),
          );
        } else if (label == "Devices") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const CategoryProductsPage(categoryName: "Devices"),
            ),
          );
        }
        // You can add navigation for other categories here as well
      },
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: Theme.of(context).iconTheme.color,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches Real Products from Supabase
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductPage(product: product)),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: SmartProductImage(
                  imageUrl: product.image,
                  category: product.category,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              product.category,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  product.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  // Prevent price overflow
                  child: Text(
                    "₹${product.price.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                InkWell(
                  onTap: () {
                    final cartItem = CartItem(
                      id: product.id,
                      name: product.name,
                      title: product.name,
                      brand: product.category,
                      size: "Standard",
                      price: product.price,
                      imagePath: product.image,
                      imageUrl: product.image,
                    );
                    context.read<CartData>().addItem(cartItem);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartPage()),
                    );
                    showCustomSnackBar(context, "Item added to cart");
                  },
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5A9CA0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fetches Real Products from Supabase
  Widget _buildRealBestsellersList() {
    return SizedBox(
      height: 280, // Increased from 260 for safety
      child: FutureBuilder<List<Product>>(
        future: _productRepo.getProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No products available"));
          }

          final allProducts = snapshot.data!;
          final products = allProducts;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildProductCard(product);
            },
          );
        },
      ),
    );
  }

  /// Custom Bottom Navigation Bar
  Widget _buildBottomNavigationBar() {
    final navItems = [
      {'icon': Icons.home, 'label': 'Home'},
      {'icon': Icons.grid_view, 'label': 'Category'},
      {'icon': Icons.favorite_border, 'label': 'Wishlist'},
      {'icon': Icons.receipt_long, 'label': 'Orders'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              return _buildNavItem(
                item['icon'] as IconData,
                item['label'] as String,
                index,
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 3) {
          //  Orders Page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrdersPage()),
          );
        } else if (index == 4) {
          // Profile Page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountPage()),
          );
        } else {
          // Home / Category / Wishlist
          setState(() => _selectedIndex = index);
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF5A9CA0) : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF5A9CA0) : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PromoBannerSlider extends StatefulWidget {
  const PromoBannerSlider({super.key});

  @override
  State<PromoBannerSlider> createState() => _PromoBannerSliderState();
}

class _PromoBannerSliderState extends State<PromoBannerSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _banners = [
    {
      "title": "PAYDAY SALE",
      "subtitle": "LOWEST PRICES ARE LIVE",
      "description": "Up to 60% Off",
      "colors": [Color(0xFF5A9CA0), Color(0xFF3A6B6E)],
      "icon": Icons.shopping_bag_outlined,
    },
    {
      "title": "SUPER DEAL",
      "subtitle": "FLAT 25% OFF ON MEDICINES",
      "description": "Use code: MED25",
      "colors": [Color(0xFF1E88E5), Color(0xFF1565C0)],
      "icon": Icons.local_offer_outlined,
    },
    {
      "title": "HEALTH CHECKUP",
      "subtitle": "FULL BODY SCREENING",
      "description": "Book Now & Save ₹500",
      "colors": [Color(0xFFE53935), Color(0xFFC62828)],
      "icon": Icons.health_and_safety_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: banner["colors"],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: banner["colors"][0].withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              banner["title"],
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            banner["subtitle"],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            banner["description"],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      banner["icon"],
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 80,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentPage == index
                    ? const Color(0xFF5A9CA0)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A stateful widget that fetches the most recent order.
/// If no order is found, it displays the PROMO BANNER (from screenshot).
class RecentPurchaseCard extends StatefulWidget {
  const RecentPurchaseCard({super.key});

  @override
  State<RecentPurchaseCard> createState() => _RecentPurchaseCardState();
}

class _RecentPurchaseCardState extends State<RecentPurchaseCard> {
  Map<String, dynamic>? recentOrder;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentOrder();
  }

  Future<void> _fetchRecentOrder() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('orders') // Ensure this matches your Supabase table name
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      setState(() {
        recentOrder = response;
        isLoading = false;
      });
    } catch (e) {
      // Handle errors (e.g., table doesn't exist yet)
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _loadingUI();
    }

    if (recentOrder == null) {
      return _noOrderUI(); // This now shows the Promo Banner design
    }

    return _orderUI();
  }

  // ---------------- UI STATES ----------------

  Widget _loadingUI() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey[200],
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Displays the Promo Banner when there are no recent purchases.
  /// Matches the visual style of the teammate's screenshot.
  Widget _noOrderUI() {
    return Container(
      width: double.infinity,
      height: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A9CA0), Color(0xFF3A6B6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A9CA0).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          "No Recent Purchase",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Displays the actual Recent Purchase details if an order exists.
  Widget _orderUI() {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A9CA0), Color(0xFF3A6B6E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Recent Purchase",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Order ID: ${recentOrder!['id']}",
            style: const TextStyle(color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "Items: ${recentOrder!['total_items'] ?? 0}",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "Status: ${recentOrder!['status'] ?? 'Pending'}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
