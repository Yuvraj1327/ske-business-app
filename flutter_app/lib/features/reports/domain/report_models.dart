import '../../sales/domain/sale_models.dart';

class SalesReport {
  final int totalSalesCount;
  final double totalSalesAmount;
  final double totalDiscount;
  final List<SaleListItem> items;

  const SalesReport({required this.totalSalesCount, required this.totalSalesAmount, required this.totalDiscount, required this.items});

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      totalSalesCount: json['total_sales_count'] as int,
      totalSalesAmount: double.parse(json['total_sales_amount'] as String),
      totalDiscount: double.parse(json['total_discount'] as String),
      items: (json['items'] as List).map((e) => SaleListItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class CustomerReportRow {
  final String customerName;
  final int salesCount;
  final double salesTotal;
  final double outstanding;

  const CustomerReportRow({required this.customerName, required this.salesCount, required this.salesTotal, required this.outstanding});

  factory CustomerReportRow.fromJson(Map<String, dynamic> json) {
    return CustomerReportRow(
      customerName: json['customer_name'] as String,
      salesCount: json['sales_count'] as int,
      salesTotal: double.parse(json['sales_total'] as String),
      outstanding: double.parse(json['outstanding'] as String),
    );
  }
}

class MethodBreakdown {
  final String label;
  final int count;
  final double total;

  const MethodBreakdown({required this.label, required this.count, required this.total});
}

class PaymentReport {
  final List<MethodBreakdown> breakdown;

  const PaymentReport({required this.breakdown});

  factory PaymentReport.fromJson(Map<String, dynamic> json) {
    return PaymentReport(
      breakdown: (json['breakdown_by_method'] as List)
          .map((e) => MethodBreakdown(label: e['payment_method'] as String, count: e['count'] as int, total: double.parse(e['total'] as String)))
          .toList(),
    );
  }
}

class OutstandingReportRow {
  final String customerName;
  final String? phone;
  final double outstanding;

  const OutstandingReportRow({required this.customerName, this.phone, required this.outstanding});

  factory OutstandingReportRow.fromJson(Map<String, dynamic> json) {
    return OutstandingReportRow(
      customerName: json['customer_name'] as String,
      phone: json['phone'] as String?,
      outstanding: double.parse(json['outstanding'] as String),
    );
  }
}

class OutstandingReport {
  final List<OutstandingReportRow> items;
  final double grandTotal;

  const OutstandingReport({required this.items, required this.grandTotal});

  factory OutstandingReport.fromJson(Map<String, dynamic> json) {
    return OutstandingReport(
      items: (json['items'] as List).map((e) => OutstandingReportRow.fromJson(e as Map<String, dynamic>)).toList(),
      grandTotal: double.parse(json['grand_total_outstanding'] as String),
    );
  }
}

class ExpenseReport {
  final List<MethodBreakdown> breakdown;

  const ExpenseReport({required this.breakdown});

  factory ExpenseReport.fromJson(Map<String, dynamic> json) {
    return ExpenseReport(
      breakdown: (json['breakdown_by_category'] as List)
          .map((e) => MethodBreakdown(label: e['category_name'] as String, count: e['count'] as int, total: double.parse(e['total'] as String)))
          .toList(),
    );
  }
}

class SalesmanReportRow {
  final String salesmanName;
  final int customersCount;
  final int salesCount;
  final double salesTotal;
  final double outstandingTotal;

  const SalesmanReportRow({
    required this.salesmanName,
    required this.customersCount,
    required this.salesCount,
    required this.salesTotal,
    required this.outstandingTotal,
  });

  factory SalesmanReportRow.fromJson(Map<String, dynamic> json) {
    return SalesmanReportRow(
      salesmanName: json['salesman_name'] as String,
      customersCount: json['customers_count'] as int,
      salesCount: json['sales_count'] as int,
      salesTotal: double.parse(json['sales_total'] as String),
      outstandingTotal: double.parse(json['outstanding_total'] as String),
    );
  }
}

class TransactionReport {
  final double totalIn;
  final double totalOut;
  final double net;
  final List<MethodBreakdown> breakdown;

  const TransactionReport({required this.totalIn, required this.totalOut, required this.net, required this.breakdown});

  factory TransactionReport.fromJson(Map<String, dynamic> json) {
    return TransactionReport(
      totalIn: double.parse(json['total_in'] as String),
      totalOut: double.parse(json['total_out'] as String),
      net: double.parse(json['net'] as String),
      breakdown: (json['breakdown'] as List)
          .map((e) => MethodBreakdown(
                label: '${e['transaction_type']} (${e['direction']})',
                count: e['count'] as int,
                total: double.parse(e['total'] as String),
              ))
          .toList(),
    );
  }
}
