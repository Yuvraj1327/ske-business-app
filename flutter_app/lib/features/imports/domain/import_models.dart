import 'package:equatable/equatable.dart';

class ImportJob extends Equatable {
  final String id;
  final String fileName;
  final String entityType;
  final String status; // queued | processing | completed | failed
  final int? totalRows;
  final int successRows;
  final int failedRows;
  final String? errorMessage;
  final DateTime createdAt;

  const ImportJob({
    required this.id,
    required this.fileName,
    required this.entityType,
    required this.status,
    this.totalRows,
    required this.successRows,
    required this.failedRows,
    this.errorMessage,
    required this.createdAt,
  });

  factory ImportJob.fromJson(Map<String, dynamic> json) {
    return ImportJob(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      entityType: json['entity_type'] as String,
      status: json['status'] as String,
      totalRows: json['total_rows'] as int?,
      successRows: json['success_rows'] as int,
      failedRows: json['failed_rows'] as int,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, fileName, entityType, status, totalRows, successRows, failedRows, errorMessage, createdAt];
}

class ImportJobRow extends Equatable {
  final int rowNumber;
  final String status; // success | failed
  final String? errorMessage;

  const ImportJobRow({required this.rowNumber, required this.status, this.errorMessage});

  factory ImportJobRow.fromJson(Map<String, dynamic> json) {
    return ImportJobRow(
      rowNumber: json['row_number'] as int,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [rowNumber, status, errorMessage];
}
