import 'package:equatable/equatable.dart';

class Salesman extends Equatable {
  final String id;
  final String fullName;
  final String? phone;
  final bool isActive;

  const Salesman({required this.id, required this.fullName, this.phone, required this.isActive});

  factory Salesman.fromJson(Map<String, dynamic> json) {
    return Salesman(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, fullName, phone, isActive];
}

class SalesmanPerformance extends Equatable {
  final String salesmanName;
  final int customersCount;
  final int salesCount;
  final double salesTotal;
  final double outstandingTotal;

  const SalesmanPerformance({
    required this.salesmanName,
    required this.customersCount,
    required this.salesCount,
    required this.salesTotal,
    required this.outstandingTotal,
  });

  factory SalesmanPerformance.fromJson(Map<String, dynamic> json) {
    return SalesmanPerformance(
      salesmanName: json['salesman_name'] as String,
      customersCount: json['customers_count'] as int,
      salesCount: json['sales_count'] as int,
      salesTotal: double.parse(json['sales_total'] as String),
      outstandingTotal: double.parse(json['outstanding_total'] as String),
    );
  }

  @override
  List<Object?> get props => [salesmanName, customersCount, salesCount, salesTotal, outstandingTotal];
}

class SalesTask extends Equatable {
  final String id;
  final String assignedTo;
  final String assignedToName;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String status; // pending | in_progress | completed | cancelled

  const SalesTask({
    required this.id,
    required this.assignedTo,
    required this.assignedToName,
    required this.title,
    this.description,
    this.dueDate,
    required this.status,
  });

  factory SalesTask.fromJson(Map<String, dynamic> json) {
    return SalesTask(
      id: json['id'] as String,
      assignedTo: json['assigned_to'] as String,
      assignedToName: json['assigned_to_name'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      status: json['status'] as String,
    );
  }

  @override
  List<Object?> get props => [id, assignedTo, assignedToName, title, description, dueDate, status];
}
