import 'package:artoku_app/transfer_fund_dialog.dart';
import 'package:artoku_app/transfer_history_tab.dart' hide TransferFundDialog;
import 'package:artoku_app/wallet_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:artoku_app/services/ui_helper.dart';

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newText.isEmpty) {
      return const TextEditingValue();
    }

    final number = int.parse(newText);
    final formatter = NumberFormat('#,###', 'id_ID');
    String formattedText = formatter.format(number);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class MyWalletScreen extends StatefulWidget {
  const MyWalletScreen({super.key});

  @override
  State<MyWalletScreen> createState() => _MyWalletScreenState();
}

class _MyWalletScreenState extends State<MyWalletScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isWalletView = true;
  final Color primaryColor = const Color(0xFF0F4C5C);

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

  void _showWalletForm({DocumentSnapshot? document}) {
    final nameController = TextEditingController(
      text: document != null ? document['name'] : '',
    );
    final balanceController = TextEditingController(
      text: document != null
          ? NumberFormat('#,###', 'id_ID')
              .format((document['balance'] as num).toInt())
          : '',
    );
    Color selectedColor =
        document != null ? Color(document['color']) : _presetColors[0];

    if (document == null) {
      // For new wallet, get available color
      _getAvailableColorFuture().then((color) {
        selectedColor = color;
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document == null ? "Tambah Dompet" : "Edit Dompet"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama Dompet"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: "Saldo Awal",
                prefixText: 'Rp ',
              ),
            ),
            // Color picker can be added here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validasi nama dompet tidak boleh kosong
              if (nameController.text.trim().isEmpty) {
                UIHelper.showError(context, "Nama dompet tidak boleh kosong!");
                return;
              }

              // Validasi nama dompet unik (jika tambah baru atau edit dengan nama berbeda)
              if (document == null || nameController.text.trim() != document['name']) {
                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('wallets')
                    .where('name', isEqualTo: nameController.text.trim())
                    .limit(1)
                    .get();

                if (query.docs.isNotEmpty) {
                  if (mounted) {
                    UIHelper.showError(context, "Nama dompet sudah ada. Silakan gunakan nama lain!");
                  }
                  return;
                }
              }

              final walletRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('wallets');

              final balance = double.tryParse(
                      balanceController.text.replaceAll('.', '')) ??
                  0;

              Map<String, dynamic> data = {
                'name': nameController.text,
                'balance': balance,
                'color': selectedColor.value,
                'isLocked': document != null ? document['isLocked'] : false,
                'createdAt': FieldValue.serverTimestamp(),
              };

              if (document == null) {
                await walletRef.add(data);
              } else {
                await walletRef.doc(document.id).update(data);
              }
              Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<Color> _getAvailableColorFuture() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('wallets')
        .get();
    
    final usedColors = snapshot.docs
        .map((doc) => (doc['color'] as int))
        .toSet();
    
    // Find first available color
    for (Color color in _presetColors) {
      if (!usedColors.contains(color.value)) {
        return color;
      }
    }
    return _presetColors[0];
  }

  void _showTransferForm({TransferModel? transfer}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TransferFundDialog(transfer: transfer);
      },
    );
  }

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
            icon: Icon(Icons.swap_horiz, color: textColor),
            onPressed: () => _showTransferForm(),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: textColor),
            onPressed: () => _showWalletForm(document: null),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToggleSwitch(Theme.of(context).cardColor, isDark),
          const SizedBox(height: 20),
          Expanded(
            child: _isWalletView
                ? _buildWalletListTab(textColor)
                : TransferHistoryTab(onEdit: _showTransferForm),
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
          _toggleButton("Dompet", _isWalletView),
          _toggleButton("Riwayat Transfer", !_isWalletView),
        ],
      ),
    );
  }

  Widget _toggleButton(String title, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isWalletView = title == "Dompet"),
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

  Widget _buildWalletListTab(Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('wallets')
          .orderBy('balance', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "Belum ada dompet.",
              style: TextStyle(color: textColor),
            ),
          );
        }

        var wallets = snapshot.data!.docs;
        double totalAssets = 0;
        List<Map<String, dynamic>> chartData = [];

        for (var doc in wallets) {
          var data = doc.data() as Map<String, dynamic>;
          double bal = (data['balance'] ?? 0).toDouble();
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

                  double percentage =
                      totalAssets > 0 ? (balance / totalAssets) : 0;
                  if (percentage < 0) percentage = 0;

                  return Opacity(
                    opacity: isLocked ? 0.6 : 1.0,
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
    );
  }

  void _toggleLock(String walletId, bool currentStatus) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(currentStatus ? "Buka Kunci Dompet" : "Kunci Dompet"),
          content: Text(
            currentStatus
                ? "Dompet akan diaktifkan kembali dan akan tampil di form Catat Transaksi dan fitur transfer."
                : "Dompet akan dikunci dan tidak akan tampil di form Catat Transaksi dan fitur transfer.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('wallets')
                    .doc(walletId)
                    .update({'isLocked': !currentStatus});
                
                Navigator.pop(context);
              },
              child: Text(currentStatus ? "Buka Kunci" : "Kunci"),
            ),
          ],
        );
      },
    );
  }

  void _deleteWallet(String walletId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Hapus Dompet?"),
          content: const Text(
            "Apakah Anda yakin ingin menghapus dompet ini? Tindakan ini tidak dapat dibatalkan.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('wallets')
                    .doc(walletId)
                    .delete();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Hapus", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatRupiah(num number) =>
      "Rp ${NumberFormat('#,###', 'id_ID').format(number)}";
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
    return "Rp ${NumberFormat('#,###', 'id_ID').format(number)}";
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
            sections: List.generate(widget.chartData.length, (i) {
              final isTouched = i == _touchedIndex;
              final fontSize = isTouched ? 16.0 : 12.0;
              final radius = isTouched ? 60.0 : 50.0;
              double val = widget.chartData[i]['value'];

              return PieChartSectionData(
                color: widget.chartData[i]['color'],
                value: val,
                title: isTouched
                    ? _formatRupiah(val)
                    : '${((val / widget.totalAssets) * 100).toStringAsFixed(0)}%',
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
