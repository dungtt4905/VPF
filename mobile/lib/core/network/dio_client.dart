import 'package:dio/dio.dart';
import '../services/secure_storage_service.dart';

class DioClient {
  // Địa chỉ server truyền lúc build: --dart-define=API_BASE_URL=https://<tên-service>.onrender.com
  // Không truyền thì gọi server local (máy thật cần adb reverse tcp:3000 tcp:3000).
  static const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:3000');
  // Server free có thể đang ngủ, request đầu tiên phải chờ nó khởi động lại.
  static const _timeout = Duration(seconds: 90);
  static const _retriedKey = 'retried_after_refresh';

  final Dio dio;
  final SecureStorageService _secureStorage;

  // Dio riêng, không có interceptor: tránh gọi đệ quy khi chính request refresh bị 401.
  final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
    ),
  );

  // Nhiều request cùng gặp 401 chỉ gọi refresh một lần, các request còn lại chờ kết quả đó.
  Future<bool>? _refreshing;

  DioClient(this._secureStorage) : dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
    ),
  ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Bỏ qua việc đính token nếu API là login/register/refresh
          if (_isAuthPath(options.path)) {
            return handler.next(options);
          }

          final token = await _secureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final request = e.requestOptions;
          final shouldRefresh = e.response?.statusCode == 401 &&
              !_isAuthPath(request.path) &&
              request.extra[_retriedKey] != true;
          if (!shouldRefresh) return handler.next(e);

          final refreshed = await (_refreshing ??= _refreshTokens().whenComplete(() => _refreshing = null));
          if (!refreshed) return handler.next(e);

          try {
            // Gửi lại request cũ; onRequest sẽ tự đính access token mới.
            request.extra[_retriedKey] = true;
            return handler.resolve(await dio.fetch(request));
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  static bool _isAuthPath(String path) =>
      path.contains('/auth/login') || path.contains('/auth/register') || path.contains('/auth/refresh');

  /// Đổi refresh token lấy cặp token mới. Trả về false nếu không làm mới được
  /// (hết hạn, mất mạng...) — token cũ được giữ nguyên, người dùng sẽ cần đăng nhập lại.
  Future<bool> _refreshTokens() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final res = await _refreshDio.post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = res.data as Map<String, dynamic>;
      await _secureStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: data['userId'] as String,
        email: data['email'] as String?,
        name: data['name'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
