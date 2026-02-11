import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CsvHelper {
  /// Generate dan share CSV untuk laporan bulanan
  static Future<void> generateMonthlyReport(
    DateTime selectedMonth,
    List<QueryDocumentSnapshot> transactionDocs,
    List<QueryDocumentSnapshot> transferDocs,
  ) async {
    // 1. Filter transaksi berdasarkan bulan
    final transactions = transactionDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] == null) return false;
      final date = (data['date'] as Timestamp).toDate();
      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    // Sort by date descending
    transactions.sort((a, b) {
      final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
      final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    // 2. Filter transfers berdasarkan bulan
    final transfers = transferDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) return false;
      final date = (data['timestamp'] as Timestamp).toDate();
      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    transfers.sort((a, b) {
      final dateA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      final dateB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    // 3. Buat data untuk CSV - Transaksi
    List<List<dynamic>> transactionRows = [
      ['=== LAPORAN KEUANGAN ARTOKU ==='],
      ['Periode: ${_getMonthName(selectedMonth.month)} ${selectedMonth.year}'],
      [],
      ['--- RIWAYAT TRANSAKSI ---'],
      ['Tanggal', 'Tipe', 'Kategori', 'Jumlah (Rp)', 'Catatan'],
    ];

    double totalIncome = 0;
    double totalExpense = 0;

    for (var doc in transactions) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp).toDate();
      final type = data['type'] ?? '';
      final category = data['category'] ?? '-';
      final amount = (data['amount'] ?? 0).toDouble();
      final note = data['note'] ?? '-';

      if (type == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }

      transactionRows.add([
        _formatDate(date),
        type == 'income' ? 'Pemasukan' : 'Pengeluaran',
        category,
        amount.toStringAsFixed(0),
        note,
      ]);
    }

    // 4. Tambah ringkasan transaksi
    transactionRows.addAll([
      [],
      ['--- RINGKASAN TRANSAKSI ---'],
      ['Total Pemasukan', '', '', totalIncome.toStringAsFixed(0), ''],
      ['Total Pengeluaran', '', '', totalExpense.toStringAsFixed(0), ''],
      ['Selisih (Nett)', '', '', (totalIncome - totalExpense).toStringAsFixed(0), ''],
    ]);

    // 5. Tambah data transfer jika ada
    if (transfers.isNotEmpty) {
      transactionRows.addAll([
        [],
        ['--- RIWAYAT TRANSFER ANTAR WALLET ---'],
        ['Tanggal', 'Dari Wallet', 'Ke Wallet', 'Jumlah (Rp)', 'Catatan'],
      ]);

      for (var doc in transfers) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['timestamp'] as Timestamp).toDate();
        final fromWallet = data['fromWalletName'] ?? '-';
        final toWallet = data['toWalletName'] ?? '-';
        final amount = (data['amount'] ?? 0).toDouble();
        final note = data['note'] ?? '-';

        transactionRows.add([
          _formatDate(date),
          fromWallet,
          toWallet,
          amount.toStringAsFixed(0),
          note,
        ]);
      }
    }

    // 6. Convert ke CSV string
    String csvData = const ListToCsvConverter().convert(transactionRows);

    // 7. Simpan ke file
    final directory = await getTemporaryDirectory();
    final fileName = 'ArtoKu_Laporan_${_getMonthName(selectedMonth.month)}_${selectedMonth.year}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvData);

    // 8. Share file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Laporan Keuangan ArtoKu - ${_getMonthName(selectedMonth.month)} ${selectedMonth.year}',
    );
  }

  /// Format tanggal ke string readable
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Get nama bulan dalam Bahasa Indonesia
  static String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }
}
