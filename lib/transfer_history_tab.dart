import 'package:artoku_app/detail_transfer_screen.dart';
import 'package:artoku_app/services/ui_helper.dart';
import 'package:artoku_app/transfer_fund_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'wallet_data.dart';

class TransferHistoryTab extends StatelessWidget {
  final Function({TransferModel transfer}) onEdit;

  const TransferHistoryTab({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Silakan login untuk melihat riwayat."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transfers')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Belum ada riwayat pemindahan dana.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final transfers = snapshot.data!.docs
            .map((doc) => TransferModel.fromSnapshot(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final transfer = transfers[index];
            final formattedDate =
                DateFormat('dd MMM yyyy, HH:mm').format(transfer.timestamp.toDate());

            return Dismissible(
              key: Key(transfer.id),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) { // Geser ke kanan (Edit)
                  showDialog(
                    context: context,
                    builder: (context) => TransferFundDialog(transfer: transfer),
                  );
                  return false; // Jangan hapus item
                } else { // Geser ke kiri (Hapus)
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final Color messageColor = isDark ? Colors.white70 : Colors.black87;
                  return await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "Hapus Transfer?",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Tindakan ini tidak dapat dibatalkan. Data transfer dan perubahan saldo akan dikembalikan.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: messageColor),
                            ),
                          ],
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              "Batal",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              "Hapus",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              onDismissed: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  // Hapus dari Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('transfers')
                      .doc(transfer.id)
                      .delete();

                  // Kembalikan saldo
                  final sourceWalletRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('wallets')
                      .doc(transfer.sourceWalletId);

                  final destinationWalletRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('wallets')
                      .doc(transfer.destinationWalletId);

                  await FirebaseFirestore.instance.runTransaction((transaction) async {
                    // Tambah saldo di dompet sumber
                    transaction.update(sourceWalletRef, {
                      'balance': FieldValue.increment(transfer.amount),
                    });
                    // Kurangi saldo di dompet tujuan
                    transaction.update(destinationWalletRef, {
                      'balance': FieldValue.increment(-transfer.amount),
                    });
                  });

                  UIHelper.showSuccess(
                    context,
                    "Berhasil",
                    "Riwayat transfer telah dihapus.",
                  );
                }
              },
              background: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.centerLeft,
                child: const Icon(Icons.edit, color: Colors.white),
              ),
              secondaryBackground: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailTransferScreen(transfer: transfer),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz, color: Color(0xFF0F4C5C), size: 40),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${transfer.sourceWalletName} → ${transfer.destinationWalletName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                UIHelper.formatRupiah(transfer.amount),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Dialog Detail Transfer
class DetailTransferDialog extends StatelessWidget {
  final TransferModel transfer;

  const DetailTransferDialog({required this.transfer});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color cardColor = Theme.of(context).cardColor;
    final formattedDate =
        DateFormat('dd MMM yyyy, HH:mm').format(transfer.timestamp.toDate());

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      content: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4C5C),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Detail Transfer",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F4C5C).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz,
                        color: Color(0xFF0F4C5C),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Transfer Dana",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      UIHelper.formatRupiah(transfer.amount),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F4C5C),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Detail rows
                    _buildDetailRow("Dari", transfer.sourceWalletName, textColor),
                    const SizedBox(height: 16),
                    _buildDetailRow("Ke", transfer.destinationWalletName, textColor),
                    const SizedBox(height: 16),
                    _buildDetailRow("Tanggal", formattedDate, textColor),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      "Catatan",
                      transfer.notes.isNotEmpty ? transfer.notes : "-",
                      textColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Dialog Edit Transfer (Form)
class TransferFundDialog extends StatefulWidget {
  final TransferModel? transfer;

  const TransferFundDialog({this.transfer});

  @override
  _TransferFundDialogState createState() => _TransferFundDialogState();
}

class _TransferFundDialogState extends State<TransferFundDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

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
    _notesController.dispose();
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
            // Try to find the wallets from the transfer being edited
            try {
              _sourceWallet = wallets.firstWhere(
                (w) => w.id == widget.transfer!.sourceWalletId,
              );
            } catch (e) {
              // If source wallet is locked, use first available
              _sourceWallet = wallets.isNotEmpty ? wallets.first : null;
            }
            
            try {
              _destinationWallet = wallets.firstWhere(
                (w) => w.id == widget.transfer!.destinationWalletId,
              );
            } catch (e) {
              // If destination wallet is locked, use last available
              _destinationWallet = wallets.length > 1 ? wallets.last : null;
            }
            
            _amountController.text = NumberFormat('#,###', 'id_ID')
                .format((widget.transfer!.amount).toInt());
            _notesController.text = widget.transfer!.notes;
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
          double.parse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));

      if (amount <= 0) {
        UIHelper.showError(context, "Jumlah harus lebih dari 0");
        return;
      }

      if (_sourceWallet == null || _destinationWallet == null) {
        UIHelper.showError(context, "Pilih dompet sumber dan tujuan");
        return;
      }

      if (_sourceWallet!.id == _destinationWallet!.id) {
        UIHelper.showError(context, "Dompet sumber dan tujuan tidak boleh sama");
        return;
      }

      if (!_isEditMode && _sourceWallet!.balance < amount) {
        UIHelper.showError(context, "Saldo dompet sumber tidak cukup");
        return;
      }

      setState(() => _isLoading = true);

      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("User tidak ditemukan");

        if (_isEditMode) {
          // Mode edit
          final oldAmount = widget.transfer!.amount;
          final amountDifference = amount - oldAmount;

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final sourceWalletRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('wallets')
                .doc(_sourceWallet!.id);

            final destinationWalletRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('wallets')
                .doc(_destinationWallet!.id);

            final transferRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('transfers')
                .doc(widget.transfer!.id);

            transaction.update(sourceWalletRef, {
              'balance': FieldValue.increment(-amountDifference),
            });
            transaction.update(destinationWalletRef, {
              'balance': FieldValue.increment(amountDifference),
            });
            transaction.update(transferRef, {
              'amount': amount,
              'notes': _notesController.text,
              'timestamp': FieldValue.serverTimestamp(),
            });
          });

          if (mounted) {
            Navigator.pop(context);
            UIHelper.showSuccess(context, "Berhasil", "Transfer berhasil diperbarui");
          }
        } else {
          // Mode create
          final batch = FirebaseFirestore.instance.batch();
          final usersRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('transfers')
              .doc();

          batch.set(usersRef, {
            'id': usersRef.id,
            'sourceWalletId': _sourceWallet!.id,
            'sourceWalletName': _sourceWallet!.name,
            'destinationWalletId': _destinationWallet!.id,
            'destinationWalletName': _destinationWallet!.name,
            'amount': amount,
            'notes': _notesController.text,
            'timestamp': FieldValue.serverTimestamp(),
          });

          batch.update(
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('wallets')
                .doc(_sourceWallet!.id),
            {'balance': FieldValue.increment(-amount)},
          );

          batch.update(
            FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('wallets')
                .doc(_destinationWallet!.id),
            {'balance': FieldValue.increment(amount)},
          );

          await batch.commit();

          if (mounted) {
            Navigator.pop(context);
            UIHelper.showSuccess(
              context,
              "Berhasil",
              "Dana berhasil dipindahkan",
            );
          }
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showError(context, "Error: $e");
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
      title: Text(_isEditMode ? "Perbarui Transfer" : "Pindahkan Dana"),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWalletDropdown(
                      label: "Dari Dompet",
                      value: _sourceWallet,
                      onChanged: (wallet) =>
                          setState(() => _sourceWallet = wallet),
                      items: _wallets,
                      excludeId: _destinationWallet?.id,
                    ),
                    const SizedBox(height: 16),
                    _buildWalletDropdown(
                      label: "Ke Dompet",
                      value: _destinationWallet,
                      onChanged: (wallet) =>
                          setState(() => _destinationWallet = wallet),
                      items: _wallets,
                      excludeId: _sourceWallet?.id,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: "Jumlah",
                        border: OutlineInputBorder(),
                        prefixText: "Rp ",
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      validator: (value) =>
                          value?.isEmpty ?? true ? "Masukkan jumlah" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: "Catatan (Opsional)",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTransfer,
          child: Text(_isEditMode ? "Perbarui" : "Pindahkan"),
        ),
      ],
    );
  }

  Widget _buildWalletDropdown({
    required String label,
    required WalletModel? value,
    required void Function(WalletModel?) onChanged,
    required List<WalletModel> items,
    String? excludeId,
  }) {
    final filteredItems = excludeId != null
        ? items.where((w) => w.id != excludeId).toList()
        : items;

    return DropdownButtonFormField<WalletModel>(
      value: value,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: filteredItems.map<DropdownMenuItem<WalletModel>>((WalletModel wallet) {
        return DropdownMenuItem<WalletModel>(
          value: wallet,
          child: Text('${wallet.name} (Rp ${NumberFormat('#,###', 'id_ID').format(wallet.balance.toInt())})'),
        );
      }).toList(),
      validator: (value) => value == null ? 'Pilih dompet' : null,
    );
  }
}