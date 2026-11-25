import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../models/budget_plan_model.dart';
import '../../models/budget_jar_model.dart';
import '../../models/budget_category_model.dart';
import '../repositories/budget_plan_repository.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../network/dio_client.dart';
import '../repositories/transaction_repository.dart';
import 'avatar_service.dart';
import 'secure_storage_service.dart';

/// Đồng bộ 2 chiều Isar <-> server (offline-first, Last-Write-Wins theo updatedAt).
/// Luồng: upload ảnh chờ -> push bản ghi chưa sync -> pull bản ghi mới từ server.
class SyncService {
  final Isar _isar;
  final DioClient _api;
  final SecureStorageService _storage;
  final TransactionRepository _transactions;
  final AvatarService _avatar;
  final BudgetPlanRepository _plans;

  bool _syncing = false;
  bool _rerun = false;
  bool _started = false;
  Timer? _debounce;
  bool _wasOffline = false;

  SyncService(this._isar, this._api, this._storage, this._transactions, this._avatar, this._plans);

  /// Tự động đồng bộ (sau 3s) mỗi khi dữ liệu local thay đổi và còn bản ghi chưa sync.
  void startAutoSync() {
    if (_started) return;
    _started = true;
    void onChange(void _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 3), () async {
        if (await _hasUnsynced()) await syncNow();
      });
    }

    // Có mạng trở lại (từ trạng thái offline) -> đồng bộ ngay phần dữ liệu đã lưu local.
    Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (!offline && _wasOffline) onChange(null);
      _wasOffline = offline;
    });

    // Dự phòng: có sóng nhưng chưa ra được internet -> thử lại định kỳ khi còn dữ liệu chưa sync.
    Timer.periodic(const Duration(minutes: 2), (_) async {
      if (await _hasUnsynced()) await syncNow();
    });

    _isar.transactionModels.watchLazy().listen(onChange);
    _isar.categoryModels.watchLazy().listen(onChange);
    _isar.budgetPlanModels.watchLazy().listen(onChange);
    _isar.budgetJarModels.watchLazy().listen(onChange);
    _isar.budgetCategoryModels.watchLazy().listen(onChange);
  }

  /// Chạy một vòng đồng bộ. Không ném lỗi: offline/lỗi server sẽ được thử lại ở lần sau.
  Future<void> syncNow() async {
    if (_syncing) {
      _rerun = true; // có thay đổi mới trong lúc đang sync -> chạy thêm một vòng
      return;
    }
    _syncing = true;
    try {
      do {
        _rerun = false;
        if (await _storage.getAccessToken() == null) return;
        await _avatar.syncPending(); // ảnh đại diện đổi lúc offline
        await _transactions.uploadPendingImages(); // để imageUrl có mặt trước khi push
        await _push();
        await _pull();
      } while (_rerun);
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<bool> _hasUnsynced() async {
    return await _isar.transactionModels.filter().isSyncedEqualTo(false).count() > 0 ||
        await _isar.categoryModels.filter().isSyncedEqualTo(false).count() > 0 ||
        await _isar.budgetPlanModels.filter().isSyncedEqualTo(false).count() > 0 ||
        await _isar.budgetJarModels.filter().isSyncedEqualTo(false).count() > 0 ||
        await _isar.budgetCategoryModels.filter().isSyncedEqualTo(false).count() > 0;
  }

  Future<void> _push() async {
    final cats = await _isar.categoryModels.filter().isSyncedEqualTo(false).findAll();
    final txns = await _isar.transactionModels.filter().isSyncedEqualTo(false).findAll();
    final plans = await _isar.budgetPlanModels.filter().isSyncedEqualTo(false).findAll();
    final jars = await _isar.budgetJarModels.filter().isSyncedEqualTo(false).findAll();
    final links = await _isar.budgetCategoryModels.filter().isSyncedEqualTo(false).findAll();
    if (cats.isEmpty && txns.isEmpty && plans.isEmpty && jars.isEmpty && links.isEmpty) return;

    await _api.dio.post('/sync/push', data: {
      'categories': cats.map((e) => e.toJson()).toList(),
      'transactions': txns.map((e) => e.toJson()).toList(),
      'budgetPlans': plans.map((e) => e.toJson()).toList(),
      'budgetJars': jars.map((e) => e.toJson()).toList(),
      'budgetCategories': links.map((e) => e.toJson()).toList(),
    });

    // Chỉ đánh dấu đã sync nếu bản ghi chưa bị sửa tiếp trong lúc push.
    await _isar.writeTxn(() async {
      for (final c in cats) {
        final cur = await _isar.categoryModels.get(c.id);
        if (cur != null && cur.updatedAt == c.updatedAt) {
          cur.isSynced = true;
          await _isar.categoryModels.put(cur);
        }
      }
      for (final t in txns) {
        final cur = await _isar.transactionModels.get(t.id);
        if (cur != null && cur.updatedAt == t.updatedAt) {
          cur.isSynced = true;
          await _isar.transactionModels.put(cur);
        }
      }
      for (final p in plans) {
        final cur = await _isar.budgetPlanModels.get(p.id);
        if (cur != null && cur.updatedAt == p.updatedAt) {
          cur.isSynced = true;
          await _isar.budgetPlanModels.put(cur);
        }
      }
      for (final j in jars) {
        final cur = await _isar.budgetJarModels.get(j.id);
        if (cur != null && cur.updatedAt == j.updatedAt) {
          cur.isSynced = true;
          await _isar.budgetJarModels.put(cur);
        }
      }
      for (final l in links) {
        final cur = await _isar.budgetCategoryModels.get(l.id);
        if (cur != null && cur.updatedAt == l.updatedAt) {
          cur.isSynced = true;
          await _isar.budgetCategoryModels.put(cur);
        }
      }
    });
  }

  Future<void> _pull() async {
    final since = await _storage.getLastSyncedAt();
    final res = await _api.dio.get('/sync/pull', queryParameters: {'lastSyncedAt': ?since});
    final data = res.data as Map<String, dynamic>;

    List<Map<String, dynamic>> rows(String key) => ((data[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    final cats = rows('categories').map(CategoryModel.fromJson).toList();
    final txns = rows('transactions').map(TransactionModel.fromJson).toList();
    final plans = rows('budgetPlans').map(BudgetPlanModel.fromJson).toList();
    final jars = rows('budgetJars').map(BudgetJarModel.fromJson).toList();
    final links = rows('budgetCategories').map(BudgetCategoryModel.fromJson).toList();

    await _isar.writeTxn(() async {
      for (final r in cats) {
        final local = await _isar.categoryModels.getBySyncId(r.syncId);
        if (local != null) {
          // Last-Write-Wins: bản local mới hơn (hoặc bằng) thì giữ, để push lên ở lần sau.
          if (!r.updatedAt.isAfter(local.updatedAt)) continue;
          r.id = local.id;
        }
        await _isar.categoryModels.put(r);
      }
      for (final r in txns) {
        final local = await _isar.transactionModels.getBySyncId(r.syncId);
        if (local != null) {
          if (!r.updatedAt.isAfter(local.updatedAt)) continue;
          r.id = local.id;
          // Giữ ảnh local nếu ảnh cloud không đổi; nếu thiết bị khác đã đổi ảnh thì bỏ ảnh cũ.
          if (local.cloudImageKey == r.cloudImageKey) {
            r.localImagePath = local.localImagePath;
            r.localThumbnailPath = local.localThumbnailPath;
          }
        }
        await _isar.transactionModels.put(r);
      }
      for (final r in plans) {
        final local = await _isar.budgetPlanModels.getBySyncId(r.syncId);
        if (local != null) {
          if (!r.updatedAt.isAfter(local.updatedAt)) continue;
          r.id = local.id;
        }
        await _isar.budgetPlanModels.put(r);
      }
      for (final r in jars) {
        final local = await _isar.budgetJarModels.getBySyncId(r.syncId);
        if (local != null) {
          if (!r.updatedAt.isAfter(local.updatedAt)) continue;
          r.id = local.id;
        }
        await _isar.budgetJarModels.put(r);
      }
      for (final r in links) {
        final local = await _isar.budgetCategoryModels.getBySyncId(r.syncId);
        if (local != null) {
          if (!r.updatedAt.isAfter(local.updatedAt)) continue;
          r.id = local.id;
        }
        await _isar.budgetCategoryModels.put(r);
      }
    });

    // Sang tháng mới trên thiết bị này (hoặc kế hoạch chưa có) -> bảo đảm có kế hoạch tháng hiện tại.
    await _plans.ensureCurrentPlan();

    await _storage.saveLastSyncedAt(data['timestamp'] as String);
  }
}
