import 'dart:convert';

import 'package:equatable/equatable.dart';

/// عملية محفوظة في طابور المزامنة تنتظر الإرسال للسيرفر.
class SyncOperation extends Equatable {
  const SyncOperation({
    required this.id,
    required this.operation,
    required this.entityId,
    required this.payload,
    required this.attempts,
    this.lastError,
  });

  factory SyncOperation.fromDb(Map<String, Object?> row) => SyncOperation(
    id: row['id']! as int,
    operation: row['operation']! as String,
    entityId: row['entity_id']! as String,
    payload: jsonDecode(row['payload']! as String) as Map<String, Object?>,
    attempts: row['attempts']! as int,
    lastError: row['last_error'] as String?,
  );

  final int id;

  /// نوع العملية، مثل `sale.create`. كل نوع له [SyncHandler] واحد.
  final String operation;

  /// معرف السجل المحلي المرتبط (مثل UUID الفاتورة).
  final String entityId;
  final Map<String, Object?> payload;
  final int attempts;
  final String? lastError;

  @override
  List<Object?> get props => [id, operation, entityId, payload, attempts, lastError];
}
