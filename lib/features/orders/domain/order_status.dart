enum OrderStatus { pending, cutting, stitching, ready, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get storageValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.cutting:
        return 'cutting';
      case OrderStatus.stitching:
        return 'stitching';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.cutting:
        return 'Cutting';
      case OrderStatus.stitching:
        return 'Stitching';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => this != OrderStatus.delivered && this != OrderStatus.cancelled;

  static OrderStatus fromStorage(String? value) {
    switch ((value ?? '').toLowerCase().trim()) {
      case 'cutting':
        return OrderStatus.cutting;
      case 'stitching':
        return OrderStatus.stitching;
      case 'ready':
        return OrderStatus.ready;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }
}
