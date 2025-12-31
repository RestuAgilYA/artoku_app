import 'package:artoku_app/services/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:artoku_app/services/logger_service.dart';

class AddTransactionSheet extends StatefulWidget {
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
  bool _isFormValid = false; // State untuk cek form lengkap/belum

  String _selectedCategory = "Makanan";
  String? _selectedWalletId;
  String? _selectedWalletName;
  double? _selectedWalletBalance;

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

    // Listener untuk validasi realtime (Tombol Simpan)
    _amountController.addListener(_validateForm);
    _noteController.addListener(_validateForm);

    _loadCustomCategories();

    if (widget.transactionData != null) {
      final data = widget.transactionData!;
      _isExpense = (data['type'] == 'expense');
      currentColor = _isExpense ? expenseColor : incomeColor;

      _selectedCategory = data['category'] ?? (_isExpense ? "Makanan" : "Gaji");
      _noteController.text = data['note'] ?? "";
      _selectedWalletId = data['walletId'];
      _selectedWalletName = data['walletName'];
      _aiSuggestedWallet = data['suggestedWallet'];

      double oldAmount = (data['amount'] ?? 0).toDouble();
      _amountController.text = oldAmount.toInt().toString();

      if (data['date'] != null) {
        _selectedDate = (data['date'] as Timestamp).toDate();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // --- LOGIC VALIDASI FORM ---
  void _validateForm() {
    // Cek apakah nominal ada & catatan tidak kosong & dompet terpilih
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
            // Pastikan kategori terpilih ada di list, kalau tidak reset ke index 0
            List<String> currentList = _isExpense
                ? _expenseCategories
                : _incomeCategories;
            if (!currentList.contains(_selectedCategory) &&
                currentList.isNotEmpty) {
              _selectedCategory = currentList[0];
            }
          });
        }
      }
    } catch (e) {
      print("Gagal load kategori: $e");
    }
  }

  // --- LOGIC HAPUS KATEGORI ---
  void _deleteCategory(String category) async {
    // Jangan hapus jika ini satu-satunya kategori
    List<String> currentList = _isExpense
        ? _expenseCategories
        : _incomeCategories;
    if (currentList.length <= 1) {
      _showAlert("Gagal", "Minimal harus ada satu kategori.");
      return;
    }

    // Dialog Konfirmasi
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
        // Jika kategori yang dihapus sedang dipilih, pindah ke yang lain
        if (_selectedCategory == category) {
          _selectedCategory = _isExpense
              ? _expenseCategories[0]
              : _incomeCategories[0];
        }
      });

      // Update Firebase
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
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper format rupiah sederhana
  String _formatSimpleRupiah(double value) {
    return "Rp ${value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // Helper Alert Window
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
    // 1. Validasi Manual (Double Check)
    if (_amountController.text.isEmpty ||
        _noteController.text.trim().isEmpty ||
        _selectedWalletId == null ||
        user == null) {
      if (_noteController.text.trim().isEmpty) {
        // Ganti dialog bawaan dengan UIHelper (Error/Warning)
        UIHelper.showError(
          context,
          "Catatan Kosong. Mohon isi catatan agar mudah diingat.",
        );
      }
      return;
    }

    double amount =
        double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    if (amount <= 0) return;

    // 2. VALIDASI SALDO (Tetap pertahankan logika ini karena spesifik)
    if (_isExpense && widget.transactionId == null) {
      if (_selectedWalletBalance != null && amount > _selectedWalletBalance!) {
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
                  Text("Dompet '${_selectedWalletName}' hanya memiliki saldo:"),
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
      // Tampilkan Loading (Opsional, tapi bagus untuk UX)
      // UIHelper.showLoading(context);

      DocumentReference transactionRef;
      if (widget.transactionId != null) {
        // --- LOGIC UPDATE ---
        transactionRef = firestore
            .collection('users')
            .doc(user!.uid)
            .collection('transactions')
            .doc(widget.transactionId);

        // Revert Saldo Lama
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
        // --- LOGIC BARU ---
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
        'color': _isExpense ? Colors.red.value : incomeColor.value,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (widget.transactionId != null) {
        batch.update(transactionRef, dataToSave);
      } else {
        batch.set(transactionRef, dataToSave);
      }

      // Update Saldo Wallet Baru
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
        Navigator.pop(context); // Tutup BottomSheet dulu
        // --- IMPLEMENTASI UI HELPER ---
        UIHelper.showSuccess(
          context,
          "Berhasil!",
          "Transaksi berhasil ${widget.transactionId == null ? 'disimpan' : 'diperbarui'}.",
        );
      }
    } catch (e, stack) {
      // Logger Service mencatat error di background
      LoggerService.error("Gagal simpan transaksi", e, stack);

      if (mounted) {
        // Tampilkan pesan error user-friendly
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

                // --- FIX 1: Filter Dompet Terkunci (Hidden) ---
                List<QueryDocumentSnapshot> activeWallets = allWallets.where((
                  doc,
                ) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isLocked'] != true;
                }).toList();

                if (activeWallets.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("Tidak ada dompet aktif (cek 'Dompet Saya')."),
                  );
                }

                // --- FIX 2: Auto-Select 'Tunai' atau 'Cash' jika belum dipilih ---
                if (_selectedWalletId == null && widget.transactionId == null) {
                  QueryDocumentSnapshot? targetWallet;

                  // Prioritas 1: Suggestion dari AI (Camera/Voice)
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

                  // Prioritas 2: Cari 'Tunai' atau 'Cash'
                  if (targetWallet == null) {
                    try {
                      targetWallet = activeWallets.firstWhere((doc) {
                        String name = (doc.data() as Map)['name']
                            .toString()
                            .toLowerCase();
                        return name.contains('tunai') || name.contains('cash');
                      });
                    } catch (_) {
                      // Tidak ketemu 'Tunai'
                    }
                  }

                  // Prioritas 3: Ambil dompet pertama di list
                  targetWallet ??= activeWallets.first;

                  // Set State setelah frame render selesai
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
                          _validateForm(); // Cek validasi saat ganti dompet
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
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

            // --- KATEGORI + DELETE FEATURE ---
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
                    // FITUR DELETE KATEGORI
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
                          if (picked != null)
                            setState(() => _selectedDate = picked);
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

            // --- TOMBOL SIMPAN (DISABLE LOGIC) ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid
                      ? currentColor
                      : Colors.grey.shade400, // Abu-abu jika disable
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: _isFormValid ? 2 : 0,
                ),
                // Jika form tidak valid, onPressed null (tombol mati)
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
