import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CsvHelper {
  /// Backward compatibility wrapper
  static Future<void> generateMonthlyReport(
    DateTime selectedMonth,
    List<QueryDocumentSnapshot> transactionDocs,
    List<QueryDocumentSnapshot> transferDocs, {
    List<QueryDocumentSnapshot>? debtDocs,
    List<QueryDocumentSnapshot>? goalDocs,
    List<QueryDocumentSnapshot>? patunganDocs,
  }) async {
    final range = DateTimeRange(
      start: DateTime(selectedMonth.year, selectedMonth.month, 1),
      end: DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59),
    );
    return generateReport(range, transactionDocs, transferDocs, debtDocs: debtDocs, goalDocs: goalDocs, patunganDocs: patunganDocs);
  }

  /// Generate dan share CSV untuk laporan dengan date range
  static Future<void> generateReport(
    DateTimeRange dateRange,
    List<QueryDocumentSnapshot> transactionDocs,
    List<QueryDocumentSnapshot> transferDocs, {
    List<QueryDocumentSnapshot>? debtDocs,
    List<QueryDocumentSnapshot>? goalDocs,
    List<QueryDocumentSnapshot>? patunganDocs,
  }) async {
    final periodLabel = '${_formatDate(dateRange.start)} - ${_formatDate(dateRange.end)}';

    // 1. Filter transaksi berdasarkan date range
    final transactions = transactionDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] == null) return false;
      final date = (data['date'] as Timestamp).toDate();
      return !date.isBefore(dateRange.start) && 
             !date.isAfter(DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59));
    }).toList();

    // Sort by date descending
    transactions.sort((a, b) {
      final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
      final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    // 2. Filter transfers berdasarkan date range
    final transfers = transferDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) return false;
      final date = (data['timestamp'] as Timestamp).toDate();
      return !date.isBefore(dateRange.start) && 
             !date.isAfter(DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59));
    }).toList();

    transfers.sort((a, b) {
      final dateA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      final dateB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    // 3. Buat data untuk CSV - Transaksi
    List<List<dynamic>> transactionRows = [
      ['=== LAPORAN KEUANGAN ARTOKU ==='],
      ['Periode: $periodLabel'],
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

    // 5b. Tambah data piutang/utang jika ada
    final debts = (debtDocs ?? []).where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isPaid = data['isPaid'] == true;
      if (data['createdAt'] == null) return !isPaid; // Kalau ga ada tanggal, tampilkan kalau masih aktif
      final date = (data['createdAt'] as Timestamp).toDate();
      
      final isInRange = !date.isBefore(dateRange.start) && 
             !date.isAfter(DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59));
             
      return isInRange || !isPaid;
    }).toList();

    if (debts.isNotEmpty) {
      transactionRows.addAll([
        [],
        ['--- PIUTANG & UTANG ---'],
        ['Tanggal', 'Tipe', 'Nama', 'Jumlah (Rp)', 'Status', 'Keterangan'],
      ]);

      for (var doc in debts) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['createdAt'] as Timestamp).toDate();
        final type = data['type'] == 'piutang' ? 'Piutang' : 'Utang';
        final amount = (data['amount'] ?? 0).toDouble();
        final status = data['isPaid'] == true ? 'Lunas' : 'Belum Lunas';

        transactionRows.add([
          _formatDate(date),
          type,
          data['personName'] ?? '-',
          amount.toStringAsFixed(0),
          status,
          data['note'] ?? '-',
        ]);
      }
    }

    // 5c. Tambah data target tabungan jika ada
    final goals = (goalDocs ?? []).where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'active';
      final isActive = status == 'active';
      
      if (data['createdAt'] == null) return isActive;
      final date = (data['createdAt'] as Timestamp).toDate();
      
      final isInRange = !date.isBefore(dateRange.start) && 
             !date.isAfter(DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59));
             
      return isInRange || isActive;
    }).toList();

    if (goals.isNotEmpty) {
      transactionRows.addAll([
        [],
        ['--- TARGET TABUNGAN ---'],
        ['Catatan: Alokasi tabungan tidak dihitung sebagai pengeluaran utama'],
        ['Tanggal Dibuat', 'Nama Target', 'Target (Rp)', 'Terkumpul (Rp)', 'Status'],
      ]);

      for (var doc in goals) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['createdAt'] as Timestamp).toDate();
        final targetAmount = (data['targetAmount'] ?? 0).toDouble();
        final currentAmount = (data['currentAmount'] ?? 0).toDouble();
        final status = data['status'] == 'completed' ? 'Tercapai' : 'Proses';

        transactionRows.add([
          _formatDate(date),
          data['name'] ?? '-',
          targetAmount.toStringAsFixed(0),
          currentAmount.toStringAsFixed(0),
          status,
        ]);
      }
    }

    // 5d. Tambah data patungan jika ada
    final patungans = (patunganDocs ?? []).where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isCompleted = data['isCompleted'] == true;
      
      if (data['createdAt'] == null) return !isCompleted;
      final date = (data['createdAt'] as Timestamp).toDate();
      
      final isInRange = !date.isBefore(dateRange.start) && 
             !date.isAfter(DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59));
             
      return isInRange || !isCompleted;
    }).toList();

    if (patungans.isNotEmpty) {
      transactionRows.addAll([
        [],
        ['--- DAFTAR PATUNGAN ---'],
        ['Tanggal Dibuat', 'Nama Patungan', 'Total (Rp)', 'Status'],
      ]);

      for (var doc in patungans) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['createdAt'] as Timestamp).toDate();
        final totalAmount = (data['totalAmount'] ?? 0).toDouble();
        final status = data['isCompleted'] == true ? 'Selesai' : 'Aktif';

        transactionRows.add([
          _formatDate(date),
          data['title'] ?? '-',
          totalAmount.toStringAsFixed(0),
          status,
        ]);
      }
    }

    // 6. Convert ke CSV string
    String csvData = const ListToCsvConverter().convert(transactionRows);

    // 7. Simpan ke file
    final directory = await getTemporaryDirectory();
    final dateStartStr = _formatDate(dateRange.start).replaceAll('/', '-');
    final dateEndStr = _formatDate(dateRange.end).replaceAll('/', '-');
    final fileName = 'ArtoKu_Laporan_${dateStartStr}_$dateEndStr.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvData);

    // 8. Share file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Laporan Keuangan ArtoKu - $periodLabel',
    );
  }

  /// Format tanggal ke string readable
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
