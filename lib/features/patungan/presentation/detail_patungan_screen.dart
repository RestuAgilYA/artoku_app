import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:artoku_app/features/patungan/data/patungan_model.dart';
import 'package:artoku_app/features/patungan/data/patungan_service.dart';
import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/features/patungan/presentation/edit_patungan_sheet.dart';

// ============================================================
// DETAIL PATUNGAN SCREEN
// ============================================================

class DetailPatunganScreen extends StatelessWidget {
  final String patunganId;

  const DetailPatunganScreen({super.key, required this.patunganId});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    const Color primaryColor = Color(0xFF0F4C5C);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Login diperlukan")));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Detail Patungan",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor),
            tooltip: "Edit Patungan",
            onPressed: () => _openEditSheet(context, user),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('patungans')
            .doc(patunganId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Patungan tidak ditemukan."));
          }

          final patungan = PatunganModel.fromSnapshot(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context, patungan, primaryColor),
                const SizedBox(height: 20),
                _buildProgressSection(
                  context,
                  patungan,
                  textColor,
                  primaryColor,
                ),
                const SizedBox(height: 25),
                Text(
                  "Daftar Peserta",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(patungan.shares.length, (index) {
                  return _buildShareItem(
                    context,
                    patungan,
                    index,
                    textColor,
                    primaryColor,
                  );
                }),
                const SizedBox(height: 30),
                // Tombol Hapus
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      "Hapus Patungan",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _confirmDelete(context, patungan),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Summary Card ──
  Widget _buildSummaryCard(
    BuildContext context,
    PatunganModel patungan,
    Color primaryColor,
  ) {
    final formattedDate =
        DateFormat('dd MMM yyyy, HH:mm').format(patungan.createdAt);
    final isSettled = patungan.status == PatunganStatus.settled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSettled
              ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
              : [const Color(0xFF0F4C5C), const Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  patungan.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSettled ? "LUNAS" : "AKTIF",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            UIHelper.formatRupiah(patungan.totalAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                patungan.walletName,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.calendar_today,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                formattedDate,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                "Dibuat oleh: ${patungan.createdBy}",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress Section ──
  Widget _buildProgressSection(
    BuildContext context,
    PatunganModel patungan,
    Color textColor,
    Color primaryColor,
  ) {
    final isSettled = patungan.status == PatunganStatus.settled;
    final progress = patungan.totalParticipants > 0
        ? patungan.paidCount / patungan.totalParticipants
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Progress Pembayaran",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              Text(
                "${patungan.paidCount}/${patungan.totalParticipants}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSettled ? Colors.green : primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.grey.shade200,
                  color: isSettled ? Colors.green : primaryColor,
                  minHeight: 8,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sudah dibayar",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    UIHelper.formatRupiah(patungan.paidAmount),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Belum dibayar",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    UIHelper.formatRupiah(patungan.unpaidAmount),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Share Item ──
  Widget _buildShareItem(
    BuildContext context,
    PatunganModel patungan,
    int index,
    Color textColor,
    Color primaryColor,
  ) {
    final share = patungan.shares[index];
    final isPaidOrCreator =
        share.status == ShareStatus.paid || share.isCreator;
    final statusColor = isPaidOrCreator ? Colors.green : Colors.orange;
    final statusText = share.isCreator
        ? "Pembuat"
        : share.status == ShareStatus.paid
            ? "Lunas"
            : "Belum Bayar";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  // ignore: deprecated_member_use
                  (share.isCreator ? primaryColor : statusColor).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              share.isCreator
                  ? Icons.star
                  : share.status == ShareStatus.paid
                      ? Icons.check_circle
                      : Icons.person,
              color: share.isCreator ? primaryColor : statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Nama & nominal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  UIHelper.formatRupiah(share.amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    // ignore: deprecated_member_use
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                if (share.paidAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Dibayar: ${DateFormat('dd MMM yyyy').format(share.paidAt!)}",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status badge & toggle button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              // Toggle hanya untuk non-creator
              if (!share.isCreator) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _toggleShareStatus(
                    context,
                    patungan,
                    index,
                    share,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (share.status == ShareStatus.paid
                              ? Colors.orange
                              : Colors.green)
                          // ignore: deprecated_member_use
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          share.status == ShareStatus.paid
                              ? Icons.undo
                              : Icons.check_circle_outline,
                          size: 14,
                          color: share.status == ShareStatus.paid
                              ? Colors.orange
                              : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          share.status == ShareStatus.paid
                              ? "Batalkan"
                              : "Tandai Lunas",
                          style: TextStyle(
                            fontSize: 11,
                            color: share.status == ShareStatus.paid
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Open Edit Sheet ──
  void _openEditSheet(BuildContext context, User user) async {
    // Fetch the current patungan data
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('patungans')
          .doc(patunganId)
          .get();

      if (!doc.exists) {
        if (context.mounted) {
          UIHelper.showError(context, "Patungan tidak ditemukan.");
        }
        return;
      }

      final patungan = PatunganModel.fromSnapshot(doc);

      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EditPatunganSheet(patungan: patungan),
      );
    } catch (e) {
      if (context.mounted) {
        UIHelper.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  // ── Toggle Share Status Dialog ──
  void _toggleShareStatus(
    BuildContext context,
    PatunganModel patungan,
    int index,
    PatunganShare share,
  ) async {
    final isPaid = share.status == ShareStatus.paid;

    if (isPaid) {
      // Batalkan pembayaran - tidak perlu pilih wallet
      final paidWalletId = share.paidWalletId ?? patungan.walletId;
      // Fetch wallet name for display
      String walletLabel = patungan.walletName;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && paidWalletId.isNotEmpty) {
          final wDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('wallets')
              .doc(paidWalletId)
              .get();
          if (wDoc.exists) {
            walletLabel = (wDoc.data()?['name'] as String?) ?? walletLabel;
          }
        }
      } catch (_) {}

      if (!context.mounted) return;

      showDialog(
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
            "Anda akan membatalkan pembayaran untuk ${share.name} "
            "sebesar ${UIHelper.formatRupiah(share.amount)}.\n\n"
            "Saldo dompet '$walletLabel' akan dikurangi otomatis.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Batal",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await PatunganService.markShareAsUnpaid(
                    patunganId: patungan.id,
                    shareIndex: index,
                  );
                  if (context.mounted) {
                    UIHelper.showSuccess(
                      context,
                      "Berhasil",
                      "Pembayaran ${share.name} telah dibatalkan.",
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    UIHelper.showError(
                      context,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Batalkan",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Tandai Lunas - tampilkan wallet picker
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch unlocked wallets (filter locally for robustness)
      // Menggunakan generic type agar .data() return Map<String, dynamic>
      // tanpa perlu cast manual yang bisa throw TypeError.
      List<QueryDocumentSnapshot<Map<String, dynamic>>> wallets = [];
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('wallets')
            .get();
        wallets = snapshot.docs.where((doc) {
          final d = doc.data();
          return d['isLocked'] != true;
        }).toList();
      } catch (_) {}

      if (!context.mounted) return;

      if (wallets.isEmpty) {
        UIHelper.showError(context, "Tidak ada dompet yang tersedia.");
        return;
      }

      // Pre-select patungan's wallet jika ada di list unlocked,
      // atau fallback ke dompet pertama
      String selectedWalletId = wallets.any((w) => w.id == patungan.walletId)
          ? patungan.walletId
          : wallets.first.id;

      showDialog(
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
                      "Tandai ${share.name} lunas "
                      "sebesar ${UIHelper.formatRupiah(share.amount)}.",
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
                            final wName =
                                (wData['name'] as String?) ?? 'Dompet';
                            final wBalance =
                                (wData['balance'] as num?)?.toDouble() ?? 0;
                            final wColor =
                                (wData['color'] as num?)?.toInt() ??
                                    0xFF0F4C5C;
                            return DropdownMenuItem<String>(
                              value: w.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(wColor),
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
                                    UIHelper.formatRupiah(wBalance),
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
                      "Saldo ${selectedWalletData['name'] ?? 'Dompet'}: "
                      "${UIHelper.formatRupiah((selectedWalletData['balance'] as num?)?.toDouble() ?? 0)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Batal",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await PatunganService.markShareAsPaid(
                          patunganId: patungan.id,
                          shareIndex: index,
                          targetWalletId: selectedWalletId,
                        );
                        if (context.mounted) {
                          UIHelper.showSuccess(
                            context,
                            "Berhasil",
                            "${share.name} telah ditandai lunas.",
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          UIHelper.showError(
                            context,
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Lunas",
                      style: TextStyle(
                        color: Colors.white,
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
  }

  // ── Confirm Delete Dialog ──
  void _confirmDelete(BuildContext context, PatunganModel patungan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color messageColor = isDark ? Colors.white70 : Colors.black87;

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
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
              "Hapus Patungan?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Semua data patungan, piutang terkait, dan transaksi expense "
              "akan dihapus. Saldo dompet akan dikembalikan.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: messageColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Batal",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Hapus",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        await PatunganService.deletePatungan(patunganId: patungan.id);
        if (context.mounted) {
          await UIHelper.showSuccess(
            context,
            "Terhapus",
            "Patungan telah dihapus.",
          );
          if (context.mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          UIHelper.showError(
            context,
            e.toString().replaceFirst('Exception: ', ''),
          );
        }
      }
    });
  }
}
