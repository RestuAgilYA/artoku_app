// FILE: transfer_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TransferModel {
  final String id;
  final String sourceWalletId;
  final String sourceWalletName;
  final String destinationWalletId;
  final String destinationWalletName;
  final double amount;
  final String notes;
  final Timestamp timestamp;

  TransferModel({
    required this.id,
    required this.sourceWalletId,
    required this.sourceWalletName,
    required this.destinationWalletId,
    required this.destinationWalletName,
    required this.amount,
    required this.timestamp,
    this.notes = '',
  });

  factory TransferModel.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransferModel(
      id: doc.id,
      sourceWalletId: data['sourceWalletId'] ?? '',
      sourceWalletName: data['sourceWalletName'] ?? 'N/A',
      destinationWalletId: data['destinationWalletId'] ?? '',
      destinationWalletName: data['destinationWalletName'] ?? 'N/A',
      amount: (data['amount'] ?? 0).toDouble(),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      notes: data['notes'] ?? '',
    );
  }
}
