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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(document == null ? "Tambah Piutang/Utang" : "Edit Piutang/Utang"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Type selector
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => selectedType = 'piutang'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedType == 'piutang' ? const Color(0xFF00897B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedType == 'piutang' ? const Color(0xFF00897B) : Colors.grey.shade300,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Piutang",
                                style: TextStyle(
                                  color: selectedType == 'piutang' ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => selectedType = 'utang'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedType == 'utang' ? Colors.red : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedType == 'utang' ? Colors.red : Colors.grey.shade300,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Utang",
                                style: TextStyle(
                                  color: selectedType == 'utang' ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: selectedType == 'piutang'
                            ? "Nama Peminjam"
                            : "Nama Pemberi Pinjaman",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: const InputDecoration(
                        labelText: "Jumlah",
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: "Keterangan (opsional)"),
                    ),
                    const SizedBox(height: 10),
                    // Pilih Dompet
                    DropdownButtonFormField<String>(
                      value: selectedWalletId,
                      decoration: const InputDecoration(labelText: "Dompet"),
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
                        setDialogState(() => selectedWalletId = value);
                      },
                      hint: const Text("Pilih dompet"),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 12),
                    // Tanggal
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Tanggal",
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Jatuh tempo (opsional)
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Jatuh Tempo (opsional)",
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dueDate != null)
                                GestureDetector(
                                  onTap: () => setDialogState(() => dueDate = null),
                                  child: const Icon(Icons.clear, size: 18),
                                ),
                              const Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                        child: Text(
                          dueDate != null
                              ? DateFormat('dd MMM yyyy').format(dueDate!)
                              : 'Tidak ada',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
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
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleDebtStatus(String debtId, bool currentStatus, Map<String, dynamic> debtData) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(currentStatus ? "Ubah ke Belum Lunas?" : "Tandai Lunas?"),
          content: Text(
            currentStatus
                ? "Status akan diubah menjadi Belum Lunas."
                : "Status akan diubah menjadi Lunas.",
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

                batch.update(debtRef, {
                  'isPaid': !currentStatus,
                  'paidAt': !currentStatus ? FieldValue.serverTimestamp() : null,
                });

                // Sync wallet balance
                final walletId = debtData['walletId'] as String?;
                final amount = (debtData['amount'] ?? 0).toDouble();
                final type = debtData['type'] ?? 'piutang';

                if (walletId != null) {
                  final walletRef = FirebaseFirestore.instance
                      .collection('users').doc(user!.uid)
                      .collection('wallets').doc(walletId);

                  if (!currentStatus) {
                    // Marking as Lunas: Piutang → money comes back (+); Utang → money paid back (-)
                    batch.update(walletRef, {
                      'balance': FieldValue.increment(
                        type == 'piutang' ? amount : -amount,
                      ),
                    });
                  } else {
                    // Undo Lunas: Piutang → money goes out (-); Utang → money received (+)
                    batch.update(walletRef, {
                      'balance': FieldValue.increment(
                        type == 'piutang' ? -amount : amount,
                      ),
                    });
                  }
                }

                await batch.commit();
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              },
              child: Text(currentStatus ? "Belum Lunas" : "Lunas"),
            ),
          ],
        );
      },
    );
  }

  void _deleteDebt(String debtId, Map<String, dynamic> debtData) {
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
                                          Text(
                                            isPiutang ? "Piutang (meminjamkan)" : "Utang (meminjam)",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: typeColor,
                                              fontWeight: FontWeight.w600,
                                            ),
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
