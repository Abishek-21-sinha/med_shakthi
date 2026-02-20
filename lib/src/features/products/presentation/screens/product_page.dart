import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../cart/data/cart_data.dart';
import '../../../cart/data/cart_item.dart';
import '../../../cart/presentation/screens/cart_page.dart';
import '../../data/models/product_model.dart';
import 'package:med_shakthi/src/features/wishlist/data/wishlist_service.dart';
import 'package:med_shakthi/src/features/wishlist/data/models/wishlist_item_model.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';

class ProductPage extends StatelessWidget {
  final Product product;

  const ProductPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🔧 FIX: pass product to TopBar
            _TopBar(product: product),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ProductImageCard(product: product),
                    const SizedBox(height: 16),
                    _ProductInfoSection(product: product),
                    const SizedBox(height: 16),
                    const _SelectPharmacyCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(product: product),
    );
  }
}

/* ---------------- TOP BAR ---------------- */

class _TopBar extends StatefulWidget {
  final Product product;

  const _TopBar({required this.product});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool isSupplier = false;
  bool isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final supplier = await Supabase.instance.client
          .from('suppliers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          isSupplier = supplier != null;
          isLoadingRole = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isLoadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes to update the heart icon
    final wishlistService = context.watch<WishlistService>();
    final bool isWishlisted = wishlistService.isInWishlist(widget.product.id);

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

          // ❤️ Show wishlist ONLY if NOT a supplier and finished loading role
          if (!isLoadingRole && !isSupplier)
            InkWell(
              onTap: () {
                if (isWishlisted) {
                  context.read<WishlistService>().removeFromWishlist(
                    widget.product.id,
                  );
                } else {
                  context.read<WishlistService>().addToWishlist(
                    WishlistItem(
                      id: widget.product.id,
                      name: widget.product.name,
                      price: widget.product.price,
                      image: widget.product.image,
                    ),
                  );
                }
              },
              child: Icon(
                isWishlisted ? Icons.favorite : Icons.favorite_border,
                color: isWishlisted ? Colors.red : Colors.grey,
              ),
            ),

          if (!isLoadingRole && !isSupplier) const SizedBox(width: 12),

          Icon(Icons.share, color: Theme.of(context).iconTheme.color),
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
        category: product.category, // Pass category for fallback logic
        height: 230,
        fit: BoxFit.contain,
        borderRadius: 0, // Container already has radius
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
          // Supplier Info
          if (product.supplierName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Sold by: ${product.supplierName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (product.supplierCode != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.supplierCode!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
        ],
      ),
    );
  }
}

/* ---------------- PHARMACY CARD ---------------- */

class _SelectPharmacyCard extends StatelessWidget {
  const _SelectPharmacyCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: const [
            Icon(Icons.local_pharmacy, size: 40, color: Colors.red),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Walgreens Pharmacy\nFree delivery • 12 min',
                style: TextStyle(fontSize: 14),
              ),
            ),
            Text('₹18.99', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/* ---------------- BOTTOM BAR ---------------- */

class _BottomBar extends StatefulWidget {
  final Product product;

  const _BottomBar({required this.product});

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool isSupplier = false;
  bool isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Check if user is in 'suppliers' table
      final supplier = await Supabase.instance.client
          .from('suppliers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          isSupplier = supplier != null;
          isLoadingRole = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isLoadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingRole || isSupplier) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              debugPrint("Product ID: ${widget.product.id}");

              context.read<CartData>().addItem(
                CartItem(
                  id: widget.product.id,
                  name: widget.product.name,
                  title: widget.product.name,
                  brand: widget.product.category,
                  size: 'Standard',
                  price: widget.product.price,
                  imagePath: widget.product.image,
                  imageUrl: widget.product.image,
                ),
              );

              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item added to cart')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              foregroundColor: Colors.white, // Force white text
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              "Add to Cart  •  ₹${widget.product.price}",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
