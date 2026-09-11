import 'package:equatable/equatable.dart';

class ChequeDetail extends Equatable {
  final String chequeNumber;
  final DateTime chequeDate;
  final String bankName;
  final DateTime? clearedDate;

  const ChequeDetail({required this.chequeNumber, required this.chequeDate, required this.bankName, this.clearedDate});

  factory ChequeDetail.fromJson(Map<String, dynamic> json) {
    return ChequeDetail(
      chequeNumber: json['cheque_number'] as String,
      chequeDate: DateTime.parse(json['cheque_date'] as String),
      bankName: json['bank_name'] as String,
      clearedDate: json['cleared_date'] != null ? DateTime.parse(json['cleared_date'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [chequeNumber, chequeDate, bankName, clearedDate];
}

class Payment extends Equatable {
  final String id;
  final String customerId;
  final String customerName;
  final String? saleId;
  final double amount;
  final String paymentMethod; // cash | upi | bank_transfer | cheque
  final DateTime paymentDate;
  final String status; // pending | cleared | cancelled
  final String? notes;
  final ChequeDetail? chequeDetail;

  const Payment({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.saleId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.status,
    this.notes,
    this.chequeDetail,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      saleId: json['sale_id'] as String?,
      amount: double.parse(json['amount'] as String),
      paymentMethod: json['payment_method'] as String,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      chequeDetail: json['cheque_detail'] != null ? ChequeDetail.fromJson(json['cheque_detail'] as Map<String, dynamic>) : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, customerId, customerName, saleId, amount, paymentMethod, paymentDate, status, notes, chequeDetail];
}
