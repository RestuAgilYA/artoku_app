import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/features/report/data/pdf_helper.dart';
import 'package:artoku_app/features/report/data/csv_helper.dart';
import 'package:artoku_app/core/services/ui_helper.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final Color primaryColor = const Color(0xFF0F4C5C);
  final User? user = FirebaseAuth.instance.currentUser;

  int _selectedTab = 0; // 0 = Pengeluaran, 1 = Pemasukan
  late PageController _pageController;
  late Stream<QuerySnapshot> _expenseStream;
  late Stream<QuerySnapshot> _incomeStream;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
    if (user != null) {
      _expenseStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .snapshots();
      _incomeStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'income')
          .snapshots();
    } else {
      _expenseStream = const Stream.empty();
      _incomeStream = const Stream.empty();
    }
  }
  bool _isExporting = false;
  bool _isExportingCsv = false;

  // Date range for export
  DateTimeRange? _exportDateRange;

  Future<void> _pickDateRangeAndExport({required bool isPdf}) async {
    final now = DateTime.now();
    var startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    var endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    if (endOfMonth.isAfter(now)) endOfMonth = now;
    if (startOfMonth.isAfter(now)) startOfMonth = now; // Guard just in case

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now, // Dibatasi hingga hari ini (nowday)
      initialDateRange: _exportDateRange ?? DateTimeRange(
        start: startOfMonth,
        end: endOfMonth,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() => _exportDateRange = picked);

    if (isPdf) {
      _exportToPdf(picked);
    } else {
      _exportToCsv(picked);
    }
  }

  Future<void> _exportToPdf(DateTimeRange dateRange) async {
    if (user == null) return;
    setState(() => _isExporting = true);

    try {
      // 1. Fetch all collections in parallel
      final transactionFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .get();
      final transferFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transfers')
          .get();
      final debtFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('debts')
          .get();
      final goalFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('goals')
          .get();
      final patunganFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('patungans')
          .get();

      final results =
          await Future.wait([transactionFuture, transferFuture, debtFuture, goalFuture, patunganFuture]);
      final transactionSnapshot = results[0] as QuerySnapshot;
      final transferSnapshot = results[1] as QuerySnapshot;
      final debtSnapshot = results[2] as QuerySnapshot;
      final goalSnapshot = results[3] as QuerySnapshot;
      final patunganSnapshot = results[4] as QuerySnapshot;

      if (!mounted) return;

      // 2. Check if there is any data at all
      if (transactionSnapshot.docs.isEmpty && 
          transferSnapshot.docs.isEmpty && 
          debtSnapshot.docs.isEmpty && 
          goalSnapshot.docs.isEmpty && 
          patunganSnapshot.docs.isEmpty) {
        UIHelper.showInfo(context, "Info", "Tidak ada data untuk diekspor pada periode ini.");
        setState(() => _isExporting = false);
        return;
      }

      // 3. Call the updated PDF helper with date range
      await PdfHelper.generateReport(
        dateRange,
        transactionSnapshot.docs,
        transferSnapshot.docs,
        debtDocs: debtSnapshot.docs,
        goalDocs: goalSnapshot.docs,
        patunganDocs: patunganSnapshot.docs,
      );
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, "Gagal mengekspor PDF: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportToCsv(DateTimeRange dateRange) async {
    if (user == null) return;
    setState(() => _isExportingCsv = true);

    try {
      // 1. Fetch all collections in parallel
      final transactionFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .get();
      final transferFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transfers')
          .get();
      final debtFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('debts')
          .get();
      final goalFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('goals')
          .get();
      final patunganFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('patungans')
          .get();

      final results = await Future.wait([transactionFuture, transferFuture, debtFuture, goalFuture, patunganFuture]);
      final transactionSnapshot = results[0] as QuerySnapshot;
      final transferSnapshot = results[1] as QuerySnapshot;
      final debtSnapshot = results[2] as QuerySnapshot;
      final goalSnapshot = results[3] as QuerySnapshot;
      final patunganSnapshot = results[4] as QuerySnapshot;

      if (!mounted) return;

      // 2. Check if there is any data at all
      if (transactionSnapshot.docs.isEmpty && 
          transferSnapshot.docs.isEmpty && 
          debtSnapshot.docs.isEmpty && 
          goalSnapshot.docs.isEmpty && 
          patunganSnapshot.docs.isEmpty) {
        UIHelper.showInfo(context, "Info", "Tidak ada data untuk diekspor pada periode ini.");
        setState(() => _isExportingCsv = false);
        return;
      }

      // 3. Call the CSV helper with date range
      await CsvHelper.generateReport(
        dateRange,
        transactionSnapshot.docs,
        transferSnapshot.docs,
        debtDocs: debtSnapshot.docs,
        goalDocs: goalSnapshot.docs,
        patunganDocs: patunganSnapshot.docs,
      );
    } catch (e) {
      if (mounted) {
        UIHelper.showError(context, "Gagal mengekspor CSV: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingCsv = false);
      }
    }
  }

  // Helper Format
  String _formatCompactCurrency(double number) {
    if (number >= 1000000) return "${(number / 1000000).toStringAsFixed(1)}jt";
    if (number >= 1000) return "${(number / 1000).toStringAsFixed(0)}rb";
    return number.toStringAsFixed(0);
  }

  String _formatFullRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  String _getMonthYear(DateTime date) {
    List<String> months = [
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
    return "${months[date.month - 1]} ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Kita HAPUS AppBar standar agar bisa custom full header
      body: Column(
        children: [
          // 1. CUSTOM HEADER (Pengganti AppBar & DateSelector)
          _buildCustomHeader(),

          const SizedBox(height: 15),
          _buildToggleSwitch(cardColor, isDark),
          const SizedBox(height: 20),

          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _selectedTab = index);
              },
              children: [
                KeepAliveWrapper(
                  child: _buildChartTab(_expenseStream, true, isDark, primaryColor),
                ),
                KeepAliveWrapper(
                  child: _buildChartTab(_incomeStream, false, isDark, primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATE: Custom Header menggantikan AppBar & DateSelector lama
  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, bottom: 25, left: 20, right: 20),
      decoration: const BoxDecoration(
        // Gradient
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F4C5C), Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bubbles Decoration
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Content
          Column(
            children: [
              // Row 1: Tombol Back - Judul - PDF
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "Tren Keuangan",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // CSV Button
                      _isExportingCsv
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.table_chart_outlined,
                                color: Colors.white,
                              ),
                              tooltip: 'Export CSV',
                              onPressed: () => _pickDateRangeAndExport(isPdf: false),
                            ),
                      // PDF Button
                      _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.white,
                              ),
                              tooltip: 'Export PDF',
                              onPressed: () => _pickDateRangeAndExport(isPdf: true),
                            ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Row 2: Pemilih Bulan
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month - 1,
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    _getMonthYear(_selectedMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    onPressed: () => setState(
                      () => _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch(Color cardColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tabWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _selectedTab * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              Row(
                children: [
                  _toggleButton("Pengeluaran", 0),
                  _toggleButton("Pemasukan", 1),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggleButton(String title, int tabIndex) {
    bool isActive = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _pageController.animateToPage(
            tabIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
            child: Text(title),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 70,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 15),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildChartTab(Stream<QuerySnapshot> stream, bool isExpense, bool isDark, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Belum ada data.");
        }
        List<double> dailyTotals = List.filled(31, 0.0);
        double totalMonth = 0;
        double maxAmount = 0;
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          Timestamp? t = data['date'];
          if (t == null) continue;
          DateTime date = t.toDate();
          if (date.year == _selectedMonth.year && date.month == _selectedMonth.month) {
            double amount = (data['amount'] ?? 0).toDouble();
            int dayIndex = date.day - 1;
            dailyTotals[dayIndex] += amount;
            totalMonth += amount;
          }
        }
        for (var val in dailyTotals) {
          if (val > maxAmount) maxAmount = val;
        }
        if (maxAmount == 0) maxAmount = 100;
        maxAmount = maxAmount * 1.2;
        if (totalMonth == 0) {
          return _buildEmptyState("Tidak ada transaksi bulan ini.");
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              Text(
                "Total ${isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                style: TextStyle(color: Colors.grey.shade500),
              ),
              Text(
                _formatFullRupiah(totalMonth),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.redAccent : Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 300,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    return BarChart(
                      BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAmount,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            "Tgl ${group.x + 1}\n",
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            children: <TextSpan>[
                              TextSpan(
                                text: _formatCompactCurrency(rod.toY),
                                style: TextStyle(color: Colors.yellowAccent.shade100, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Text(
                              _formatCompactCurrency(value),
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            int day = value.toInt() + 1;
                            if (day == 1 || day % 5 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  day.toString(),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        // ignore: deprecated_member_use
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    barGroups: List.generate(31, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: dailyTotals[index] * animValue,
                            color: isExpense ? primaryColor : Colors.teal,
                            width: 6,
                            borderRadius: BorderRadius.circular(2),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxAmount,
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Grafik di atas menampilkan tren ${isExpense ? 'pengeluaran' : 'pemasukan'} Anda per hari dalam bulan ini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
