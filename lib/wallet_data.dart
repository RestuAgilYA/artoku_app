// FILE: wallet_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WalletModel {
  final String id;
  final String name;
  final double balance;
  final int colorValue;

  WalletModel({
    required this.id,
    required this.name,
    required this.balance,
    required this.colorValue,
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
    );
  }

  // Helper untuk mendapatkan Color object langsung
  Color get color => Color(colorValue);
}
