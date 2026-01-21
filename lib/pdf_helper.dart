import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfHelper {
  // Fungsi utama untuk generate dan print PDF
  static Future<void> generateMonthlyReport(
    DateTime selectedMonth,
    List<QueryDocumentSnapshot> transactionDocs,
    List<QueryDocumentSnapshot> transferDocs,
  ) async {
    final pdf = pw.Document();

    // 1. Hitung Ringkasan Data Transaksi
    double totalIncome = 0;
    double totalExpense = 0;

    final transactions = transactionDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] == null) return false;
      final date = (data['date'] as Timestamp).toDate();
      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    transactions.sort((a, b) {
      final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
      final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    for (var doc in transactions) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      if (data['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    // 2. Filter & Urutkan Riwayat Transfer
    final transfers = transferDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) return false;
      final date = (data['timestamp'] as Timestamp).toDate();
      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    transfers.sort((a, b) {
      final dateA =
          (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      final dateB =
          (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    // 3. Desain Halaman PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Laporan Keuangan',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('ArtoKu App',
                      style: const pw.TextStyle(
                          fontSize: 16, color: PdfColors.grey)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // INFO BULAN & RINGKASAN
            pw.Text(
              "Periode: ${_getMonthName(selectedMonth.month)} ${selectedMonth.year}",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem("Pemasukan", totalIncome, PdfColors.green),
                  _buildSummaryItem(
                      "Pengeluaran", totalExpense, PdfColors.red),
                  _buildSummaryItem(
                    "Sisa Saldo",
                    totalIncome - totalExpense,
                    (totalIncome - totalExpense) >= 0
                        ? PdfColors.blue
                        : PdfColors.orange,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // TABEL TRANSAKSI
            pw.Text(
              "Detail Transaksi",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Tanggal', 'Kategori', 'Catatan', 'Nominal'],
              data: transactions.isEmpty
                  ? [
                      ['Tidak ada data transaksi bulan ini.', '', '', '']
                    ]
                  : transactions.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();
                      final type = data['type'] ?? 'expense';
                      final amount = (data['amount'] ?? 0).toDouble();
                      final prefix = type == 'income' ? '+ ' : '- ';
                      return [
                        "${date.day}/${date.month}/${date.year}",
                        data['category'] ?? '-',
                        data['note'] ?? '-',
                        "$prefix${_formatCurrency(amount)}",
                      ];
                    }).toList(),
              border: null,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F4C5C)),
              rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                3: pw.Alignment.centerRight
              },
            ),
            pw.SizedBox(height: 30),

            // TABEL RIWAYAT TRANSFER
            pw.Text(
              "Riwayat Transfer Saldo",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Tanggal', 'Dari Dompet', 'Ke Dompet', 'Jumlah'],
              data: transfers.isEmpty
                  ? [
                      ['Tidak ada riwayat transfer bulan ini.', '', '', '']
                    ]
                  : transfers.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['timestamp'] as Timestamp).toDate();
                      final amount = (data['amount'] ?? 0).toDouble();
                      return [
                        "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}",
                        data['sourceWalletName'] ?? '-',
                        data['destinationWalletName'] ?? '-',
                        _formatCurrency(amount),
                      ];
                    }).toList(),
              border: null,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFF00897B)), // Warna beda
              rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                3: pw.Alignment.centerRight
              },
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.Theme.of(context)
                  .defaultTextStyle
                  .copyWith(color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    // 4. Tampilkan Preview / Print
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Laporan_${_getMonthName(selectedMonth.month)}_${selectedMonth.year}.pdf',
    );
  }

  static pw.Widget _buildSummaryItem(
    String title,
    double amount,
    PdfColor color,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          _formatCurrency(amount),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static String _getMonthName(int month) {
    const months = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return months[month - 1];
  }

  static String _formatCurrency(double amount) {
    return "Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }
}
