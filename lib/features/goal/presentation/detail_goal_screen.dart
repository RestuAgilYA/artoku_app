import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:artoku_app/features/goal/data/goal_model.dart';
import 'package:artoku_app/features/goal/data/goal_service.dart';
import 'package:artoku_app/core/services/ui_helper.dart';
import 'package:artoku_app/core/utils/currency_input_formatter.dart';
import 'package:artoku_app/features/goal/presentation/create_goal_sheet.dart';

class DetailGoalScreen extends StatelessWidget {
  final String goalId;

  const DetailGoalScreen({super.key, required this.goalId});

  static const Color _primaryColor = Color(0xFF0F4C5C);

  String _formatRupiah(num number) {
    return "Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";
  }

  String _formatDate(DateTime date) {
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

  String _formatDateTime(DateTime date) {
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
    return "${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatMonthYear(DateTime date) {
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
    return "${months[date.month - 1]} ${date.year}";
  }

  DateTime _stripTime(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: GoalService.getGoalStream(goalId: goalId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Target tabungan tidak ditemukan"));
          }

          final goal = GoalModel.fromSnapshot(snapshot.data!);
          return _buildContent(context, goal, isDark);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, GoalModel goal, bool isDark) {
    final statusClr = _getStatusColor(goal.status);

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F4C5C), Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 90,
                      left: 25,
                      right: 25,
                      bottom: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          goal.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                // ignore: deprecated_member_use
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                goal.status.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (goal.isOverdue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  // ignore: deprecated_member_use
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Overdue",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) => _handleMenuAction(context, value, goal),
              itemBuilder: (context) => [
                if (goal.status != GoalStatus.cancelled)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 18,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        const SizedBox(width: 10),
                        const Text("Edit"),
                      ],
                    ),
                  ),
                if (goal.status == GoalStatus.cancelled)
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: Row(
                      children: [
                        Icon(Icons.replay, size: 18, color: Colors.green),
                        SizedBox(width: 10),
                        Text("Aktifkan Kembali"),
                      ],
                    ),
                  ),
                if (goal.status == GoalStatus.active)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, size: 18, color: Colors.orange),
                        SizedBox(width: 10),
                        Text("Batalkan"),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text("Hapus", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress card
                _buildProgressCard(context, goal, statusClr),
                const SizedBox(height: 20),

                // Info detail card
                _buildInfoCard(context, goal, isDark),
                const SizedBox(height: 20),

                // Deadline Intelligence
                if (goal.status == GoalStatus.active) ...[
                  _buildDeadlineIntelligence(context, goal, isDark),
                  const SizedBox(height: 20),
                ],

                // Action buttons
                if (goal.canDeposit || goal.canWithdraw) ...[
                  _buildActionButtons(context, goal),
                  const SizedBox(height: 20),
                ],

                // Allocation history
                _buildAllocationHistory(context, goal, isDark),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    GoalModel goal,
    Color statusClr,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          // Circular progress
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: goal.progress,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(statusClr),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${goal.progressPercent.toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: statusClr,
                        ),
                      ),
                      Text(
                        "tercapai",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current / Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Terkumpul",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(goal.currentAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusClr,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Target",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(goal.targetAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusClr),
            ),
          ),
          const SizedBox(height: 8),

          // Remaining
          if (goal.sisaTarget > 0)
            Text(
              "Kurang ${_formatRupiah(goal.sisaTarget)} lagi",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, GoalModel goal, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            "Detail Informasi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(
            context,
            Icons.account_balance_wallet,
            "Dompet",
            goal.walletName.isNotEmpty ? goal.walletName : "Dompet",
          ),
          _buildInfoRow(
            context,
            Icons.calendar_today,
            "Dibuat",
            _formatDate(goal.createdAt),
          ),
          _buildInfoRow(
            context,
            Icons.event,
            "Tenggat",
            goal.deadline != null ? _formatDate(goal.deadline!) : "Tidak ada",
          ),
          _buildInfoRow(
            context,
            Icons.update,
            "Terakhir diperbarui",
            _formatDate(goal.updatedAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineIntelligence(
    BuildContext context,
    GoalModel goal,
    bool isDark,
  ) {
    final sisaBulan = goal.sisaWaktuBulan;
    final perBulan = goal.kebutuhanPerBulan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: goal.isOverdue ? Colors.red : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Analisa Target",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          if (goal.isOverdue) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Target ini sudah melewati tenggat waktu!",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Sisa target
          _buildAnalysisRow(
            context,
            "Sisa Target",
            _formatRupiah(goal.sisaTarget),
            goal.sisaTarget > 0 ? Colors.orange : Colors.green,
          ),

          // Sisa waktu
          if (goal.deadline != null) ...[
            _buildAnalysisRow(
              context,
              "Sisa Waktu",
              sisaBulan != null && sisaBulan > 0
                  ? "${sisaBulan.toStringAsFixed(1)} bulan"
                  : "Sudah lewat",
              sisaBulan != null && sisaBulan > 0 ? _primaryColor : Colors.red,
            ),
          ],

          // Kebutuhan per bulan
          if (perBulan != null && goal.sisaTarget > 0) ...[
            _buildAnalysisRow(
              context,
              "Nabung / Bulan",
              _formatRupiah(perBulan),
              _primaryColor,
            ),
          ] else if (goal.deadline != null && goal.sisaTarget > 0) ...[
            _buildAnalysisRow(
              context,
              "Nabung / Bulan",
              "Tenggat sudah lewat",
              Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, GoalModel goal) {
    return Row(
      children: [
        if (goal.canDeposit)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showDepositWithdrawDialog(context, goal, true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Setor"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        if (goal.canDeposit && goal.canWithdraw) const SizedBox(width: 12),
        if (goal.canWithdraw)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showDepositWithdrawDialog(context, goal, false),
              icon: const Icon(Icons.remove, size: 18),
              label: const Text("Tarik"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllocationHistory(
    BuildContext context,
    GoalModel goal,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Riwayat Alokasi",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot>(
          stream: GoalService.getAllocationsStream(goalId: goalId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text(
                      "Belum ada riwayat alokasi",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            final allocations =
                snapshot.data!.docs
                    .map((doc) => GoalAllocation.fromSnapshot(doc))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final Map<DateTime, List<GoalAllocation>> groupedAllocations = {};
            for (final alloc in allocations) {
              final key = DateTime(alloc.createdAt.year, alloc.createdAt.month);
              groupedAllocations.putIfAbsent(key, () => []).add(alloc);
            }
            final monthKeys = groupedAllocations.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: monthKeys.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final monthKey = monthKeys[index];
                  final monthAllocations = groupedAllocations[monthKey] ?? [];
                  monthAllocations.sort(
                    (a, b) => b.createdAt.compareTo(a.createdAt),
                  );

                  return Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 6),
                      title: Text(
                        _formatMonthYear(monthKey),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        "${monthAllocations.length} transaksi",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      children: [
                        for (int i = 0; i < monthAllocations.length; i++) ...[
                          _buildAllocationItem(
                            context,
                            goal,
                            monthAllocations[i],
                          ),
                          if (i != monthAllocations.length - 1)
                            Divider(height: 1, color: Colors.grey.shade200),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllocationItem(
    BuildContext context,
    GoalModel goal,
    GoalAllocation alloc,
  ) {
    final isDeposit = alloc.type == AllocationType.deposit;
    return Dismissible(
      key: ValueKey(alloc.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFF0F4C5C),
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Edit",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.red,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "Hapus",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _showEditAllocationDialog(context, goal, alloc);
          return false;
        }

        final bool shouldDelete = await _showDeleteAllocationConfirmation(
          context,
          goal,
          alloc,
        );
        return shouldDelete;
      },
      onDismissed: (_) async {
        try {
          await GoalService.deleteAllocation(
            goalId: goal.id,
            allocationId: alloc.id,
          );
          if (context.mounted) {
            UIHelper.showSuccess(
              context,
              "Berhasil",
              "Riwayat alokasi berhasil dihapus.",
            );
          }
        } catch (e) {
          if (context.mounted) {
            UIHelper.showError(
              context,
              e.toString().replaceAll('Exception: ', ''),
            );
          }
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isDeposit
              // ignore: deprecated_member_use
              ? Colors.green.withOpacity(0.1)
              // ignore: deprecated_member_use
              : Colors.red.withOpacity(0.1),
          child: Icon(
            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isDeposit ? Colors.green : Colors.red,
            size: 18,
          ),
        ),
        title: Text(
          "${isDeposit ? '+' : '-'} ${_formatRupiah(alloc.amount)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDeposit ? Colors.green : Colors.red,
          ),
        ),
        subtitle: Text(
          alloc.note?.isNotEmpty == true ? alloc.note! : alloc.type.label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Text(
          _formatDateTime(alloc.createdAt),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Color _getStatusColor(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return _primaryColor;
      case GoalStatus.completed:
        return Colors.green;
      case GoalStatus.cancelled:
        return Colors.grey;
    }
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    GoalModel goal,
  ) async {
    switch (action) {
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CreateGoalSheet(goal: goal),
        );
        break;
      case 'cancel':
        _showCancelConfirmation(context, goal);
        break;
      case 'reactivate':
        try {
          await GoalService.reactivateGoal(goalId: goal.id);
          if (context.mounted) {
            UIHelper.showSuccess(
              context,
              "Berhasil",
              "Target tabungan diaktifkan kembali.",
            );
          }
        } catch (e) {
          if (context.mounted) {
            UIHelper.showError(
              context,
              e.toString().replaceAll('Exception: ', ''),
            );
          }
        }
        break;
      case 'delete':
        _showDeleteConfirmation(context, goal);
        break;
    }
  }

  void _showCancelConfirmation(BuildContext context, GoalModel goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color messageColor = isDark ? Colors.white70 : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Colors.orange,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Batalkan Target?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Target \"${goal.title}\" akan dibatalkan. "
              "Anda masih bisa mengaktifkannya kembali nanti.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: messageColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Kembali",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await GoalService.cancelGoal(goalId: goal.id);
                if (context.mounted) {
                  UIHelper.showSuccess(
                    context,
                    "Dibatalkan",
                    "Target tabungan telah dibatalkan.",
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  UIHelper.showError(
                    context,
                    e.toString().replaceAll('Exception: ', ''),
                  );
                }
              }
            },
            child: const Text(
              "Ya, Batalkan",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, GoalModel goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color messageColor = isDark ? Colors.white70 : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              "Hapus Target?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color.fromRGBO(183, 28, 28, 1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Target \"${goal.title}\" beserta riwayat alokasi akan dihapus permanen. "
              "Tindakan ini tidak dapat dibatalkan.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: messageColor),
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
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await GoalService.deleteGoal(goalId: goal.id);
                if (context.mounted) {
                  Navigator.pop(context); // Go back to goal list
                }
              } catch (e) {
                if (context.mounted) {
                  UIHelper.showError(
                    context,
                    e.toString().replaceAll('Exception: ', ''),
                  );
                }
              }
            },
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDepositWithdrawDialog(
    BuildContext context,
    GoalModel goal,
    bool isDeposit,
  ) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final amountFormatter = const CurrencyTextInputFormatter();
    DateTime selectedDate = DateTime.now();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDeposit
                              // ignore: deprecated_member_use
                              ? _primaryColor.withOpacity(0.1)
                              // ignore: deprecated_member_use
                              : Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDeposit ? Icons.add : Icons.remove,
                          color: isDeposit ? _primaryColor : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isDeposit ? "Setor ke Target" : "Tarik dari Target",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Current info
                  Text(
                    "Saldo saat ini: ${_formatRupiah(goal.currentAmount)}",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  if (isDeposit)
                    Text(
                      "Sisa target: ${_formatRupiah(goal.sisaTarget)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Amount field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [amountFormatter],
                    decoration: InputDecoration(
                      labelText: "Jumlah (Rp)",
                      prefixText: "Rp ",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: isDeposit ? _primaryColor : Colors.red,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note field
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: "Catatan (opsional)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tanggal transaksi
                  InkWell(
                    onTap: isLoading
                        ? null
                        : () async {
                            final DateTime today = DateTime.now();
                            final DateTime firstDate = DateTime(
                              today.year - 5,
                              1,
                              1,
                            );
                            final DateTime lastDate = DateTime(
                              today.year + 5,
                              12,
                              31,
                            );
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _stripTime(selectedDate),
                              firstDate: firstDate,
                              lastDate: lastDate,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  selectedDate.hour,
                                  selectedDate.minute,
                                  selectedDate.second,
                                  selectedDate.millisecond,
                                  selectedDate.microsecond,
                                );
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(15),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: isDeposit
                            ? "Tanggal Setor"
                            : "Tanggal Tarik",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_formatDate(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final amountText = amountController.text
                                  .replaceAll('.', '')
                                  .replaceAll(',', '')
                                  .trim();
                              final amount = double.tryParse(amountText);

                              if (amount == null || amount <= 0) {
                                UIHelper.showError(
                                  context,
                                  "Masukkan jumlah yang valid",
                                );
                                return;
                              }

                              setDialogState(() => isLoading = true);
                              try {
                                if (isDeposit) {
                                  await GoalService.depositGoal(
                                    goalId: goal.id,
                                    amount: amount,
                                    note: noteController.text.trim().isEmpty
                                        ? null
                                        : noteController.text.trim(),
                                    transactionDate: selectedDate,
                                  );
                                } else {
                                  await GoalService.withdrawGoal(
                                    goalId: goal.id,
                                    amount: amount,
                                    note: noteController.text.trim().isEmpty
                                        ? null
                                        : noteController.text.trim(),
                                    transactionDate: selectedDate,
                                  );
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  UIHelper.showSuccess(
                                    context,
                                    "Berhasil",
                                    isDeposit
                                        ? "Setoran berhasil ditambahkan"
                                        : "Penarikan berhasil dilakukan",
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isLoading = false);
                                if (context.mounted) {
                                  UIHelper.showError(
                                    context,
                                    e.toString().replaceAll('Exception: ', ''),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDeposit ? _primaryColor : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isDeposit ? "Setor Sekarang" : "Tarik Sekarang",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditAllocationDialog(
    BuildContext context,
    GoalModel goal,
    GoalAllocation allocation,
  ) async {
    final TextEditingController amountController = TextEditingController(
      text: allocation.amount
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          ),
    );
    final TextEditingController noteController = TextEditingController(
      text: allocation.note ?? '',
    );
    final amountFormatter = const CurrencyTextInputFormatter();
    DateTime selectedDate = allocation.createdAt;
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Edit ${allocation.type == AllocationType.deposit ? 'Setor' : 'Tarik'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountFormatter],
                    decoration: InputDecoration(
                      labelText: 'Jumlah (Rp)',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: isLoading
                        ? null
                        : () async {
                            final DateTime now = DateTime.now();
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _stripTime(selectedDate),
                              firstDate: DateTime(now.year - 5, 1, 1),
                              lastDate: DateTime(now.year + 5, 12, 31),
                            );
                            if (picked != null) {
                              setStateModal(() {
                                selectedDate = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  selectedDate.hour,
                                  selectedDate.minute,
                                  selectedDate.second,
                                  selectedDate.millisecond,
                                  selectedDate.microsecond,
                                );
                              });
                            }
                          },
                    borderRadius: BorderRadius.circular(15),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Tanggal Transaksi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_formatDate(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final String amountText = amountController.text
                                  .replaceAll('.', '')
                                  .replaceAll(',', '')
                                  .trim();
                              final double? amount = double.tryParse(
                                amountText,
                              );

                              if (amount == null || amount <= 0) {
                                UIHelper.showError(
                                  context,
                                  'Masukkan jumlah yang valid',
                                );
                                return;
                              }

                              setStateModal(() => isLoading = true);
                              try {
                                await GoalService.editAllocation(
                                  goalId: goal.id,
                                  allocationId: allocation.id,
                                  amount: amount,
                                  note: noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim(),
                                  transactionDate: selectedDate,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  UIHelper.showSuccess(
                                    context,
                                    'Berhasil',
                                    'Riwayat alokasi berhasil diperbarui.',
                                  );
                                }
                              } catch (e) {
                                setStateModal(() => isLoading = false);
                                if (context.mounted) {
                                  UIHelper.showError(
                                    context,
                                    e.toString().replaceAll('Exception: ', ''),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showDeleteAllocationConfirmation(
    BuildContext context,
    GoalModel goal,
    GoalAllocation allocation,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Riwayat?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Riwayat ${allocation.type == AllocationType.deposit ? 'setor' : 'tarik'} '
          '${_formatRupiah(allocation.amount)} akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false;
    }

    // Validation ringan agar parameter dipakai dan intent tetap jelas.
    if (goal.id.isEmpty) {
      return false;
    }

    return true;
  }
}
