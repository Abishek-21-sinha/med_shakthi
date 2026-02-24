// ignore_for_file: deprecated_member_use, no_leading_underscores_for_local_identifiers
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'order_success_screen.dart';
import 'package:med_shakthi/src/features/checkout/presentation/screens/payment_method_store.dart';
import 'package:med_shakthi/src/features/checkout/presentation/widgets/add_payment_method_sheet.dart';
import '../../../cart/data/cart_data.dart';
import '../../../cart/data/cart_item.dart';
import 'package:med_shakthi/src/features/checkout/data/models/payment_method_model.dart';
import 'package:uuid/uuid.dart';
import 'package:med_shakthi/src/features/checkout/data/models/address_model.dart';

class PaymentMethodScreen extends StatefulWidget {
  final bool isCheckout;
  final AddressModel? deliveryAddress;
  const PaymentMethodScreen({
    super.key,
    this.isCheckout = true,
    this.deliveryAddress,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final supabase = Supabase.instance.client;
  bool _placingOrder = false;
  late Razorpay _razorpay;
  String? _razorpayPaymentId; // Filled on successful Razorpay payment

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<PaymentMethodStore>().fetchPaymentMethods();
    });
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _showAddMethodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPaymentMethodSheet(),
    );
  }

  // ── Razorpay Handlers ─────────────────────────────────────────────
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Razorpay Payment Success: ${response.paymentId}');
    _razorpayPaymentId = response.paymentId;
    _placeOrder(paymentMode: 'razorpay_online', paymentStatus: 'paid');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay Error: ${response.message}');
    if (mounted) {
      showCustomSnackBar(
        context,
        'Payment failed: ${response.message ?? "Unknown error"}',
        isError: true,
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 External wallet: ${response.walletName}');
  }

  void _startRazorpayPayment() {
    final cart = context.read<CartData>();
    final user = supabase.auth.currentUser;
    if (user == null || cart.items.isEmpty) return;

    const shipping = 10;
    final total = cart.subTotal + shipping;
    final amountPaise = (total * 100).round(); // Razorpay uses paise

    // Use test key from .env, fallback to test key
    final razorpayKey = dotenv.env['RAZORPAY_KEY_ID'] ?? 'rzp_test_placeholder';

    final options = {
      'key': razorpayKey,
      'amount': amountPaise,
      'name': 'Med Shakthi',
      'description': 'Order Payment',
      'prefill': {'contact': '', 'email': user.email ?? ''},
      'theme': {'color': '#00B894'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      showCustomSnackBar(context, 'Could not open payment: $e', isError: true);
    }
  }

  Future<void> _placeOrder({
    String paymentMode = 'cod',
    String paymentStatus = 'pending',
  }) async {
    final cart = context.read<CartData>();
    final user = supabase.auth.currentUser;
    final paymentStore = context.read<PaymentMethodStore>();

    if (user == null) {
      showCustomSnackBar(context, "User not logged in", isError: true);
      return;
    }

    if (cart.items.isEmpty) {
      showCustomSnackBar(context, "Cart is empty", isError: true);
      return;
    }

    // Require payment method selection if methods exist
    if (paymentStore.selectedMethodId == null &&
        paymentStore.paymentMethods.isNotEmpty) {
      showCustomSnackBar(
        context,
        "Please select a payment method",
        isError: true,
      );
      return;
    }

    setState(() => _placingOrder = true);

    try {
      // 1. Fetch supplier_id for all products in cart
      final productIds = cart.items.map((item) => item.id).toList();
      final productsData = await supabase
          .from('products')
          .select('id, supplier_id')
          .inFilter('id', productIds);

      // Create a map: product_id -> supplier_id
      final Map<String, String?> productSuppliers = {
        for (var p in productsData)
          p['id'] as String: p['supplier_id'] as String?,
      };

      // 2. Group cart items by supplier
      final Map<String?, List<CartItem>> itemsBySupplier = {};
      for (var item in cart.items) {
        final supplierId = productSuppliers[item.id];
        itemsBySupplier.putIfAbsent(supplierId, () => []).add(item);
      }

      // 3. Create shared order group ID
      final orderGroupId = const Uuid().v4();
      const shipping = 10;

      // Format delivery address
      final String deliveryAddressText = widget.deliveryAddress != null
          ? widget.deliveryAddress!.fullAddress
          : 'No address provided';

      // 4. Create ONE order per supplier
      /*for (var entry in itemsBySupplier.entries) {
        final supplierId = entry.key;
        final items = entry.value;

        // Calculate total for this supplier's items
        final supplierSubtotal = items.fold(
          0.0,
          (sum, item) => sum + (item.price * item.quantity),
        );
        final supplierTotal = supplierSubtotal + shipping;

        // Insert ONE order row for this supplier
        final order = await supabase
            .from('orders')
            .insert({
              "user_id": user.id,
              "order_group_id": orderGroupId,
              "supplier_id": supplierId,
              "total_amount": supplierTotal,
              "shipping": shipping,
              "shipping_address": deliveryAddressText,
              "status": "pending",
              "payment_status": "pending",
              "payment_method_id": paymentStore.selectedMethodId,
            })
            .select()
            .single();

        // 5. Insert order_details for each item in this supplier's order
        final orderDetailRows = items.map((item) {
          return {
            "order_id": order['id'],
            "product_id": item.id,
            "supplier_id": supplierId, // NEW: Track supplier per item
            "item_name": item.title ?? item.name,
            "brand": item.brand ?? "",
            "unit_size": item.size ?? "",
            "image_url": item.imagePath ?? item.imageUrl ?? "",
            "price": item.price,
            "quantity": item.quantity,
          };
        }).toList();

        await supabase.from('order_details').insert(orderDetailRows);
      }*/

      for (var entry in itemsBySupplier.entries) {
        final supplierId = entry.key;
        final items = entry.value;

        // Calculate total
        final supplierSubtotal = items.fold(
          0.0,
          (sum, item) => sum + (item.price * item.quantity),
        );
        final supplierTotal = supplierSubtotal + shipping;

        // Insert order
        final order = await supabase
            .from('orders')
            .insert({
              "user_id": user.id,
              "order_group_id": orderGroupId,
              "supplier_id": supplierId,
              "total_amount": supplierTotal,
              "shipping": shipping,
              "shipping_address": deliveryAddressText,
              "status": "pending",
              "payment_status": paymentStatus,
              "payment_method": paymentMode,
              "razorpay_payment_id": _razorpayPaymentId,
              "payment_method_id": paymentStore.selectedMethodId,
            })
            .select()
            .single();

        // Create order details rows
        final orderDetailRows = items.map((item) {
          return {
            "order_id": order['id'],
            "product_id": item.id,
            "supplier_id": supplierId,
            "item_name": item.title ?? item.name,
            "brand": item.brand ?? "",
            "unit_size": item.size ?? "",
            "image_url": item.imagePath ?? item.imageUrl ?? "",
            "price": item.price,
            "quantity": item.quantity,
          };
        }).toList();

        //  Insert order details
        await supabase.from('order_details').insert(orderDetailRows);
        // print("Calling Edge Function for supplier: $supplierId");

        // CALL EDGE FUNCTION HERE (AFTER INSERT)
        if (supplierId != null) {
          try {
            debugPrint("Calling Edge Function for supplier: $supplierId");
            await supabase.functions.invoke(
              'send-order-notification',
              body: {"supplier_id": supplierId, "order_id": order['id']},
            );
          } catch (e) {
            // Log the error but DO NOT fail the order
            debugPrint(
              "Failed to send notification to supplier $supplierId: $e",
            );
          }
        }
      }

      if (!mounted) return;
      showCustomSnackBar(context, "Order Placed Successfully");

      cart.clearCart();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OrderSuccessScreen()),
      );
    } on PostgrestException catch (e) {
      debugPrint("Supabase error: ${e.message}");
      if (mounted) {
        showCustomSnackBar(
          context,
          "Order failed: ${e.message}",
          isError: true,
        );
      }
    } catch (e) {
      debugPrint("Order failed: $e");
      if (mounted) {
        showCustomSnackBar(context, "Order failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  IconData _getIconForType(String type, Map<String, dynamic> details) {
    if (type == 'upi') {
      final provider = details['provider'];
      if (provider == 'google_pay') {
        return Icons.g_mobiledata;
      }
      if (provider == 'phonepe') {
        return Icons.payments;
      }
      if (provider == 'paytm') {
        return Icons.account_balance_wallet;
      }
      return Icons.qr_code_2;
    }
    switch (type) {
      case 'bank_transfer':
        return Icons.account_balance;
      case 'card':
        return Icons.credit_card;
      case 'paypal':
        return Icons.paypal; // Or Icons.payment if paypal not available
      default:
        return Icons.payment;
    }
  }

  String _getSubtitle(PaymentMethodModel method) {
    switch (method.type) {
      case 'upi':
        return "${(method.details['provider'] as String?)?.replaceAll('_', ' ').toUpperCase() ?? 'UPI'}: ${method.details['upi_id'] ?? ''}";
      case 'card':
        if (method.details['card_number_masked'] != null) {
          return "${method.details['card_type'] ?? 'Card'} ending ${method.details['card_number_masked'].toString().split('-').last}";
        }
        return "Card ending **${method.details['card_last4'] ?? ''}";
      case 'bank_transfer':
        return "Acc: ${method.details['account_no'] ?? ''}";
      case 'paypal':
        return "Email: ${method.details['email'] ?? ''}";
      default:
        return method.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartData>();
    final store = context.watch<PaymentMethodStore>();

    const shipping = 10;
    final subTotal = cart.subTotal;
    final total = subTotal + shipping;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text("Payment Method")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Address Summary
              if (widget.deliveryAddress != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Address',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.deliveryAddress!.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.deliveryAddress!.fullAddress,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      if (widget.deliveryAddress!.remarks != null &&
                          widget.deliveryAddress!.remarks!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Note: ${widget.deliveryAddress!.remarks}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your Payment Methods",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _showAddMethodSheet,
                    icon: const Icon(Icons.add),
                    label: const Text("Add New"),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (store.loading)
                const Center(child: CircularProgressIndicator())
              else if (store.paymentMethods.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.payment_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "No payment methods saved",
                        style: TextStyle(color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: _showAddMethodSheet,
                        child: const Text("Add One Now"),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: store.paymentMethods.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final method = store.paymentMethods[i];
                    final isSelected = store.selectedMethodId == method.id;

                    return Dismissible(
                      key: Key(method.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        store.deletePaymentMethod(method.id);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.teal
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: method.id,
                          groupValue: store.selectedMethodId,
                          activeColor: Colors.teal,
                          onChanged: (val) {
                            if (val != null) store.selectMethod(val);
                          },
                          secondary: Icon(
                            _getIconForType(method.type, method.details),
                            color: isSelected ? Colors.teal : Colors.grey,
                          ),
                          title: Text(
                            method.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getSubtitle(method),
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (method.type == 'card' &&
                                  method.details.containsKey('expiry'))
                                Text(
                                  "Expires: ${method.details['expiry']}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (widget.isCheckout) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                const Text(
                  "Billing Summary",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Subtotal"),
                    Text("₹${subTotal.toStringAsFixed(2)}"),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text("Shipping & Tax"), Text("₹$shipping")],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "₹${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                // ── PAY ONLINE (Razorpay) ──
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _placingOrder ? null : _startRazorpayPayment,
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text(
                      'PAY ONLINE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── PLACE ORDER (COD) ──
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _placingOrder
                        ? null
                        : () => _placeOrder(
                            paymentMode: 'cod',
                            paymentStatus: 'pending',
                          ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF00B894),
                        width: 1.5,
                      ),
                      foregroundColor: const Color(0xFF00B894),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _placingOrder
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00B894),
                            ),
                          )
                        : const Text(
                            'CASH ON DELIVERY',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
