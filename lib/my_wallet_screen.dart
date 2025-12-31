import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  final List<Color> _presetColors = [
    const Color(0xFF0F4C5C),
    const Color(0xFFE53935),
    const Color(0xFF43A047),
    const Color(0xFF1E88E5),
    const Color(0xFF8E24AA),
    const Color(0xFFFB8C00),
    const Color(0xFF5D4037),
    const Color(0xFF757575),
  ];

  // Helper Form (Sama, ditambah checkbox Locked nanti jika perlu di form edit, tapi kita pakai icon di list aja biar cepat)
  void _showWalletForm({DocumentSnapshot? document}) {
    // ... (Copy Logic Form Anda sebelumnya di sini) ...
    // Saya singkat:
    TextEditingController nameController = TextEditingController(
      text: document?['name'],
    );
    TextEditingController balanceController = TextEditingController(
      text: document?['balance'].toString(),
    );
    Color selectedColor = document != null
        ? Color(document['color'])
        : _presetColors[0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama"),
            ),
            TextField(
              controller: balanceController,
              decoration: const InputDecoration(labelText: "Saldo"),
            ),
            // Color picker...
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Logic Save
              final walletRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('wallets');
              Map<String, dynamic> data = {
                'name': nameController.text,
                'balance': double.tryParse(balanceController.text) ?? 0,
                'color': selectedColor.value,
                'isLocked':
                    document?['isLocked'] ?? false, // Pertahankan status lock
                'createdAt':
                    FieldValue.serverTimestamp(), // Untuk sort fallback
              };
              if (document == null)
                await walletRef.add(data);
              else
                await walletRef.doc(document.id).update(data);
              Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // FITUR 2: Toggle Lock
  void _toggleLock(String walletId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('wallets')
        .doc(walletId)
        .update({'isLocked': !currentStatus});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !currentStatus
              ? "Dompet disembunyikan dari transaksi"
              : "Dompet aktif kembali",
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _deleteWallet(String walletId) {
    // Logic delete lama
    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('wallets')
        .doc(walletId)
        .delete();
  }

  String _formatRupiah(num number) =>
      "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Dompet Saya",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: textColor),
            onPressed: () => _showWalletForm(document: null),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // FITUR 3: Sorting Balance (High to Low)
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('wallets')
            .orderBy('balance', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return Center(
              child: Text(
                "Belum ada dompet.",
                style: TextStyle(color: textColor),
              ),
            );

          var wallets = snapshot.data!.docs;
          double totalAssets = 0;
          List<Map<String, dynamic>> chartData = [];

          for (var doc in wallets) {
            var data = doc.data() as Map<String, dynamic>;
            double bal = (data['balance'] ?? 0).toDouble();
            // Chart hanya tampilkan yang visible (tidak di-lock) & > 0?
            // Biasanya Aset tetap dihitung meski di lock, tapi opsional.
            // Kita hitung semua aset real.
            if (bal > 0) {
              totalAssets += bal;
              chartData.add({
                'name': data['name'],
                'value': bal,
                'color': Color(data['color'] ?? 0xFF0F4C5C),
              });
            }
          }

          return Column(
            children: [
              // FITUR 1: CHART FLICKER FIX (Extract Widget)
              if (totalAssets > 0)
                SizedBox(
                  height: 220,
                  child: _WalletPieChart(
                    totalAssets: totalAssets,
                    chartData: chartData,
                    textColor: textColor,
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    var wallet = wallets[index];
                    var data = wallet.data() as Map<String, dynamic>;
                    Color walletColor = Color(data['color'] ?? 0xFF0F4C5C);
                    double balance = (data['balance'] ?? 0).toDouble();
                    bool isLocked = data['isLocked'] ?? false;

                    double percentage = totalAssets > 0
                        ? (balance / totalAssets)
                        : 0;
                    if (percentage < 0) percentage = 0;

                    return Opacity(
                      opacity: isLocked
                          ? 0.6
                          : 1.0, // Visual feedback kalau locked
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: walletColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLocked
                                    ? Icons.lock
                                    : Icons.account_balance_wallet,
                                color: walletColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor: Colors.grey.shade200,
                                      color: walletColor,
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatRupiah(balance),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    // FITUR 2: Lock Button
                                    GestureDetector(
                                      onTap: () =>
                                          _toggleLock(wallet.id, isLocked),
                                      child: Icon(
                                        isLocked
                                            ? Icons.lock_open
                                            : Icons.lock_outline,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () =>
                                          _showWalletForm(document: wallet),
                                      child: Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => _deleteWallet(wallet.id),
                                      child: Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// WIDGET TERPISAH UNTUK CHART (MENCEGAH FLICKER)
class _WalletPieChart extends StatefulWidget {
  final double totalAssets;
  final List<Map<String, dynamic>> chartData;
  final Color textColor;

  const _WalletPieChart({
    required this.totalAssets,
    required this.chartData,
    required this.textColor,
  });

  @override
  State<_WalletPieChart> createState() => _WalletPieChartState();
}

class _WalletPieChartState extends State<_WalletPieChart> {
  int _touchedIndex = -1;

  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                // setState di sini HANYA me-rebuild _WalletPieChart, bukan seluruh Screen/StreamBuilder
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
            centerSpaceRadius: 40,
            sections: List.generate(widget.chartData.length, (i) {
              final isTouched = i == _touchedIndex;
              final fontSize = isTouched ? 16.0 : 10.0;
              final radius = isTouched ? 50.0 : 40.0;
              double val = widget.chartData[i]['value'];

              return PieChartSectionData(
                color: widget.chartData[i]['color'],
                value: val,
                title:
                    '${((val / widget.totalAssets) * 100).toStringAsFixed(0)}%',
                radius: radius,
                titleStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                ),
              );
            }),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Total Aset",
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
            Text(
              _formatRupiah(widget.totalAssets),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: widget.textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
