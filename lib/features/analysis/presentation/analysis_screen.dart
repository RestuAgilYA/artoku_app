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

  int _viewMode = 0;
  late PageController _pageController;
  late Stream<QuerySnapshot> _expenseStream;
  late Stream<QuerySnapshot> _incomeStream;
  late Stream<QuerySnapshot> _allStream;
  late Stream<QuerySnapshot> _debtStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _viewMode);
    if (user != null) {
      final txCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions');
      
      _expenseStream = txCollection.where('type', isEqualTo: 'expense').snapshots();
      _incomeStream = txCollection.where('type', isEqualTo: 'income').snapshots();
      _allStream = txCollection.snapshots();
      _debtStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('debts')
          .snapshots();
    } else {
      _expenseStream = const Stream.empty();
      _incomeStream = const Stream.empty();
      _allStream = const Stream.empty();
      _debtStream = const Stream.empty();
    }
  }

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double tabWidth = constraints.maxWidth / 4;
                Color activeColor;
                switch (_viewMode) {
                  case 0: activeColor = const Color(0xFF0F4C5C); break;
                  case 1: activeColor = const Color(0xFF00897B); break;
                  case 2: activeColor = Colors.blueAccent; break;
                  case 3: activeColor = const Color(0xFFFF8F00); break;
                  default: activeColor = const Color(0xFF0F4C5C);
                }
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: _viewMode * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildToggleButton("Keluar", 0),
                        _buildToggleButton("Masuk", 1),
                        _buildToggleButton("Banding", 2),
                        _buildToggleButton("Piutang", 3),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 3. KONTEN CHART
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _viewMode = index);
              },
              children: [
                KeepAliveWrapper(child: _buildTransactionAnalysis(_expenseStream, textColor, 0)),
                KeepAliveWrapper(child: _buildTransactionAnalysis(_incomeStream, textColor, 1)),
                KeepAliveWrapper(child: _buildTransactionAnalysis(_allStream, textColor, 2)),
                KeepAliveWrapper(child: _buildDebtAnalysis(textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PIUTANG/UTANG ANALYSIS ====================
  Widget _buildDebtAnalysis(Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _debtStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Belum ada data piutang/utang.");
        }

        final docs = snapshot.data!.docs;

        // Filter by selected month
        final monthDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? t = data['createdAt'] as Timestamp?;
          if (t == null) return false;
          final date = t.toDate();
          return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
        }).toList();

        if (monthDocs.isEmpty) {
          return _buildEmptyState("Tidak ada data piutang/utang di bulan ini.");
        }

        double totalPiutangActive = 0;
        double totalUtangActive = 0;
        double totalPiutangPaid = 0;
        double totalUtangPaid = 0;
        int countPiutang = 0;
        int countUtang = 0;

        for (var doc in monthDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] ?? 0).toDouble();
          final isPaid = data['isPaid'] == true;
          if (data['type'] == 'piutang') {
            countPiutang++;
            if (isPaid) {
              totalPiutangPaid += amount;
            } else {
              totalPiutangActive += amount;
            }
          } else {
            countUtang++;
            if (isPaid) {
              totalUtangPaid += amount;
            } else {
              totalUtangActive += amount;
            }
          }
        }

        final double netPosition = totalPiutangActive - totalUtangActive;

        // Pie chart data
        final List<MapEntry<String, double>> chartEntries = [];
        if (totalPiutangActive > 0) {
          chartEntries.add(MapEntry('Piutang Aktif', totalPiutangActive));
        }
        if (totalUtangActive > 0) {
          chartEntries.add(MapEntry('Utang Aktif', totalUtangActive));
        }
        if (totalPiutangPaid > 0) {
          chartEntries.add(MapEntry('Piutang Lunas', totalPiutangPaid));
        }
        if (totalUtangPaid > 0) {
          chartEntries.add(MapEntry('Utang Lunas', totalUtangPaid));
        }

        final Map<String, Color> debtColors = {
          'Piutang Aktif': const Color(0xFF00897B),
          'Utang Aktif': Colors.red,
          'Piutang Lunas': const Color(0xFF80CBC4),
          'Utang Lunas': const Color(0xFFEF9A9A),
        };

        // ignore: avoid_types_as_parameter_names
        final double chartTotal = chartEntries.fold(0, (sum, e) => sum + e.value);

        return Column(
          children: [
            // Pie Chart
            if (chartEntries.isNotEmpty && chartTotal > 0)
              _DebtPieChart(
                chartEntries: chartEntries,
                chartTotal: chartTotal,
                debtColors: debtColors,
                netPosition: netPosition,
                textColor: textColor,
              ),

            const SizedBox(height: 12),

            // Summary cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildDebtSummaryCard(
                    "Piutang Aktif",
                    totalPiutangActive,
                    countPiutang,
                    const Color(0xFF00897B),
                    Icons.arrow_downward,
                  ),
                  const SizedBox(width: 12),
                  _buildDebtSummaryCard(
                    "Utang Aktif",
                    totalUtangActive,
                    countUtang,
                    Colors.red,
                    Icons.arrow_upward,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Detail list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (totalPiutangPaid > 0 || totalUtangPaid > 0)
                    _buildDebtDetailRow("Piutang Lunas", totalPiutangPaid, const Color(0xFF80CBC4), textColor),
                  if (totalPiutangPaid > 0 || totalUtangPaid > 0)
                    _buildDebtDetailRow("Utang Lunas", totalUtangPaid, const Color(0xFFEF9A9A), textColor),
                  _buildDebtDetailRow("Piutang Aktif", totalPiutangActive, const Color(0xFF00897B), textColor),
                  _buildDebtDetailRow("Utang Aktif", totalUtangActive, Colors.red, textColor),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Selisih (Piutang - Utang)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                        Text(
                          "${netPosition >= 0 ? '+' : '-'}${_formatRupiah(netPosition.abs())}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: netPosition >= 0 ? const Color(0xFF00897B) : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDebtSummaryCard(String title, double amount, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatRupiah(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "$count transaksi",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtDetailRow(String label, double amount, Color color, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
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
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textColor,
              ),
            ),
          ),
          Text(
            _formatRupiah(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
  // _buildDebtDetailRow remains inside _AnalysisScreenState

  Widget _buildToggleButton(String text, int modeIndex) {
    bool isActive = _viewMode == modeIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _pageController.animateToPage(
            modeIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionAnalysis(Stream<QuerySnapshot> stream, Color textColor, int typeIndex) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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
              date.month != _selectedMonth.month) {
            continue;
          }

          hasDataThisMonth = true;
          double amount = (data['amount'] ?? 0).toDouble();
          String type = data['type'] ?? 'expense';

          if (typeIndex == 2) {
            if (type == 'income') {
              totalIncome += amount;
            } else {
              totalExpense += amount;
            }
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

        if (!hasDataThisMonth) {
          return _buildEmptyState("Tidak ada data di bulan ini.");
        }

        if (typeIndex == 2) {
          dataMap = {
            'Pemasukan': totalIncome,
            'Pengeluaran': totalExpense,
          };
          grandTotal = totalIncome + totalExpense;
          if (grandTotal == 0) {
            return _buildEmptyState("Nol transaksi bulan ini.");
          }
        }

        var sortedEntries = dataMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          children: [
            // A. PIE CHART (Widget Terpisah Anti-Kedip)
            _PieChartWidget(
              sortedEntries: sortedEntries,
              grandTotal: grandTotal,
              viewMode: typeIndex,
              expenseColors: _expenseColors,
              incomeColors: _incomeColors,
              textColor: textColor,
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
                  if (typeIndex == 2) {
                    color = key == 'Pemasukan'
                        ? const Color(0xFF00897B)
                        : const Color(0xFF0F4C5C);
                  } else {
                    var colorMap = typeIndex == 0
                        ? _expenseColors
                        : _incomeColors;
                    color = colorMap[key] ?? Colors.grey;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.category,
                            color: color,
                            size: 24,
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
class _DebtPieChart extends StatefulWidget {
  final List<MapEntry<String, double>> chartEntries;
  final double chartTotal;
  final Map<String, Color> debtColors;
  final double netPosition;
  final Color textColor;

  const _DebtPieChart({
    required this.chartEntries,
    required this.chartTotal,
    required this.debtColors,
    required this.netPosition,
    required this.textColor,
  });

  @override
  State<_DebtPieChart> createState() => _DebtPieChartState();
}

class _DebtPieChartState extends State<_DebtPieChart> {
  int _touchedIndex = -1;

  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return ShaderMask(
                shaderCallback: (rect) {
                  return SweepGradient(
                    startAngle: 0.0,
                    endAngle: 2 * 3.141592653589793,
                    stops: [value, value],
                    colors: const [Colors.black, Colors.transparent],
                    transform: const GradientRotation(-3.141592653589793 / 2),
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: child,
              );
            },
            child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: List.generate(widget.chartEntries.length, (i) {
                final isTouched = i == _touchedIndex;
                final fontSize = isTouched ? 14.0 : 12.0;
                final radius = isTouched ? 65.0 : 50.0;
                final entry = widget.chartEntries[i];
                final percentage = (entry.value / widget.chartTotal) * 100;

                return PieChartSectionData(
                  color: widget.debtColors[entry.key] ?? Colors.grey,
                  value: entry.value,
                  title: isTouched
                      ? _formatRupiah(entry.value)
                      : '${percentage.toStringAsFixed(0)}%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                );
              }),
            ),
          ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Posisi Bersih",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                _formatRupiah(widget.netPosition.abs()),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: widget.netPosition >= 0 ? const Color(0xFF00897B) : Colors.red,
                ),
              ),
              Text(
                widget.netPosition >= 0 ? "Lebih banyak piutang" : "Lebih banyak utang",
                style: TextStyle(
                  fontSize: 9,
                  color: widget.netPosition >= 0 ? const Color(0xFF00897B) : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// === WIDGET TERPISAH CHART (ANTI-FLICKER) ===
class _PieChartWidget extends StatefulWidget {
  final List<MapEntry<String, double>> sortedEntries;
  final double grandTotal;
  final int viewMode;
  final Map<String, Color> expenseColors;
  final Map<String, Color> incomeColors;
  final Color textColor;

  const _PieChartWidget({
    required this.sortedEntries,
    required this.grandTotal,
    required this.viewMode,
    required this.expenseColors,
    required this.incomeColors,
    required this.textColor,
  });

  @override
  State<_PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<_PieChartWidget> {
  int _touchedIndex = -1;

  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return ShaderMask(
                shaderCallback: (rect) {
                  return SweepGradient(
                    startAngle: 0.0,
                    endAngle: 2 * 3.141592653589793,
                    stops: [value, value],
                    colors: const [Colors.black, Colors.transparent],
                    transform: const GradientRotation(-3.141592653589793 / 2),
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: child,
              );
            },
            child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: List.generate(widget.sortedEntries.length, (i) {
              final isTouched = i == _touchedIndex;
              
              // Membesar saat disentuh
              final fontSize = isTouched ? 16.0 : 12.0;
              final radius = isTouched ? 60.0 : 50.0;

              String key = widget.sortedEntries[i].key;
              double value = widget.sortedEntries[i].value;

              Color color;
              if (widget.viewMode == 2) {
                color = key == 'Pemasukan'
                    ? const Color(0xFF00897B)
                    : const Color(0xFF0F4C5C);
              } else {
                var colorMap = widget.viewMode == 0
                    ? widget.expenseColors
                    : widget.incomeColors;
                color = colorMap[key] ?? Colors.grey;
              }

              return PieChartSectionData(
                color: color,
                value: value,
                title: isTouched 
                  ? _formatRupiah(value) 
                  : '${((value / widget.grandTotal) * 100).toStringAsFixed(0)}%',
                radius: radius,
                titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 2),
                  ],
                  ),
                );
              }),
            ),
          ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.viewMode == 2
                    ? "Selisih"
                    : (widget.viewMode == 0 ? "Total Keluar" : "Total Masuk"),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                widget.viewMode == 2
                    ? _formatRupiah(
                        widget.sortedEntries.isNotEmpty &&
                                widget.sortedEntries.length > 1
                            ? (widget.sortedEntries[0].value -
                                      widget.sortedEntries[1].value)
                                  .abs()
                            : widget.grandTotal,
                      )
                    : _formatRupiah(widget.grandTotal),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: widget.textColor,
                ),
              ),
              if (widget.viewMode == 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Arus Kas",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
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

