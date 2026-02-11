import 'package:artoku_app/services/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:artoku_app/services/logger_service.dart';
import 'package:intl/intl.dart';

// Custom Formatter
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const separator = '.'; // Separator for thousands

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Get the numeric value
    String newText = newValue.text.replaceAll(separator, '');

    if (int.tryParse(newText) == null) {
      return oldValue;
    }

    final formatter = NumberFormat('#,###');
    String newFormattedText = formatter.format(int.parse(newText)).replaceAll(',', separator);

    return newValue.copyWith(
      text: newFormattedText,
      selection: TextSelection.collapsed(offset: newFormattedText.length),
    );
  }
}


class AddTransactionSheet extends StatefulWidget {
  // Parameter untuk menerima hasil analisa Gemini
  final Map<String, dynamic>? transactionData;
  final String? transactionId;

  const AddTransactionSheet({
    super.key,
    this.transactionData,
    this.transactionId,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  Color currentColor = const Color(0xFF0F4C5C);

  final Color expenseColor = const Color(0xFF0F4C5C);
  final Color incomeColor = const Color(0xFF00897B);

  bool _isExpense = true;
  bool _isFormValid = false;

  String _selectedCategory = "Makanan";
  String? _selectedWalletId;
  String? _selectedWalletName;
  double? _selectedWalletBalance;

  // Variabel untuk menampung saran dompet dari AI
  String? _aiSuggestedWallet;

  late TextEditingController _amountController;
  late TextEditingController _noteController;
  DateTime _selectedDate = DateTime.now();

  final User? user = FirebaseAuth.instance.currentUser;

  List<String> _expenseCategories = [
    "Makanan",
    "Transport",
    "Belanja",
    "Tagihan",
    "Hiburan",
    "Lainnya",
  ];
  List<String> _incomeCategories = [
    "Gaji",
    "Bonus",
    "Investasi",
    "Hadiah",
    "Lainnya",
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();

    _amountController.addListener(_validateForm);
    _noteController.addListener(_validateForm);

    _loadCustomCategories();

    // --- LOGIC AUTO-FILL DARI GEMINI ---
    if (widget.transactionData != null) {
      final data = widget.transactionData!;

      // 1. Tipe Transaksi
      if (data['type'] != null) {
        _isExpense = (data['type'] == 'expense');
        currentColor = _isExpense ? expenseColor : incomeColor;
      }

      // 2. Kategori (Akan divalidasi nanti di _loadCustomCategories)
      if (data['category'] != null) {
        _selectedCategory = data['category'];
      }

      // 3. Catatan
      _noteController.text = data['note'] ?? "";

      // 4. Dompet (Simpan nama saran dari AI, nanti dicocokkan di StreamBuilder)
      _selectedWalletId = data['walletId']; // Kalau edit manual
      _selectedWalletName = data['walletName'];
      _aiSuggestedWallet = data['wallet']; // Dari Gemini berupa string nama

      // 5. Nominal
      double amount = (data['amount'] ?? 0).toDouble();
      if (amount > 0) {
        final formatter = NumberFormat('#,###');
        _amountController.text = formatter.format(amount.toInt()).replaceAll(',', '.');
      }

      // 6. Tanggal
      if (data['date'] != null) {
        if (data['date'] is Timestamp) {
          _selectedDate = (data['date'] as Timestamp).toDate();
        } else if (data['date'] is String) {
          // Jika format string YYYY-MM-DD dari gemini
          try {
            _selectedDate = DateTime.parse(data['date']);
          } catch (_) {}
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _validateForm() {
    double amount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    bool isValid =
        amount > 0 &&
        _noteController.text.trim().isNotEmpty &&
        _selectedWalletId != null;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _loadCustomCategories() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (data['expense_categories'] != null) {
              _expenseCategories = List<String>.from(
                data['expense_categories'],
              );
            }
            if (data['income_categories'] != null) {
              _incomeCategories = List<String>.from(data['income_categories']);
            }

            // Validasi: Pastikan kategori dari AI ada di list user
            List<String> currentList = _isExpense
                ? _expenseCategories
                : _incomeCategories;

            // Cari yang mirip (Case Insensitive)
            String? match = currentList.firstWhere(
              (c) => c.toLowerCase() == _selectedCategory.toLowerCase(),
              orElse: () => "",
            );

            if (match.isNotEmpty) {
              _selectedCategory = match;
            } else if (currentList.isNotEmpty) {
              // Jika tidak ketemu, default ke yang pertama atau "Lainnya"
              _selectedCategory = currentList.contains("Lainnya")
                  ? "Lainnya"
                  : currentList[0];
            }
          });
        }
      }
    } catch (e) {
      LoggerService.error("Gagal load kategori", e);
    }
  }

  void _deleteCategory(String category) async {
    // ... (delete category) ...
    List<String> currentList = _isExpense
        ? _expenseCategories
        : _incomeCategories;
    if (currentList.length <= 1) {
      _showAlert("Gagal", "Minimal harus ada satu kategori.");
      return;
    }
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Hapus Kategori?"),
            content: Text(
              "Kategori '$category' akan dihapus dari daftar pilihan.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Batal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && user != null) {
      setState(() {
        if (_isExpense) {
          _expenseCategories.remove(category);
        } else {
          _incomeCategories.remove(category);
        }

        if (_selectedCategory == category) {
          _selectedCategory = _isExpense
              ? _expenseCategories[0]
              : _incomeCategories[0];
        }
      });
      String field = _isExpense ? 'expense_categories' : 'income_categories';
      List<String> listToSave = _isExpense
          ? _expenseCategories
          : _incomeCategories;
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        field: listToSave,
      }, SetOptions(merge: true));
    }
  }

  void _showAddCategoryDialog() {
    // ... (add category) ...
    TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Tambah Kategori ${_isExpense ? 'Pengeluaran' : 'Pemasukan'}",
        ),
        content: TextField(
          controller: catController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: "Contoh: Tabungan Nikah",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: currentColor),
            onPressed: () async {
              String newCat = catController.text.trim();
              if (newCat.isNotEmpty && user != null) {
                setState(() {
                  if (_isExpense) {
                    _expenseCategories.add(newCat);
                  } else {
                    _incomeCategories.add(newCat);
                  }
                  _selectedCategory = newCat;
                });
                String field = _isExpense
                    ? 'expense_categories'
                    : 'income_categories';
                List<String> listToSave = _isExpense
                    ? _expenseCategories
                    : _incomeCategories;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .set({field: listToSave}, SetOptions(merge: true));
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatSimpleRupiah(double value) {
    return "Rp ${value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  Future<void> _showAlert(
    String title,
    String message, {
    bool isError = true,
  }) async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: isError ? Colors.red : Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: isError ? Colors.red : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Oke",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTransaction() async {
    // ... (Logika save) ...
    if (_amountController.text.isEmpty ||
        _noteController.text.trim().isEmpty ||
        _selectedWalletId == null ||
        user == null) {
      if (_noteController.text.trim().isEmpty) {
        UIHelper.showError(context, "Catatan Kosong. Mohon isi catatan.");
      }
      return;
    }
    double amount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    if (amount <= 0) return;

    if (_isExpense && widget.transactionId == null) {
      if (_selectedWalletBalance != null && amount > _selectedWalletBalance!) {
        // Tampilkan warning saldo tidak cukup
        await showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Saldo Tidak Cukup",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Dompet '$_selectedWalletName' hanya memiliki saldo:"),
                  const SizedBox(height: 5),
                  Text(
                    _formatSimpleRupiah(_selectedWalletBalance!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20),
                  const Text("Kamu mencoba mencatat:"),
                  const SizedBox(height: 5),
                  Text(
                    _formatSimpleRupiah(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Saya Mengerti",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
        return;
      }
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      DocumentReference transactionRef;
      if (widget.transactionId != null) {
        transactionRef = firestore
            .collection('users')
            .doc(user!.uid)
            .collection('transactions')
            .doc(widget.transactionId);
        double oldAmount = (widget.transactionData!['amount'] ?? 0).toDouble();
        String? oldWalletId = widget.transactionData!['walletId'];
        String oldType = widget.transactionData!['type'] ?? 'expense';

        if (oldWalletId != null) {
          final oldWalletRef = firestore
              .collection('users')
              .doc(user!.uid)
              .collection('wallets')
              .doc(oldWalletId);
          double reverseAmount = (oldType == 'expense')
              ? oldAmount
              : -oldAmount;
          batch.update(oldWalletRef, {
            'balance': FieldValue.increment(reverseAmount),
          });
        }
      } else {
        transactionRef = firestore
            .collection('users')
            .doc(user!.uid)
            .collection('transactions')
            .doc();
      }

      Map<String, dynamic> dataToSave = {
        'title': _selectedCategory,
        'note': _noteController.text,
        'amount': amount,
        'type': _isExpense ? 'expense' : 'income',
        'date': Timestamp.fromDate(_selectedDate),
        'category': _selectedCategory,
        'walletId': _selectedWalletId,
        'walletName': _selectedWalletName,
        // ignore: deprecated_member_use
        'color': _isExpense ? Colors.red.value : incomeColor.value,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.transactionId != null) {
        batch.update(transactionRef, dataToSave);
      } else {
        batch.set(transactionRef, dataToSave);
      }

      final newWalletRef = firestore
          .collection('users')
          .doc(user!.uid)
          .collection('wallets')
          .doc(_selectedWalletId);
      double finalAmount = _isExpense ? -amount : amount;
      batch.update(newWalletRef, {
        'balance': FieldValue.increment(finalAmount),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        UIHelper.showSuccess(
          context,
          "Berhasil!",
          "Transaksi berhasil ${widget.transactionId == null ? 'disimpan' : 'diperbarui'}.",
        );
      }
    } catch (e, stack) {
      LoggerService.error("Gagal simpan transaksi", e, stack);
      if (mounted) {
        UIHelper.showError(context, "Gagal menyimpan data database.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color hintColor = isDark ? Colors.grey : Colors.grey.shade400;
    final Color unselectedChipBg = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade100;
    final Color unselectedChipText = isDark ? Colors.white70 : Colors.black87;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    List<String> currentCategories = _isExpense
        ? _expenseCategories
        : _incomeCategories;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: sheetBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: unselectedChipBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleButton("Pengeluaran", true),
                    _buildToggleButton("Pemasukan", false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              _isExpense ? "Bayar Menggunakan:" : "Masuk ke Dompet:",
              style: TextStyle(color: hintColor, fontSize: 12),
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('wallets')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 50);
                List<QueryDocumentSnapshot> allWallets = snapshot.data!.docs;
                List<QueryDocumentSnapshot> activeWallets = allWallets.where((
                  doc,
                ) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isLocked'] != true;
                }).toList();

                if (activeWallets.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("Tidak ada dompet aktif."),
                  );
                }

                // --- SMART WALLET SELECTION ---
                // Logic ini dijalankan jika user belum memilih dompet secara manual
                if (_selectedWalletId == null && widget.transactionId == null) {
                  QueryDocumentSnapshot? targetWallet;

                  // 1. Coba cari berdasarkan saran AI (jika ada)
                  if (_aiSuggestedWallet != null) {
                    try {
                      targetWallet = activeWallets.firstWhere((doc) {
                        String name = (doc.data() as Map)['name']
                            .toString()
                            .toLowerCase();
                        return name.contains(_aiSuggestedWallet!.toLowerCase());
                      });
                    } catch (_) {}
                  }

                  // 2. Jika tidak ada, cari default "Tunai" / "Cash"
                  if (targetWallet == null) {
                    try {
                      targetWallet = activeWallets.firstWhere((doc) {
                        String name = (doc.data() as Map)['name']
                            .toString()
                            .toLowerCase();
                        return name.contains('tunai') || name.contains('cash');
                      });
                    } catch (_) {}
                  }

                  // 3. Fallback ke dompet pertama
                  targetWallet ??= activeWallets.first;

                  // Update state setelah build selesai
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedWalletId = targetWallet!.id;
                        _selectedWalletName =
                            (targetWallet.data() as Map)['name'];
                        _selectedWalletBalance =
                            ((targetWallet.data() as Map)['balance'] ?? 0)
                                .toDouble();
                      });
                      _validateForm();
                    }
                  });
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: activeWallets.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      bool isSelected = _selectedWalletId == doc.id;
                      Color wColor = Color(data['color']);
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedWalletId = doc.id;
                          _selectedWalletName = data['name'];
                          _selectedWalletBalance = (data['balance'] ?? 0)
                              .toDouble();
                          _validateForm();
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? wColor : unselectedChipBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : unselectedChipText,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                data['name'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : unselectedChipText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const Divider(height: 30),
            Text("Nominal", style: TextStyle(color: hintColor, fontSize: 12)),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: currentColor,
              ),
              decoration: InputDecoration(
                prefixText: "Rp ",
                prefixStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: currentColor,
                ),
                border: InputBorder.none,
                hintText: "0",
                hintStyle: TextStyle(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Kategori",
                  style: TextStyle(color: hintColor, fontSize: 12),
                ),
                Text(
                  "(Tahan untuk hapus)",
                  style: TextStyle(
                    // ignore: deprecated_member_use
                    color: hintColor.withOpacity(0.5),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...currentCategories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onLongPress: () => _deleteCategory(category),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: currentColor,
                      backgroundColor: unselectedChipBg,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : unselectedChipText,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (selected) =>
                          setState(() => _selectedCategory = category),
                    ),
                  );
                }),
                ActionChip(
                  label: const Icon(Icons.add, size: 18),
                  backgroundColor: unselectedChipBg,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: _showAddCategoryDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tanggal",
                        style: TextStyle(color: hintColor, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: hintColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Catatan (Wajib)",
                        style: TextStyle(color: hintColor, fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _noteController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: _isExpense
                              ? "Makan siang..."
                              : "Gaji bulan ini...",
                          hintStyle: TextStyle(color: hintColor),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid
                      ? currentColor
                      : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: _isFormValid ? 2 : 0,
                ),
                onPressed: _isFormValid ? _saveTransaction : null,
                child: Text(
                  widget.transactionId == null ? "Simpan" : "Update",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isExpenseBtn) {
    bool isActive = _isExpense == isExpenseBtn;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpense = isExpenseBtn;
          currentColor = _isExpense ? expenseColor : incomeColor;
          _selectedCategory = _isExpense
              ? (_expenseCategories.isNotEmpty ? _expenseCategories[0] : "")
              : (_incomeCategories.isNotEmpty ? _incomeCategories[0] : "");
          _validateForm();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? (isExpenseBtn ? expenseColor : incomeColor)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}