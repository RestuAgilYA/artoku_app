import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:artoku_app/features/goal/data/goal_model.dart';
import 'package:artoku_app/features/goal/data/goal_service.dart';
import 'package:artoku_app/features/goal/presentation/detail_goal_screen.dart';
import 'package:artoku_app/features/goal/presentation/create_goal_sheet.dart';

class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  static const Color _primaryColor = Color(0xFF0F4C5C);

  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: GoalService.getGoalsStream(),
      builder: (context, snapshot) {
        final hasGoals = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              "Target Tabungan",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!hasGoals) {
              return _buildEmptyState(context);
            }

            final goals = snapshot.data!.docs
                .map((doc) => GoalModel.fromSnapshot(doc))
                .toList();

            // Separate by status
            final activeGoals =
                goals.where((g) => g.status == GoalStatus.active).toList();
            final completedGoals =
                goals.where((g) => g.status == GoalStatus.completed).toList();
            final cancelledGoals =
                goals.where((g) => g.status == GoalStatus.cancelled).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card
                  _buildSummaryCard(context, goals, isDark),
                  const SizedBox(height: 25),

                  // Active goals
                  if (activeGoals.isNotEmpty) ...[
                    _buildSectionTitle(context, "Aktif", activeGoals.length),
                    const SizedBox(height: 12),
                    ...activeGoals.map((g) => _GoalCard(
                          goal: g,
                          formatRupiah: _formatRupiah,
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Completed goals
                  if (completedGoals.isNotEmpty) ...[
                    _buildSectionTitle(
                        context, "Tercapai", completedGoals.length),
                    const SizedBox(height: 12),
                    ...completedGoals.map((g) => _GoalCard(
                          goal: g,
                          formatRupiah: _formatRupiah,
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Cancelled goals
                  if (cancelledGoals.isNotEmpty) ...[
                    _buildSectionTitle(
                        context, "Dibatalkan", cancelledGoals.length),
                    const SizedBox(height: 12),
                    ...cancelledGoals.map((g) => _GoalCard(
                          goal: g,
                          formatRupiah: _formatRupiah,
                        )),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            );
          }(),
          floatingActionButton: hasGoals
              ? FloatingActionButton.extended(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreateGoalSheet(),
                  ),
                  backgroundColor: _primaryColor,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Buat Target",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_circle_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              "Belum ada target tabungan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Buat target tabungan untuk membantu\nmencapai tujuan keuangan Anda",
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
                builder: (context) => const CreateGoalSheet(),
              ),
              icon: const Icon(Icons.add),
              label: const Text("Buat Target Pertama"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
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

  Widget _buildSummaryCard(
      BuildContext context, List<GoalModel> goals, bool isDark) {
    final activeGoals =
        goals.where((g) => g.status == GoalStatus.active).toList();
    final completedCount =
        goals.where((g) => g.status == GoalStatus.completed).length;

    double totalTarget = 0;
    double totalSaved = 0;
    for (final g in activeGoals) {
      totalTarget += g.targetAmount;
      totalSaved += g.currentAmount;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C5C), Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_circle, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Ringkasan Target",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${activeGoals.length} Aktif • $completedCount Tercapai",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _formatRupiah(totalSaved),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "dari ${_formatRupiah(totalTarget)} target aktif",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (totalTarget > 0) ...[
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: totalTarget > 0 ? (totalSaved / totalTarget).clamp(0, 1) : 0,
                minHeight: 8,
                // ignore: deprecated_member_use
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF69F0AE),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${(totalTarget > 0 ? (totalSaved / totalTarget * 100) : 0).toStringAsFixed(1)}% tercapai",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$count",
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// GOAL CARD WIDGET
// ============================================================
class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final String Function(num) formatRupiah;

  const _GoalCard({required this.goal, required this.formatRupiah});

  Color _statusColor() {
    switch (goal.status) {
      case GoalStatus.active:
        return const Color(0xFF0F4C5C);
      case GoalStatus.completed:
        return Colors.green;
      case GoalStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (goal.status) {
      case GoalStatus.active:
        return Icons.flag_circle_outlined;
      case GoalStatus.completed:
        return Icons.check_circle;
      case GoalStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _formatDeadline() {
    if (goal.deadline == null) return "Tanpa batas waktu";
    final d = goal.deadline!;
    List<String> months = [
      "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
      "Jul", "Agu", "Sep", "Okt", "Nov", "Des",
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final statusClr = _statusColor();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailGoalScreen(goalId: goal.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: statusClr.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_statusIcon(), color: statusClr, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              goal.walletName.isNotEmpty
                                  ? goal.walletName
                                  : "Dompet",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: statusClr.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal.status.label,
                    style: TextStyle(
                      color: statusClr,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusClr),
              ),
            ),
            const SizedBox(height: 10),

            // Amount row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatRupiah(goal.currentAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: statusClr,
                  ),
                ),
                Text(
                  "/ ${formatRupiah(goal.targetAmount)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bottom info row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      goal.isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_today,
                      size: 12,
                      color: goal.isOverdue ? Colors.red : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDeadline(),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            goal.isOverdue ? Colors.red : Colors.grey.shade500,
                        fontWeight:
                            goal.isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${goal.progressPercent.toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusClr,
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
