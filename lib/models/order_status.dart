enum OrderStatus { pending, cutting, ready, delivered, cancelled }

enum ClothStatus { pending, cutting, ready, delivered }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.cutting:
        return 'Cutting';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get value => name;

  static OrderStatus fromValue(String value) {
    return OrderStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

extension ClothStatusX on ClothStatus {
  String get label {
    switch (this) {
      case ClothStatus.pending:
        return 'Pending';
      case ClothStatus.cutting:
        return 'Cutting Complete';
      case ClothStatus.ready:
        return 'Ready';
      case ClothStatus.delivered:
        return 'Delivered';
    }
  }

  String get value => name;

  static ClothStatus fromValue(String value) {
    return ClothStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ClothStatus.pending,
    );
  }
}
