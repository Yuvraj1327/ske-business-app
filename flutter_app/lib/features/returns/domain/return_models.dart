import 'package:equatable/equatable.dart';

class SalesReturnItem extends Equatable {
  final String id;
  final String saleItemId;
  final String productName;
  final double quantity;
  final double amount;

  const SalesReturnItem({
    required this.id,
    required this.saleItemId,
    required this.productName,
    required this.quantity,
    required this.amount,
  });

  factory SalesReturnItem.fromJson(Map<String, dynamic> json) {
    return SalesReturnItem(
      id: json['id'] as String,
      saleItemId: json['sale_item_id'] as String,
      productName: json['product_name'] as String,
      quantity: double.parse(json['quantity'] as String),
      amount: double.parse(json['amount'] as String),
    );
  }

  @override
  List<Object?> get props => [id, saleItemId, productName, quantity, amount];
}

class SalesReturn extends Equatable {
  final String id;
  final String saleId;
  final String customerId;
  final String customerName;
  final DateTime returnDate;
  final double totalReturnAmount;
  final String? reason;
  final String status;
  final List<SalesReturnItem> items;

  const SalesReturn({
    required this.id,
    required this.saleId,
    required this.customerId,
    required this.customerName,
    required this.returnDate,
    required this.totalReturnAmount,
    this.reason,
    required this.status,
    required this.items,
  });

  factory SalesReturn.fromJson(Map<String, dynamic> json) {
    return SalesReturn(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      returnDate: DateTime.parse(json['return_date'] as String),
      totalReturnAmount: double.parse(json['total_return_amount'] as String),
      reason: json['reason'] as String?,
      status: json['status'] as String,
      items: (json['items'] as List).map((e) => SalesReturnItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  List<Object?> get props =>
      [id, saleId, customerId, customerName, returnDate, totalReturnAmount, reason, status, items];
}
