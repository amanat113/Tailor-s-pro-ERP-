import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/app_constants.dart';
import '../models/shop_settings.dart';
import '../models/tailor_order.dart';

class PdfService {
  const PdfService();

  Future<Uint8List> buildSlipPdf({required TailorOrder order, required ShopSettings settings}) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(settings.shopName.isEmpty ? AppConstants.appName : settings.shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              if (settings.address.isNotEmpty) pw.Text(settings.address),
              if (settings.phone.isNotEmpty) pw.Text('Phone: ${settings.phone}'),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: <pw.Widget>[
                pw.Text('Slip No: ${order.slipNo}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(date),
              ]),
              pw.SizedBox(height: 12),
              pw.Text('Customer: ${order.customerName}'),
              pw.Text('Mobile: ${order.mobile}'),
              pw.Text('Clothes: ${order.clothQty}'),
              pw.SizedBox(height: 12),
              pw.Text('Measurements', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: order.measurements.entries
                    .map(
                      (entry) => pw.TableRow(children: <pw.Widget>[
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.key)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.value)),
                      ]),
                    )
                    .toList(),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Billing', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _billingRow('Total Bill', order.totalBill),
              _billingRow('Advance Paid', order.advancePaid),
              _billingRow('Due Amount', order.dueAmount),
              if (order.designUrl.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 10), child: pw.Text('Design Reference: ${order.designUrl}')),
              pw.Spacer(),
              pw.Text(settings.slipNote),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _billingRow(String label, num value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: <pw.Widget>[
        pw.Text(label),
        pw.Text('Rs. $value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  Future<void> shareSlip({required TailorOrder order, required ShopSettings settings}) async {
    final bytes = await buildSlipPdf(order: order, settings: settings);
    await Printing.sharePdf(bytes: bytes, filename: '${order.slipNo}_slip.pdf');
  }

  Future<String> uploadSlip({required TailorOrder order, required ShopSettings settings}) async {
    final bytes = await buildSlipPdf(order: order, settings: settings);
    final ref = FirebaseStorage.instance.ref('shops/${AppConstants.shopId}/slips/${order.slipNo}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    return ref.getDownloadURL();
  }
}
