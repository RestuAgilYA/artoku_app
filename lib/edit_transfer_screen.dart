import 'package:artoku_app/services/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'wallet_data.dart';

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

class EditTransferScreen extends StatefulWidget {
  final TransferModel transfer;

  const EditTransferScreen({super.key, required this.transfer});

  @override
  // ignore: library_private_types_in_public_api
  _EditTransferScreenState createState() => _EditTransferScreenState();
}

class _EditTransferScreenState extends State<EditTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: NumberFormat('#,###', 'id_ID').format(widget.transfer.amount));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _updateTransfer() async {
    if (_formKey.currentState?.validate() ?? false) {
      final double newAmount =
          double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
      final double oldAmount = widget.transfer.amount;

      if (newAmount <= 0) {
        UIHelper.showError(context, "Jumlah tidak valid.");
        return;
      }

      setState(() => _isLoading = true);

      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final batch = FirebaseFirestore.instance.batch();
        final usersRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        // Reference to the transfer document
        final transferDocRef =
            usersRef.collection('transfers').doc(widget.transfer.id);

        // Update transfer amount
        batch.update(transferDocRef, {'amount': newAmount});

        // Revert old transaction amounts from wallets
        final sourceWalletRef =
            usersRef.collection('wallets').doc(widget.transfer.sourceWalletId);
        batch.update(sourceWalletRef, {'balance': FieldValue.increment(oldAmount)});

        final destinationWalletRef = usersRef
            .collection('wallets')
            .doc(widget.transfer.destinationWalletId);
        batch.update(
            destinationWalletRef, {'balance': FieldValue.increment(-oldAmount)});

        // Apply new transaction amounts to wallets
        batch.update(
            sourceWalletRef, {'balance': FieldValue.increment(-newAmount)});
        batch.update(
            destinationWalletRef, {'balance': FieldValue.increment(newAmount)});

        await batch.commit();

      // ignore: use_build_context_synchronously
        Navigator.of(context).pop(); // Close screen on success
        // ignore: use_build_context_synchronously
        UIHelper.showSuccess(context, "Berhasil", "Transfer telah diperbarui.");
      } catch (e) {
        if (mounted) {
          UIHelper.showError(context, "Gagal memperbarui transfer: $e");
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Transfer"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dari: ${widget.transfer.sourceWalletName}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ke: ${widget.transfer.destinationWalletName}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateTransfer,
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
