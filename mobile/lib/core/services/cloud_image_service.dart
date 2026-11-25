import 'dart:io';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';

class UploadedImage {
  final String url;
  final String key;
  const UploadedImage({required this.url, required this.key});
}

/// Upload ảnh giao dịch lên cloud (Supabase Storage) qua presigned URL do backend cấp.
class CloudImageService {
  final DioClient _api;

  // Dio riêng, KHÔNG gắn Bearer token: presigned URL đã tự chứa chữ ký,
  // thêm header Authorization sẽ làm Supabase từ chối request.
  final Dio _uploader = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  CloudImageService(this._api);

  /// Trả về null nếu upload thất bại (offline, hết hạn...) để caller thử lại sau.
  Future<UploadedImage?> upload(String localPath, {String contentType = 'image/jpeg'}) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;
      final length = await file.length();
      if (length == 0) return null;

      final res = await _api.dio.post('/storage/presigned-url', data: {
        'fileName': localPath.split(Platform.pathSeparator).last,
        'contentType': contentType,
      });
      final data = res.data as Map<String, dynamic>;

      await _uploader.put(
        data['uploadUrl'] as String,
        data: file.openRead(),
        options: Options(headers: {
          // Phải trùng contentType đã gửi lên backend, nếu lệch chữ ký sẽ sai.
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: length,
        }),
      );

      return UploadedImage(url: data['publicUrl'] as String, key: data['key'] as String);
    } catch (_) {
      return null;
    }
  }
}
