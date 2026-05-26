import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:artoku_app/core/services/logger_service.dart';

class PatunganService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> createPatungan({
    required String title,
    required double totalAmount,
    required String walletId,
    required String walletName,
    required String creatorName,
    required String category,
    required List<Map<String, dynamic>> participants,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    // ── Validasi Input ──
    if (title.trim().isEmpty) {
      throw Exception('Judul patungan tidak boleh kosong');
    }
    if (totalAmount <= 0) {
      throw Exception('Total nominal harus lebih dari 0');
    }
    if (participants.length < 2) {
      throw Exception('Minimal 2 peserta diperlukan');
    }
    if (walletId.isEmpty) {
      throw Exception('Pilih dompet terlebih dahulu');
    }

    // Validasi setiap peserta
    double sumShares = 0;
    for (final p in participants) {
      final name = (p['name'] as String?)?.trim() ?? '';
      final amount = (p['amount'] as num?)?.toDouble() ?? 0;
      if (name.isEmpty) throw Exception('Nama peserta tidak boleh kosong');
      if (amount <= 0) {
        throw Exception('Nominal untuk "$name" harus lebih dari 0');
      }
      sumShares += amount;
    }

    // Validasi sum shares == totalAmount (tolerance floating point)
    if ((sumShares - totalAmount).abs() > 0.01) {
      throw Exception(
        'Total bagian (Rp ${sumShares.toStringAsFixed(0)}) tidak sama dengan '
        'total patungan (Rp ${totalAmount.toStringAsFixed(0)})',
      );
    }

    // Validasi nama unik
    final names = participants
        .map((p) => (p['name'] as String).trim().toLowerCase())
        .toList();
    if (names.toSet().length != names.length) {
      throw Exception('Nama peserta tidak boleh ada yang sama');
    }

    // ── Firestore References ──
    final userDocRef = _firestore.collection('users').doc(user.uid);
    final walletRef = userDocRef.collection('wallets').doc(walletId);
    final patunganRef = userDocRef.collection('patungans').doc();
    final expenseRef = userDocRef.collection('transactions').doc();

    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    // ── Atomic Transaction ──
    await _firestore.runTransaction((transaction) async {
      // READ phase: harus sebelum semua write
      final walletSnap = await transaction.get(walletRef);
      if (!walletSnap.exists) throw Exception('Dompet tidak ditemukan');

      final walletData = walletSnap.data() as Map<String, dynamic>;
      final currentBalance = (walletData['balance'] ?? 0).toDouble();

      if (currentBalance < totalAmount) {
        throw Exception(
          'Saldo dompet tidak cukup. '
          'Saldo: Rp ${currentBalance.toStringAsFixed(0)}, '
          'Dibutuhkan: Rp ${totalAmount.toStringAsFixed(0)}',
        );
      }

      // WRITE phase
      // 1. Kurangi saldo wallet sebesar totalAmount
      transaction.update(walletRef, {
        'balance': FieldValue.increment(-totalAmount),
      });

      // 2. Build shares & buat receivable untuk non-creator
      final List<Map<String, dynamic>> sharesData = [];
      final creatorNameLower = creatorName.trim().toLowerCase();

      for (final p in participants) {
        final name = (p['name'] as String).trim();
        final amount = (p['amount'] as num).toDouble();
        final isCreator = name.toLowerCase() == creatorNameLower;

        if (isCreator) {
          // Creator: share otomatis settled, tanpa receivable
          sharesData.add({
            'name': name,
            'amount': amount,
            'status': 'paid',
            'paidAt': null,
            'isCreator': true,
            'receivableId': null,
          });
        } else {
          // Non-creator: buat piutang (receivable) di collection debts
          // walletId disimpan di receivable supaya terlihat di Piutang tab,
          // tapi wallet TIDAK di-adjust di sini (sudah via expense).
          final receivableRef = userDocRef.collection('debts').doc();

          transaction.set(receivableRef, {
            'type': 'piutang',
            'personName': name,
            'amount': amount,
            'note': 'Patungan: $title',
            'isPaid': false,
            'createdAt': timestamp,
            'dueDate': null,
            'walletId': walletId,
            'patunganId': patunganRef.id,
            'updatedAt': timestamp,
            'paidAt': null,
          });

          sharesData.add({
            'name': name,
            'amount': amount,
            'status': 'unpaid',
            'paidAt': null,
            'isCreator': false,
            'receivableId': receivableRef.id,
          });
        }
      }

      // 3. Buat 1 transaksi EXPENSE
      transaction.set(expenseRef, {
        'title': 'Patungan',
        'note': title,
        'amount': totalAmount,
        'type': 'expense',
        'date': timestamp,
        'category': category,
        'walletId': walletId,
        'walletName': walletName,
        'color': 0xFF0F4C5C,
        'createdAt': timestamp,
      });

      // 4. Buat patungan document
      transaction.set(patunganRef, {
        'title': title,
        'totalAmount': totalAmount,
        'category': category,
        'walletId': walletId,
        'walletName': walletName,
        'createdBy': creatorName.trim(),
        'status': 'active',
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'expenseTransactionId': expenseRef.id,
        'shares': sharesData,
      });
    });

    LoggerService.info(
      'Patungan "$title" berhasil dibuat. '
      'Total: $totalAmount, Peserta: ${participants.length}',
    );
  }

  // ----------------------------------------------------------
  // EDIT PATUNGAN
  // ----------------------------------------------------------
  static Future<void> editPatungan({
    required String patunganId,
    required String newTitle,
    required double newTotalAmount,
    required String newWalletId,
    required String newWalletName,
    required String newCategory,
    required List<Map<String, dynamic>> newParticipants,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    // ── Validasi Input ──
    if (newTitle.trim().isEmpty) {
      throw Exception('Judul patungan tidak boleh kosong');
    }
    if (newTotalAmount <= 0) {
      throw Exception('Total nominal harus lebih dari 0');
    }
    if (newParticipants.length < 2) {
      throw Exception('Minimal 2 peserta diperlukan');
    }
    if (newWalletId.isEmpty) {
      throw Exception('Pilih dompet terlebih dahulu');
    }

    // Validasi sum
    double sumShares = 0;
    for (final p in newParticipants) {
      final name = (p['name'] as String?)?.trim() ?? '';
      final amount = (p['amount'] as num?)?.toDouble() ?? 0;
      if (name.isEmpty) throw Exception('Nama peserta tidak boleh kosong');
      if (amount <= 0) {
        throw Exception('Nominal untuk "$name" harus lebih dari 0');
      }
      sumShares += amount;
    }
    if ((sumShares - newTotalAmount).abs() > 0.01) {
      throw Exception(
        'Total bagian (Rp ${sumShares.toStringAsFixed(0)}) tidak sama dengan '
        'total patungan (Rp ${newTotalAmount.toStringAsFixed(0)})',
      );
    }

    // Validasi nama unik
    final names = newParticipants
        .map((p) => (p['name'] as String).trim().toLowerCase())
        .toList();
    if (names.toSet().length != names.length) {
      throw Exception('Nama peserta tidak boleh ada yang sama');
    }

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final patunganRef = userDocRef.collection('patungans').doc(patunganId);

    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      // ── READ phase (semua read harus sebelum write) ──
      final patunganSnap = await transaction.get(patunganRef);
      if (!patunganSnap.exists) throw Exception('Patungan tidak ditemukan');

      final data = patunganSnap.data() as Map<String, dynamic>;
      final oldShares = List<Map<String, dynamic>>.from(
        (data['shares'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map)),
      );
      final oldWalletId = data['walletId'] as String? ?? '';
      final oldTotalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final expenseTransactionId = data['expenseTransactionId'] as String?;
      final walletChanged = newWalletId != oldWalletId;

      // Read wallet(s) berdasarkan skenario
      final oldWalletRef = userDocRef.collection('wallets').doc(oldWalletId);
      final newWalletRef = userDocRef.collection('wallets').doc(newWalletId);

      DocumentSnapshot? oldWalletSnap;
      DocumentSnapshot? newWalletSnap;

      if (walletChanged) {
        // Baca kedua wallet
        if (oldWalletId.isNotEmpty) {
          oldWalletSnap = await transaction.get(oldWalletRef);
        }
        newWalletSnap = await transaction.get(newWalletRef);
        if (!newWalletSnap.exists) {
          throw Exception('Dompet baru tidak ditemukan');
        }

        // Cek saldo wallet baru cukup untuk full amount
        final newWalletData = newWalletSnap.data() as Map<String, dynamic>;
        final newBalance = (newWalletData['balance'] ?? 0).toDouble();
        if (newBalance < newTotalAmount) {
          throw Exception(
            'Saldo dompet tidak cukup. '
            'Saldo: Rp ${newBalance.toStringAsFixed(0)}, '
            'Dibutuhkan: Rp ${newTotalAmount.toStringAsFixed(0)}',
          );
        }
      } else {
        // Wallet sama – cek saldo jika total naik
        final amountDiff = newTotalAmount - oldTotalAmount;
        if (amountDiff > 0) {
          final walletSnap = await transaction.get(oldWalletRef);
          if (!walletSnap.exists) throw Exception('Dompet tidak ditemukan');

          final walletData = walletSnap.data() as Map<String, dynamic>;
          final balance = (walletData['balance'] ?? 0).toDouble();
          if (balance < amountDiff) {
            throw Exception(
              'Saldo dompet tidak cukup untuk menaikkan total. '
              'Saldo: Rp ${balance.toStringAsFixed(0)}, '
              'Tambahan: Rp ${amountDiff.toStringAsFixed(0)}',
            );
          }
        }
      }

      // Read expense transaction
      DocumentSnapshot? expenseSnap;
      if (expenseTransactionId != null && expenseTransactionId.isNotEmpty) {
        expenseSnap = await transaction.get(
          userDocRef.collection('transactions').doc(expenseTransactionId),
        );
      }

      // Kumpulkan receivableId lama yang perlu di-read
      final oldReceivableIds = <String>{};
      for (final s in oldShares) {
        final rid = s['receivableId'] as String?;
        if (rid != null && rid.isNotEmpty) oldReceivableIds.add(rid);
      }

      // Kumpulkan receivableId yang masih ada di new participants
      final keptReceivableIds = <String>{};
      for (final p in newParticipants) {
        final rid = p['receivableId'] as String?;
        if (rid != null && rid.isNotEmpty) keptReceivableIds.add(rid);
      }

      // receivableId yang perlu dihapus
      final toDeleteIds = oldReceivableIds.difference(keptReceivableIds);

      // Read semua receivable yang ada (untuk update / delete)
      final receivableSnaps = <String, DocumentSnapshot>{};
      for (final rid in oldReceivableIds) {
        receivableSnaps[rid] = await transaction.get(
          userDocRef.collection('debts').doc(rid),
        );
      }

      // ── WRITE phase ──

      // 1. Adjust wallet balance
      if (walletChanged) {
        // Refund wallet lama (kembalikan expense yang pernah dicharge)
        if (oldWalletSnap != null && oldWalletSnap.exists) {
          transaction.update(oldWalletRef, {
            'balance': FieldValue.increment(oldTotalAmount),
          });
        }
        // Charge wallet baru dengan jumlah baru
        transaction.update(newWalletRef, {
          'balance': FieldValue.increment(-newTotalAmount),
        });
      } else {
        // Wallet sama – hanya adjust delta
        final amountDiff = newTotalAmount - oldTotalAmount;
        if (amountDiff != 0) {
          transaction.update(oldWalletRef, {
            'balance': FieldValue.increment(-amountDiff),
          });
        }
      }

      // 2. Update expense transaction
      //    Amount = newTotalAmount - paidBackAmount (net pengeluaran)
      if (expenseSnap != null && expenseSnap.exists) {
        // Hitung total yang sudah dibayar oleh non-creator yang status-nya paid
        double paidBackAmount = 0;
        for (final p in newParticipants) {
          if (p['isCreator'] == true) continue;
          if (p['status'] == 'paid') {
            paidBackAmount += (p['amount'] as num?)?.toDouble() ?? 0;
          }
        }

        final expenseUpdate = <String, dynamic>{
          'amount': newTotalAmount - paidBackAmount,
          'note': newTitle,
          'category': newCategory,
        };
        if (walletChanged) {
          expenseUpdate['walletId'] = newWalletId;
          expenseUpdate['walletName'] = newWalletName;
        }
        transaction.update(
          userDocRef.collection('transactions').doc(expenseTransactionId),
          expenseUpdate,
        );
      }

      // 3. Build new shares & handle receivables
      final effectiveWalletId = walletChanged ? newWalletId : oldWalletId;
      final List<Map<String, dynamic>> newSharesData = [];

      for (final p in newParticipants) {
        final name = (p['name'] as String).trim();
        final amount = (p['amount'] as num).toDouble();
        final isCreator = p['isCreator'] == true;
        final existingReceivableId = p['receivableId'] as String?;
        final status =
            p['status'] as String? ?? (isCreator ? 'paid' : 'unpaid');
        final paidAt = p['paidAt'];
        final paidWalletId = p['paidWalletId'] as String?;

        if (isCreator) {
          newSharesData.add({
            'name': name,
            'amount': amount,
            'status': 'paid',
            'paidAt': null,
            'isCreator': true,
            'receivableId': null,
            'paidWalletId': null,
          });
        } else if (status == 'paid') {
          // Peserta sudah bayar – update amount/name di receivable
          if (existingReceivableId != null &&
              existingReceivableId.isNotEmpty &&
              receivableSnaps[existingReceivableId]?.exists == true) {
            final receivableUpdate = <String, dynamic>{
              'amount': amount,
              'personName': name,
              'note': 'Patungan: $newTitle',
              'updatedAt': timestamp,
            };
            if (walletChanged) {
              receivableUpdate['walletId'] = effectiveWalletId;
            }
            transaction.update(
              userDocRef.collection('debts').doc(existingReceivableId),
              receivableUpdate,
            );
          }
          newSharesData.add({
            'name': name,
            'amount': amount,
            'status': 'paid',
            'paidAt': paidAt,
            'isCreator': false,
            'receivableId': existingReceivableId,
            'paidWalletId': paidWalletId,
          });
        } else {
          // Peserta belum bayar
          if (existingReceivableId != null &&
              existingReceivableId.isNotEmpty &&
              receivableSnaps[existingReceivableId]?.exists == true) {
            // Update existing receivable
            final receivableUpdate = <String, dynamic>{
              'amount': amount,
              'personName': name,
              'note': 'Patungan: $newTitle',
              'updatedAt': timestamp,
            };
            if (walletChanged) {
              receivableUpdate['walletId'] = effectiveWalletId;
            }
            transaction.update(
              userDocRef.collection('debts').doc(existingReceivableId),
              receivableUpdate,
            );
            newSharesData.add({
              'name': name,
              'amount': amount,
              'status': 'unpaid',
              'paidAt': null,
              'isCreator': false,
              'receivableId': existingReceivableId,
              'paidWalletId': null,
            });
          } else {
            // Peserta baru – buat receivable baru
            final newRecRef = userDocRef.collection('debts').doc();
            transaction.set(newRecRef, {
              'type': 'piutang',
              'personName': name,
              'amount': amount,
              'note': 'Patungan: $newTitle',
              'isPaid': false,
              'createdAt': timestamp,
              'dueDate': null,
              'walletId': effectiveWalletId,
              'patunganId': patunganId,
              'updatedAt': timestamp,
              'paidAt': null,
            });
            newSharesData.add({
              'name': name,
              'amount': amount,
              'status': 'unpaid',
              'paidAt': null,
              'isCreator': false,
              'receivableId': newRecRef.id,
              'paidWalletId': null,
            });
          }
        }
      }

      // 4. Delete removed receivables
      for (final rid in toDeleteIds) {
        if (receivableSnaps[rid]?.exists == true) {
          transaction.delete(userDocRef.collection('debts').doc(rid));
        }
      }

      // 5. Check if all paid
      final allPaid = newSharesData.every(
        (s) => s['status'] == 'paid' || s['isCreator'] == true,
      );

      // 6. Update patungan document
      final patunganUpdate = <String, dynamic>{
        'title': newTitle.trim(),
        'totalAmount': newTotalAmount,
        'category': newCategory,
        'shares': newSharesData,
        'status': allPaid ? 'settled' : 'active',
        'updatedAt': timestamp,
      };
      if (walletChanged) {
        patunganUpdate['walletId'] = newWalletId;
        patunganUpdate['walletName'] = newWalletName;
      }
      transaction.update(patunganRef, patunganUpdate);
    });

    LoggerService.info(
      'Patungan $patunganId berhasil diedit. '
      'Title: "$newTitle", Total: $newTotalAmount, Wallet: $newWalletId',
    );
  }

  // ----------------------------------------------------------
  // MARK SHARE AS PAID
  // ----------------------------------------------------------
  static Future<void> markShareAsPaid({
    required String patunganId,
    required int shareIndex,
    String? targetWalletId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final patunganRef = userDocRef.collection('patungans').doc(patunganId);

    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      // READ phase
      final patunganSnap = await transaction.get(patunganRef);
      if (!patunganSnap.exists) throw Exception('Patungan tidak ditemukan');

      final data = patunganSnap.data() as Map<String, dynamic>;
      final shares = List<Map<String, dynamic>>.from(
        (data['shares'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map)),
      );

      if (shareIndex < 0 || shareIndex >= shares.length) {
        throw Exception('Index peserta tidak valid');
      }

      final share = shares[shareIndex];

      if (share['isCreator'] == true) {
        throw Exception('Pembuat patungan tidak perlu ditandai bayar');
      }
      if (share['status'] == 'paid') {
        throw Exception('Peserta ini sudah lunas');
      }

      final double shareAmount = (share['amount'] as num?)?.toDouble() ?? 0;
      final String originalWalletId = data['walletId'] as String? ?? '';
      final String effectiveWalletId = targetWalletId ?? originalWalletId;
      final String? receivableId = share['receivableId'] as String?;
      final String? expenseTransactionId =
          data['expenseTransactionId'] as String?;

      if (effectiveWalletId.isEmpty) throw Exception('ID Dompet tidak ditemukan');

      // Read receivable jika ada (harus sebelum write)
      DocumentSnapshot? receivableSnap;
      if (receivableId != null && receivableId.isNotEmpty) {
        final receivableRef = userDocRef.collection('debts').doc(receivableId);
        receivableSnap = await transaction.get(receivableRef);
      }

      // Read expense transaction (untuk update amount)
      DocumentSnapshot? expenseSnap;
      if (expenseTransactionId != null && expenseTransactionId.isNotEmpty) {
        expenseSnap = await transaction.get(
          userDocRef.collection('transactions').doc(expenseTransactionId),
        );
      }

      // WRITE phase
      // 1. Update share status di patungan doc
      shares[shareIndex] = {
        ...share,
        'status': 'paid',
        'paidAt': timestamp,
        'paidWalletId': effectiveWalletId,
      };

      final allPaid = shares.every(
        (s) => s['status'] == 'paid' || s['isCreator'] == true,
      );

      transaction.update(patunganRef, {
        'shares': shares,
        'status': allPaid ? 'settled' : 'active',
        'updatedAt': timestamp,
      });

      // 2. Update receivable (piutang) jika masih ada
      if (receivableSnap != null && receivableSnap.exists) {
        transaction.update(
          userDocRef.collection('debts').doc(receivableId),
          {
            'isPaid': true,
            'paidAt': timestamp,
            'updatedAt': timestamp,
          },
        );
      }

      // 3. Tambah saldo wallet (uang sudah diterima)
      final walletRef = userDocRef.collection('wallets').doc(effectiveWalletId);
      transaction.update(walletRef, {
        'balance': FieldValue.increment(shareAmount),
      });

      // 4. Update expense transaction: kurangi amount karena sudah diterima kembali
      if (expenseSnap != null && expenseSnap.exists) {
        transaction.update(
          userDocRef.collection('transactions').doc(expenseTransactionId),
          {
            'amount': FieldValue.increment(-shareAmount),
          },
        );
      }
    });

    LoggerService.info(
      'Share index $shareIndex di patungan $patunganId ditandai lunas.'
      '${targetWalletId != null ? ' Wallet: $targetWalletId' : ''}',
    );
  }

  // ----------------------------------------------------------
  // MARK SHARE AS UNPAID (Reversal)
  // ----------------------------------------------------------
  static Future<void> markShareAsUnpaid({
    required String patunganId,
    required int shareIndex,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final patunganRef = userDocRef.collection('patungans').doc(patunganId);

    final now = DateTime.now().toUtc();
    final timestamp = Timestamp.fromDate(now);

    await _firestore.runTransaction((transaction) async {
      // READ phase
      final patunganSnap = await transaction.get(patunganRef);
      if (!patunganSnap.exists) throw Exception('Patungan tidak ditemukan');

      final data = patunganSnap.data() as Map<String, dynamic>;
      final shares = List<Map<String, dynamic>>.from(
        (data['shares'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map)),
      );

      if (shareIndex < 0 || shareIndex >= shares.length) {
        throw Exception('Index peserta tidak valid');
      }

      final share = shares[shareIndex];

      if (share['isCreator'] == true) {
        throw Exception('Status pembuat tidak bisa diubah');
      }
      if (share['status'] != 'paid') {
        throw Exception('Peserta ini belum ditandai lunas');
      }

      final double shareAmount = (share['amount'] as num?)?.toDouble() ?? 0;
      final String originalWalletId = data['walletId'] as String? ?? '';
      final String paidWalletId = (share['paidWalletId'] as String?) ?? originalWalletId;
      final String? receivableId = share['receivableId'] as String?;
      final String? expenseTransactionId =
          data['expenseTransactionId'] as String?;

      // Read receivable
      DocumentSnapshot? receivableSnap;
      if (receivableId != null && receivableId.isNotEmpty) {
        final receivableRef = userDocRef.collection('debts').doc(receivableId);
        receivableSnap = await transaction.get(receivableRef);
      }

      // Read expense transaction (untuk update amount)
      DocumentSnapshot? expenseSnap;
      if (expenseTransactionId != null && expenseTransactionId.isNotEmpty) {
        expenseSnap = await transaction.get(
          userDocRef.collection('transactions').doc(expenseTransactionId),
        );
      }

      // WRITE phase
      shares[shareIndex] = {
        ...share,
        'status': 'unpaid',
        'paidAt': null,
        'paidWalletId': null,
      };

      transaction.update(patunganRef, {
        'shares': shares,
        'status': 'active', // Selalu active jika ada reversal
        'updatedAt': timestamp,
      });

      // Revert receivable
      if (receivableSnap != null && receivableSnap.exists) {
        transaction.update(
          userDocRef.collection('debts').doc(receivableId),
          {
            'isPaid': false,
            'paidAt': null,
            'updatedAt': timestamp,
          },
        );
      }

      // Kurangi saldo wallet (dari wallet tempat pembayaran diterima)
      if (paidWalletId.isNotEmpty) {
        final walletRef = userDocRef.collection('wallets').doc(paidWalletId);
        transaction.update(walletRef, {
          'balance': FieldValue.increment(-shareAmount),
        });
      }

      // 4. Update expense transaction: tambah kembali amount karena dibatalkan
      if (expenseSnap != null && expenseSnap.exists) {
        transaction.update(
          userDocRef.collection('transactions').doc(expenseTransactionId),
          {
            'amount': FieldValue.increment(shareAmount),
          },
        );
      }
    });

    LoggerService.info(
      'Share index $shareIndex di patungan $patunganId dibatalkan lunas.',
    );
  }

  // ----------------------------------------------------------
  // DELETE PATUNGAN
  // ----------------------------------------------------------
  /// Menghapus patungan dan membalikkan semua efek akuntansi.
  ///
  /// Refund wallet: +(totalAmount - paidBack)
  /// Dimana paidBack = jumlah yang sudah dibayar oleh non-creator.
  static Future<void> deletePatungan({
    required String patunganId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final patunganRef = userDocRef.collection('patungans').doc(patunganId);

    await _firestore.runTransaction((transaction) async {
      // READ phase
      final patunganSnap = await transaction.get(patunganRef);
      if (!patunganSnap.exists) throw Exception('Patungan tidak ditemukan');

      final data = patunganSnap.data() as Map<String, dynamic>;
      final shares = List<Map<String, dynamic>>.from(
        (data['shares'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map)),
      );
      final walletId = data['walletId'] as String? ?? '';
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final expenseTransactionId = data['expenseTransactionId'] as String?;

      // Hitung jumlah yang sudah diterima kembali per wallet
      // Kelompokkan paid shares berdasarkan wallet tempat pembayaran diterima
      final Map<String, double> paidBackPerWallet = {};
      for (final share in shares) {
        if (share['status'] == 'paid' && share['isCreator'] != true) {
          final amount = (share['amount'] as num?)?.toDouble() ?? 0;
          final paidWallet = (share['paidWalletId'] as String?) ?? walletId;
          paidBackPerWallet[paidWallet] =
              (paidBackPerWallet[paidWallet] ?? 0) + amount;
        }
      }

      // Read semua wallet yang terlibat (untuk paid shares ke wallet lain)
      final Map<String, DocumentSnapshot> paidWalletSnaps = {};
      for (final pwId in paidBackPerWallet.keys) {
        if (pwId != walletId && pwId.isNotEmpty) {
          final ref = userDocRef.collection('wallets').doc(pwId);
          paidWalletSnaps[pwId] = await transaction.get(ref);
        }
      }

      // Read semua receivable yang terkait
      final receivableRefs = <String, DocumentSnapshot>{};
      for (final share in shares) {
        final receivableId = share['receivableId'] as String?;
        if (receivableId != null && receivableId.isNotEmpty) {
          final ref = userDocRef.collection('debts').doc(receivableId);
          receivableRefs[receivableId] = await transaction.get(ref);
        }
      }

      // Read expense transaction
      DocumentSnapshot? expenseSnap;
      if (expenseTransactionId != null && expenseTransactionId.isNotEmpty) {
        final expenseRef = userDocRef
            .collection('transactions')
            .doc(expenseTransactionId);
        expenseSnap = await transaction.get(expenseRef);
      }

      // WRITE phase
      // 1. Refund wallet original: kembalikan totalAmount (expense refund)
      if (walletId.isNotEmpty) {
        final walletRef = userDocRef.collection('wallets').doc(walletId);
        transaction.update(walletRef, {
          'balance': FieldValue.increment(totalAmount),
        });
      }

      // 2. Reverse semua pembayaran yang diterima (per wallet)
      for (final entry in paidBackPerWallet.entries) {
        final pwId = entry.key;
        final amount = entry.value;
        if (pwId.isNotEmpty) {
          final ref = userDocRef.collection('wallets').doc(pwId);
          transaction.update(ref, {
            'balance': FieldValue.increment(-amount),
          });
        }
      }

      // 3. Delete semua receivable
      for (final entry in receivableRefs.entries) {
        if (entry.value.exists) {
          transaction.delete(userDocRef.collection('debts').doc(entry.key));
        }
      }

      // 4. Delete expense transaction
      if (expenseSnap != null && expenseSnap.exists) {
        transaction.delete(
          userDocRef.collection('transactions').doc(expenseTransactionId),
        );
      }

      // 5. Delete patungan document
      transaction.delete(patunganRef);
    });

    LoggerService.info('Patungan $patunganId berhasil dihapus.');
  }

  // ----------------------------------------------------------
  // FIND SHARE INDEX BY RECEIVABLE ID
  // ----------------------------------------------------------
  /// Mencari share index berdasarkan receivableId (debtId).
  /// Digunakan oleh Piutang/Utang tab untuk toggle status dari sisi debt.
  static Future<int> findShareIndex({
    required String patunganId,
    required String receivableId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User belum login');

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('patungans')
        .doc(patunganId)
        .get();

    if (!doc.exists) throw Exception('Patungan tidak ditemukan');

    final shares = (doc.data()!['shares'] as List<dynamic>);
    for (int i = 0; i < shares.length; i++) {
      if (shares[i]['receivableId'] == receivableId) return i;
    }
    throw Exception('Peserta tidak ditemukan di patungan');
  }

  // ----------------------------------------------------------
  // STREAM HELPER
  // ----------------------------------------------------------
  /// Stream semua patungan user, diurutkan berdasarkan createdAt descending.
  static Stream<QuerySnapshot> getPatungansStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('patungans')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
