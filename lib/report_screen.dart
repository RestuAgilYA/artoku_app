import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pdf_helper.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final Color primaryColor = const Color(0xFF0F4C5C);
  final User? user = FirebaseAuth.instance.currentUser;

  bool _isExpense = true;
  DateTime _selectedMonth = DateTime.now();
  bool _isExporting = false;

  Future<void> _exportToPdf() async {
    if (user == null) return;
    setState(() => _isExporting = true);

    try {
      // 1. Fetch both collections in parallel
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

      final results =
          await Future.wait([transactionFuture, transferFuture]);
      final transactionSnapshot = results[0] as QuerySnapshot;
      final transferSnapshot = results[1] as QuerySnapshot;

      if (!mounted) return;

      // 2. Check if there is any data at all
      if (transactionSnapshot.docs.isEmpty && transferSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak ada data untuk diekspor.")));
        setState(() => _isExporting = false);
        return;
      }

      // 3. Call the updated PDF helper
      await PdfHelper.generateMonthlyReport(
        _selectedMonth,
        transactionSnapshot.docs,
        transferSnapshot.docs,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal mengekspor PDF: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('transactions')
                  .where('type', isEqualTo: _isExpense ? 'expense' : 'income')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("Belum ada data.");
                }

                // --- LOGIKA BAR CHART ---
                List<double> dailyTotals = List.filled(31, 0.0);
                double totalMonth = 0;
                double maxAmount = 0;

                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  Timestamp? t = data['date'];
                  if (t == null) continue;

                  DateTime date = t.toDate();

                  if (date.year == _selectedMonth.year &&
                      date.month == _selectedMonth.month) {
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
                        "Total ${_isExpense ? 'Pengeluaran' : 'Pemasukan'}",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      Text(
                        _formatFullRupiah(totalMonth),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isExpense ? Colors.redAccent : Colors.green,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        height: 300,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxAmount,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (group) => Colors.blueGrey,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        "Tgl ${group.x + 1}\n",
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: <TextSpan>[
                                          TextSpan(
                                            text: _formatCompactCurrency(
                                              rod.toY,
                                            ),
                                            style: TextStyle(
                                              color:
                                                  Colors.yellowAccent.shade100,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0)
                                      return const SizedBox.shrink();
                                    return Text(
                                      _formatCompactCurrency(value),
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (double value, TitleMeta meta) {
                                        int day = value.toInt() + 1;
                                        if (day == 1 || day % 5 == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8.0,
                                            ),
                                            child: Text(
                                              day.toString(),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
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
                                color: Colors.grey.withOpacity(0.1),
                                strokeWidth: 1,
                              ),
                            ),
                            barGroups: List.generate(31, (index) {
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: dailyTotals[index],
                                    color: _isExpense
                                        ? primaryColor
                                        : Colors.teal,
                                    width: 6,
                                    borderRadius: BorderRadius.circular(2),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: maxAmount,
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey.shade100,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "Grafik di atas menampilkan tren ${_isExpense ? 'pengeluaran' : 'pemasukan'} Anda per hari dalam bulan ini.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                          onPressed: _exportToPdf,
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _toggleButton("Pengeluaran", _isExpense),
          _toggleButton("Pemasukan", !_isExpense),
        ],
      ),
    );
  }

  Widget _toggleButton(String title, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isExpense = title == "Pengeluaran"),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
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
}
