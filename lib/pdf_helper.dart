import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

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
    
    // Data untuk chart kategori
    Map<String, double> expenseByCategory = {};
    Map<String, double> incomeByCategory = {};
    
    // Data untuk chart harian (31 hari)
    List<double> dailyExpense = List.filled(31, 0.0);
    List<double> dailyIncome = List.filled(31, 0.0);

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
      final category = data['category'] ?? 'Lainnya';
      final date = (data['date'] as Timestamp).toDate();
      final dayIndex = date.day - 1;
      
      if (data['type'] == 'income') {
        totalIncome += amount;
        incomeByCategory[category] = (incomeByCategory[category] ?? 0) + amount;
        dailyIncome[dayIndex] += amount;
      } else {
        totalExpense += amount;
        expenseByCategory[category] = (expenseByCategory[category] ?? 0) + amount;
        dailyExpense[dayIndex] += amount;
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
            pw.SizedBox(height: 25),
            
            // ========== CHART: PERBANDINGAN PEMASUKAN VS PENGELUARAN ==========
            pw.Text(
              "Perbandingan Pemasukan vs Pengeluaran",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildIncomeExpenseBarChart(totalIncome, totalExpense),
            pw.SizedBox(height: 25),
            
            // ========== CHART: TREN HARIAN ==========
            pw.Text(
              "Tren Harian",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildDailyTrendChart(dailyIncome, dailyExpense, selectedMonth),
            pw.SizedBox(height: 25),
            
            // ========== CHART: DISTRIBUSI KATEGORI PENGELUARAN ==========
            if (expenseByCategory.isNotEmpty) ...[
              pw.Text(
                "Distribusi Pengeluaran per Kategori",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildCategoryBreakdown(expenseByCategory, totalExpense, true),
              pw.SizedBox(height: 25),
            ],
            
            // ========== CHART: DISTRIBUSI KATEGORI PEMASUKAN ==========
            if (incomeByCategory.isNotEmpty) ...[
              pw.Text(
                "Distribusi Pemasukan per Kategori",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildCategoryBreakdown(incomeByCategory, totalIncome, false),
              pw.SizedBox(height: 25),
            ],

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
  
  // ========== CHART HELPERS ==========
  
  /// Bar Chart: Perbandingan Pemasukan vs Pengeluaran
  static pw.Widget _buildIncomeExpenseBarChart(double income, double expense) {
    final maxValue = math.max(income, expense);
    if (maxValue == 0) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Text("Tidak ada data untuk ditampilkan", 
          style: const pw.TextStyle(color: PdfColors.grey)),
      );
    }
    
    final incomeWidth = (income / maxValue) * 400;
    final expenseWidth = (expense / maxValue) * 400;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Pemasukan Bar
          pw.Row(
            children: [
              pw.SizedBox(
                width: 80,
                child: pw.Text("Pemasukan", style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Container(
                width: incomeWidth,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.green,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(_formatCompact(income), 
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 10),
          // Pengeluaran Bar
          pw.Row(
            children: [
              pw.SizedBox(
                width: 80,
                child: pw.Text("Pengeluaran", style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Container(
                width: expenseWidth,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.red,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(_formatCompact(expense), 
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Line-style Chart: Tren Harian
  static pw.Widget _buildDailyTrendChart(
    List<double> dailyIncome, 
    List<double> dailyExpense,
    DateTime selectedMonth,
  ) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final maxValue = math.max(
      dailyIncome.reduce(math.max),
      dailyExpense.reduce(math.max),
    );
    
    if (maxValue == 0) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Text("Tidak ada data untuk ditampilkan", 
          style: const pw.TextStyle(color: PdfColors.grey)),
      );
    }
    
    const chartHeight = 80.0;
    const chartWidth = 480.0;
    final barWidth = chartWidth / daysInMonth - 2;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          // Chart Area
          pw.SizedBox(
            height: chartHeight,
            width: chartWidth,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: List.generate(daysInMonth, (i) {
                final incomeHeight = (dailyIncome[i] / maxValue) * chartHeight;
                final expenseHeight = (dailyExpense[i] / maxValue) * chartHeight;
                return pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          width: barWidth / 2 - 1,
                          height: incomeHeight > 0 ? incomeHeight : 1,
                          color: incomeHeight > 0 ? PdfColors.green : PdfColors.grey200,
                        ),
                        pw.SizedBox(width: 1),
                        pw.Container(
                          width: barWidth / 2 - 1,
                          height: expenseHeight > 0 ? expenseHeight : 1,
                          color: expenseHeight > 0 ? PdfColors.red : PdfColors.grey200,
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
          pw.SizedBox(height: 5),
          // X-axis labels (show every 5 days)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("1", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("5", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("10", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("15", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("20", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("25", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text("$daysInMonth", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
          pw.SizedBox(height: 10),
          // Legend
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 12, height: 12, color: PdfColors.green),
              pw.SizedBox(width: 5),
              pw.Text("Pemasukan", style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 20),
              pw.Container(width: 12, height: 12, color: PdfColors.red),
              pw.SizedBox(width: 5),
              pw.Text("Pengeluaran", style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Horizontal Bar Chart: Distribusi per Kategori
  static pw.Widget _buildCategoryBreakdown(
    Map<String, double> categoryData, 
    double total,
    bool isExpense,
  ) {
    if (categoryData.isEmpty || total == 0) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Text("Tidak ada data untuk ditampilkan", 
          style: const pw.TextStyle(color: PdfColors.grey)),
      );
    }
    
    // Sort by value descending
    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 8 categories
    final topCategories = sortedEntries.take(8).toList();
    
    final barColor = isExpense ? PdfColors.red : PdfColors.green;
    final maxValue = topCategories.first.value;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: topCategories.map((entry) {
          final percentage = (entry.value / total * 100);
          final barWidth = (entry.value / maxValue) * 350;
          
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(
                    entry.key.length > 12 ? '${entry.key.substring(0, 12)}...' : entry.key,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Container(
                  width: barWidth,
                  height: 14,
                  decoration: pw.BoxDecoration(
                    color: barColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  "${percentage.toStringAsFixed(1)}%",
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  /// Format angka ke format compact (1.5jt, 500rb)
  static String _formatCompact(double number) {
    if (number >= 1000000) return "${(number / 1000000).toStringAsFixed(1)}jt";
    if (number >= 1000) return "${(number / 1000).toStringAsFixed(0)}rb";
    return number.toStringAsFixed(0);
  }
}
