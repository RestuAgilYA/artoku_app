import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/core/services/logger_service.dart';

class GoalService {
  static final _firestore = FirebaseFirestore.instance;

  /// Get user document reference (helper).
  static DocumentReference _userDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');
    return _firestore.collection('users').doc(user.uid);
  }

  // ----------------------------------------------------------
  // CREATE GOAL
  // ----------------------------------------------------------
  static Future<String> createGoal({
    required String title,
    required String walletId,
    required String walletName,
    required double targetAmount,
    DateTime? deadline,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    // Validasi input
    if (title.trim().isEmpty) {
      throw Exception('Judul target tabungan tidak boleh kosong');
    }
    if (walletId.isEmpty) {
      throw Exception('Pilih dompet terlebih dahulu');
    }
    if (targetAmount <= 0) {
      throw Exception('Target nominal harus lebih dari 0');
    }
    if (deadline != null && deadline.isBefore(DateTime.now().toUtc())) {
      throw Exception('Tenggat waktu harus di masa depan');
    }

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc();
    final walletRef = userDocRef.collection('wallets').doc(walletId);

    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    // Validate wallet exists using transaction
    await _firestore.runTransaction((transaction) async {
      final walletSnap = await transaction.get(walletRef);
      if (!walletSnap.exists) throw Exception('Dompet tidak ditemukan');

      transaction.set(goalRef, {
        'title': title.trim(),
        'walletId': walletId,
        'walletName': walletName,
        'targetAmount': targetAmount,
        'currentAmount': 0,
        'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
        'status': 'active',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });
    });

    LoggerService.info(
      'Goal "${title.trim()}" berhasil dibuat. '
      'Target: $targetAmount, Wallet: $walletId',
    );

    return goalRef.id;
  }

  // ----------------------------------------------------------
  // EDIT GOAL (title, targetAmount, deadline only)
  // ----------------------------------------------------------
  static Future<void> editGoal({
    required String goalId,
    required String title,
    required double targetAmount,
    DateTime? deadline,
    String? walletId,
    String? walletName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    if (title.trim().isEmpty) {
      throw Exception('Judul target tabungan tidak boleh kosong');
    }
    if (targetAmount <= 0) {
      throw Exception('Target nominal harus lebih dari 0');
    }

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc(goalId);
    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      final goalSnap = await transaction.get(goalRef);
      if (!goalSnap.exists) throw Exception('Target tabungan tidak ditemukan');

      final data = goalSnap.data() as Map<String, dynamic>;
      final currentAmount = (data['currentAmount'] as num?)?.toDouble() ?? 0;
      final currentStatus = data['status'] as String? ?? 'active';

      if (currentStatus == 'cancelled') {
        throw Exception('Target tabungan yang dibatalkan tidak bisa diedit');
      }

      // Validate new wallet if changed
      if (walletId != null && walletId.isNotEmpty) {
        final walletRef = userDocRef.collection('wallets').doc(walletId);
        final walletSnap = await transaction.get(walletRef);
        if (!walletSnap.exists) throw Exception('Dompet tidak ditemukan');
      }

      // Determine new status based on currentAmount vs new targetAmount
      String newStatus = currentStatus;
      if (currentAmount >= targetAmount && targetAmount > 0) {
        newStatus = 'completed';
      } else if (currentStatus == 'completed' && currentAmount < targetAmount) {
        newStatus = 'active';
      }

      final updateData = <String, dynamic>{
        'title': title.trim(),
        'targetAmount': targetAmount,
        'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
        'status': newStatus,
        'updatedAt': timestamp,
      };

      if (walletId != null && walletId.isNotEmpty) {
        updateData['walletId'] = walletId;
        updateData['walletName'] = walletName ?? '';
      }

      transaction.update(goalRef, updateData);
    });

    LoggerService.info('Goal $goalId berhasil diedit. Title: "$title"');
  }

  // ----------------------------------------------------------
  // DEPOSIT TO GOAL
  // ----------------------------------------------------------
  static Future<void> depositGoal({
    required String goalId,
    required double amount,
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    if (amount <= 0) {
      throw Exception('Jumlah setoran harus lebih dari 0');
    }

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc(goalId);
    final allocationRef = goalRef.collection('allocations').doc();
    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      final goalSnap = await transaction.get(goalRef);
      if (!goalSnap.exists) throw Exception('Target tabungan tidak ditemukan');

      final data = goalSnap.data() as Map<String, dynamic>;
      final currentStatus = data['status'] as String? ?? 'active';
      final currentAmount = (data['currentAmount'] as num?)?.toDouble() ?? 0;
      final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0;

      // Business rule: status must be active for deposit
      if (currentStatus != 'active') {
        throw Exception(
          'Tidak bisa menyetor ke target yang sudah ${currentStatus == 'completed' ? 'tercapai' : 'dibatalkan'}',
        );
      }

      final newAmount = currentAmount + amount;

      // Determine if goal is now completed
      final newStatus = newAmount >= targetAmount ? 'completed' : 'active';

      // Atomic update goal
      transaction.update(goalRef, {
        'currentAmount': newAmount,
        'status': newStatus,
        'updatedAt': timestamp,
      });

      // Create allocation record
      transaction.set(allocationRef, {
        'amount': amount,
        'type': 'deposit',
        'note': note?.trim(),
        'createdAt': timestamp,
      });
    });

    LoggerService.info(
      'Deposit $amount ke goal $goalId berhasil.${note != null ? ' Note: $note' : ''}',
    );
  }

  // ----------------------------------------------------------
  // WITHDRAW FROM GOAL
  // ----------------------------------------------------------
  static Future<void> withdrawGoal({
    required String goalId,
    required double amount,
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    if (amount <= 0) {
      throw Exception('Jumlah penarikan harus lebih dari 0');
    }

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc(goalId);
    final allocationRef = goalRef.collection('allocations').doc();
    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      final goalSnap = await transaction.get(goalRef);
      if (!goalSnap.exists) throw Exception('Target tabungan tidak ditemukan');

      final data = goalSnap.data() as Map<String, dynamic>;
      final currentStatus = data['status'] as String? ?? 'active';
      final currentAmount = (data['currentAmount'] as num?)?.toDouble() ?? 0;
      final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0;

      // Business rule: cancelled goals cannot be withdrawn
      if (currentStatus == 'cancelled') {
        throw Exception('Tidak bisa menarik dari target yang dibatalkan');
      }

      // Business rule: amount <= currentAmount
      if (amount > currentAmount) {
        throw Exception(
          'Jumlah penarikan melebihi saldo target. '
          'Saldo saat ini: Rp ${currentAmount.toStringAsFixed(0)}',
        );
      }

      final newAmount = currentAmount - amount;

      // If was completed and now below target → revert to active
      String newStatus = currentStatus;
      if (currentStatus == 'completed' && newAmount < targetAmount) {
        newStatus = 'active';
      }

      // Atomic update goal
      transaction.update(goalRef, {
        'currentAmount': newAmount,
        'status': newStatus,
        'updatedAt': timestamp,
      });

      // Create allocation record
      transaction.set(allocationRef, {
        'amount': amount,
        'type': 'withdraw',
        'note': note?.trim(),
        'createdAt': timestamp,
      });
    });

    LoggerService.info(
      'Withdraw $amount dari goal $goalId berhasil.${note != null ? ' Note: $note' : ''}',
    );
  }

  // ----------------------------------------------------------
  // CANCEL GOAL
  // ----------------------------------------------------------
  static Future<void> cancelGoal({required String goalId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc(goalId);
    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      final goalSnap = await transaction.get(goalRef);
      if (!goalSnap.exists) throw Exception('Target tabungan tidak ditemukan');

      final data = goalSnap.data() as Map<String, dynamic>;
      final currentStatus = data['status'] as String? ?? 'active';

      if (currentStatus == 'cancelled') {
        throw Exception('Target tabungan sudah dibatalkan');
      }

      transaction.update(goalRef, {
        'status': 'cancelled',
        'updatedAt': timestamp,
      });
    });

    LoggerService.info('Goal $goalId dibatalkan.');
  }

  // ----------------------------------------------------------
  // REACTIVATE GOAL (from cancelled)
  // ----------------------------------------------------------
  static Future<void> reactivateGoal({required String goalId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc(goalId);
    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      final goalSnap = await transaction.get(goalRef);
      if (!goalSnap.exists) throw Exception('Target tabungan tidak ditemukan');

      final data = goalSnap.data() as Map<String, dynamic>;
      final currentStatus = data['status'] as String? ?? 'active';
      final currentAmount = (data['currentAmount'] as num?)?.toDouble() ?? 0;
      final targetAmount = (data['targetAmount'] as num?)?.toDouble() ?? 0;

      if (currentStatus != 'cancelled') {
        throw Exception('Hanya target yang dibatalkan yang bisa diaktifkan kembali');
      }

      final newStatus = currentAmount >= targetAmount ? 'completed' : 'active';

      transaction.update(goalRef, {
        'status': newStatus,
        'updatedAt': timestamp,
      });
    });

    LoggerService.info('Goal $goalId diaktifkan kembali.');
  }

  // ----------------------------------------------------------
  // DELETE GOAL
  // ----------------------------------------------------------
  static Future<void> deleteGoal({required String goalId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final userDocRef = _userDoc();
    final goalRef = userDocRef.collection('goals').doc(goalId);

    // Delete allocations subcollection first (batch)
    final allocationsSnap = await goalRef.collection('allocations').get();
    final batch = _firestore.batch();
    for (final doc in allocationsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(goalRef);
    await batch.commit();

    LoggerService.info('Goal $goalId berhasil dihapus beserta allocations.');
  }

  // ----------------------------------------------------------
  // CALCULATE WALLET ALLOCATION
  // Menghitung total alokasi dari semua goal aktif per wallet.
  // ----------------------------------------------------------
  static Future<double> calculateWalletAllocation({
    required String walletId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .where('walletId', isEqualTo: walletId)
        .where('status', isEqualTo: 'active')
        .get();

    double totalAllocated = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalAllocated += (data['currentAmount'] as num?)?.toDouble() ?? 0;
    }

    return totalAllocated;
  }

  /// Get available balance for a wallet = wallet.balance - totalAllocatedGoals.
  static Future<double> getAvailableBalance({
    required String walletId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final walletSnap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('wallets')
        .doc(walletId)
        .get();

    if (!walletSnap.exists) throw Exception('Dompet tidak ditemukan');

    final walletData = walletSnap.data() as Map<String, dynamic>;
    final balance = (walletData['balance'] ?? 0).toDouble();
    final allocated = await calculateWalletAllocation(walletId: walletId);

    return balance - allocated;
  }

  // ----------------------------------------------------------
  // STREAM: All goals for current user
  // ----------------------------------------------------------
  static Stream<QuerySnapshot> getGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ----------------------------------------------------------
  // STREAM: Goals for a specific wallet
  // ----------------------------------------------------------
  static Stream<QuerySnapshot> getGoalsByWalletStream({
    required String walletId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .where('walletId', isEqualTo: walletId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ----------------------------------------------------------
  // STREAM: Allocations for a specific goal
  // ----------------------------------------------------------
  static Stream<QuerySnapshot> getAllocationsStream({
    required String goalId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId)
        .collection('allocations')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ----------------------------------------------------------
  // STREAM: Single goal document
  // ----------------------------------------------------------
  static Stream<DocumentSnapshot> getGoalStream({
    required String goalId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId)
        .snapshots();
  }
}
