import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/services/avatar_service.dart';
import '../../core/theme/app_colors.dart';

/// Ảnh đại diện tròn của người dùng. Ưu tiên ảnh ở máy (hiện ngay, dùng được offline),
/// sau đó đến ảnh trên cloud, cuối cùng là biểu tượng người mặc định. Tự cập nhật khi ảnh đổi.
class UserAvatar extends StatelessWidget {
  final double radius;
  const UserAvatar({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    final service = getIt<AvatarService>();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final size = radius * 2;
        final fallback = Icon(Icons.person, size: radius, color: Colors.white);

        Widget? image;
        final local = service.localPath;
        if (local != null && File(local).existsSync()) {
          image = Image.file(File(local), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
        } else if (service.url != null) {
          image = Image.network(
            service.url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // Lúc đang tải hoặc lỗi mạng thì hiện biểu tượng mặc định thay vì ô trống.
            loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
            errorBuilder: (_, __, ___) => fallback,
          );
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary,
          child: image == null ? fallback : ClipOval(child: image),
        );
      },
    );
  }
}
