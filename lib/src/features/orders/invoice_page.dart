import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Displays a professional invoice for a completed order.
/// Pass [orderData] (the order Map) and [items] (list of order_detail maps).
class InvoicePage extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final List<Map<String, dynamic>> items;

  /// Optional buyer info (name, phone) fetched from users table
  final String buyerName;
  final String buyerPhone;

  const InvoicePage({
    super.key,
    required this.orderData,
    required this.items,
    this.buyerName = '',
    this.buyerPhone = '',
  });

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get _orderNumber {
    return orderData['order_number']?.toString() ??
        'INV-${(orderData['order_group_id'] ?? orderData['id'] ?? 'N/A').toString().substring(0, 8).toUpperCase()}';
  }

  String get _invoiceDate {
    final raw = orderData['created_at'];
    if (raw == null) return DateFormat('dd MMM yyyy').format(DateTime.now());
    final dt = DateTime.tryParse(raw.toString()) ?? DateTime.now();
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  double get _subtotal => items.fold(
    0,
    (s, i) => s + ((i['price'] as num? ?? 0) * (i['quantity'] as num? ?? 0)),
  );

  // ── PDF generation ────────────────────────────────────────────────────────

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final doc = pw.Document();

    // Load a font that supports the Rupee glyph (₹ = U+20B9)
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final accentColor = PdfColor.fromHex('#4C8077');
    final lightAccent = PdfColor.fromHex('#EAF4F2');
    final grey = PdfColor.fromHex('#777777');

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(accentColor, lightAccent),
        footer: (ctx) => _buildFooter(ctx, grey),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _buildMetaRow(accentColor, grey),
          pw.SizedBox(height: 20),
          _buildAddressSection(grey, accentColor),
          pw.SizedBox(height: 20),
          _buildItemsTable(accentColor, lightAccent, grey),
          pw.SizedBox(height: 16),
          _buildTotalsSection(accentColor, lightAccent),
          pw.SizedBox(height: 32),
          _buildFooterNote(grey),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(PdfColor accent, PdfColor light) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MED SHAKTHI',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Medical Supplies Platform',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: const PdfColor(1, 1, 1, 0.7),
                  ),
                ),
              ],
            ),
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx, PdfColor grey) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Med Shakthi — medshakthi.app',
            style: pw.TextStyle(fontSize: 9, color: grey),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetaRow(PdfColor accent, PdfColor grey) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Invoice #',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
            pw.Text(
              _orderNumber,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Invoice Date',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
            pw.Text(
              _invoiceDate,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Payment Method',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
            pw.Text(
              orderData['payment_method']?.toString() ?? 'Online',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Status', style: pw.TextStyle(fontSize: 10, color: grey)),
            pw.Text(
              (orderData['status'] ?? 'Pending').toString().toUpperCase(),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildAddressSection(PdfColor grey, PdfColor accent) {
    final address = orderData['shipping_address'] ?? 'Not provided';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildAddressCard(
            title: 'Bill To / Ship To',
            lines: [
              if (buyerName.isNotEmpty) buyerName,
              if (buyerPhone.isNotEmpty) buyerPhone,
              address,
            ],
            accent: accent,
            grey: grey,
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _buildAddressCard(
            title: 'From',
            lines: [
              'Med Shakthi Platform',
              'medshakthi.app',
              'support@medshakthi.app',
            ],
            accent: accent,
            grey: grey,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAddressCard({
    required String title,
    required List<String> lines,
    required PdfColor accent,
    required PdfColor grey,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F8F8'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 6),
          ...lines.map(
            (l) => pw.Text(l, style: pw.TextStyle(fontSize: 11, color: grey)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(PdfColor accent, PdfColor light, PdfColor grey) {
    final headers = ['#', 'Item / Description', 'Qty', 'Unit Price', 'Total'];

    final rows = items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final qty = (item['quantity'] as num? ?? 0).toInt();
      final price = (item['price'] as num? ?? 0).toDouble();
      final total = qty * price;
      return [
        '${i + 1}',
        '${item['item_name'] ?? 'Unknown'}\n${item['brand'] != null && item['brand'].toString().isNotEmpty ? item['brand'] : ''}${item['unit_size'] != null ? '  •  ${item['unit_size']}' : ''}',
        '$qty',
        '₹${price.toStringAsFixed(2)}',
        '₹${total.toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: pw.BoxDecoration(color: accent),
      headerHeight: 28,
      cellHeight: 36,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellStyle: pw.TextStyle(fontSize: 10),
      oddRowDecoration: pw.BoxDecoration(color: light),
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#E0E0E0'),
        width: 0.5,
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(36),
        3: const pw.FixedColumnWidth(72),
        4: const pw.FixedColumnWidth(72),
      },
    );
  }

  pw.Widget _buildTotalsSection(PdfColor accent, PdfColor light) {
    final subtotal = _subtotal;
    final shippingFee = (orderData['shipping'] as num?)?.toDouble() ?? 0.0;
    final total = (orderData['total_amount'] as num?)?.toDouble() ?? subtotal;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 260,
        decoration: pw.BoxDecoration(
          color: light,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: accent, width: 0.5),
        ),
        padding: const pw.EdgeInsets.all(14),
        child: pw.Column(
          children: [
            _totalRow('Items Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
            pw.SizedBox(height: 4),
            _totalRow(
              'Shipping & Handling',
              shippingFee > 0 ? '₹${shippingFee.toStringAsFixed(2)}' : 'Free',
            ),
            pw.Divider(color: accent, thickness: 0.5),
            _totalRow(
              'Grand Total',
              '₹${total.toStringAsFixed(2)}',
              bold: true,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: bold ? 13 : 11,
      color: color,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  pw.Widget _buildFooterNote(PdfColor grey) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F8F8'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'This is a computer-generated invoice. No signature required.\n'
        'For queries, contact us at support@medshakthi.app.',
        style: pw.TextStyle(fontSize: 9, color: grey),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ── Flutter UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice — $_orderNumber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: () async {
              final bytes = await _buildPdf(PdfPageFormat.a4);
              await Printing.sharePdf(
                bytes: bytes,
                filename: '$_orderNumber.pdf',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () async {
              await Printing.layoutPdf(onLayout: (format) => _buildPdf(format));
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: _buildPdf,
        allowPrinting: false, // we handle via AppBar buttons
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: '$_orderNumber.pdf',
        initialPageFormat: PdfPageFormat.a4,
        actionBarTheme: PdfActionBarTheme(
          backgroundColor: colorScheme.primary,
          iconColor: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
