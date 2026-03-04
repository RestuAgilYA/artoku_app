import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/features/wallet/data/wallet_model.dart';
import 'package:artoku_app/features/transfer/data/transfer_model.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Formatter for thousand separators
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

class TransferFundDialog extends StatefulWidget {
  final TransferModel? transfer;

  const TransferFundDialog({super.key, this.transfer});

  @override
  // ignore: library_private_types_in_public_api
  _TransferFundDialogState createState() => _TransferFundDialogState();
}

class _TransferFundDialogState extends State<TransferFundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  WalletModel? _sourceWallet;
  WalletModel? _destinationWallet;
  List<WalletModel> _wallets = [];
  bool _isLoading = true;
  bool get _isEditMode => widget.transfer != null;

  @override
  void initState() {
    super.initState();
    _fetchWallets();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallets() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wallets')
          .get();

      final wallets = snapshot.docs
          .map((doc) => WalletModel.fromSnapshot(doc))
          .where((wallet) => !wallet.isLocked)
          .toList();

      if (mounted) {
        setState(() {
          _wallets = wallets;
          if (_isEditMode) {
            _sourceWallet = _wallets.firstWhere((w) => w.id == widget.transfer!.sourceWalletId);
            _destinationWallet = _wallets.firstWhere((w) => w.id == widget.transfer!.destinationWalletId);
            _amountController.text =
                NumberFormat('#,###', 'id_ID').format(widget.transfer!.amount);
            _noteController.text = widget.transfer!.notes;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UIHelper.showError(context, "Gagal memuat dompet: $e");
      }
    }
  }

  Future<void> _saveTransfer() async {
    if (_formKey.currentState?.validate() ?? false) {
      final double amount =
          double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;

      if (amount <= 0) {
        UIHelper.showError(context, "Jumlah tidak valid.");
        return;
      }
      if (_sourceWallet == null || _destinationWallet == null) {
        UIHelper.showError(context, "Pilih dompet sumber dan tujuan.");
        return;
      }
      if (_sourceWallet!.id == _destinationWallet!.id) {
        UIHelper.showError(context, "Dompet sumber dan tujuan tidak boleh sama.");
        return;
      }
      if (!_isEditMode && _sourceWallet!.balance < amount) {
        UIHelper.showError(context, "Saldo dompet sumber tidak mencukupi.");
        return;
      }

      setState(() => _isLoading = true);

      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final batch = FirebaseFirestore.instance.batch();
        final usersRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        if (_isEditMode) {
          // Revert the old transfer
          final double oldAmount = widget.transfer!.amount;
          final oldSourceWalletRef =
              usersRef.collection('wallets').doc(widget.transfer!.sourceWalletId);
          batch.update(oldSourceWalletRef, {'balance': FieldValue.increment(oldAmount)});
          final oldDestWalletRef = usersRef
              .collection('wallets')
              .doc(widget.transfer!.destinationWalletId);
          batch.update(
              oldDestWalletRef, {'balance': FieldValue.increment(-oldAmount)});
        }

        // Apply the new/updated transfer
        final sourceDocRef =
            usersRef.collection('wallets').doc(_sourceWallet!.id);
        batch.update(sourceDocRef, {'balance': FieldValue.increment(-amount)});

        final destDocRef =
            usersRef.collection('wallets').doc(_destinationWallet!.id);
        batch.update(destDocRef, {'balance': FieldValue.increment(amount)});

        DocumentReference transferDocRef;
        if (_isEditMode) {
          transferDocRef =
              usersRef.collection('transfers').doc(widget.transfer!.id);
          batch.update(transferDocRef, {
            'sourceWalletId': _sourceWallet!.id,
            'sourceWalletName': _sourceWallet!.name,
            'destinationWalletId': _destinationWallet!.id,
            'destinationWalletName': _destinationWallet!.name,
            'amount': amount,
            'timestamp': FieldValue.serverTimestamp(),
            'notes': _noteController.text.trim(),
          });
        } else {
          transferDocRef = usersRef.collection('transfers').doc();
          batch.set(transferDocRef, {
            'sourceWalletId': _sourceWallet!.id,
            'sourceWalletName': _sourceWallet!.name,
            'destinationWalletId': _destinationWallet!.id,
            'destinationWalletName': _destinationWallet!.name,
            'amount': amount,
            'timestamp': FieldValue.serverTimestamp(),
            'notes': _noteController.text.trim(),
          });
        }

        await batch.commit();

      // ignore: use_build_context_synchronously
        Navigator.of(context).pop(); // Close dialog on success
        UIHelper.showSuccess(
          // ignore: use_build_context_synchronously
            context, "Berhasil", "Dana telah ${_isEditMode ? 'diperbarui' : 'dipindahkan'}.");
      } catch (e) {
        if (mounted) {
          UIHelper.showError(context, "Gagal menyimpan transfer: $e");
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final hintColor = isDark ? Colors.grey : Colors.grey.shade400;
    const primaryColor = Color(0xFF0F4C5C);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: _isLoading && _wallets.isEmpty
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header icon
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: primaryColor, size: 30),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isEditMode ? "Edit Transfer" : "Pindahkan Dana",
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Pindahkan saldo antar dompet",
                        style: TextStyle(color: hintColor, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      // Source wallet
                      _buildStyledWalletSelector(
                        context: context,
                        label: "Dari Dompet",
                        icon: Icons.output_rounded,
                        value: _sourceWallet,
                        items: _wallets.where((w) => w.id != _destinationWallet?.id).toList(),
                        onChanged: (wallet) {
                          setState(() {
                            _sourceWallet = wallet;
                            if (_destinationWallet != null && _destinationWallet!.id == wallet?.id) {
                              _destinationWallet = null;
                            }
                          });
                        },
                        textColor: textColor,
                        hintColor: hintColor,
                      ),

                      // Arrow indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: primaryColor.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, color: primaryColor, size: 20),
                        ),
                      ),

                      // Destination wallet
                      _buildStyledWalletSelector(
                        context: context,
                        label: "Ke Dompet",
                        icon: Icons.input_rounded,
                        value: _destinationWallet,
                        items: _wallets.where((w) => w.id != _sourceWallet?.id).toList(),
                        onChanged: (wallet) {
                          setState(() {
                            _destinationWallet = wallet;
                            if (_sourceWallet != null && _sourceWallet!.id == wallet?.id) {
                              _sourceWallet = null;
                            }
                          });
                        },
                        textColor: textColor,
                        hintColor: hintColor,
                      ),
                      const SizedBox(height: 20),

                      // Amount field
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Jumlah Transfer", style: TextStyle(color: hintColor, fontSize: 12)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsFormatter()],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          hintText: "0",
                          hintStyle: TextStyle(color: Colors.grey.shade300),
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
                            borderSide: const BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Masukkan jumlah';
                          final amount = double.tryParse(value.replaceAll('.', '')) ?? 0;
                          if (amount <= 0) return 'Jumlah harus lebih dari 0';
                          return null;
                        },
                      ),
                      // Source balance info
                      if (_sourceWallet != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Saldo tersedia: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_sourceWallet!.balance)}",
                              style: TextStyle(color: hintColor, fontSize: 11),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Note field
                      TextFormField(
                        controller: _noteController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Catatan (Opsional)',
                          labelStyle: TextStyle(color: hintColor, fontSize: 13),
                          prefixIcon: Icon(Icons.notes_outlined, color: hintColor, size: 20),
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
                            borderSide: const BorderSide(color: primaryColor, width: 1.5),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
                              onPressed: _isLoading ? null : _saveTransfer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                disabledBackgroundColor: primaryColor.withAlpha(100),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      _isEditMode ? "Perbarui" : "Pindahkan",
                                      style: const TextStyle(
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
              ),
      ),
    );
  }

  Widget _buildStyledWalletSelector({
    required BuildContext context,
    required String label,
    required IconData icon,
    required WalletModel? value,
    required List<WalletModel> items,
    required void Function(WalletModel?) onChanged,
    required Color textColor,
    required Color hintColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800.withAlpha(120) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: hintColor),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: hintColor, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<WalletModel>(
            // ignore: deprecated_member_use
            initialValue: value,
            onChanged: onChanged,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            style: TextStyle(color: textColor, fontSize: 14),
            hint: Text("Pilih dompet", style: TextStyle(color: hintColor)),
            items: items.map<DropdownMenuItem<WalletModel>>((WalletModel wallet) {
              return DropdownMenuItem<WalletModel>(
                value: wallet,
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: wallet.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(wallet.name, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(wallet.balance),
                      style: TextStyle(color: hintColor, fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
            validator: (value) => value == null ? 'Pilih salah satu dompet' : null,
          ),
        ],
      ),
    );
  }
}