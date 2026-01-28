import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'profile_screen.dart';
import 'add_transaction_sheet.dart';
import 'report_screen.dart';
import 'analysis_screen.dart';
import 'detail_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'my_wallet_screen.dart';
import 'package:artoku_app/services/ai_transaction_helper.dart';
import 'package:artoku_app/services/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color primaryColor = const Color(0xFF0F4C5C);
  bool _isExpenseVisible = true;

  // STREAM (Disimpan di state agar tidak refresh/kedip saat setState lain berjalan)
  late Stream<QuerySnapshot> _transactionStream;

  @override
  void initState() {
    super.initState();
    _loadVisibilityPreference();
    _checkAndCreateDefaultWallets();
    _initTransactionStream();
  }

  Future<void> _loadVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isExpenseVisible = prefs.getBool('isExpenseVisible') ?? true;
    });
  }

  void _initTransactionStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _transactionStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots();
    }
  }

  Future<void> _checkAndCreateDefaultWallets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final walletRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wallets');

    final snapshot = await walletRef.limit(1).get();
    if (snapshot.docs.isEmpty) {
      await walletRef.add({
        'name': 'Tunai / Cash',
        'balance': 0,
        'color': 0xFF4CAF50,
        'createdAt': FieldValue.serverTimestamp(),
        'usage': 0,
        'isLocked': false,
      });
    }
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

  // FIX: Hapus tanda seru (!) agar tidak warning kuning dan aman dari null
  String _getUserDisplayName(User? user) {
    final displayName = user?.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final email = user?.email;
    if (email != null) {
      String name = email.split('@')[0];
      if (name.isNotEmpty) {
        return name[0].toUpperCase() + name.substring(1);
      }
    }
    return "User";
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Keluar Aplikasi?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari aplikasi?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Batal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    // Handle null safety: return false if dialog dismissed without choice
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmationDialog(context);
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(user),
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: _buildQuickMenu(isDark),
                  ),
                  const SizedBox(height: 10),
                  _buildTransactionList(isDark, textColor, user),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _buildCustomFAB(),
        bottomNavigationBar: _buildBottomAppBar(isDark),
      ),
    );
  }

  Widget _buildHeader(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .snapshots(),
      builder: (context, snapshot) {
        double thisMonthExpense = 0;
        double thisMonthIncome = 0;
        double lastMonthExpense = 0;
        DateTime now = DateTime.now();

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            DateTime date = (data['date'] as Timestamp).toDate();
            double amount = (data['amount'] ?? 0).toDouble();
            String type = data['type'] ?? 'expense';

            if (date.year == now.year && date.month == now.month) {
              if (type == 'expense') {
                thisMonthExpense += amount;
              } else if (type == 'income')
                // ignore: curly_braces_in_flow_control_structures
                thisMonthIncome += amount;
            }
            if (date.year == now.year && date.month == now.month - 1) {
              if (type == 'expense') lastMonthExpense += amount;
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
                    // ignore: deprecated_member_use
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
                    // ignore: deprecated_member_use
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
                              _getUserDisplayName(user),
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
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            setState(() {
                              _isExpenseVisible = !_isExpenseVisible;
                              prefs.setBool(
                                'isExpenseVisible',
                                _isExpenseVisible,
                              );
                            });
                          },
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
                        const SizedBox(width: 10),
                        if (_isExpenseVisible)
                          _buildPillBadge(thisMonthExpense, lastMonthExpense),
                      ],
                    ),
                    const SizedBox(height: 25),
                    IntrinsicHeight(
                      child: Row(
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
                                  // FIX: Hide Pemasukan juga
                                  Text(
                                    _isExpenseVisible
                                        ? _formatRupiah(thisMonthIncome)
                                        : "**********",
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
                              child: _buildWalletCardInfo(user),
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

  Widget _buildPillBadge(double current, double last) {
    if (last == 0) return const SizedBox();
    double diff = current - last;
    double percentage = (diff / last) * 100;
    bool isHemat = diff < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            isHemat ? Icons.arrow_downward : Icons.arrow_upward,
            color: isHemat ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
            size: 12,
          ),
          Text(
            "${percentage.abs().toStringAsFixed(0)}%",
            style: TextStyle(
              color: isHemat
                  ? const Color(0xFF69F0AE)
                  : const Color(0xFFFF5252),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCardInfo(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wallets')
          .snapshots(),
      builder: (context, snapshot) {
        double totalBalance = 0;
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs){
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
              // FIX: Hide Saldo Dompet
              Text(
                _isExpenseVisible ? _formatRupiah(totalBalance) : "**********",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "$count Akun Terhubung",
                style: TextStyle(
                  // ignore: deprecated_member_use
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
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
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
          // FIX: Kembalikan label SOON
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
        // ignore: deprecated_member_use
        ? Colors.grey.withOpacity(0.1)
        // ignore: deprecated_member_use
        : primaryColor.withOpacity(0.1);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            if (isComingSoon)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Soon",
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
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

  Widget _buildTransactionList(bool isDark, Color textColor, User user) {
    Color dateColor = isDark ? Colors.grey : Colors.grey.shade600;

    // FIX: Gunakan variable _transactionStream dari initState agar tidak refresh/kedip
    return StreamBuilder<QuerySnapshot>(
      stream: _transactionStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100);
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
                return _transactionItem(
                  doc.id,
                  data['note'] ?? data['category'],
                  "${data['category']} • ${_formatDate(data['date'])}",
                  _formatRupiah(data['amount']),
                  Color(data['color'] ?? 0xFFF44336),
                  textColor,
                  dateColor,
                  data,
                  user,
                );
              // ignore: unnecessary_to_list_in_spreads
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _transactionItem(
    String docId,
    String title,
    String subtitle,
    String price,
    Color color,
    Color titleColor,
    Color subtitleColor,
    Map<String, dynamic> rawData,
    User user,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Dismissible(
        key: Key(docId),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddTransactionSheet(
                transactionId: docId,
                transactionData: rawData,
              ),
            );
            return false;
          }
          // Konfirmasi hapus swipe kiri - modern dialog
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final Color messageColor = isDark ? Colors.white70 : Colors.black87;
          final confirmed = await showDialog<bool>(
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
                    "Hapus Transaksi?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color.fromRGBO(183, 28, 28, 1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Tindakan ini tidak dapat dibatalkan. Saldo dompet akan dikembalikan sesuai transaksi.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: messageColor),
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
          );
          return confirmed == true;
        },
        background: Container(
          color: Colors.blue,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        secondaryBackground: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (d) async {
          // Hapus dan refund saldo
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .doc(docId)
              .delete();

          if (rawData['walletId'] != null) {
            String type = rawData['type'] ?? 'expense';
            double amount = (rawData['amount'] ?? 0).toDouble();
            bool isExpense = (type == 'expense' || type == 'Pengeluaran');
            double refund = isExpense ? amount : -amount;
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('wallets')
                .doc(rawData['walletId'])
                .update({'balance': FieldValue.increment(refund)});
          }

          // Pop up sukses, lalu kembali ke dashboard tanpa reload
          if (context.mounted) {
            await UIHelper.showSuccess(
              // ignore: use_build_context_synchronously
              context,
              "Terhapus",
              "Transaksi telah dihapus.",
            );
            // Tidak perlu pushAndRemoveUntil, cukup pop jika ada navigation stack
            // Dismissible sudah otomatis menghapus item dari list
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailTransactionScreen(
                  data: {
                    ...rawData,
                    "id": docId,
                    "title": title,
                    "price": price,
                    "color": color,
                    "date": subtitle,
                  },
                ),
              ),
            ),
            leading: CircleAvatar(
              // ignore: deprecated_member_use
              backgroundColor: color.withOpacity(0.1),
              radius: 24,
              child: Icon(Icons.monetization_on, color: color, size: 24),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: titleColor,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              subtitle,
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
    );
  }

  Widget _buildCustomFAB() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        // ignore: deprecated_member_use
        border: Border.all(color: Colors.grey.shade200.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => AiTransactionHelper.pickAndScanImage(
              context,
              ImageSource.camera,
            ),
            child: _buildCircularIcon(Icons.camera_alt_outlined),
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
                ),
              ),
              child: const Text(
                "Catat Transaksi",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // HAPUS SIZEDBOX GANDA DISINI
          GestureDetector(
            onTap: () => AiTransactionHelper.showVoiceInput(context),
            child: _buildCircularIcon(Icons.mic_none_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // ignore: deprecated_member_use
        border: Border.all(color: Colors.grey.shade300.withOpacity(0.3)),
        color: Theme.of(context).cardColor,
      ),
      child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 24),
    );
  }

  Widget _buildBottomAppBar(bool isDark) => BottomAppBar(
    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const CircularNotchedRectangle(),
    notchMargin: 8,
    child: const SizedBox(height: 60),
  );
}
