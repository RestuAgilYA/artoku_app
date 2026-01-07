import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'profile_screen.dart';
import 'add_transaction_sheet.dart';
import 'report_screen.dart';
import 'analysis_screen.dart';
import 'detail_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'my_wallet_screen.dart';
import 'gemini_service.dart';
import 'package:artoku_app/services/ui_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color primaryColor = const Color(0xFF0F4C5C);
  bool _isExpenseVisible = true;

  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // HAPUS: bool _isAnalyzing = false; (Sudah tidak perlu)

  final User? user = FirebaseAuth.instance.currentUser;
  late Stream<QuerySnapshot> _transactionStream;

  @override
  void initState() {
    super.initState();
    _checkAndCreateDefaultWallets();

    if (user != null) {
      _transactionStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots();
    }
  }

  Future<void> _checkAndCreateDefaultWallets() async {
    if (user == null) return;
    final walletRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('wallets');

    final snapshot = await walletRef.limit(1).get();
    if (snapshot.docs.isEmpty) {
      await walletRef.add({
        'name': 'Tunai / Cash',
        'balance': 0,
        'color': 0xFF4CAF50,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _handleCameraScan() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (photo == null) return;

      // Tampilkan Loading Dialog
      if (mounted) {
        UIHelper.showLoading(context);
      }

      File imageFile = File(photo.path);
      final result = await GeminiService.scanReceipt(imageFile);

      // Tutup Loading Dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (result != null && mounted) {
        _openAddTransactionWithData(result);
      } else {
        if (mounted) {
          UIHelper.showError(context, "Gagal membaca struk.");
        }
      }
    } catch (e) {
      // Pastikan loading tertutup jika error
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleVoiceInput() async {
    bool available = await _speech.initialize(
      onError: (val) => debugPrint('Error: $val'),
      onStatus: (val) => debugPrint('Status: $val'),
    );

    if (available) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const VoiceListeningDialog(),
      ).then((result) async {
        if (result != null && result.toString().isNotEmpty) {
          String text = result.toString();

          // Tampilkan Loading
          if (mounted) UIHelper.showLoading(context);

          try {
            final data = await GeminiService.analyzeText(text);

            // Tutup Loading
            if (mounted) Navigator.pop(context);

            if (data != null && mounted) {
              _openAddTransactionWithData(data);
            } else {
              if (mounted) {
                UIHelper.showError(context, "Gagal menganalisa suara.");
              }
            }
          } catch (e) {
            if (mounted) Navigator.pop(context);
          }
        }
      });
    } else {
      UIHelper.showError(context, "Mikrofon tidak tersedia.");
    }
  }

  void _openAddTransactionWithData(Map<String, dynamic> data) {
    Timestamp now = Timestamp.now();
    String type = data['type'] ?? 'expense';
    if (type != 'expense' && type != 'income') type = 'expense';

    Map<String, dynamic> prepData = {
      'amount': data['amount'] ?? 0,
      'category': data['category'] ?? 'Lainnya',
      'note': data['note'] ?? '',
      'type': type,
      'date': now,
      'walletId': null,
      'walletName': null,
      'suggestedWallet': data['wallet'],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(transactionData: prepData),
    );
  }

  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    List<String> months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String _getUserDisplayName() {
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user!.displayName!;
    }
    if (user?.email != null) {
      String name = user!.email!.split('@')[0];
      return name[0].toUpperCase() + name.substring(1);
    }
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: _buildQuickMenu(isDark),
                ),
                const SizedBox(height: 10),
                _buildTransactionList(isDark, textColor),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildCustomFAB(),
      bottomNavigationBar: _buildBottomAppBar(isDark),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('transactions')
          .snapshots(),
      builder: (context, snapshot) {
        double thisMonthExpense = 0;
        double thisMonthIncome = 0;
        DateTime now = DateTime.now();

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            Timestamp? t = data['date'];
            if (t == null) continue;
            DateTime date = t.toDate();
            double amount = (data['amount'] ?? 0).toDouble();
            String type = data['type'] ?? 'expense';

            if (date.year == now.year && date.month == now.month) {
              if (type == 'expense')
                thisMonthExpense += amount;
              else
                thisMonthIncome += amount;
            }
          }
        }

        return Container(
          width: double.infinity,
          height: 340,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F4C5C), Color(0xFF00695C)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 60,
                  left: 25,
                  right: 25,
                  bottom: 30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getUserDisplayName(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Pengeluaran Bulan Ini",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isExpenseVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _isExpenseVisible = !_isExpenseVisible,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isExpenseVisible
                              ? _formatRupiah(thisMonthExpense)
                              : "**********",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Pemasukan",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatRupiah(thisMonthIncome),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MyWalletScreen(),
                                ),
                              ),
                              child: _buildWalletCardInfo(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalletCardInfo() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('wallets')
          .snapshots(),
      builder: (context, snapshot) {
        double totalBalance = 0;
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            totalBalance += (doc['balance'] ?? 0).toDouble();
          }
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.greenAccent,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Dompet Saya >",
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatRupiah(totalBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "$count Akun Terhubung",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickMenu(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMenuItem(
            "Laporan",
            Icons.menu_book,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportScreen()),
            ),
          ),
          _buildMenuItem(
            "Analisa",
            Icons.pie_chart,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AnalysisScreen()),
            ),
          ),
          _buildMenuItem("Patungan", Icons.groups, isComingSoon: true),
          _buildMenuItem("Catatan", Icons.edit_note, isComingSoon: true),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData icon, {
    VoidCallback? onTap,
    bool isComingSoon = false,
  }) {
    Color iconColor = isComingSoon ? Colors.grey : primaryColor;
    Color bgColor = isComingSoon
        ? Colors.grey.withOpacity(0.1)
        : primaryColor.withOpacity(0.1);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(bool isDark, Color textColor) {
    Color dateColor = isDark ? Colors.grey : Colors.grey.shade600;

    return StreamBuilder<QuerySnapshot>(
      stream: _transactionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 50,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Belum ada transaksi",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }

        var documents = snapshot.data!.docs;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Transaksi Terakhir",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AllTransactionsScreen(),
                      ),
                    ),
                    child: const Text("Lihat semua >"),
                  ),
                ],
              ),
              ...documents.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String category = data['category'] ?? 'Tanpa Kategori';
                String note = data['note'] ?? '';
                String displayTitle = (note.isNotEmpty) ? note : category;
                String displaySubtitle = category;
                double amount = (data['amount'] ?? 0).toDouble();
                String formattedPrice = _formatRupiah(amount);
                String dateString = "";
                if (data['date'] != null)
                  dateString = _formatDate(data['date'] as Timestamp);

                String fullSubtitle = "$displaySubtitle • $dateString";
                Color color = Color(data['color'] ?? 0xFFF44336);

                return _transactionItem(
                  doc.id,
                  displayTitle,
                  fullSubtitle,
                  formattedPrice,
                  color,
                  textColor,
                  dateColor,
                  data,
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // --- SWIPE GESTURE & POP-UP DIALOG ---
  Widget _transactionItem(
    String docId,
    String title,
    String subtitle,
    String price,
    Color color,
    Color titleColor,
    Color subtitleColor,
    Map<String, dynamic> rawData,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Dismissible(
        key: Key(docId),
        // Swipe Right (Edit) & Left (Delete)
        background: Container(
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerLeft,
          child: const Icon(Icons.edit, color: Colors.white, size: 28),
        ),
        secondaryBackground: Container(
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // EDIT
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddTransactionSheet(
                transactionId: docId,
                transactionData: rawData,
              ),
            );
            return false; // Jangan hapus dari list visual dulu
          } else {
            // DELETE (Dialog Konfirmasi)
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Hapus Transaksi?"),
                content: const Text(
                  "Data akan dihapus permanen dan saldo dikembalikan.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Batal"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "Hapus",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }
        },
        onDismissed: (direction) async {
          // PROSES HAPUS & REFUND SALDO
          if (direction == DismissDirection.endToStart) {
            double amount = (rawData['amount'] ?? 0).toDouble();
            String? walletId = rawData['walletId'];
            String type = rawData['type'] ?? 'expense';

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('transactions')
                .doc(docId)
                .delete();

            if (walletId != null) {
              final walletRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('wallets')
                  .doc(walletId);
              double refund = (type == 'expense') ? amount : -amount;
              await walletRef.update({'balance': FieldValue.increment(refund)});
            }

            if (mounted) {
              // GANTI SNACKBAR DENGAN POP-UP DIALOG SUKSES
              UIHelper.showSuccess(
                context,
                "Terhapus",
                "Transaksi telah dihapus.",
              );
            }
          }
        },
        child: GestureDetector(
          onTap: () {
            Map<String, dynamic> transactionData = {
              ...rawData,
              "title": title,
              "date": subtitle,
              "price": price,
              "color": color,
              "id": docId,
            };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DetailTransactionScreen(data: transactionData),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                radius: 24,
                child: Icon(Icons.monetization_on, color: color, size: 24),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
              trailing: Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFAB() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _handleCameraScan,
            child: _buildCircularIconButton(
              Icons.camera_alt_outlined,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const AddTransactionSheet(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C5C), Color(0xFF082D37)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Text(
                "Catat Transaksi",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleVoiceInput,
            child: _buildCircularIconButton(Icons.mic_none_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIconButton(IconData icon, {double size = 24}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.3),
          width: 1.2,
        ),
        color: Theme.of(context).cardColor,
      ),
      child: Icon(icon, color: Theme.of(context).iconTheme.color, size: size),
    );
  }

  Widget _buildBottomAppBar(bool isDark) {
    return BottomAppBar(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: const SizedBox(height: 60),
    );
  }
}

// === WIDGET DIALOG ANIMASI SUARA ===
class VoiceListeningDialog extends StatefulWidget {
  const VoiceListeningDialog({super.key});

  @override
  State<VoiceListeningDialog> createState() => _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends State<VoiceListeningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  stt.SpeechToText _speech = stt.SpeechToText();
  String _text = "Mendengarkan...";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(_controller);

    _startListening();
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(
        onResult: (val) {
          setState(() {
            _text = val.recognizedWords;
          });
        },
        localeId: "id_ID",
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ScaleTransition(
            scale: _animation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, size: 50, color: Colors.red),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Silakan Bicara...",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _text == "Mendengarkan..." ? "" : _text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C5C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Selesai & Proses",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
