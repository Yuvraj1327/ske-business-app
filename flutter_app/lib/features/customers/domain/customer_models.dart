import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNumber;
  final String? assignedSalesmanId;
  final bool isActive;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
    this.assignedSalesmanId,
    required this.isActive,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      gstNumber: json['gst_number'] as String?,
      assignedSalesmanId: json['assigned_salesman_id'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, address, gstNumber, assignedSalesmanId, isActive, createdAt];
}

class CustomerOutstanding extends Equatable {
  final double totalSales;
  final double totalPaid;
  final double totalReturned;
  final double outstanding;

  const CustomerOutstanding({
    required this.totalSales,
    required this.totalPaid,
    required this.totalReturned,
    required this.outstanding,
  });

  factory CustomerOutstanding.fromJson(Map<String, dynamic> json) {
    return CustomerOutstanding(
      totalSales: double.parse(json['total_sales'] as String),
      totalPaid: double.parse(json['total_paid'] as String),
      totalReturned: double.parse(json['total_returned'] as String),
      outstanding: double.parse(json['outstanding'] as String),
    );
  }

  @override
  List<Object?> get props => [totalSales, totalPaid, totalReturned, outstanding];
}

class LedgerEntry extends Equatable {
  final DateTime entryDate;
  final String entryType; // sale | payment | return
  final String referenceLabel;
  final double debit;
  final double credit;

  const LedgerEntry({
    required this.entryDate,
    required this.entryType,
    required this.referenceLabel,
    required this.debit,
    required this.credit,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryType: json['entry_type'] as String,
      referenceLabel: json['reference_label'] as String,
      debit: double.parse(json['debit'] as String),
      credit: double.parse(json['credit'] as String),
    );
  }

  @override
  List<Object?> get props => [entryDate, entryType, referenceLabel, debit, credit];
}

class CustomerLedger extends Equatable {
  final List<LedgerEntry> entries;
  final double outstanding;

  const CustomerLedger({required this.entries, required this.outstanding});

  factory CustomerLedger.fromJson(Map<String, dynamic> json) {
    return CustomerLedger(
      entries: (json['entries'] as List).map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList(),
      outstanding: double.parse(json['outstanding'] as String),
    );
  }

  @override
  List<Object?> get props => [entries, outstanding];
}
