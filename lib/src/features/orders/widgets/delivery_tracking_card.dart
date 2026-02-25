import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:med_shakthi/src/core/services/shiprocket_service.dart';

/// A card shown on OrderDetailScreen to display live delivery tracking info.
/// Shows courier name, AWB code, current status, and a link to track online.
class DeliveryTrackingCard extends StatefulWidget {
  /// The order's AWB code (air waybill number from courier)
  final String? awbCode;

  /// The Shiprocket shipment ID (fallback if AWB not available yet)
  final String? shiprocketShipmentId;

  /// Courier name already stored in DB
  final String? courierName;

  /// External tracking URL stored in DB
  final String? trackingUrl;

  const DeliveryTrackingCard({
    super.key,
    this.awbCode,
    this.shiprocketShipmentId,
    this.courierName,
    this.trackingUrl,
  });

  @override
  State<DeliveryTrackingCard> createState() => _DeliveryTrackingCardState();
}

class _DeliveryTrackingCardState extends State<DeliveryTrackingCard> {
  bool _loading = false;
  String? _currentStatus;
  String? _location;
  String? _lastUpdated;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchTracking();
  }

  Future<void> _fetchTracking() async {
    final awb = widget.awbCode;
    final shipmentId = widget.shiprocketShipmentId;

    if (awb == null && shipmentId == null) return;

    setState(() => _loading = true);

    try {
      Map<String, dynamic>? data;
      if (awb != null && awb.isNotEmpty) {
        data = await ShiprocketService.trackByAwb(awb);
      } else if (shipmentId != null && shipmentId.isNotEmpty) {
        data = await ShiprocketService.trackByShipmentId(shipmentId);
      }

      if (data != null && mounted) {
        // Shiprocket tracking response parsing
        final trackData = data['tracking_data'] as Map<String, dynamic>?;
        final shipmentTrack = trackData?['shipment_track'] as List?;
        final trackActivities =
            trackData?['shipment_track_activities'] as List?;

        setState(() {
          if (shipmentTrack != null && shipmentTrack.isNotEmpty) {
            final latest = shipmentTrack.first as Map<String, dynamic>;
            _currentStatus = latest['current_status'] as String?;
            _location = latest['current_status_description'] as String?;
            _lastUpdated = latest['updated_at'] as String?;
          }
          if (trackActivities != null) {
            _activities = trackActivities
                .take(5)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Tracking fetch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF00B894);

    // Don't show if no tracking info at all
    if (widget.awbCode == null &&
        widget.shiprocketShipmentId == null &&
        widget.courierName == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 18,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Tracking',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.courierName != null)
                        Text(
                          widget.courierName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  )
                else
                  InkWell(
                    onTap: _fetchTracking,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── AWB + Status ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.awbCode != null && widget.awbCode!.isNotEmpty)
                  _infoRow(
                    icon: Icons.qr_code_rounded,
                    label: 'AWB / Tracking No.',
                    value: widget.awbCode!,
                  ),

                if (_currentStatus != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Current Status',
                    value: _currentStatus!,
                    valueColor: primary,
                  ),
                ],

                if (_location != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _location!,
                  ),
                ],

                if (_lastUpdated != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Last Updated',
                    value: _lastUpdated!,
                  ),
                ],
              ],
            ),
          ),

          // ── Activity Timeline ────────────────────────────────
          if (_activities.isNotEmpty) ...[
            const Divider(height: 24, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'TRACKING HISTORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: _activities.asMap().entries.map((entry) {
                  final i = entry.key;
                  final act = entry.value;
                  final isLast = i == _activities.length - 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: i == 0 ? primary : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 36,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act['activity'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: i == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: i == 0
                                      ? theme.textTheme.bodyLarge?.color
                                      : theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              if (act['date'] != null)
                                Text(
                                  act['date'].toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Track Online Button ───────────────────────────────
          if (widget.trackingUrl != null && widget.trackingUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(widget.trackingUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Track on Courier Website'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
