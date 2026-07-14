import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:artoku_app/features/patungan/data/patungan_model.dart';
import 'package:artoku_app/features/patungan/data/patungan_service.dart';
import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/features/patungan/presentation/create_patungan_sheet.dart';
import 'package:artoku_app/features/patungan/presentation/detail_patungan_screen.dart';

class PatunganScreen extends StatelessWidget {
  const PatunganScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    const Color primaryColor = Color(0xFF0F4C5C);

    return StreamBuilder<QuerySnapshot>(
      stream: PatunganService.getPatungansStream(),
      builder: (context, snapshot) {
        final hasPatungans = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              "Patungan",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!hasPatungans) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text(
                        "Belum ada patungan",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Buat patungan untuk membagi\npengeluaran bersama teman",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const CreatePatunganSheet(),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text("Buat Patungan Pertama"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final patungans = snapshot.data!.docs
                .map((doc) => PatunganModel.fromSnapshot(doc))
                .toList();

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: patungans.length,
              itemBuilder: (context, index) {
                final patungan = patungans[index];
                return _PatunganCard(patungan: patungan);
              },
            );
          }(),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: hasPatungans
              ? FloatingActionButton.extended(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreatePatunganSheet(),
                  ),
                  backgroundColor: primaryColor,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Buat Patungan",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _PatunganCard extends StatelessWidget {
  final PatunganModel patungan;

  const _PatunganCard({required this.patungan});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    const Color primaryColor = Color(0xFF0F4C5C);

    final isSettled = patungan.status == PatunganStatus.settled;
    final progress = patungan.totalParticipants > 0
        ? patungan.paidCount / patungan.totalParticipants
        : 0.0;
    final formattedDate =
        DateFormat('dd MMM yyyy').format(patungan.createdAt);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DetailPatunganScreen(patunganId: patungan.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        // ignore: deprecated_member_use
                        (isSettled ? Colors.green : primaryColor).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSettled ? Icons.check_circle : Icons.groups,
                    color: isSettled ? Colors.green : primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patungan.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${patungan.walletName} • $formattedDate",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      UIHelper.formatRupiah(patungan.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            // ignore: deprecated_member_use
                            (isSettled ? Colors.green : Colors.orange)
                                // ignore: deprecated_member_use
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isSettled ? "Lunas" : "Aktif",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSettled ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.grey.shade200,
                          color: isSettled ? Colors.green : primaryColor,
                          minHeight: 5,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${patungan.paidCount}/${patungan.totalParticipants} lunas",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
