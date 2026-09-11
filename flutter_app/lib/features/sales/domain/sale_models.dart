import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineDiscount;
  final double lineTotal;

  const SaleItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineDiscount,
    required this.lineTotal,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: double.parse(json['quantity'] as String),
      unitPrice: double.parse(json['unit_price'] as String),
      lineDiscount: double.parse(json['line_discount'] as String),
      lineTotal: double.parse(json['line_total'] as String),
    );
  }

  @override
  List<Object?> get props => [id, productId, productName, quantity, unitPrice, lineDiscount, lineTotal];
}

class InvoiceSummary extends Equatable {
  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String status;

  const InvoiceSummary({required this.id, required this.invoiceNumber, required this.invoiceDate, required this.status});

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      invoiceDate: DateTime.parse(json['invoice_date'] as String),
      status: json['status'] as String,
    );
  }

  @override
  List<Object?> get props => [id, invoiceNumber, invoiceDate, status];
}

class Sale extends Equatable {
  final String id;
  final String customerId;
  final String customerName;
  final DateTime saleDate;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String paymentStatus; // unpaid | partial | paid
  final String status; // active | cancelled
  final List<SaleItem> items;
  final InvoiceSummary? invoice;

  const Sale({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.saleDate,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.paymentStatus,
    required this.status,
    required this.items,
    required this.invoice,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      saleDate: DateTime.parse(json['sale_date'] as String),
      subtotal: double.parse(json['subtotal'] as String),
      discountAmount: double.parse(json['discount_amount'] as String),
      totalAmount: double.parse(json['total_amount'] as String),
      paidAmount: double.parse(json['paid_amount'] as String),
      outstandingAmount: double.parse(json['outstanding_amount'] as String),
      paymentStatus: json['payment_status'] as String,
      status: json['status'] as String,
      items: (json['items'] as List).map((e) => SaleItem.fromJson(e as Map<String, dynamic>)).toList(),
      invoice: json['invoice'] != null ? InvoiceSummary.fromJson(json['invoice'] as Map<String, dynamic>) : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        saleDate,
        subtotal,
        discountAmount,
        totalAmount,
        paidAmount,
        outstandingAmount,
        paymentStatus,
        status,
        items,
        invoice,
      ];
}

class SaleListItem extends Equatable {
  final String id;
  final String customerId;
  final String customerName;
  final DateTime saleDate;
  final double totalAmount;
  final double outstandingAmount;
  final String paymentStatus;
  final String status;
  final String? invoiceNumber;

  const SaleListItem({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.saleDate,
    required this.totalAmount,
    required this.outstandingAmount,
    required this.paymentStatus,
    required this.status,
    this.invoiceNumber,
  });

  factory SaleListItem.fromJson(Map<String, dynamic> json) {
    return SaleListItem(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      saleDate: DateTime.parse(json['sale_date'] as String),
      totalAmount: double.parse(json['total_amount'] as String),
      outstandingAmount: double.parse(json['outstanding_amount'] as String),
      paymentStatus: json['payment_status'] as String,
      status: json['status'] as String,
      invoiceNumber: json['invoice_number'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, customerId, customerName, saleDate, totalAmount, outstandingAmount, paymentStatus, status, invoiceNumber];
}

/// A line the user is building in the Create Sale form — client-side only,
/// never sent as-is. Only product_id/quantity/unit_price/line_discount are
/// sent; line_total shown here is a local UX preview, always recalculated
/// authoritatively by the backend.
class DraftSaleItem extends Equatable {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineDiscount;

  const DraftSaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.lineDiscount = 0,
  });

  double get lineTotal => (quantity * unitPrice) - lineDiscount;

  @override
  List<Object?> get props => [productId, productName, quantity, unitPrice, lineDiscount];
}
