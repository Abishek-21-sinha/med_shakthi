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

  final Map<String, dynamic>? supplierInfo;

  const InvoicePage({
    super.key,
    required this.orderData,
    required this.items,
    this.buyerName = '',
    this.buyerPhone = '',
    this.supplierInfo,
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

    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final primaryColor = PdfColor.fromHex('#1E6E65'); // Deep medical teal
    final lightBg = PdfColor.fromHex('#F4F9F8');
    final greyText = PdfColor.fromHex('#555555');
    final lightGrey = PdfColor.fromHex('#EEEEEE');

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: format.copyWith(
          marginTop: 40,
          marginBottom: 40,
          marginLeft: 40,
          marginRight: 40,
        ),
        header: (ctx) => _buildProfessionalHeader(primaryColor, greyText),
        footer: (ctx) => _buildProfessionalFooter(ctx, greyText, primaryColor),
        build: (ctx) => [
          pw.SizedBox(height: 30),
          _buildAddressesAndMeta(primaryColor, lightBg, greyText),
          pw.SizedBox(height: 30),
          _buildProfessionalTable(primaryColor, lightBg, lightGrey, greyText),
          pw.SizedBox(height: 20),
          _buildProfessionalTotals(primaryColor, lightBg),
          pw.SizedBox(height: 40),
          _buildTermsAndConditions(greyText),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _buildProfessionalHeader(PdfColor primaryColor, PdfColor greyText) {
    final companyName =
        supplierInfo != null &&
            supplierInfo!['company'] != null &&
            supplierInfo!['company'].toString().isNotEmpty
        ? supplierInfo!['company'].toString().toUpperCase()
        : 'MEDICAL SUPPLIES PROVIDER';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'MEDICAL TAX INVOICE',
                  style: pw.TextStyle(
                    color: greyText,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#DDDDDD'),
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'INV: $_orderNumber',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Date: $_invoiceDate',
                  style: pw.TextStyle(fontSize: 10, color: greyText),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: primaryColor, thickness: 2),
      ],
    );
  }

  pw.Widget _buildAddressesAndMeta(
    PdfColor primary,
    PdfColor lightBg,
    PdfColor greyText,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // BILLED BY (Supplier)
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILLED FROM / SUPPLIER',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: primary,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (supplierInfo?['name'] != null &&
                  supplierInfo!['name'].toString().isNotEmpty)
                pw.Text(
                  supplierInfo!['name'],
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (supplierInfo?['address'] != null &&
                  supplierInfo!['address'].toString().isNotEmpty)
                pw.Text(
                  supplierInfo!['address'],
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: greyText,
                    lineSpacing: 2,
                  ),
                ),
              pw.SizedBox(height: 4),
              if (supplierInfo?['phone'] != null &&
                  supplierInfo!['phone'].toString().isNotEmpty)
                pw.Text(
                  'P: ${supplierInfo!['phone']}',
                  style: pw.TextStyle(fontSize: 10, color: greyText),
                ),
              if (supplierInfo?['email'] != null &&
                  supplierInfo!['email'].toString().isNotEmpty)
                pw.Text(
                  'E: ${supplierInfo!['email']}',
                  style: pw.TextStyle(fontSize: 10, color: greyText),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        // BILLED TO (Buyer)
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILLED TO',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: primary,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                buyerName.isNotEmpty ? buyerName : 'Customer',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (orderData['shipping_address'] != null)
                pw.Text(
                  orderData['shipping_address'],
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: greyText,
                    lineSpacing: 2,
                  ),
                ),
              if (buyerPhone.isNotEmpty)
                pw.Text(
                  'P: $buyerPhone',
                  style: pw.TextStyle(fontSize: 10, color: greyText),
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        // MEDICAL & TAX INFO
        pw.Expanded(
          flex: 1,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'REGISTRATION DETAILS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: primary,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                _buildRegRow('GSTIN:', supplierInfo?['gst']?.toString()),
                _buildRegRow('D.L. No:', supplierInfo?['dl']?.toString()),
                if (supplierInfo?['dlExpiry'] != null &&
                    supplierInfo!['dlExpiry'].toString().isNotEmpty)
                  _buildRegRow(
                    'D.L. Exp:',
                    DateFormat('dd MMM yyyy').format(
                      DateTime.tryParse(supplierInfo!['dlExpiry'].toString()) ??
                          DateTime.now(),
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Divider(color: PdfColor.fromHex('#CCCCCC'), thickness: 0.5),
                pw.SizedBox(height: 4),
                _buildRegRow(
                  'Payment:',
                  orderData['payment_method']?.toString() ?? 'Online',
                ),
                _buildRegRow(
                  'Status:',
                  (orderData['status'] ?? 'Pending').toString().toUpperCase(),
                  boldValue: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildRegRow(
    String label,
    String? value, {
    bool boldValue = false,
  }) {
    if (value == null || value.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 45,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('#777777'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: boldValue
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalTable(
    PdfColor primary,
    PdfColor lightBg,
    PdfColor lightGrey,
    PdfColor greyText,
  ) {
    final headers = ['#', 'DESCRIPTION', 'QTY', 'PRICE', 'AMOUNT'];

    final rows = items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      final qty = (item['quantity'] as num? ?? 0).toInt();
      final price = (item['price'] as num? ?? 0).toDouble();
      final total = qty * price;

      final itemName = item['item_name'] ?? 'Unknown Item';
      final details = [
        if (item['brand'] != null && item['brand'].toString().isNotEmpty)
          item['brand'],
        if (item['unit_size'] != null &&
            item['unit_size'].toString().isNotEmpty)
          item['unit_size'],
      ].join(' • ');

      return [
        '${i + 1}',
        '$itemName${details.isNotEmpty ? '\n$details' : ''}',
        '$qty',
        '₹ ${price.toStringAsFixed(2)}',
        '₹ ${total.toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: lightGrey, width: 0.5),
        bottom: pw.BorderSide(color: primary, width: 1),
      ),
      headerStyle: pw.TextStyle(
        color: primary,
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: pw.BoxDecoration(
        color: lightBg,
        border: pw.Border(
          top: pw.BorderSide(color: primary, width: 1),
          bottom: pw.BorderSide(color: primary, width: 1),
        ),
      ),
      cellHeight: 32,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellStyle: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#333333')),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(50),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(80),
      },
    );
  }

  pw.Widget _buildProfessionalTotals(PdfColor primary, PdfColor lightBg) {
    final subtotal = _subtotal;
    final shippingFee = (orderData['shipping'] as num?)?.toDouble() ?? 0.0;
    final total = (orderData['total_amount'] as num?)?.toDouble() ?? subtotal;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(), // Empty space on left
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            children: [
              _buildTotalRow('Subtotal', '₹ ${subtotal.toStringAsFixed(2)}'),
              _buildTotalRow(
                'Shipping',
                shippingFee > 0
                    ? '₹ ${shippingFee.toStringAsFixed(2)}'
                    : 'Free',
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: _buildTotalRow(
                  'TOTAL',
                  '₹ ${total.toStringAsFixed(2)}',
                  isTotal: true,
                  primary: primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool isTotal = false,
    PdfColor? primary,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 12 : 10,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? primary : PdfColor.fromHex('#555555'),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 10,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? primary : PdfColor.fromHex('#333333'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTermsAndConditions(PdfColor greyText) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TERMS & CONDITIONS',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: greyText,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '1. All disputes are subject to the jurisdiction of the supplier\'s registered address.\n'
          '2. Medicines once sold cannot be returned unless expired or damaged upon receipt.\n'
          '3. This is a computer-generated invoice and does not require a physical signature.',
          style: pw.TextStyle(fontSize: 8, color: greyText, lineSpacing: 1.5),
        ),
      ],
    );
  }

  pw.Widget _buildProfessionalFooter(
    pw.Context ctx,
    PdfColor greyText,
    PdfColor primary,
  ) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromHex('#EEEEEE'), thickness: 1),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated via Med Shakthi — Pharmaceutical Supply Chain Platform',
              style: pw.TextStyle(fontSize: 8, color: greyText),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: greyText),
            ),
          ],
        ),
      ],
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
