import 'package:url_launcher/url_launcher.dart';

import '../models/tailor_order.dart';

class NotificationService {
  const NotificationService();

  String orderSaved(TailorOrder order) {
    return 'Hello ${order.customerName}, your order (Slip: ${order.slipNo}) has been placed. Total: ₹${order.totalBill}, Advance: ₹${order.advancePaid}, Due: ₹${order.dueAmount}. Thank you!';
  }

  String cuttingComplete(TailorOrder order) {
    return 'Hello ${order.customerName}, cutting for your order (Slip: ${order.slipNo}) is complete and stitching has begun.';
  }

  String orderReady(TailorOrder order) {
    return 'Good news ${order.customerName}! Your clothes (Slip: ${order.slipNo}) are ready for delivery.';
  }

  String deliveryConfirmed(TailorOrder order) {
    return 'Thank you ${order.customerName}! Your order (Slip: ${order.slipNo}) has been successfully delivered.';
  }

  Future<void> openWhatsApp({required String mobile, required String message}) async {
    final phone = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> callCustomer(String mobile) async {
    final uri = Uri.parse('tel:$mobile');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
