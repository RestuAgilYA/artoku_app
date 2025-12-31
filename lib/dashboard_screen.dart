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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color primaryColor = const Color(0xFF0F4C5C);
  bool _isExpenseVisible = true;

  // Hapus inisialisasi user di sini agar selalu ambil state terbaru
  // final User? user = FirebaseAuth.instance.currentUser;

  // ALAT INPUT
  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _checkAndCreateDefaultWallets();
    // Stream tidak lagi diinisialisasi di sini untuk mencegah data kosong
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
      });
    }
  }

  // --- 1. FITUR KAMERA (SCAN STRUK) ---
  Future<void> _handleCameraScan() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (photo == null) return;

      setState(() => _isAnalyzing = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gemini sedang membaca struk...")),
        );
      }

      File imageFile = File(photo.path);
      final result = await GeminiService.scanReceipt(imageFile);

      if (mounted) setState(() => _isAnalyzing = false);

      if (result != null && mounted) {
        _openAddTransactionWithData(result);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gagal membaca struk. Pastikan gambar jelas."),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isAnalyzing = false);
      print(e);
    }
  }

  // --- 2. FITUR MIKROFON (VOICE INPUT) ---
  Future<void> _handleVoiceInput() async {
    bool available = await _speech.initialize(
      onError: (val) => print('Speech Error: $val'),
      onStatus: (val) => print('Speech Status: $val'),
    );

    if (available) {
      if (!mounted) return;

      String recordedWords = "";

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  const Text("Silakan bicara..."),
                  const SizedBox(height: 10),
                  Text(
                    recordedWords.isEmpty ? "..." : recordedWords,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _speech.stop();
                      Navigator.pop(context, recordedWords);
                    },
                    child: const Text("Selesai"),
                  ),
                ],
              ),
            );
          },
        ),
      ).then((finalResult) async {
        if (finalResult != null && finalResult.toString().isNotEmpty) {
          String textToAnalyze = finalResult.toString();
          setState(() => _isAnalyzing = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Menganalisa: '$textToAnalyze'...")),
          );

          try {
            final result = await GeminiService.analyzeText(textToAnalyze);

            if (mounted) setState(() => _isAnalyzing = false);

            if (result != null && mounted) {
              _openAddTransactionWithData(result);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Gemini bingung, coba kalimat lain."),
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) setState(() => _isAnalyzing = false);
          }
        }
      });

      _speech.listen(
        onResult: (val) {
          recordedWords = val.recognizedWords;
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: "id_ID",
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Izin mikrofon ditolak atau tidak tersedia."),
          ),
        );
      }
    }
  }

  void _openAddTransactionWithData(Map<String, dynamic> data) {
    Timestamp now = Timestamp.now();
    String type = data['type'] ?? 'expense';
    if (type != 'expense' && type != 'income') type = 'expense';
    String? detectedWallet = data['wallet'];

    Map<String, dynamic> prepData = {
      'amount': data['amount'] ?? 0,
      'category': data['category'] ?? 'Lainnya',
      'note': data['note'] ?? '',
      'type': type,
      'date': now,
      'walletId': null,
      'walletName': null,
      'suggestedWallet': detectedWallet,
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

  String _getUserDisplayName(User? user) {
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
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

    // Ambil user langsung di dalam build agar tidak null
    final User? user = FirebaseAuth.instance.currentUser;

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
                _buildHeader(user),
                // Menggeser menu ke atas agar overlap dengan header
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
          if (_isAnalyzing)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      "AI sedang menganalisa...",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildCustomFAB(),
      bottomNavigationBar: _buildBottomAppBar(isDark),
    );
  }

  // Header dengan Corak (Gradient + Bubbles) + STREAM FIX
  Widget _buildHeader(User user) {
    return StreamBuilder<QuerySnapshot>(
      // FIX: Panggil stream langsung di sini
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
            Timestamp? t = data['date'];
            if (t == null) continue;

            DateTime date = t.toDate();
            double amount = (data['amount'] ?? 0).toDouble();
            String type = data['type'] ?? 'expense';

            if (date.year == now.year && date.month == now.month) {
              if (type == 'expense') {
                thisMonthExpense += amount;
              } else if (type == 'income') {
                thisMonthIncome += amount;
              }
            }

            DateTime lastMonthDate = DateTime(now.year, now.month - 1);
            if (date.year == lastMonthDate.year &&
                date.month == lastMonthDate.month) {
              if (type == 'expense') {
                lastMonthExpense += amount;
              }
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
              // --- CORAK DEKORASI ---
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

              // --- KONTEN UTAMA ---
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
                        const SizedBox(width: 10),
                        if (_isExpenseVisible)
                          _buildPillBadge(thisMonthExpense, lastMonthExpense),
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
                                  const Text(
                                    "Bulan Ini",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 9,
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
                              // Kirim user untuk stream di dalam widget ini
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
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHemat ? Icons.arrow_downward : Icons.arrow_upward,
            color: isHemat ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
            size: 12,
          ),
          const SizedBox(width: 4),
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

  // FIX: Stream Wallet dipanggil langsung
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
            if (isComingSoon)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Soon",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

  // FIX: Stream Transaksi dipanggil langsung
  Widget _buildTransactionList(bool isDark, Color textColor, User user) {
    Color dateColor = isDark ? Colors.grey : Colors.grey.shade600;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
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
                  user,
                );
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
          } else {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Hapus Transaksi?"),
                  content: const Text("Saldo di dompet akan dikembalikan."),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Batal"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        "Hapus",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            );
          }
        },
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
        onDismissed: (direction) async {
          if (direction == DismissDirection.endToStart) {
            double amountToRefund = (rawData['amount'] ?? 0).toDouble();
            String? walletId = rawData['walletId'];
            String type = rawData['type'] ?? 'expense';

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('transactions')
                .doc(docId)
                .delete();

            if (walletId != null) {
              double refund = type == 'expense'
                  ? amountToRefund
                  : -amountToRefund;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('wallets')
                  .doc(walletId)
                  .update({'balance': FieldValue.increment(refund)});
            }
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$title dihapus"),
                  backgroundColor: Colors.red,
                ),
              );
          }
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
    );
  }

  // --- WIDGET LAIN SAMA PERSIS SEPERTI SEBELUMNYA ---
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
        border: Border.all(
          color: Colors.grey.shade200.withOpacity(0.2),
          width: 1.5,
        ),
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
