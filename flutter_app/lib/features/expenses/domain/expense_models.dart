import 'package:equatable/equatable.dart';

class ExpenseCategory extends Equatable {
  final String id;
  final String name;
  final bool isActive;

  const ExpenseCategory({required this.id, required this.name, required this.isActive});

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(id: json['id'] as String, name: json['name'] as String, isActive: json['is_active'] as bool);
  }

  @override
  List<Object?> get props => [id, name, isActive];
}

class Expense extends Equatable {
  final String id;
  final String categoryId;
  final String categoryName;
  final double amount;
  final DateTime expenseDate;
  final String? description;
  final String status; // active | voided

  const Expense({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.expenseDate,
    this.description,
    required this.status,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      amount: double.parse(json['amount'] as String),
      expenseDate: DateTime.parse(json['expense_date'] as String),
      description: json['description'] as String?,
      status: json['status'] as String,
    );
  }

  @override
  List<Object?> get props => [id, categoryId, categoryName, amount, expenseDate, description, status];
}
