import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/services/ui_helper.dart';

class DetailTransactionScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const DetailTransactionScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color cardColor = Theme.of(context).cardColor;

    // Ambil data dari Map
    String title = data['title'] ?? 'Tanpa Judul';
    String price = data['price'] ?? 'Rp 0';
    String date = data['date'] ?? '-';
    String note = data['note'] ?? '-';
    String walletName = data['walletName'] ?? 'Dompet';
    String type = data['type'] ?? 'expense';

    // Warna tema berdasarkan data
    Color color = data['color'] is int
        ? Color(data['color'])
        : (data['color'] as Color? ?? Colors.grey);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Detail Transaksi",
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
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'expense' ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 40,
              ),
            ),

            const SizedBox(height: 20),

            // 2. JUDUL & NOMINAL
            Text(
              title,
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            Text(
              price,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
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
                  _buildDetailRow("Tanggal", date, textColor),
                  const Divider(height: 30),
                  _buildDetailRow(
                    "Kategori",
                    title,
                    textColor,
                  ), // Kategori biasanya sama dengan title di logic kita
                  const Divider(height: 30),
                  _buildDetailRow("Dompet", walletName, textColor),
                  const Divider(height: 30),
                  _buildDetailRow("Catatan", note, textColor, isNote: true),
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
                  "Hapus Transaksi",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _confirmDelete(
                  context,
                  data['id'],
                  data['amount'],
                  data['walletId'],
                  type,
                ),
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
    Color textColor, {
    bool isNote = false,
  }) {
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
              fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  // LOGIKA HAPUS (Copy logic dari Dashboard agar konsisten)
  void _confirmDelete(
    BuildContext context,
    String? docId,
    dynamic amountRaw,
    String? walletId,
    String type,
  ) {
    if (docId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Transaksi?"),
        content: const Text(
          "Data akan dihapus permanen dan saldo dikembalikan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              // 1. Hapus Dokumen
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('transactions')
                    .doc(docId)
                    .delete();

                // 2. Refund Saldo
                if (walletId != null) {
                  final walletRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('wallets')
                      .doc(walletId);
                  double amount = (amountRaw ?? 0).toDouble();

                  // Kalau Expense dihapus -> Saldo Nambah
                  // Kalau Income dihapus -> Saldo Kurang
                  double refund = (type == 'expense') ? amount : -amount;

                  await walletRef.update({
                    'balance': FieldValue.increment(refund),
                  });
                }
              }

              if (context.mounted) {
                Navigator.pop(context); // Tutup Dialog
                Navigator.pop(context); // Balik Dashboard

                // GANTI SNACKBAR LAMA DENGAN UIHELPER
                UIHelper.showSuccess(
                  context,
                  "Terhapus",
                  "Transaksi berhasil dihapus dan saldo dikembalikan.",
                );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
