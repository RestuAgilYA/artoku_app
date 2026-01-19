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
    String? walletIdRaw, // Kita ubah nama param biar gak bingung
    String typeRaw,
  ) {
    if (docId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Transaksi?"),
        content: const Text(
          "Data akan dihapus permanen. Saldo dompet akan dikembalikan (jika data valid).",
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
              
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              try {
                // 1. AMBIL DATA FRESH DARI DATABASE (PENTING!)
                // Kita tidak percaya data dari layar sebelumnya, kita ambil langsung dari sumbernya.
                final docRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('transactions')
                    .doc(docId);
                
                final docSnap = await docRef.get();
                
                if (!docSnap.exists) {
                   UIHelper.showError(context, "Error: Data transaksi tidak ditemukan di DB!");
                   return;
                }

                final data = docSnap.data() as Map<String, dynamic>;
                
                // 2. DIAGNOSA DATA
                String? realWalletId = data['walletId'];
                String realType = data['type'] ?? 'expense';
                
                // Parsing Amount Super Aman (Handle String/Int/Double)
                double realAmount = 0;
                if (data['amount'] is int) {
                  realAmount = (data['amount'] as int).toDouble();
                } else if (data['amount'] is double) {
                  realAmount = data['amount'];
                } else if (data['amount'] is String) {
                  realAmount = double.tryParse(data['amount']) ?? 0;
                }

                // Cek Tipe Bahasa (Inggris/Indo)
                bool isExpense = (realType == 'expense' || realType == 'Pengeluaran');

                // 3. DEBUGGING: TAMPILKAN APA YANG DIBACA APLIKASI
                // Jika walletId null, kita akan tahu disini.
                if (realWalletId == null || realWalletId.isEmpty) {
                   UIHelper.showError(context, "Gagal Refund: ID Dompet Kosong di Database!");
                   // Tetap hapus history biar gak nyangkut, tapi saldo ga balik
                   await docRef.delete();
                   Navigator.pop(context); 
                   return;
                }

                // 4. EKSEKUSI REFUND
                final walletRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('wallets')
                    .doc(realWalletId);
                
                // Cek apakah dompetnya beneran ada?
                final walletSnap = await walletRef.get();
                if (!walletSnap.exists) {
                   UIHelper.showError(context, "Gagal Refund: Dompet dengan ID '$realWalletId' sudah dihapus!");
                   await docRef.delete();
                   Navigator.pop(context);
                   return;
                }

                // Hitung Refund
                double refund = isExpense ? realAmount : -realAmount;

                // Update Saldo
                await walletRef.update({
                  'balance': FieldValue.increment(refund),
                });

                // Hapus Transaksi
                await docRef.delete();

                if (context.mounted) {
                  Navigator.pop(context); // Balik ke Dashboard
                  
                  // PESAN SUKSES DENGAN DETAIL
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Sukses! Saldo dikembalikan: Rp ${realAmount.toStringAsFixed(0)} ke Dompet."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

              } catch (e) {
                if (context.mounted) {
                  UIHelper.showError(context, "Error Sistem: $e");
                }
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
