import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import 'cloud_image_service.dart';
import 'image_storage_service.dart';
import 'secure_storage_service.dart';

/// Ảnh đại diện của người dùng. Offline-first: ảnh được lưu ở máy và hiển thị ngay,
/// sau đó tự tải lên cloud và ghi URL lên tài khoản khi có mạng (xem [syncPending]).
class AvatarService extends ChangeNotifier {
  static const _pendingUpload = 'upload';
  static const _pendingRemove = 'remove';

  final SecureStorageService _storage;
  final DioClient _api;
  final CloudImageService _cloud;
  final ImageStorageService _images;

  AvatarService(this._storage, this._api, this._cloud, this._images);

  String? _url; // ảnh trên cloud
  String? _localPath; // ảnh ở máy (hiển thị ưu tiên)
  String? _pending; // thay đổi chưa đưa lên server: upload | remove
  bool _syncing = false;

  String? get url => _url;
  String? get localPath => _localPath;
  bool get hasAvatar => (_localPath != null && File(_localPath!).existsSync()) || _url != null;
  bool get hasPending => _pending != null;

  Future<void> load() async {
    _url = await _storage.getAvatarUrl();
    _localPath = await _storage.getAvatarLocalPath();
    _pending = await _storage.getAvatarPending();
    notifyListeners();
  }

  /// Nhận ảnh từ server (sau đăng nhập / làm mới hồ sơ). Không ghi đè thay đổi chưa kịp đưa lên server.
  Future<void> setFromRemote(String? url) async {
    if (_pending != null) return;
    if (url == _url) return;
    _url = url;
    // Ảnh trên server khác ảnh đang lưu ở máy (đổi ở thiết bị khác) -> bỏ ảnh máy để hiện ảnh mới.
    await _deleteLocalFile();
    _localPath = null;
    await _persist();
    notifyListeners();
  }

  /// Đặt ảnh mới từ file người dùng chọn: nén vuông nhỏ, lưu máy, rồi thử tải lên.
  /// Trả về true nếu đã lên được server ngay; false nếu còn chờ mạng.
  Future<bool> change(File picked) async {
    final path = await _images.processAvatar(picked.path);
    if (path == null) throw Exception('Không xử lý được ảnh');
    await _deleteLocalFile();
    _localPath = path;
    _pending = _pendingUpload;
    await _persist();
    notifyListeners();
    return syncPending();
  }

  /// Xóa ảnh đại diện (quay về biểu tượng mặc định).
  Future<bool> remove() async {
    await _deleteLocalFile();
    _localPath = null;
    _pending = _pendingRemove;
    await _persist();
    notifyListeners();
    return syncPending();
  }

  /// Đưa thay đổi ảnh còn chờ lên server. An toàn khi gọi nhiều lần; lỗi/offline thì giữ lại để thử sau.
  /// Trả về true nếu không còn gì chờ.
  Future<bool> syncPending() async {
    if (_pending == null) return true;
    if (_syncing) return false;
    _syncing = true;
    try {
      if (_pending == _pendingRemove) {
        await _api.dio.patch('/auth/me/avatar', data: {'avatarUrl': null});
        _url = null;
      } else {
        final path = _localPath;
        if (path == null || !File(path).existsSync()) {
          _pending = null; // file đã mất, không còn gì để tải
          await _persist();
          return true;
        }
        final uploaded = await _cloud.upload(path);
        if (uploaded == null) return false;
        await _api.dio.patch('/auth/me/avatar', data: {'avatarUrl': uploaded.url});
        _url = uploaded.url;
      }
      _pending = null;
      await _persist();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      debugPrint('Đồng bộ ảnh đại diện thất bại: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Đồng bộ ảnh đại diện thất bại: $e');
      return false;
    } finally {
      _syncing = false;
    }
  }

  /// Dọn dữ liệu khi đăng xuất.
  Future<void> clear() async {
    await _deleteLocalFile();
    _url = null;
    _localPath = null;
    _pending = null;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveAvatar(url: _url, localPath: _localPath, pending: _pending);
  }

  Future<void> _deleteLocalFile() async {
    final p = _localPath;
    if (p == null) return;
    try {
      final f = File(p);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
