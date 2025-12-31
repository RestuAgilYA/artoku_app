import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'detail_transaction_screen.dart';
import 'add_transaction_sheet.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // STATE FILTER
  DateTime _selectedMonth = DateTime.now();
  String _selectedType = 'all'; // 'all', 'income', 'expense'

  // STATE SEARCH
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper Format Rupiah
  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  // Helper Format Tanggal Lengkap
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
    return "${date.day} ${months[date.month - 1]} ${date.year}"; // Format ringkas
  }

  // Helper Nama Bulan Tahun (Filter)
  String _getMonthYear(DateTime date) {
    List<String> months = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Riwayat Transaksi",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // =========================================
          // 1. AREA FILTER & SEARCH
          // =========================================
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
            color: bgColor,
            child: Column(
              children: [
                // SEARCH BAR
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: "Cari (cth: Nasi Goreng)...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade900
                        : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 15),

                // FILTER BULAN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: textColor),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month - 1,
                          );
                        });
                      },
                    ),
                    Text(
                      _getMonthYear(_selectedMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: textColor),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          );
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // FILTER TIPE
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterChip("Semua", 'all'),
                      const SizedBox(width: 10),
                      _buildFilterChip(
                        "Pemasukan",
                        'income',
                        color: const Color(0xFF00897B),
                      ),
                      const SizedBox(width: 10),
                      _buildFilterChip(
                        "Pengeluaran",
                        'expense',
                        color: const Color(0xFF0F4C5C),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // =========================================
          // 2. LIST TRANSAKSI
          // =========================================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('transactions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("Belum ada data transaksi.");
                }

                var allDocs = snapshot.data!.docs;

                // --- FILTERING LOGIC ---
                var filteredDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  Timestamp? t = data['date'];
                  if (t == null) return false;

                  DateTime date = t.toDate();

                  // 1. Filter Bulan
                  bool matchMonth =
                      (date.year == _selectedMonth.year &&
                      date.month == _selectedMonth.month);

                  // 2. Filter Tipe
                  bool matchType = true;
                  if (_selectedType != 'all') {
                    matchType = (data['type'] == _selectedType);
                  }

                  // 3. Filter Search (Cari di Judul, Kategori, atau Note)
                  bool matchSearch = true;
                  if (_searchQuery.isNotEmpty) {
                    String category = (data['category'] ?? '')
                        .toString()
                        .toLowerCase();
                    String note = (data['note'] ?? '').toString().toLowerCase();
                    // Kita cari di Note atau Kategori
                    matchSearch =
                        category.contains(_searchQuery) ||
                        note.contains(_searchQuery);
                  }

                  return matchMonth && matchType && matchSearch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  if (_searchQuery.isNotEmpty) {
                    return _buildEmptyState("Tidak ditemukan '$_searchQuery'");
                  }
                  return _buildEmptyState("Tidak ada transaksi di bulan ini.");
                }

                return Column(
                  children: [
                    // List View
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          var doc = filteredDocs[index];
                          var data = doc.data() as Map<String, dynamic>;

                          // --- LOGIKA TAMPILAN BARU ---
                          // Ambil data
                          String category =
                              data['category'] ?? 'Tanpa Kategori';
                          String note = data['note'] ?? '';

                          // TENTUKAN JUDUL UTAMA:
                          // Jika ada Note, pakai Note (misal "Nasi Goreng").
                          // Jika Note kosong, pakai Kategori (misal "Makanan").
                          String displayTitle = (note.isNotEmpty)
                              ? note
                              : category;

                          // SUBTITLE:
                          // Tampilkan Tanggal dan Kategori
                          String dateString = "";
                          if (data['date'] != null) {
                            dateString = _formatDate(data['date'] as Timestamp);
                          }
                          String displaySubtitle = "$dateString • $category";

                          double amount = (data['amount'] ?? 0).toDouble();
                          String formattedPrice = _formatRupiah(amount);

                          bool isExpense = (data['type'] == 'expense');
                          Color color = isExpense
                              ? (data['color'] != null
                                    ? Color(data['color'])
                                    : Colors.red)
                              : const Color(0xFF00897B);

                          String prefix = isExpense ? "- " : "+ ";
                          Color amountColor = isExpense
                              ? Colors.red
                              : const Color(0xFF00897B);

                          return _buildTransactionItem(
                            context,
                            doc,
                            data,
                            displayTitle,
                            displaySubtitle,
                            formattedPrice,
                            prefix,
                            amountColor,
                            color,
                            isExpense,
                            amount,
                            cardColor,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET ITEM TRANSAKSI
  Widget _buildTransactionItem(
    BuildContext context,
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    String title,
    String subtitle,
    String formattedPrice,
    String prefix,
    Color amountColor,
    Color color,
    bool isExpense,
    double amount,
    Color cardColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Dismissible(
        key: Key(doc.id),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // EDIT
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AddTransactionSheet(
                transactionId: doc.id,
                transactionData: data,
              ),
            );
            return false;
          } else {
            // HAPUS
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Hapus Transaksi?"),
                content: const Text("Saldo akan disesuaikan kembali."),
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
        background: _buildSwipeBg(
          Alignment.centerLeft,
          Colors.blueAccent,
          Icons.edit,
        ),
        secondaryBackground: _buildSwipeBg(
          Alignment.centerRight,
          Colors.redAccent.shade100,
          Icons.delete_outline,
        ),

        onDismissed: (direction) async {
          if (direction == DismissDirection.endToStart) {
            String? walletId = data['walletId'];
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('transactions')
                .doc(doc.id)
                .delete();

            if (walletId != null) {
              final walletRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('wallets')
                  .doc(walletId);
              double refundAmount = isExpense ? amount : -amount;
              await walletRef.update({
                'balance': FieldValue.increment(refundAmount),
              });
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Transaksi dihapus"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },

        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
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
              // Kirim data ke Detail
              Map<String, dynamic> transactionData = {
                ...data,
                "title": title, // Kirim judul yang sudah disesuaikan
                "date": subtitle, // Kirim tanggal/subtitle
                "price": formattedPrice,
                "color": color,
                "id": doc.id,
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
              child: Icon(
                isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 24,
              ),
            ),
            // JUDUL UTAMA SEKARANG 'NOTE' (KALAU ADA)
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            // SUBTITLE ADA KATEGORINYA
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey
                    : Colors.grey.shade600,
              ),
            ),
            trailing: Text(
              "$prefix$formattedPrice",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: amountColor,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    bool isSelected = _selectedType == value;
    Color activeColor = color ?? const Color(0xFF0F4C5C);

    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBg(Alignment align, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: align,
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
