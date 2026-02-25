import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shiprocket API Service
/// Uses env vars: SHIPROCKET_EMAIL and SHIPROCKET_PASSWORD
/// Token is cached in-memory and refreshed on 401.
class ShiprocketService {
  static const _baseUrl = 'https://apiv2.shiprocket.in/v1/external';
  static String? _token;
  static DateTime? _tokenExpiry;

  /// Set to true for testing without real Shiprocket credentials.
  /// Returns realistic mock tracking data so the UI can be validated.
  static bool mockMode = false;

  // ── Mock Data (for testing) ──────────────────────────────────────────

  static Map<String, dynamic> _mockTrackingResponse(String awb) {
    return {
      'tracking_data': {
        'shipment_track': [
          {
            'current_status': 'In Transit',
            'current_status_description':
                'Shipment is in transit to destination',
            'updated_at': DateTime.now()
                .subtract(const Duration(hours: 3))
                .toIso8601String(),
          },
        ],
        'shipment_track_activities': [
          {
            'activity': 'Out for delivery',
            'date': DateTime.now()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
            'location': 'Local Delivery Hub',
          },
          {
            'activity': 'Arrived at destination facility',
            'date': DateTime.now()
                .subtract(const Duration(hours: 8))
                .toIso8601String(),
            'location': 'City Sorting Center',
          },
          {
            'activity': 'Departed origin facility',
            'date': DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'location': 'Mumbai Hub',
          },
          {
            'activity': 'Order picked up',
            'date': DateTime.now()
                .subtract(const Duration(days: 2))
                .toIso8601String(),
            'location': 'Seller Location',
          },
          {
            'activity': 'Shipment created',
            'date': DateTime.now()
                .subtract(const Duration(days: 2, hours: 4))
                .toIso8601String(),
            'location': 'Shiprocket System',
          },
        ],
        'awb_code': awb,
      },
    };
  }

  static Map<String, dynamic> _mockCreateOrderResponse(String orderId) {
    return {
      'order_id': orderId,
      'shipment_id': 'MOCK_SHIP_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'NEW',
      'status_id': 1,
      'awb_assign_error': '',
      'payment_status': 'MOCK',
      'method': 'MOCK',
    };
  }

  // ── Token Management ────────────────────────────────────────────────

  static Future<String?> _getToken() async {
    // Return cached token if still valid (< 24h old)
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _token;
    }

    final email = dotenv.env['SHIPROCKET_EMAIL'];
    final password = dotenv.env['SHIPROCKET_PASSWORD'];

    if (email == null || password == null) {
      debugPrint(
        '❌ Shiprocket: SHIPROCKET_EMAIL or SHIPROCKET_PASSWORD not set in .env',
      );
      return null;
    }

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['token'] as String?;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 23));
        debugPrint('✅ Shiprocket token obtained');
        return _token;
      } else {
        debugPrint('❌ Shiprocket login failed: ${res.statusCode} ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Shiprocket login error: $e');
      return null;
    }
  }

  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Create Shiprocket Order ──────────────────────────────────────────

  static Future<Map<String, dynamic>?> createOrder({
    required String orderId, // Our internal order_number
    required String orderDate, // yyyy-MM-dd
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String shippingAddress,
    required String city,
    required String state,
    required String pincode,
    required List<Map<String, dynamic>> items, // [{name, sku, units, price}]
    required double subTotal,
    required String paymentMethod, // 'COD' or 'Prepaid'
  }) async {
    // ── MOCK MODE: for testing without real Shiprocket account ──
    if (mockMode) {
      debugPrint('🧪 [MOCK] Shiprocket createOrder for: $orderId');
      await Future.delayed(const Duration(milliseconds: 600));
      return _mockCreateOrderResponse(orderId);
    }

    final token = await _getToken();
    if (token == null) return null;

    final payload = {
      'order_id': orderId,
      'order_date': orderDate,
      'pickup_location': dotenv.env['SHIPROCKET_PICKUP_LOCATION'] ?? 'Primary',
      'billing_customer_name': customerName,
      'billing_last_name': '',
      'billing_address': shippingAddress,
      'billing_city': city,
      'billing_pincode': pincode,
      'billing_state': state,
      'billing_country': 'India',
      'billing_email': customerEmail,
      'billing_phone': customerPhone,
      'shipping_is_billing': true,
      'order_items': items,
      'payment_method': paymentMethod,
      'sub_total': subTotal,
      'length': 10,
      'breadth': 10,
      'height': 5,
      'weight': 0.5,
    };

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/orders/create/adhoc'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        debugPrint('✅ Shiprocket order created: ${data['order_id']}');
        return data;
      } else {
        debugPrint(
          '❌ Shiprocket order creation failed: ${res.statusCode} ${res.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Shiprocket createOrder error: $e');
      return null;
    }
  }

  // ── Track Shipment by AWB ────────────────────────────────────────────

  static Future<Map<String, dynamic>?> trackByAwb(String awbCode) async {
    // ── MOCK MODE ──
    if (mockMode) {
      debugPrint('🧪 [MOCK] Shiprocket trackByAwb: $awbCode');
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockTrackingResponse(awbCode);
    }

    final token = await _getToken();
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/courier/track/awb/$awbCode'),
        headers: _headers(token),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ Shiprocket tracking failed: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Shiprocket track error: $e');
      return null;
    }
  }

  // ── Track Shipment by Shiprocket Shipment ID ─────────────────────────

  static Future<Map<String, dynamic>?> trackByShipmentId(
    String shipmentId,
  ) async {
    // ── MOCK MODE ──
    if (mockMode) {
      debugPrint('🧪 [MOCK] Shiprocket trackByShipmentId: $shipmentId');
      await Future.delayed(const Duration(milliseconds: 800));
      return _mockTrackingResponse('MOCK_AWB_$shipmentId');
    }

    final token = await _getToken();
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/courier/track/shipment/$shipmentId'),
        headers: _headers(token),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          '❌ Shiprocket tracking by shipmentId failed: ${res.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Shiprocket track by shipment error: $e');
      return null;
    }
  }

  // ── Helper: Save Shiprocket details back to our orders table ─────────

  static Future<void> saveToOrder({
    required String orderId, // Our UUID
    required String? shiprocketOrderId,
    required String? shiprocketShipmentId,
    required String? awbCode,
    required String? courierName,
    required String? trackingUrl,
  }) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update(
            {
              'shiprocket_order_id': shiprocketOrderId,
              'shiprocket_shipment_id': shiprocketShipmentId,
              'awb_code': awbCode,
              'courier_name': courierName,
              'tracking_url': trackingUrl,
            }..removeWhere((_, v) => v == null),
          )
          .eq('id', orderId);
      debugPrint('✅ Shiprocket details saved to orders table');
    } catch (e) {
      debugPrint('❌ Failed to save Shiprocket details: $e');
    }
  }
}
