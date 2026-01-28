import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ExportService {
  // Fungsi utama untuk export
  static Future<void> exportToCSV() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Ambil semua data transaksi dari Firestore
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      // 2. Siapkan Header CSV
      List<List<dynamic>> rows = [];
      rows.add([
        "Tanggal",
        "Kategori",
        "Catatan",
        "Tipe",
        "Nominal (Rp)",
        "Dompet",
      ]);

      // 3. Masukkan data ke baris
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Format Tanggal
        DateTime date = (data['date'] as Timestamp).toDate();
        String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);

        rows.add([
          formattedDate,
          data['category'] ?? '-',
          data['note'] ?? '-',
          data['type'] == 'expense' ? 'Pengeluaran' : 'Pemasukan',
          data['amount'] ?? 0,
          data['walletName'] ?? '-',
        ]);
      }

      // 4. Konversi ke String CSV
      String csvData = const ListToCsvConverter().convert(rows);

      // 5. Simpan ke file temporary
      final String dir = (await getTemporaryDirectory()).path;
      final String path =
          "$dir/Laporan_ArtoKu_${DateTime.now().millisecondsSinceEpoch}.csv";

      final File file = File(path);
      await file.writeAsString(csvData);

      // 6. Bagikan File (Share Sheet)
      await Share.shareXFiles([XFile(path)], text: 'Laporan Keuangan ArtoKu');
    } catch (e) {
      // ignore: avoid_print
      print("Error Export CSV: $e");
      rethrow; // Lempar error agar bisa ditangkap di UI
    }
  }
}
