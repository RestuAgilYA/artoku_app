// FILE: wallet_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WalletModel {
  final String id;
  final String name;
  final double balance;
  final int colorValue;
  final bool isLocked;

  WalletModel({
    required this.id,
    required this.name,
    required this.balance,
    required this.colorValue,
    this.isLocked = false,
  });

  // Factory method: Mengubah data mentah dari Firestore (JSON) menjadi Object WalletModel
  factory WalletModel.fromSnapshot(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      id: doc.id,
      name: data['name'] ?? 'Dompet',
      balance: (data['balance'] ?? 0).toDouble(),
      // Default warna teal jika null
      colorValue: data['color'] ?? 0xFF0F4C5C,
      isLocked: data['isLocked'] ?? false,
    );
  }

  // Helper untuk mendapatkan Color object langsung
  Color get color => Color(colorValue);
}

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
