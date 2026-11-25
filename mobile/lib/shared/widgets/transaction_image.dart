import '../../core/theme/app_colors.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Trả về đường dẫn đầu tiên trỏ tới file ảnh tồn tại và không rỗng, nếu không có thì null.
String? usableImagePath(String? first, [String? second]) {
  for (final p in [first, second]) {
    if (p == null || p.isEmpty) continue;
    try {
      final f = File(p);
      if (f.existsSync() && f.lengthSync() > 0) return p;
    } catch (_) {}
  }
  return null;
}

/// Ảnh từ file local, an toàn khi file mất/rỗng/hỏng: hiện placeholder thay vì lỗi render.
class SafeFileImage extends StatelessWidget {
  final String? path;
  final String? fallbackPath;
  final BoxFit fit;
  final int? cacheWidth;
  final double? width;
  final double? height;

  const SafeFileImage({
    super.key,
    required this.path,
    this.fallbackPath,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final p = usableImagePath(path, fallbackPath);
    if (p == null) return _placeholder();
    return Image.file(
      File(p),
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400),
      );
}

/// Hộp thoại chọn nguồn ảnh: chụp mới hoặc chọn từ thư viện.
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
            title: const Text('Chụp ảnh mới'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Chọn nguồn rồi lấy ảnh; trả về null nếu người dùng hủy hoặc có lỗi (đã báo bằng SnackBar).
Future<File?> pickTransactionImage(BuildContext context, ImagePicker picker) async {
  final source = await showImageSourceSheet(context);
  if (source == null || !context.mounted) return null;
  try {
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return null;
    final file = File(image.path);
    if (!file.existsSync() || file.lengthSync() == 0) throw Exception('Ảnh rỗng');
    return file;
  } catch (e) {
    debugPrint('Lỗi chọn ảnh: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể lấy ảnh. Vui lòng kiểm tra quyền camera/thư viện.')),
      );
    }
    return null;
  }
}
