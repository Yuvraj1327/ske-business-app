import 'package:equatable/equatable.dart';

class AppTransaction extends Equatable {
  final String id;
  final String transactionType; // cash | upi | bank
  final String direction; // in | out
  final double amount;
  final DateTime transactionDate;
  final String? relatedPaymentId;
  final String? relatedExpenseId;
  final String? referenceNote;

  const AppTransaction({
    required this.id,
    required this.transactionType,
    required this.direction,
    required this.amount,
    required this.transactionDate,
    this.relatedPaymentId,
    this.relatedExpenseId,
    this.referenceNote,
  });

  factory AppTransaction.fromJson(Map<String, dynamic> json) {
    return AppTransaction(
      id: json['id'] as String,
      transactionType: json['transaction_type'] as String,
      direction: json['direction'] as String,
      amount: double.parse(json['amount'] as String),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      relatedPaymentId: json['related_payment_id'] as String?,
      relatedExpenseId: json['related_expense_id'] as String?,
      referenceNote: json['reference_note'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, transactionType, direction, amount, transactionDate, relatedPaymentId, relatedExpenseId, referenceNote];
}
