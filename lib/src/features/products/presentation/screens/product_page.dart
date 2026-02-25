import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
                    if (product.description != null &&
                        product.description!.isNotEmpty)
                      _DescriptionSection(description: product.description!),
                    const SizedBox(height: 16),
                    _ReviewsSection(product: product),
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

  void _shareProduct() {
    // GitHub Pages redirect → opens medshakthi://product/{id} on Android
    final link =
        'https://subhuu.github.io/medshakthi/product?id=${widget.product.id}';
    final text =
        '💊 Check out ${widget.product.name} on Med Shakthi!\n₹${widget.product.price}\n\n$link';
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
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

          InkWell(
            onTap: _shareProduct,
            child: Icon(Icons.share, color: Theme.of(context).iconTheme.color),
          ),
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
          // Rating row - dynamically computed by _ReviewsSection
          _RatingRow(productId: product.id),
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

/* ---------------- RATING ROW (review-based) ---------------- */

class _RatingRow extends StatefulWidget {
  final String productId;

  const _RatingRow({required this.productId});

  @override
  State<_RatingRow> createState() => _RatingRowState();
}

class _RatingRowState extends State<_RatingRow> {
  double _avgRating = 0.0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _fetchRating();
  }

  Future<void> _fetchRating() async {
    try {
      final res = await Supabase.instance.client
          .from('product_reviews')
          .select('rating')
          .eq('product_id', widget.productId);

      final list = res as List<dynamic>;
      if (list.isNotEmpty) {
        final avg =
            list
                .map((e) => (e['rating'] as num).toDouble())
                .reduce((a, b) => a + b) /
            list.length;
        if (mounted) {
          setState(() {
            _avgRating = double.parse(avg.toStringAsFixed(1));
            _count = list.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Rating fetch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(
          _avgRating > 0 ? '$_avgRating' : 'No reviews yet',
          style: const TextStyle(fontSize: 14),
        ),
        if (_count > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($_count)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ],
    );
  }
}

/* ---------------- DESCRIPTION SECTION ---------------- */

class _DescriptionSection extends StatelessWidget {
  final String description;

  const _DescriptionSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- REVIEWS SECTION ---------------- */

class _ReviewsSection extends StatefulWidget {
  final Product product;

  const _ReviewsSection({required this.product});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    try {
      final res = await Supabase.instance.client
          .from('product_reviews')
          .select('rating, review_text, created_at, user_id')
          .eq('product_id', widget.product.id)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reviews',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (_reviews.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_reviews.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reviews yet',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Buy this product to leave a review!',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          else
            ...(_reviews.map((r) => _ReviewCard(review: r))),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num).toInt();
    final text = review['review_text'] as String?;
    final createdAt = review['created_at'] as String?;
    final date = createdAt != null ? DateTime.tryParse(createdAt) : null;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text(
            'Verified Purchase',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
        boxShadow: const [
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

              HapticFeedback.lightImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              foregroundColor: Colors.white,
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
