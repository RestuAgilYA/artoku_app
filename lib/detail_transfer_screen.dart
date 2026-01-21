import 'package:artoku_app/services/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'wallet_data.dart';

class DetailTransferScreen extends StatelessWidget {
  final TransferModel transfer;

  const DetailTransferScreen({super.key, required this.transfer});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color cardColor = Theme.of(context).cardColor;
    final formattedDate =
        DateFormat('dd MMM yyyy, HH:mm').format(transfer.timestamp.toDate());
    final formattedAmount = UIHelper.formatRupiah(transfer.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Detail Transfer",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. ICON BESAR
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C5C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: Color(0xFF0F4C5C),
                size: 40,
              ),
            ),

            const SizedBox(height: 20),

            // 2. JUDUL & NOMINAL
            Text(
              '${transfer.sourceWalletName} → ${transfer.destinationWalletName}',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              formattedAmount,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 40),

            // 3. KARTU DETAIL
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow("Tanggal", formattedDate, textColor),
                  const Divider(height: 30),
                  _buildDetailRow(
                      "Dari Dompet", transfer.sourceWalletName, textColor),
                  const Divider(height: 30),
                  _buildDetailRow("Ke Dompet", transfer.destinationWalletName,
                      textColor),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 4. TOMBOL HAPUS
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  "Hapus Transfer",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _confirmDelete(context, transfer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color textColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, TransferModel transfer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Transfer?"),
        content: const Text(
          "Data akan dihapus permanen. Saldo dompet akan dikembalikan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Tutup Dialog dulu
              _deleteTransfer(context, transfer);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransfer(
      BuildContext context, TransferModel transfer) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Delete transfer document
      final transferDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transfers')
          .doc(transfer.id);
      batch.delete(transferDocRef);

      // Revert wallet balances
      final sourceWalletRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wallets')
          .doc(transfer.sourceWalletId);
      batch.update(sourceWalletRef, {'balance': FieldValue.increment(transfer.amount)});

      final destinationWalletRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wallets')
          .doc(transfer.destinationWalletId);
      batch.update(
          destinationWalletRef, {'balance': FieldValue.increment(-transfer.amount)});

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Balik ke halaman sebelumnya
        UIHelper.showSuccess(
          context,
          "Berhasil",
          "Riwayat transfer telah dihapus.",
        );
      }
    } catch (e) {
      if (context.mounted) {
        UIHelper.showError(context, "Gagal menghapus transfer: $e");
      }
    }
  }
}
