import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:artoku_app/features/patungan/data/patungan_service.dart';
import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/core/utils/currency_input_formatter.dart';

// ============================================================
// CREATE PATUNGAN SHEET

class CreatePatunganSheet extends StatefulWidget {
  const CreatePatunganSheet({super.key});

  @override
  State<CreatePatunganSheet> createState() => _CreatePatunganSheetState();
}

class _CreatePatunganSheetState extends State<CreatePatunganSheet> {
  static const Color _primaryColor = Color(0xFF0F4C5C);

  final _titleController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final CurrencyTextInputFormatter _currencyFormatter =
      const CurrencyTextInputFormatter();

  String? _selectedWalletId;
  String? _selectedWalletName;
  double? _selectedWalletBalance;
  bool _isLoading = false;
  late String _creatorName;

  // Kategori (sama dengan expense categories di AddTransactionSheet)
  String _selectedCategory = 'Lainnya';
  List<String> _expenseCategories = [
    'Makanan',
    'Transport',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Lainnya',
  ];

  // Participants: index 0 = creator
  final List<_ParticipantEntry> _participants = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _creatorName = _getUserDisplayName(user);

    // Creator sebagai peserta pertama
    _participants.add(
      _ParticipantEntry(
        nameController: TextEditingController(text: _creatorName),
        amountController: TextEditingController(),
        isCreator: true,
      ),
    );
    // Satu peserta kosong
    _participants.add(
      _ParticipantEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ),
    );

    _titleController.addListener(_onFormChanged);
    _totalAmountController.addListener(_onAmountChanged);
    for (final p in _participants) {
      p.nameController.addListener(_onFormChanged);
      p.amountController.addListener(_onFormChanged);
    }
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalAmountController.dispose();
    for (final p in _participants) {
      p.nameController.dispose();
      p.amountController.dispose();
    }
    super.dispose();
  }

  String _getUserDisplayName(User? user) {
    final displayName = user?.displayName;
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user?.email;
    if (email != null) {
      String name = email.split('@')[0];
      if (name.isNotEmpty) return name[0].toUpperCase() + name.substring(1);
    }
    return "User";
  }

  // ── Kategori helpers ──

  Future<void> _loadCustomCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['expense_categories'] != null) {
          final loaded = List<String>.from(data['expense_categories']);
          // Pastikan selected masih valid setelah load
          setState(() {
            _expenseCategories = loaded;
            if (!_expenseCategories.contains(_selectedCategory)) {
              _selectedCategory = _expenseCategories.contains('Lainnya')
                  ? 'Lainnya'
                  : _expenseCategories.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _deleteCategory(String category) {
    if (_expenseCategories.length <= 1) {
      UIHelper.showError(context, 'Minimal harus ada satu kategori.');
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text("Kategori '$category' akan dihapus dari daftar pilihan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _expenseCategories.remove(category);
        if (_selectedCategory == category) {
          _selectedCategory = _expenseCategories.contains('Lainnya')
              ? 'Lainnya'
              : _expenseCategories.first;
        }
      });
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'expense_categories': _expenseCategories,
        }, SetOptions(merge: true));
      }
    });
  }

  void _showAddCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: TextField(
          controller: catController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Contoh: Liburan',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              final newCat = catController.text.trim();
              if (newCat.isEmpty) return;
              final user = FirebaseAuth.instance.currentUser;
              setState(() {
                _expenseCategories.add(newCat);
                _selectedCategory = newCat;
              });
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .set({
                      'expense_categories': _expenseCategories,
                    }, SetOptions(merge: true));
              }
              // ignore: use_build_context_synchronously
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onAmountChanged() => setState(() {});

  void _onFormChanged() => setState(() {});

  bool get _isFormValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_getTotalAmount() <= 0) return false;
    if (_selectedWalletId == null) return false;
    for (final p in _participants) {
      if (p.nameController.text.trim().isEmpty) return false;
      final amt =
          double.tryParse(
            p.amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      if (amt <= 0) return false;
    }
    final sumShares = _getSumOfShares();
    final totalAmount = _getTotalAmount();
    if ((sumShares - totalAmount).abs() > 0.01) return false;
    return true;
  }

  void _addParticipant() {
    setState(() {
      final entry = _ParticipantEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      );
      entry.nameController.addListener(_onFormChanged);
      entry.amountController.addListener(_onFormChanged);
      _participants.add(entry);
    });
  }

  void _removeParticipant(int index) {
    if (index == 0) return; // Tidak bisa hapus creator
    if (_participants.length <= 2) {
      UIHelper.showError(context, "Minimal 2 peserta diperlukan.");
      return;
    }
    setState(() {
      _participants[index].nameController.dispose();
      _participants[index].amountController.dispose();
      _participants.removeAt(index);
    });
  }

  double _getTotalAmount() {
    return double.tryParse(
          _totalAmountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  double _getSumOfShares() {
    double sum = 0;
    for (final p in _participants) {
      sum +=
          double.tryParse(
            p.amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
    }
    return sum;
  }

  void _splitEqually() {
    final total = _getTotalAmount();
    if (total <= 0) {
      UIHelper.showError(context, "Masukkan total nominal terlebih dahulu.");
      return;
    }

    final count = _participants.length;
    final perPerson = (total / count).floorToDouble();
    final remainder = total - (perPerson * count);

    setState(() {
      for (int i = 0; i < _participants.length; i++) {
        double amount = perPerson;
        // Sisa pembulatan diberikan ke peserta pertama
        if (i == 0) amount += remainder;
        final formatter = NumberFormat('#,###', 'id_ID');
        _participants[i].amountController.text = formatter.format(
          amount.toInt(),
        );
      }
    });
  }

  Future<void> _save() async {
    // ── Validasi ──
    if (_titleController.text.trim().isEmpty) {
      UIHelper.showError(context, "Judul patungan tidak boleh kosong.");
      return;
    }

    final totalAmount = _getTotalAmount();
    if (totalAmount <= 0) {
      UIHelper.showError(context, "Total nominal harus lebih dari 0.");
      return;
    }

    if (_selectedWalletId == null) {
      UIHelper.showError(context, "Pilih dompet terlebih dahulu.");
      return;
    }

    if (_selectedWalletBalance != null &&
        totalAmount > _selectedWalletBalance!) {
      UIHelper.showError(
        context,
        "Saldo dompet tidak cukup. "
        "Saldo: ${UIHelper.formatRupiah(_selectedWalletBalance!)}",
      );
      return;
    }

    // Validasi peserta
    for (int i = 0; i < _participants.length; i++) {
      final name = _participants[i].nameController.text.trim();
      if (name.isEmpty) {
        UIHelper.showError(
          context,
          "Nama peserta ke-${i + 1} tidak boleh kosong.",
        );
        return;
      }
      final amount =
          double.tryParse(
            _participants[i].amountController.text.replaceAll(
              RegExp(r'[^0-9]'),
              '',
            ),
          ) ??
          0;
      if (amount <= 0) {
        UIHelper.showError(
          context,
          "Nominal untuk '$name' harus lebih dari 0.",
        );
        return;
      }
    }

    // Validasi sum
    final sumShares = _getSumOfShares();
    if ((sumShares - totalAmount).abs() > 0.01) {
      UIHelper.showError(
        context,
        "Total bagian (${UIHelper.formatRupiah(sumShares)}) tidak sama "
        "dengan total patungan (${UIHelper.formatRupiah(totalAmount)}).",
      );
      return;
    }

    // Validasi nama unik
    final names = _participants
        .map((p) => p.nameController.text.trim().toLowerCase())
        .toList();
    if (names.toSet().length != names.length) {
      UIHelper.showError(context, "Nama peserta tidak boleh ada yang sama.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final participants = _participants.map((p) {
        return {
          'name': p.nameController.text.trim(),
          'amount': double.parse(
            p.amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ),
        };
      }).toList();

      await PatunganService.createPatungan(
        title: _titleController.text.trim(),
        totalAmount: totalAmount,
        walletId: _selectedWalletId!,
        walletName: _selectedWalletName!,
        creatorName: _participants[0].nameController.text.trim(),
        category: _selectedCategory,
        participants: participants,
      );

      if (mounted) {
        Navigator.pop(context);
        UIHelper.showSuccess(context, "Berhasil!", "Patungan berhasil dibuat.");
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color sheetBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color hintColor = isDark ? Colors.grey : Colors.grey.shade400;
    final Color chipBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final Color chipText = isDark ? Colors.white70 : Colors.black87;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final totalAmount = _getTotalAmount();
    final sumShares = _getSumOfShares();
    final remaining = totalAmount - sumShares;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: sheetBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
          const SizedBox(height: 15),
          Text(
            "Buat Patungan Baru",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),

          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Judul ──
                  Text(
                    "Judul",
                    style: TextStyle(color: hintColor, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Contoh: Makan Siang Kantor",
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
                  const SizedBox(height: 15),

                  // ── Kategori ──
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._expenseCategories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return GestureDetector(
                          onLongPress: () => _deleteCategory(cat),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: _primaryColor,
                            backgroundColor: chipBg,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : chipText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat),
                          ),
                        );
                      }),
                      ActionChip(
                        label: const Icon(Icons.add, size: 16),
                        backgroundColor: chipBg,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ── Total Nominal ──
                  Text(
                    "Total Nominal",
                    style: TextStyle(color: hintColor, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _totalAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_currencyFormatter],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                    decoration: InputDecoration(
                      prefixText: "Rp ",
                      prefixStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                      hintText: "0",
                      hintStyle: TextStyle(color: Colors.grey.shade300),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),

                  // ── Wallet Selector ──
                  Text(
                    "Dompet yang Digunakan",
                    style: TextStyle(color: hintColor, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  _buildWalletSelector(chipBg, chipText),
                  const Divider(height: 30),

                  // ── Peserta Header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Peserta (${_participants.length})",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _splitEqually,
                            icon: Icon(
                              Icons.auto_fix_high,
                              size: 16,
                              color: _primaryColor,
                            ),
                            label: Text(
                              "Bagi Rata",
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _addParticipant,
                            icon: Icon(
                              Icons.person_add,
                              color: _primaryColor,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Participant List ──
                  ...List.generate(_participants.length, (index) {
                    return _buildParticipantRow(
                      index,
                      textColor,
                      hintColor,
                      chipBg,
                    );
                  }),

                  const SizedBox(height: 10),

                  // ── Remaining Amount Indicator ──
                  if (totalAmount > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: remaining.abs() < 0.01
                            // ignore: deprecated_member_use
                            ? Colors.green.withOpacity(0.1)
                            // ignore: deprecated_member_use
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            remaining.abs() < 0.01
                                ? "Pembagian sudah pas! ✓"
                                : remaining > 0
                                ? "Sisa belum dibagi:"
                                : "Kelebihan:",
                            style: TextStyle(
                              color: remaining.abs() < 0.01
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (remaining.abs() >= 0.01)
                            Text(
                              UIHelper.formatRupiah(remaining.abs()),
                              style: TextStyle(
                                color: remaining > 0
                                    ? Colors.orange
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 25),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isLoading || !_isFormValid)
                              ? _primaryColor.withAlpha(100)
                              : _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: (_isLoading || !_isFormValid) ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Buat Patungan",
                                style: TextStyle(
                                  color: _isFormValid
                                      ? Colors.white
                                      : Colors.white.withAlpha(120),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSelector(Color chipBg, Color chipText) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('wallets')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50);

        final wallets = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isLocked'] != true;
        }).toList();

        if (wallets.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text("Tidak ada dompet aktif."),
          );
        }

        // Auto-select dompet pertama jika belum dipilih
        if (_selectedWalletId == null && wallets.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final data = wallets.first.data() as Map<String, dynamic>;
              setState(() {
                _selectedWalletId = wallets.first.id;
                _selectedWalletName = data['name'] as String?;
                _selectedWalletBalance = (data['balance'] ?? 0).toDouble();
              });
            }
          });
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: wallets.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isSelected = _selectedWalletId == doc.id;
              final wColor = Color(data['color'] ?? 0xFF0F4C5C);
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedWalletId = doc.id;
                  _selectedWalletName = data['name'] as String?;
                  _selectedWalletBalance = (data['balance'] ?? 0).toDouble();
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? wColor : chipBg,
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
                        color: isSelected ? Colors.white : chipText,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data['name'] ?? '',
                        style: TextStyle(
                          color: isSelected ? Colors.white : chipText,
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
    );
  }

  Widget _buildParticipantRow(
    int index,
    Color textColor,
    Color hintColor,
    Color cardBg,
  ) {
    final p = _participants[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Index indicator
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.isCreator ? _primaryColor : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Text(
              "${index + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nama peserta
          Expanded(
            flex: 3,
            child: TextField(
              controller: p.nameController,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Nama",
                hintStyle: TextStyle(color: hintColor, fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixIcon: p.isCreator
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Anda",
                            style: TextStyle(
                              fontSize: 9,
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minHeight: 20,
                  minWidth: 40,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nominal peserta
          Expanded(
            flex: 3,
            child: TextField(
              controller: p.amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [_currencyFormatter],
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                prefixText: "Rp ",
                prefixStyle: TextStyle(color: hintColor, fontSize: 13),
                hintText: "0",
                hintStyle: TextStyle(color: hintColor, fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),

          // Tombol hapus (tidak untuk creator)
          if (!p.isCreator)
            GestureDetector(
              onTap: () => _removeParticipant(index),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.shade300,
                  size: 22,
                ),
              ),
            )
          else
            const SizedBox(width: 26),
        ],
      ),
    );
  }
}

/// Internal class for managing participant form state.
class _ParticipantEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final bool isCreator;

  _ParticipantEntry({
    required this.nameController,
    required this.amountController,
    this.isCreator = false,
  });
}
