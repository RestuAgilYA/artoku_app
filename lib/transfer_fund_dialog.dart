import 'package:artoku_app/services/ui_helper.dart';
import 'package:artoku_app/wallet_data.dart';
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
  _TransferFundDialogState createState() => _TransferFundDialogState();
}

class _TransferFundDialogState extends State<TransferFundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

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
          });
        }

        await batch.commit();

        Navigator.of(context).pop(); // Close dialog on success
        UIHelper.showSuccess(
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
    return AlertDialog(
      title: Text(_isEditMode ? "Edit Transfer" : "Pindahkan Dana"),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWalletDropdown(
                      label: "Dari Dompet",
                      value: _sourceWallet,
                      onChanged: (wallet) {
                        setState(() {
                          _sourceWallet = wallet;
                          // Jika dompet tujuan sama dengan dompet sumber, reset tujuan
                          if (_destinationWallet != null && _destinationWallet!.id == wallet?.id) {
                            _destinationWallet = null;
                          }
                        });
                      },
                      items: _wallets
                          .where((w) => w.id != _destinationWallet?.id)
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    _buildWalletDropdown(
                      label: "Ke Dompet",
                      value: _destinationWallet,
                      onChanged: (wallet) {
                        setState(() {
                          _destinationWallet = wallet;
                          // Jika dompet sumber sama dengan dompet tujuan, reset sumber
                          if (_sourceWallet != null && _sourceWallet!.id == wallet?.id) {
                            _sourceWallet = null;
                          }
                        });
                      },
                      items: _wallets
                          .where((w) => w.id != _sourceWallet?.id)
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Masukkan jumlah';
                        }
                        final amount =
                            double.tryParse(value.replaceAll('.', '')) ?? 0;
                        if (amount <= 0) {
                          return 'Jumlah harus lebih dari 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
      actions: _isLoading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: _saveTransfer,
                child: Text(_isEditMode ? 'Perbarui' : 'Pindahkan'),
              ),
            ],
    );
  }

  Widget _buildWalletDropdown({
    required String label,
    required WalletModel? value,
    required void Function(WalletModel?) onChanged,
    required List<WalletModel> items,
  }) {
    return DropdownButtonFormField<WalletModel>(
      value: value,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map<DropdownMenuItem<WalletModel>>((WalletModel wallet) {
        return DropdownMenuItem<WalletModel>(
          value: wallet,
          child: Text(
              "${wallet.name} (${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(wallet.balance)})"),
        );
      }).toList(),
      validator: (value) => value == null ? 'Pilih salah satu dompet' : null,
    );
  }
}