import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  DateTime _selectedMonth = DateTime.now();
  int _touchedIndex = -1;

  // 0 = Pengeluaran, 1 = Pemasukan, 2 = Banding (Arus Kas)
  int _viewMode = 0;

  // Warna Kategori Pengeluaran
  final Map<String, Color> _expenseColors = {
    'Makanan': const Color(0xFFEF5350), // Merah
    'Transport': const Color(0xFF42A5F5), // Biru
    'Belanja': const Color(0xFFAB47BC), // Ungu
    'Tagihan': const Color(0xFFFFA726), // Orange
    'Hiburan': const Color(0xFF26C6DA), // Cyan
    'Lainnya': const Color(0xFF78909C), // Abu-abu
  };

  // Warna Kategori Pemasukan
  final Map<String, Color> _incomeColors = {
    'Gaji': const Color(0xFF66BB6A), // Hijau
    'Bonus': const Color(0xFFFFD700), // Emas
    'Investasi': const Color(0xFF1E88E5), // Biru Tua
    'Hadiah': const Color(0xFFEC407A), // Pink
    'Lainnya': const Color(0xFF78909C), // Abu-abu
  };

  String _formatRupiah(num number) {
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
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;

    // [FIX] Variabel activeColor yang tidak terpakai sudah dihapus

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Analisa Keuangan",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. FILTER BULAN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: textColor),
                  onPressed: () => setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    ),
                  ),
                ),
                Text(
                  _getMonthYear(_selectedMonth),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: textColor),
                  onPressed: () => setState(
                    () => _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. TOGGLE SWITCH 3 MODE
          Container(
            height: 45,
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                _buildToggleButton("Keluar", 0, const Color(0xFF0F4C5C)),
                _buildToggleButton("Masuk", 1, const Color(0xFF00897B)),
                _buildToggleButton("Banding", 2, Colors.blueAccent),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. KONTEN CHART
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _viewMode == 2
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .collection('transactions')
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .collection('transactions')
                        .where(
                          'type',
                          isEqualTo: _viewMode == 0 ? 'expense' : 'income',
                        )
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("Belum ada data transaksi.");
                }

                // --- GROUPING DATA ---
                Map<String, double> dataMap = {};
                double grandTotal = 0;

                double totalIncome = 0;
                double totalExpense = 0;
                bool hasDataThisMonth = false;

                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  Timestamp? t = data['date'];
                  if (t == null) continue;
                  DateTime date = t.toDate();

                  if (date.year != _selectedMonth.year ||
                      date.month != _selectedMonth.month)
                    continue;

                  hasDataThisMonth = true;
                  double amount = (data['amount'] ?? 0).toDouble();
                  String type = data['type'] ?? 'expense';

                  if (_viewMode == 2) {
                    if (type == 'income')
                      totalIncome += amount;
                    else
                      totalExpense += amount;
                  } else {
                    String category = data['category'] ?? 'Lainnya';
                    if (dataMap.containsKey(category)) {
                      dataMap[category] = dataMap[category]! + amount;
                    } else {
                      dataMap[category] = amount;
                    }
                    grandTotal += amount;
                  }
                }

                if (!hasDataThisMonth)
                  return _buildEmptyState("Tidak ada data di bulan ini.");

                if (_viewMode == 2) {
                  dataMap = {
                    'Pemasukan': totalIncome,
                    'Pengeluaran': totalExpense,
                  };
                  grandTotal = totalIncome + totalExpense;
                  if (grandTotal == 0)
                    return _buildEmptyState("Nol transaksi bulan ini.");
                }

                var sortedEntries = dataMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return Column(
                  children: [
                    // A. PIE CHART
                    SizedBox(
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event
                                                .isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection ==
                                                null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse
                                            .touchedSection!
                                            .touchedSectionIndex;
                                      });
                                    },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 50,
                              sections: List.generate(sortedEntries.length, (
                                i,
                              ) {
                                final isTouched = i == _touchedIndex;
                                final fontSize = isTouched ? 18.0 : 12.0;
                                final radius = isTouched ? 60.0 : 50.0;

                                String key = sortedEntries[i].key;
                                double value = sortedEntries[i].value;

                                Color color;
                                if (_viewMode == 2) {
                                  color = key == 'Pemasukan'
                                      ? const Color(0xFF00897B)
                                      : const Color(0xFF0F4C5C);
                                } else {
                                  var colorMap = _viewMode == 0
                                      ? _expenseColors
                                      : _incomeColors;
                                  color = colorMap[key] ?? Colors.grey;
                                }

                                return PieChartSectionData(
                                  color: color,
                                  value: value,
                                  title:
                                      '${((value / grandTotal) * 100).toStringAsFixed(0)}%',
                                  radius: radius,
                                  titleStyle: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                          // INFO TENGAH CHART
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _viewMode == 2
                                    ? "Selisih"
                                    : (_viewMode == 0
                                          ? "Total Keluar"
                                          : "Total Masuk"),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                _viewMode == 2
                                    ? _formatRupiah(totalIncome - totalExpense)
                                    : _formatRupiah(grandTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              if (_viewMode == 2)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    (totalIncome - totalExpense) >= 0
                                        ? "Surplus"
                                        : "Defisit",
                                    style: TextStyle(
                                      color: (totalIncome - totalExpense) >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // B. LIST DETAIL
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: sortedEntries.length,
                        itemBuilder: (context, index) {
                          String key = sortedEntries[index].key;
                          double amount = sortedEntries[index].value;
                          double percentage = (amount / grandTotal) * 100;

                          Color color;
                          if (_viewMode == 2) {
                            color = key == 'Pemasukan'
                                ? const Color(0xFF00897B)
                                : const Color(0xFF0F4C5C);
                          } else {
                            var colorMap = _viewMode == 0
                                ? _expenseColors
                                : _incomeColors;
                            color = colorMap[key] ?? Colors.grey;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        key,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: percentage / 100,
                                        backgroundColor: Colors.grey.shade200,
                                        color: color,
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatRupiah(amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      "${percentage.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, int modeIndex, Color activeColor) {
    bool isActive = _viewMode == modeIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = modeIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
          Icon(Icons.pie_chart_outline, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
