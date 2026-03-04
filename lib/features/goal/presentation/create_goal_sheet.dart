import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:artoku_app/features/goal/data/goal_model.dart';
import 'package:artoku_app/features/goal/data/goal_service.dart';
import 'package:artoku_app/core/services/ui_helper.dart';

// ============================================================
// CREATE / EDIT GOAL SHEET
// Jika `goal` diberikan, mode = Edit. Jika null, mode = Create.
// ============================================================

class ThousandsSeparatorFormatter extends TextInputFormatter {
  static const separator = '.';

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = newValue.text.replaceAll(separator, '');
    if (int.tryParse(newText) == null) {
      return oldValue;
    }

    final formatter = NumberFormat('#,###');
    String formatted =
        formatter.format(int.parse(newText)).replaceAll(',', separator);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CreateGoalSheet extends StatefulWidget {
  final GoalModel? goal; // null = create, non-null = edit

  const CreateGoalSheet({super.key, this.goal});

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  static const Color _primaryColor = Color(0xFF0F4C5C);

  late TextEditingController _titleController;
  late TextEditingController _amountController;

  String? _selectedWalletId;
  String? _selectedWalletName;
  DateTime? _selectedDeadline;
  bool _isLoading = false;
  bool _isFormValid = false;

  bool get _isEditMode => widget.goal != null;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title ?? '');
    _amountController = TextEditingController(
      text: widget.goal != null
          ? _formatNumber(widget.goal!.targetAmount.toInt())
          : '',
    );
    _selectedWalletId = widget.goal?.walletId;
    _selectedWalletName = widget.goal?.walletName;
    _selectedDeadline = widget.goal?.deadline;

    _titleController.addListener(_validateForm);
    _amountController.addListener(_validateForm);

    // Delay to allow sheet to build, then validate
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateForm());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number).replaceAll(',', '.');
  }

  void _validateForm() {
    final title = _titleController.text.trim();
    final amountText =
        _amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
    final amount = double.tryParse(amountText) ?? 0;

    setState(() {
      _isFormValid =
          title.isNotEmpty && amount > 0 && _selectedWalletId != null;
    });
  }

  double _parseAmount() {
    final text =
        _amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0;
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: (brightness == Brightness.dark
                    ? ColorScheme.dark(
                        primary: _primaryColor,
                        onPrimary: Colors.white,
                        surface: Theme.of(context).scaffoldBackgroundColor,
                      )
                    : ColorScheme.light(
                        primary: _primaryColor,
                        onPrimary: Colors.white,
                        surface: Theme.of(context).scaffoldBackgroundColor,
                      )),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_isFormValid) return;

    final title = _titleController.text.trim();
    final amount = _parseAmount();

    setState(() => _isLoading = true);

    try {
      if (_isEditMode) {
        await GoalService.editGoal(
          goalId: widget.goal!.id,
          title: title,
          targetAmount: amount,
          deadline: _selectedDeadline,
          walletId: _selectedWalletId,
          walletName: _selectedWalletName,
        );
      } else {
        await GoalService.createGoal(
          title: title,
          walletId: _selectedWalletId!,
          walletName: _selectedWalletName ?? '',
          targetAmount: amount,
          deadline: _selectedDeadline,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        UIHelper.showSuccess(
          // ignore: use_build_context_synchronously
          context,
          _isEditMode ? "Berhasil Diedit" : "Berhasil Dibuat",
          _isEditMode
              ? "Target tabungan berhasil diperbarui."
              : "Target tabungan \"$title\" berhasil dibuat!",
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        UIHelper.showError(
          // ignore: use_build_context_synchronously
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              _isEditMode ? "Edit Target Tabungan" : "Buat Target Tabungan",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _isEditMode
                  ? "Perbarui detail target tabungan Anda"
                  : "Tentukan tujuan keuangan Anda",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 25),

            // Goal Title
            _buildLabel("Judul Target"),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "Contoh: Beli iPhone, Dana Darurat",
                prefixIcon: const Icon(Icons.savings_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Target Amount
            _buildLabel("Target Nominal"),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorFormatter(),
              ],
              decoration: InputDecoration(
                hintText: "0",
                prefixText: "Rp ",
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Wallet Selector
            _buildLabel("Pilih Dompet"),
            const SizedBox(height: 8),
            _buildWalletSelector(),
            const SizedBox(height: 20),

            // Deadline (optional)
            _buildLabel("Tenggat Waktu (Opsional)"),
            const SizedBox(height: 8),
            _buildDeadlinePicker(),
            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isFormValid && !_isLoading) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  // ignore: deprecated_member_use
                  disabledBackgroundColor: _primaryColor.withOpacity(0.35),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditMode ? "Simpan Perubahan" : "Buat Target",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }

  Widget _buildWalletSelector() {
    if (_user == null) {
      return const Text("User belum login");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .collection('wallets')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final wallets = snapshot.data!.docs;
        if (wallets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 10),
                Text("Belum ada dompet. Buat dompet terlebih dahulu."),
              ],
            ),
          );
        }

        // Auto-select first wallet if not yet selected
        if (_selectedWalletId == null && wallets.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final first = wallets.first;
              final data = first.data() as Map<String, dynamic>;
              setState(() {
                _selectedWalletId = first.id;
                _selectedWalletName = data['name'] ?? 'Dompet';
              });
              _validateForm();
            }
          });
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: wallets.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Dompet';
              final balance = (data['balance'] ?? 0).toDouble();
              final color = Color(data['color'] ?? 0xFF0F4C5C);
              final isSelected = _selectedWalletId == doc.id;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedWalletId = doc.id;
                    _selectedWalletName = name;
                  });
                  _validateForm();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Theme.of(context).cardColor,
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
                        color: isSelected ? Colors.white : color,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            UIHelper.formatRupiah(balance),
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
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

  Widget _buildDeadlinePicker() {
    List<String> months = [
      "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember",
    ];

    return GestureDetector(
      onTap: _pickDeadline,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: _selectedDeadline != null
                  ? _primaryColor
                  : Colors.grey.shade500,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDeadline != null
                    ? "${_selectedDeadline!.day} ${months[_selectedDeadline!.month - 1]} ${_selectedDeadline!.year}"
                    : "Pilih tanggal (opsional)",
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedDeadline != null
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Colors.grey.shade500,
                ),
              ),
            ),
            if (_selectedDeadline != null)
              GestureDetector(
                onTap: () {
                  setState(() => _selectedDeadline = null);
                },
                child: Icon(
                  Icons.close,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
