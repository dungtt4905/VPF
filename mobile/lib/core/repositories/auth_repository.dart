import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../network/dio_client.dart';
import '../services/avatar_service.dart';
import '../services/secure_storage_service.dart';
import '../../models/transaction_model.dart';
import '../../models/budget_plan_model.dart';
import '../../models/budget_jar_model.dart';
import '../../models/budget_category_model.dart';
import '../../models/category_model.dart';

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorageService _storage;
  final Isar _isar;
  final AvatarService _avatar;

  AuthRepository(this._dioClient, this._storage, this._isar, this._avatar);

  Future<void> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      
      final data = response.data;
      await _storage.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        userId: data['userId'],
        email: data['email'],
        name: data['name'],
      );
      await _avatar.setFromRemote(data['avatarUrl'] as String?);
    } catch (e) {
      if (e is DioException) {
        debugPrint('--- LOGIN ERROR ---');
        debugPrint('URL: ${e.requestOptions.uri}');
        debugPrint('Status Code: ${e.response?.statusCode}');
        debugPrint('Response Data: ${e.response?.data}');
        debugPrint('Error Message: ${e.message}');
        debugPrint('-------------------');
        throw Exception(_message(e, 'Đăng nhập thất bại'));
      }
      throw Exception('Đã xảy ra lỗi không mong muốn');
    }
  }

  Future<void> register(String email, String password, String name) async {
    try {
      final response = await _dioClient.dio.post(
        '/auth/register',
        data: {'email': email, 'password': password, 'name': name},
      );
      
      final data = response.data;
      await _storage.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
        userId: data['userId'],
        email: data['email'],
        name: data['name'],
      );
      await _avatar.setFromRemote(data['avatarUrl'] as String?);
    } catch (e) {
      if (e is DioException) {
        debugPrint('--- REGISTER ERROR ---');
        debugPrint('URL: ${e.requestOptions.uri}');
        debugPrint('Status Code: ${e.response?.statusCode}');
        debugPrint('Response Data: ${e.response?.data}');
        debugPrint('Error Message: ${e.message}');
        debugPrint('----------------------');
        throw Exception(_message(e, 'Đăng ký thất bại'));
      }
      throw Exception('Đã xảy ra lỗi không mong muốn');
    }
  }

  static String _message(DioException e, String fallback) {
    final data = e.response?.data;
    final msg = data is Map ? data["message"] : null;
    if (msg is String && msg.isNotEmpty) return msg;
    if (msg is List && msg.isNotEmpty) return msg.first.toString();
    return fallback;
  }

  Future<void> logout() async {
    await _avatar.clear();
    await _storage.clearAll();

    // Xóa dữ liệu người dùng trong Isar (giữ lại danh mục mặc định)
    await _isar.writeTxn(() async {
      await _isar.transactionModels.clear();
      await _isar.budgetPlanModels.clear();
      await _isar.budgetJarModels.clear();
      await _isar.budgetCategoryModels.clear();
      await _isar.categoryModels.filter().isPredefinedEqualTo(false).deleteAll();
    });
  }

  /// Đồng bộ lại tên/email từ server (session cũ có thể đang lưu tên rỗng). Lỗi mạng/token hết hạn thì bỏ qua.
  Future<void> refreshProfile() async {
    try {
      final res = await _dioClient.dio.get('/auth/me');
      final data = res.data;
      if (data is! Map) return;
      await _storage.saveProfile(name: data['name'] as String?, email: data['email'] as String?);
      await _avatar.setFromRemote(data['avatarUrl'] as String?);
    } catch (e) {
      debugPrint('refreshProfile failed: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.getAccessToken();
    return token != null;
  }
}
