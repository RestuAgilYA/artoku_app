import 'package:cloud_firestore/cloud_firestore.dart';

/// Status enum for a Patungan group expense.
enum PatunganStatus {
  active,
  settled;

  String get value {
    switch (this) {
      case PatunganStatus.active:
        return 'active';
      case PatunganStatus.settled:
        return 'settled';
    }
  }

  static PatunganStatus fromString(String? value) {
    if (value == 'settled') return PatunganStatus.settled;
    return PatunganStatus.active;
  }
}

/// Status enum for a participant's share payment.
enum ShareStatus {
  unpaid,
  paid;

  String get value {
    switch (this) {
      case ShareStatus.unpaid:
        return 'unpaid';
      case ShareStatus.paid:
        return 'paid';
    }
  }

  static ShareStatus fromString(String? value) {
    if (value == 'paid') return ShareStatus.paid;
    return ShareStatus.unpaid;
  }
}

/// Immutable model representing a participant's share in a Patungan.
class PatunganShare {
  final String name;
  final double amount;
  final ShareStatus status;
  final DateTime? paidAt;
  final bool isCreator;
  final String? receivableId;
  final String? paidWalletId;

  const PatunganShare({
    required this.name,
    required this.amount,
    this.status = ShareStatus.unpaid,
    this.paidAt,
    this.isCreator = false,
    this.receivableId,
    this.paidWalletId,
  });

  factory PatunganShare.fromMap(Map<String, dynamic> map) {
    return PatunganShare(
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: ShareStatus.fromString(map['status'] as String?),
      paidAt: map['paidAt'] != null
          ? (map['paidAt'] as Timestamp).toDate()
          : null,
      isCreator: map['isCreator'] as bool? ?? false,
      receivableId: map['receivableId'] as String?,
      paidWalletId: map['paidWalletId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'status': status.value,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'isCreator': isCreator,
      'receivableId': receivableId,
      'paidWalletId': paidWalletId,
    };
  }

  PatunganShare copyWith({
    String? name,
    double? amount,
    ShareStatus? status,
    DateTime? paidAt,
    bool? isCreator,
    String? receivableId,
    String? paidWalletId,
  }) {
    return PatunganShare(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      isCreator: isCreator ?? this.isCreator,
      receivableId: receivableId ?? this.receivableId,
      paidWalletId: paidWalletId ?? this.paidWalletId,
    );
  }
}

/// Immutable model representing a Patungan group expense.
class PatunganModel {
  final String id;
  final String title;
  final double totalAmount;
  final String category;
  final String walletId;
  final String walletName;
  final String createdBy;
  final PatunganStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? expenseTransactionId;
  final List<PatunganShare> shares;

  const PatunganModel({
    required this.id,
    required this.title,
    required this.totalAmount,
    this.category = 'Patungan',
    required this.walletId,
    required this.walletName,
    required this.createdBy,
    this.status = PatunganStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.expenseTransactionId,
    this.shares = const [],
  });

  factory PatunganModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatunganModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'Patungan',
      walletId: data['walletId'] as String? ?? '',
      walletName: data['walletName'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      status: PatunganStatus.fromString(data['status'] as String?),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      expenseTransactionId: data['expenseTransactionId'] as String?,
      shares: data['shares'] != null
          ? (data['shares'] as List<dynamic>)
              .map((s) => PatunganShare.fromMap(s as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  /// Total amount received from non-creator paid shares.
  double get paidAmount => shares
      .where((s) => s.status == ShareStatus.paid && !s.isCreator)
      // ignore: avoid_types_as_parameter_names
      .fold(0.0, (sum, s) => sum + s.amount);

  /// Total amount still unpaid from non-creator shares.
  double get unpaidAmount => shares
      .where((s) => s.status == ShareStatus.unpaid && !s.isCreator)
      // ignore: avoid_types_as_parameter_names
      .fold(0.0, (sum, s) => sum + s.amount);

  /// Count of shares marked as paid or creator (settled).
  int get paidCount =>
      shares.where((s) => s.status == ShareStatus.paid || s.isCreator).length;

  /// Total number of participants.
  int get totalParticipants => shares.length;

  /// Creator's share amount.
  double get creatorShare =>
      // ignore: avoid_types_as_parameter_names
      shares.where((s) => s.isCreator).fold(0.0, (sum, s) => sum + s.amount);

  /// Whether all non-creator shares are paid.
  bool get isFullySettled =>
      shares.every((s) => s.status == ShareStatus.paid || s.isCreator);
}
