import 'package:artoku_app/features/transfer/presentation/transfer_fund_dialog.dart';
import 'package:artoku_app/features/transfer/presentation/transfer_history_tab.dart' hide TransferFundDialog;
import 'package:artoku_app/features/transfer/data/transfer_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/features/patungan/data/patungan_service.dart';

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
  int _selectedTab = 0; // 0 = Dompet, 1 = Riwayat Transfer, 2 = Piutang/Utang
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        final hintColor = isDark ? Colors.grey : Colors.grey.shade400;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 16, left: 24, right: 24, bottom: bottomInset + 24,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      document == null ? "Tambah Dompet" : "Edit Dompet",
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: textColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nama Dompet
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Nama Dompet", style: TextStyle(color: hintColor, fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Contoh: Dompet Utama",
                        hintStyle: TextStyle(color: hintColor),
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: hintColor, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F4C5C), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Saldo Awal
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Saldo Awal", style: TextStyle(color: hintColor, fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        hintText: "0",
                        hintStyle: TextStyle(color: hintColor),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F4C5C), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Color Picker
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Warna Dompet", style: TextStyle(color: hintColor, fontSize: 12)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._presetColors.map((color) {
                          final isSelected = selectedColor == color;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: textColor, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 1)]
                                    : [],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }),
                        // Custom color button
                        GestureDetector(
                          onTap: () {
                            _showCustomColorPicker(context, selectedColor, (color) {
                              setSheetState(() => selectedColor = color);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: !_presetColors.contains(selectedColor)
                                    ? textColor
                                    : Colors.grey.shade400,
                                width: !_presetColors.contains(selectedColor) ? 2.5 : 1.5,
                              ),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.orange,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.cyan,
                                  Colors.blue,
                                  Colors.purple,
                                  Colors.red,
                                ],
                              ),
                              boxShadow: !_presetColors.contains(selectedColor)
                                  ? [BoxShadow(color: selectedColor.withAlpha(100), blurRadius: 8, spreadRadius: 1)]
                                  : [],
                            ),
                            child: !_presetColors.contains(selectedColor)
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                : Icon(Icons.colorize, color: Colors.white, size: 16,
                                    shadows: [Shadow(color: Colors.black.withAlpha(120), blurRadius: 3)]),
                          ),
                        ),
                      ],
                    ),
                    // Show selected custom color preview
                    if (!_presetColors.contains(selectedColor))
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: selectedColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Warna kustom dipilih",
                              style: TextStyle(color: hintColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text("Batal", style: TextStyle(color: textColor)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Validasi nama dompet tidak boleh kosong
                              if (nameController.text.trim().isEmpty) {
                                UIHelper.showError(context, "Nama dompet tidak boleh kosong!");
                                return;
                              }

                              // Validasi nama dompet unik
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
                                    // ignore: use_build_context_synchronously
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
                                // ignore: deprecated_member_use
                                'color': selectedColor.value,
                                'isLocked': document != null ? document['isLocked'] : false,
                                'createdAt': FieldValue.serverTimestamp(),
                              };

                              if (document == null) {
                                await walletRef.add(data);
                              } else {
                                await walletRef.doc(document.id).update(data);
                              }
                              // ignore: use_build_context_synchronously
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Simpan",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomColorPicker(BuildContext parentContext, Color currentColor, Function(Color) onColorSelected) {
    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;

    showDialog(
      context: parentContext,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return StatefulBuilder(
          builder: (context, setPickerState) {
            final previewColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: previewColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Pilih Warna", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hue slider
                    Text("Warna", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: List.generate(
                            360 ~/ 10,
                            (i) => HSVColor.fromAHSV(1.0, i * 10.0, 1.0, 1.0).toColor(),
                          ),
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 28,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          overlayColor: Colors.white24,
                        ),
                        child: Slider(
                          value: hue,
                          min: 0,
                          max: 359,
                          onChanged: (v) => setPickerState(() => hue = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Saturation slider
                    Text("Saturasi", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            HSVColor.fromAHSV(1.0, hue, 0.0, value).toColor(),
                            HSVColor.fromAHSV(1.0, hue, 1.0, value).toColor(),
                          ],
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 24,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          overlayColor: Colors.white24,
                        ),
                        child: Slider(
                          value: saturation,
                          min: 0,
                          max: 1,
                          onChanged: (v) => setPickerState(() => saturation = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Brightness slider
                    Text("Kecerahan", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            HSVColor.fromAHSV(1.0, hue, saturation, 0.0).toColor(),
                            HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor(),
                          ],
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 24,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          overlayColor: Colors.white24,
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: 1,
                          onChanged: (v) => setPickerState(() => value = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Preview large
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        // ignore: deprecated_member_use
                        '#${previewColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: TextStyle(
                          color: value > 0.5 ? Colors.black54 : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Batal", style: TextStyle(color: textColor)),
                ),
                ElevatedButton(
                  onPressed: () {
                    onColorSelected(previewColor);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: previewColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Pilih Warna",
                    style: TextStyle(
                      color: value > 0.5 ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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
      // ignore: deprecated_member_use
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
            icon: Icon(Icons.add_circle_outline, color: textColor),
            onPressed: () {
              if (_selectedTab == 0) {
                _showWalletForm(document: null);
              } else if (_selectedTab == 1) {
                _showTransferForm();
              } else {
                _showDebtForm();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToggleSwitch(Theme.of(context).cardColor, isDark),
          const SizedBox(height: 20),
          Expanded(
            child: _selectedTab == 0
                ? _buildWalletListTab(textColor)
                : _selectedTab == 1
                    ? TransferHistoryTab(onEdit: _showTransferForm)
                    : _buildDebtTab(textColor),
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
      child: Row(
        children: [
          _toggleButton("Dompet", 0),
          _toggleButton("Transfer", 1),
          _toggleButton("Piutang/Utang", 2),
        ],
      ),
    );
  }

  Widget _toggleButton(String title, int tabIndex) {
    bool isActive = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabIndex),
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
              fontSize: 12,
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
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
                // ignore: use_build_context_synchronously
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

  // ==================== PIUTANG/UTANG TAB ====================

  void _showDebtForm({DocumentSnapshot? document}) async {
    // Cegah edit untuk piutang dari Patungan
    if (document != null) {
      final docData = document.data() as Map<String, dynamic>;
      if (docData['patunganId'] != null) {
        UIHelper.showError(context, "Piutang ini terhubung dengan Patungan. Kelola dari menu Patungan.");
        return;
      }
    }
    // Fetch unlocked wallets
    final walletSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('wallets')
        .where('isLocked', isEqualTo: false)
        .get();
    final unlockedWallets = walletSnapshot.docs;

    String? selectedWalletId;
    if (document != null) {
      final docWalletId = (document.data() as Map<String, dynamic>)['walletId'] as String?;
      if (docWalletId != null && unlockedWallets.any((w) => w.id == docWalletId)) {
        selectedWalletId = docWalletId;
      }
    }

    final nameController = TextEditingController(
      text: document != null ? (document.data() as Map<String, dynamic>)['personName'] ?? '' : '',
    );
    final amountController = TextEditingController(
      text: document != null
          ? NumberFormat('#,###', 'id_ID')
              .format(((document.data() as Map<String, dynamic>)['amount'] as num).toInt())
          : '',
    );
    final noteController = TextEditingController(
      text: document != null ? (document.data() as Map<String, dynamic>)['note'] ?? '' : '',
    );

    String selectedType = document != null
        ? (document.data() as Map<String, dynamic>)['type'] ?? 'piutang'
        : 'piutang';

    DateTime selectedDate = document != null && (document.data() as Map<String, dynamic>)['createdAt'] != null
        ? ((document.data() as Map<String, dynamic>)['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    DateTime? dueDate = document != null && (document.data() as Map<String, dynamic>)['dueDate'] != null
        ? ((document.data() as Map<String, dynamic>)['dueDate'] as Timestamp).toDate()
        : null;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        final hintColor = isDark ? Colors.grey : Colors.grey.shade400;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final piutangActive = selectedType == 'piutang';
            final accentColor = piutangActive ? const Color(0xFF00897B) : Colors.red;

            InputDecoration fieldDecoration({
              required String label,
              String? hint,
              Widget? prefixIcon,
              String? prefixText,
              Widget? suffixIcon,
            }) {
              return InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: hintColor, fontSize: 13),
                hintText: hint,
                hintStyle: TextStyle(color: hintColor),
                prefixIcon: prefixIcon,
                prefixText: prefixText,
                prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                suffixIcon: suffixIcon,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
              );
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                top: 16, left: 24, right: 24, bottom: bottomInset + 24,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      document == null ? "Tambah Piutang/Utang" : "Edit Piutang/Utang",
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Type selector
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => selectedType = 'piutang'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: piutangActive ? const Color(0xFF00897B) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: piutangActive
                                      ? [BoxShadow(color: const Color(0xFF00897B).withAlpha(60), blurRadius: 8)]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: piutangActive ? Colors.white : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Piutang",
                                      style: TextStyle(
                                        color: piutangActive ? Colors.white : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => selectedType = 'utang'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !piutangActive ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !piutangActive
                                      ? [BoxShadow(color: Colors.red.withAlpha(60), blurRadius: 8)]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: !piutangActive ? Colors.white : Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Utang",
                                      style: TextStyle(
                                        color: !piutangActive ? Colors.white : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Nama
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      decoration: fieldDecoration(
                        label: piutangActive ? "Nama Peminjam" : "Nama Pemberi Pinjaman",
                        prefixIcon: Icon(Icons.person_outline, color: hintColor, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Jumlah
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      style: TextStyle(color: textColor),
                      decoration: fieldDecoration(
                        label: "Jumlah",
                        prefixText: 'Rp ',
                        hint: "0",
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Keterangan
                    TextField(
                      controller: noteController,
                      style: TextStyle(color: textColor),
                      decoration: fieldDecoration(
                        label: "Keterangan (opsional)",
                        prefixIcon: Icon(Icons.notes_outlined, color: hintColor, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pilih Dompet
                    DropdownButtonFormField<String>(
                      initialValue: selectedWalletId,
                      decoration: fieldDecoration(
                        label: "Dompet",
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: hintColor, size: 20),
                      ),
                      dropdownColor: sheetBg,
                      style: TextStyle(color: textColor, fontSize: 14),
                      items: unlockedWallets.map((wallet) {
                        final walletData = wallet.data();
                        final walletBalance = (walletData['balance'] ?? 0).toDouble();
                        return DropdownMenuItem<String>(
                          value: wallet.id,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  walletData['name'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatRupiah(walletBalance),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setSheetState(() => selectedWalletId = value);
                      },
                      hint: Text("Pilih dompet", style: TextStyle(color: hintColor)),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 14),

                    // Tanggal & Jatuh Tempo in a row
                    Row(
                      children: [
                        // Tanggal
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: hintColor),
                                      const SizedBox(width: 4),
                                      Text("Tanggal", style: TextStyle(color: hintColor, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(selectedDate),
                                    style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Jatuh Tempo
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setSheetState(() => dueDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.event, size: 14, color: hintColor),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text("Jatuh Tempo", style: TextStyle(color: hintColor, fontSize: 11), overflow: TextOverflow.ellipsis),
                                      ),
                                      if (dueDate != null)
                                        GestureDetector(
                                          onTap: () => setSheetState(() => dueDate = null),
                                          child: Icon(Icons.clear, size: 14, color: hintColor),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dueDate != null
                                        ? DateFormat('dd MMM yyyy').format(dueDate!)
                                        : 'Tidak ada',
                                    style: TextStyle(
                                      color: dueDate != null ? textColor : hintColor,
                                      fontSize: 13, fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            child: Text("Batal", style: TextStyle(color: textColor)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) {
                                UIHelper.showError(context, "Nama tidak boleh kosong!");
                                return;
                              }

                              final debtRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user!.uid)
                                  .collection('debts');

                              final amount = double.tryParse(
                                      amountController.text.replaceAll('.', '')) ??
                                  0;

                              if (amount <= 0) {
                                UIHelper.showError(context, "Jumlah harus lebih dari 0!");
                                return;
                              }

                              Map<String, dynamic> data = {
                                'type': selectedType,
                                'personName': nameController.text.trim(),
                                'amount': amount,
                                'note': noteController.text.trim(),
                                'isPaid': document != null
                                    ? (document.data() as Map<String, dynamic>)['isPaid'] ?? false
                                    : false,
                                'createdAt': Timestamp.fromDate(selectedDate),
                                'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
                                'walletId': selectedWalletId,
                                'updatedAt': FieldValue.serverTimestamp(),
                              };

                              final batch = FirebaseFirestore.instance.batch();

                              // Reverse old wallet effect when editing
                              if (document != null) {
                                final oldData = document.data() as Map<String, dynamic>;
                                final oldWalletId = oldData['walletId'] as String?;
                                final oldAmount = (oldData['amount'] ?? 0).toDouble();
                                final oldType = oldData['type'] ?? 'piutang';
                                final oldIsPaid = oldData['isPaid'] == true;

                                if (oldWalletId != null && !oldIsPaid) {
                                  final oldWalletRef = FirebaseFirestore.instance
                                      .collection('users').doc(user!.uid)
                                      .collection('wallets').doc(oldWalletId);
                                  // Reverse: piutang was -, so add back; utang was +, so subtract back
                                  batch.update(oldWalletRef, {
                                    'balance': FieldValue.increment(
                                      oldType == 'piutang' ? oldAmount : -oldAmount,
                                    ),
                                  });
                                }
                              }

                              // Apply new wallet effect
                              final isPaid = data['isPaid'] == true;
                              if (selectedWalletId != null && !isPaid) {
                                final walletRef = FirebaseFirestore.instance
                                    .collection('users').doc(user!.uid)
                                    .collection('wallets').doc(selectedWalletId);
                                // Piutang (lending): decrease balance; Utang (borrowing): increase balance
                                batch.update(walletRef, {
                                  'balance': FieldValue.increment(
                                    selectedType == 'piutang' ? -amount : amount,
                                  ),
                                });
                              }

                              if (document == null) {
                                batch.set(debtRef.doc(), data);
                              } else {
                                batch.update(debtRef.doc(document.id), data);
                              }

                              await batch.commit();
                              // ignore: use_build_context_synchronously
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Simpan",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleDebtStatus(String debtId, bool currentStatus, Map<String, dynamic> debtData) async {
    final isPatungan = debtData['patunganId'] != null;

    if (isPatungan) {
      // Patungan piutang - gunakan PatunganService dengan wallet picker
      await _togglePatunganDebtStatus(debtId, currentStatus, debtData);
      return;
    }

    final personName = debtData['personName'] ?? '-';
    final amount = (debtData['amount'] ?? 0).toDouble();
    final type = debtData['type'] ?? 'piutang';

    if (currentStatus) {
      // === UNDO LUNAS ===
      // Gunakan paidWalletId (jika ada), fallback ke walletId asli
      final paidWalletId = debtData['paidWalletId'] as String? ?? debtData['walletId'] as String?;
      String paidWalletLabel = 'dompet terkait';

      if (paidWalletId != null) {
        try {
          final wDoc = await FirebaseFirestore.instance
              .collection('users').doc(user!.uid)
              .collection('wallets').doc(paidWalletId)
              .get();
          if (wDoc.exists) {
            paidWalletLabel = (wDoc.data()?['name'] ?? 'Dompet') as String;
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Batalkan Pelunasan?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Membatalkan pelunasan ${type == 'piutang' ? 'piutang dari' : 'utang kepada'} "
                "$personName sebesar ${_formatRupiah(amount)}.",
              ),
              if (paidWalletId != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Saldo $paidWalletLabel akan ${type == 'piutang' ? 'dikurangi' : 'ditambah'} otomatis.",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Batalkan",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        final batch = FirebaseFirestore.instance.batch();

        final debtRef = FirebaseFirestore.instance
            .collection('users').doc(user!.uid)
            .collection('debts').doc(debtId);

        batch.update(debtRef, {
          'isPaid': false,
          'paidAt': null,
          'paidWalletId': null,
        });

        // Reverse wallet balance
        if (paidWalletId != null) {
          final walletRef = FirebaseFirestore.instance
              .collection('users').doc(user!.uid)
              .collection('wallets').doc(paidWalletId);
          // Undo Lunas: Piutang → money goes out (-); Utang → money received (+)
          batch.update(walletRef, {
            'balance': FieldValue.increment(
              type == 'piutang' ? -amount : amount,
            ),
          });
        }

        await batch.commit();
        if (mounted) {
          UIHelper.showSuccess(
            context,
            "Berhasil",
            "Pelunasan $personName telah dibatalkan.",
          );
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showError(
            context,
            "Gagal membatalkan: ${e.toString().replaceFirst('Exception: ', '')}",
          );
        }
      }
    } else {
      // === TANDAI LUNAS - tampilkan wallet picker ===
      List<QueryDocumentSnapshot<Map<String, dynamic>>> wallets = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('wallets')
            .get();
        wallets = snapshot.docs
            .where((d) => d.data()['isLocked'] != true)
            .toList();
      } catch (_) {}

      if (!mounted) return;

      if (wallets.isEmpty) {
        UIHelper.showError(context, "Tidak ada dompet yang tersedia.");
        return;
      }

      final originalWalletId = debtData['walletId'] as String?;
      String selectedWalletId = (originalWalletId != null &&
              wallets.any((w) => w.id == originalWalletId))
          ? originalWalletId
          : wallets.first.id;

      final confirmed = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              // Lookup manual: menghindari ListBase.firstWhere yang
              // conflict dengan runtime type _JsonQueryDocumentSnapshot.
              late final QueryDocumentSnapshot<Map<String, dynamic>>
                  selectedWallet;
              for (final w in wallets) {
                if (w.id == selectedWalletId) {
                  selectedWallet = w;
                  break;
                }
              }
              final selectedWalletData = selectedWallet.data();

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Tandai Lunas?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tandai ${type == 'piutang' ? 'piutang dari' : 'utang kepada'} "
                      "$personName lunas sebesar ${_formatRupiah(amount)}.",
                    ),
                    const SizedBox(height: 16),
                    Text(
                      type == 'piutang'
                          ? "Terima pembayaran ke:"
                          : "Bayar dari dompet:",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedWalletId,
                          isExpanded: true,
                          items: wallets.map((w) {
                            final wData = w.data();
                            final wName = wData['name'] ?? 'Dompet';
                            final wBalance =
                                (wData['balance'] as num?)?.toDouble() ?? 0;
                            return DropdownMenuItem<String>(
                              value: w.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(
                                          (wData['color'] as num?)?.toInt() ?? 0xFF0F4C5C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      wName,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatRupiah(wBalance),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(
                                  () => selectedWalletId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Saldo ${selectedWalletData['name']}: "
                      "${_formatRupiah((selectedWalletData['balance'] as num?)?.toDouble() ?? 0)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text("Batal",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selectedWalletId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Lunas",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == null || !mounted) return;

      try {
        final batch = FirebaseFirestore.instance.batch();

        final debtRef = FirebaseFirestore.instance
            .collection('users').doc(user!.uid)
            .collection('debts').doc(debtId);

        batch.update(debtRef, {
          'isPaid': true,
          'paidAt': FieldValue.serverTimestamp(),
          'paidWalletId': confirmed,
        });

        // Adjust chosen wallet balance
        final walletRef = FirebaseFirestore.instance
            .collection('users').doc(user!.uid)
            .collection('wallets').doc(confirmed);
        // Piutang → money comes back (+); Utang → money paid back (-)
        batch.update(walletRef, {
          'balance': FieldValue.increment(
            type == 'piutang' ? amount : -amount,
          ),
        });

        await batch.commit();
        if (mounted) {
          UIHelper.showSuccess(
            context,
            "Berhasil",
            "$personName telah ditandai lunas.",
          );
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showError(
            context,
            "Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}",
          );
        }
      }
    }
  }

  /// Toggle status piutang Patungan via PatunganService (dengan wallet picker)
  Future<void> _togglePatunganDebtStatus(
    String debtId,
    bool currentStatus,
    Map<String, dynamic> debtData,
  ) async {
    final patunganId = debtData['patunganId'] as String;
    final personName = debtData['personName'] ?? '-';
    final amount = (debtData['amount'] ?? 0).toDouble();

    // Cari share index
    int shareIndex;
    try {
      shareIndex = await PatunganService.findShareIndex(
        patunganId: patunganId,
        receivableId: debtId,
      );
    } catch (e) {
      if (mounted) {
        UIHelper.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
      return;
    }

    if (!mounted) return;

    if (currentStatus) {
      // Batalkan pembayaran - langsung tanpa wallet picker
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Batalkan Pembayaran?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Membatalkan pembayaran $personName "
            "sebesar ${UIHelper.formatRupiah(amount)}.\n\n"
            "Saldo dompet akan dikurangi otomatis.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Batalkan",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        await PatunganService.markShareAsUnpaid(
          patunganId: patunganId,
          shareIndex: shareIndex,
        );
        if (mounted) {
          UIHelper.showSuccess(
            context,
            "Berhasil",
            "Pembayaran $personName telah dibatalkan.",
          );
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showError(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    } else {
      // Tandai Lunas - tampilkan wallet picker
      List<QueryDocumentSnapshot<Map<String, dynamic>>> wallets = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('wallets')
            .get();
        wallets = snapshot.docs
            .where((d) => d.data()['isLocked'] != true)
            .toList();
      } catch (_) {}

      if (!mounted) return;

      if (wallets.isEmpty) {
        UIHelper.showError(context, "Tidak ada dompet yang tersedia.");
        return;
      }

      final originalWalletId = debtData['walletId'] as String?;
      String selectedWalletId = (originalWalletId != null &&
              wallets.any((w) => w.id == originalWalletId))
          ? originalWalletId
          : wallets.first.id;

      final confirmed = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              // Lookup manual: menghindari ListBase.firstWhere yang
              // conflict dengan runtime type _JsonQueryDocumentSnapshot.
              late final QueryDocumentSnapshot<Map<String, dynamic>>
                  selectedWallet;
              for (final w in wallets) {
                if (w.id == selectedWalletId) {
                  selectedWallet = w;
                  break;
                }
              }
              final selectedWalletData = selectedWallet.data();

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Tandai Lunas?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tandai $personName lunas "
                      "sebesar ${UIHelper.formatRupiah(amount)}.",
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Terima pembayaran ke:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedWalletId,
                          isExpanded: true,
                          items: wallets.map((w) {
                            final wData = w.data();
                            final wName = wData['name'] ?? 'Dompet';
                            final wBalance =
                                (wData['balance'] as num?)?.toDouble() ?? 0;
                            return DropdownMenuItem<String>(
                              value: w.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(
                                          wData['color'] ?? 0xFF0F4C5C),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      wName,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatRupiah(wBalance),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(
                                  () => selectedWalletId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Saldo ${selectedWalletData['name']}: "
                      "${_formatRupiah((selectedWalletData['balance'] ?? 0).toDouble())}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text("Batal",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selectedWalletId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Lunas",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == null || !mounted) return;

      try {
        await PatunganService.markShareAsPaid(
          patunganId: patunganId,
          shareIndex: shareIndex,
          targetWalletId: confirmed,
        );
        if (mounted) {
          UIHelper.showSuccess(
            context,
            "Berhasil",
            "$personName telah ditandai lunas.",
          );
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showError(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    }
  }

  void _deleteDebt(String debtId, Map<String, dynamic> debtData) {
    // Cegah hapus untuk piutang dari Patungan
    if (debtData['patunganId'] != null) {
      UIHelper.showError(context, "Piutang ini terhubung dengan Patungan. Hapus dari menu Patungan.");
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Hapus Data?"),
          content: const Text(
            "Apakah Anda yakin ingin menghapus data ini? Tindakan ini tidak dapat dibatalkan.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final batch = FirebaseFirestore.instance.batch();

                final debtRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('debts')
                    .doc(debtId);
                batch.delete(debtRef);

                // Reverse wallet effect if not yet paid
                final walletId = debtData['walletId'] as String?;
                final isPaid = debtData['isPaid'] == true;
                final amount = (debtData['amount'] ?? 0).toDouble();
                final type = debtData['type'] ?? 'piutang';

                if (walletId != null && !isPaid) {
                  final walletRef = FirebaseFirestore.instance
                      .collection('users').doc(user!.uid)
                      .collection('wallets').doc(walletId);
                  // Reverse: piutang was -, so add back; utang was +, so subtract back
                  batch.update(walletRef, {
                    'balance': FieldValue.increment(
                      type == 'piutang' ? amount : -amount,
                    ),
                  });
                }

                await batch.commit();
                // ignore: use_build_context_synchronously
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

  Widget _buildDebtTab(Color textColor) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('debts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "Belum ada data piutang/utang.",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              var docs = snapshot.data!.docs;
              
              // Sort: Belum Lunas first, then Lunas
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aPaid = aData['isPaid'] == true ? 1 : 0;
                final bPaid = bData['isPaid'] == true ? 1 : 0;
                if (aPaid != bPaid) return aPaid.compareTo(bPaid);
                // Then by date descending
                final aDate = aData['createdAt'] as Timestamp?;
                final bDate = bData['createdAt'] as Timestamp?;
                if (aDate == null || bDate == null) return 0;
                return bDate.compareTo(aDate);
              });

              // Calculate summaries
              double totalPiutang = 0;
              double totalUtang = 0;
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['isPaid'] == true) continue;
                final amount = (data['amount'] ?? 0).toDouble();
                if (data['type'] == 'piutang') {
                  totalPiutang += amount;
                } else {
                  totalUtang += amount;
                }
              }

              return Column(
                children: [
                  // Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Piutang Aktif", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            Text(
                              _formatRupiah(totalPiutang),
                              style: const TextStyle(
                                color: Color(0xFF00897B),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Utang Aktif", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            Text(
                              _formatRupiah(totalUtang),
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        bool isPiutang = data['type'] == 'piutang';
                        bool isPaid = data['isPaid'] == true;
                        double amount = (data['amount'] ?? 0).toDouble();
                        String personName = data['personName'] ?? '-';
                        String note = data['note'] ?? '';
                        DateTime? createdAt = data['createdAt'] != null
                            ? (data['createdAt'] as Timestamp).toDate()
                            : null;
                        DateTime? dueDate = data['dueDate'] != null
                            ? (data['dueDate'] as Timestamp).toDate()
                            : null;

                        Color typeColor = isPiutang ? const Color(0xFF00897B) : Colors.red;
                        IconData typeIcon = isPiutang
                            ? Icons.arrow_downward
                            : Icons.arrow_upward;

                        return Opacity(
                          opacity: isPaid ? 0.5 : 1.0,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(18),
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
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        // ignore: deprecated_member_use
                                        color: typeColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(typeIcon, color: typeColor, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            personName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: textColor,
                                              decoration: isPaid ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                isPiutang ? "Piutang (meminjamkan)" : "Utang (meminjam)",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: typeColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (data['patunganId'] != null) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    // ignore: deprecated_member_use
                                                    color: const Color(0xFF0F4C5C).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "Patungan",
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF0F4C5C),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatRupiah(amount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: typeColor,
                                            decoration: isPaid ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isPaid
                                                // ignore: deprecated_member_use
                                                ? Colors.green.withOpacity(0.1)
                                                // ignore: deprecated_member_use
                                                : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            isPaid ? "Lunas" : "Belum Lunas",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isPaid ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Date info row
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      createdAt != null
                                          ? DateFormat('dd MMM yyyy').format(createdAt)
                                          : '-',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                    if (dueDate != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(Icons.timer_outlined, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Jatuh tempo: ${DateFormat('dd MMM yyyy').format(dueDate)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: !isPaid && dueDate.isBefore(DateTime.now())
                                              ? Colors.red
                                              : Colors.grey.shade500,
                                          fontWeight: !isPaid && dueDate.isBefore(DateTime.now())
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    note,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                                const Divider(height: 16),
                                // Action buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _toggleDebtStatus(doc.id, isPaid, data),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          // ignore: deprecated_member_use
                                          color: (isPaid ? Colors.orange : Colors.green).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPaid ? Icons.undo : Icons.check_circle_outline,
                                              size: 14,
                                              color: isPaid ? Colors.orange : Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isPaid ? "Belum Lunas" : "Tandai Lunas",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isPaid ? Colors.orange : Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showDebtForm(document: doc),
                                      child: Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => _deleteDebt(doc.id, data),
                                      child: Icon(Icons.delete, size: 18, color: Colors.grey.shade400),
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
        ),
      ],
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
