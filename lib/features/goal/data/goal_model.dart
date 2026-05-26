import 'package:cloud_firestore/cloud_firestore.dart';

/// Status enum for a Savings Goal.
enum GoalStatus {
  active,
  completed,
  cancelled;

  String get value {
    switch (this) {
      case GoalStatus.active:
        return 'active';
      case GoalStatus.completed:
        return 'completed';
      case GoalStatus.cancelled:
        return 'cancelled';
    }
  }

  static GoalStatus fromString(String? value) {
    switch (value) {
      case 'completed':
        return GoalStatus.completed;
      case 'cancelled':
        return GoalStatus.cancelled;
      default:
        return GoalStatus.active;
    }
  }

  String get label {
    switch (this) {
      case GoalStatus.active:
        return 'Aktif';
      case GoalStatus.completed:
        return 'Tercapai';
      case GoalStatus.cancelled:
        return 'Dibatalkan';
    }
  }
}

/// Type enum for allocation records.
enum AllocationType {
  deposit,
  withdraw;

  String get value {
    switch (this) {
      case AllocationType.deposit:
        return 'deposit';
      case AllocationType.withdraw:
        return 'withdraw';
    }
  }

  static AllocationType fromString(String? value) {
    if (value == 'withdraw') return AllocationType.withdraw;
    return AllocationType.deposit;
  }

  String get label {
    switch (this) {
      case AllocationType.deposit:
        return 'Setor';
      case AllocationType.withdraw:
        return 'Tarik';
    }
  }
}

/// Immutable model representing an allocation record for a Goal.
class GoalAllocation {
  final String id;
  final double amount;
  final AllocationType type;
  final String? note;
  final DateTime createdAt;

  const GoalAllocation({
    required this.id,
    required this.amount,
    required this.type,
    this.note,
    required this.createdAt,
  });

  factory GoalAllocation.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalAllocation(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: AllocationType.fromString(data['type'] as String?),
      note: data['note'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type.value,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  GoalAllocation copyWith({
    String? id,
    double? amount,
    AllocationType? type,
    String? note,
    DateTime? createdAt,
  }) {
    return GoalAllocation(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Immutable model representing a Savings Goal (Virtual Bucket).
class GoalModel {
  final String id;
  final String title;
  final String walletId;
  final String walletName;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalModel({
    required this.id,
    required this.title,
    required this.walletId,
    this.walletName = '',
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.status = GoalStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoalModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      walletId: data['walletId'] as String? ?? '',
      walletName: data['walletName'] as String? ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0,
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      status: GoalStatus.fromString(data['status'] as String?),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'walletId': walletId,
      'walletName': walletName,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GoalModel copyWith({
    String? id,
    String? title,
    String? walletId,
    String? walletName,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    GoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // COMPUTED PROPERTIES
  // ============================================================

  /// Progress percentage (0.0 - 1.0), capped at 1.0.
  double get progress {
    if (targetAmount <= 0) return 0;
    final p = currentAmount / targetAmount;
    return p > 1.0 ? 1.0 : p;
  }

  /// Progress percentage (0 - 100).
  double get progressPercent => progress * 100;

  /// Remaining amount to reach the target.
  double get sisaTarget {
    final sisa = targetAmount - currentAmount;
    return sisa < 0 ? 0 : sisa;
  }

  /// Whether the goal is overdue (deadline passed and not yet completed).
  bool get isOverdue {
    if (deadline == null) return false;
    if (status == GoalStatus.completed) return false;
    return DateTime.now().toUtc().isAfter(deadline!);
  }

  /// Remaining time in months (fractional).
  /// Returns null if no deadline is set.
  double? get sisaWaktuBulan {
    if (deadline == null) return null;
    final now = DateTime.now().toUtc();
    final diff = deadline!.difference(now);
    if (diff.isNegative) return 0;
    return diff.inDays / 30.0;
  }

  /// Required monthly saving to meet the deadline.
  /// Returns null if no deadline or already completed.
  double? get kebutuhanPerBulan {
    final sisa = sisaTarget;
    if (sisa <= 0) return 0;
    final bulan = sisaWaktuBulan;
    if (bulan == null || bulan <= 0) return null; // overdue or no deadline
    return sisa / bulan;
  }

  /// Whether this goal can accept a deposit.
  bool get canDeposit => status == GoalStatus.active;

  /// Whether this goal can process a withdrawal.
  bool get canWithdraw =>
      currentAmount > 0 &&
      (status == GoalStatus.active || status == GoalStatus.completed);
}
