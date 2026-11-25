import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _nameKey = 'user_name';
  static const _lastSyncedAtKey = 'last_synced_at';
  static const _avatarUrlKey = 'avatar_url';
  static const _avatarLocalKey = 'avatar_local_path';
  static const _avatarPendingKey = 'avatar_pending';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? email,
    String? name,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
    // Luôn ghi đè để không giữ lại tên/email của tài khoản trước đó.
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _nameKey, value: name);
  }

  Future<void> saveProfile({String? name, String? email}) async {
    await _storage.write(key: _nameKey, value: name);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<String?> getAccessToken() async => await _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() async => await _storage.read(key: _refreshTokenKey);
  Future<String?> getUserId() async => await _storage.read(key: _userIdKey);
  Future<String?> getEmail() async => await _storage.read(key: _emailKey);
  Future<String?> getName() async => await _storage.read(key: _nameKey);

  /// Tên hiển thị: tên thật -> phần trước @ của email -> 'Người dùng'.
  Future<String> getDisplayName() async {
    final name = (await getName())?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = (await getEmail())?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Người dùng';
  }

  // Ảnh đại diện: URL trên cloud, bản ở máy, và thay đổi chưa đưa lên server (upload | remove).
  Future<String?> getAvatarUrl() async => await _storage.read(key: _avatarUrlKey);
  Future<String?> getAvatarLocalPath() async => await _storage.read(key: _avatarLocalKey);
  Future<String?> getAvatarPending() async => await _storage.read(key: _avatarPendingKey);
  Future<void> saveAvatar({String? url, String? localPath, String? pending}) async {
    await _storage.write(key: _avatarUrlKey, value: url);
    await _storage.write(key: _avatarLocalKey, value: localPath);
    await _storage.write(key: _avatarPendingKey, value: pending);
  }

  // Mốc pull gần nhất; bị xóa cùng clearAll() khi đăng xuất nên tài khoản mới sẽ pull lại từ đầu.
  Future<String?> getLastSyncedAt() async => await _storage.read(key: _lastSyncedAtKey);
  Future<void> saveLastSyncedAt(String value) async => await _storage.write(key: _lastSyncedAtKey, value: value);

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
