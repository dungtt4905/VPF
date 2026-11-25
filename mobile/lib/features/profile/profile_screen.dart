import '../../core/theme/app_colors.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar/isar.dart';
import 'package:share_plus/share_plus.dart';
import '../category/manage_categories_screen.dart';
import '../auth/cubit/auth_cubit.dart';
import '../../core/di/injection.dart';
import '../../core/services/avatar_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../shared/widgets/user_avatar.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/transaction_reminder_service.dart';
import '../../core/repositories/auth_repository.dart';
import '../../models/transaction_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reminderEnabled = false;
  bool _avatarBusy = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final reminder = getIt<TransactionReminderService>();
    final reminderOn = await reminder.isEnabled();
    final time = await reminder.getTime();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = reminderOn;
      _reminderTime = TimeOfDay(hour: time.hour, minute: time.minute);
    });
  }

  Future<void> _loadUser() async {
    final storage = getIt<SecureStorageService>();
    await getIt<AuthRepository>().refreshProfile();
    final name = await storage.getDisplayName();
    final email = (await storage.getEmail())?.trim() ?? '';
    if (!mounted) return;
    setState(() {
      _name = name;
      _email = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            children: [
              _buildUserInfo(),
              const SizedBox(height: 28),
              _buildPreferencesSection(),
              const SizedBox(height: AppSpacing.xxl),
              _buildLogoutButton(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// Bảng chọn: chụp ảnh, chọn từ thư viện, hoặc xóa ảnh hiện tại.
  Future<void> _showAvatarOptions() async {
    final hasAvatar = getIt<AvatarService>().hasAvatar;
    final choice = await showModalBottomSheet<String>(
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
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa ảnh đại diện', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      await _runAvatarTask(() => getIt<AvatarService>().remove(), doneMessage: 'Đã xóa ảnh đại diện');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;
      await _runAvatarTask(() => getIt<AvatarService>().change(File(picked.path)), doneMessage: 'Đã cập nhật ảnh đại diện');
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Không thể lấy ảnh. Vui lòng kiểm tra quyền camera/thư viện.')));
    }
  }

  /// Chạy tác vụ đổi ảnh: hiện vòng quay, báo kết quả. Offline thì ảnh vẫn được giữ ở máy và tự tải lên sau.
  Future<void> _runAvatarTask(Future<bool> Function() task, {required String doneMessage}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _avatarBusy = true);
    try {
      final synced = await task();
      messenger.showSnackBar(SnackBar(
        content: Text(synced ? doneMessage : 'Đã lưu trên máy, sẽ tự đồng bộ lên tài khoản khi có mạng.'),
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không đổi được ảnh đại diện: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _avatarBusy ? null : _showAvatarOptions,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const UserAvatar(radius: 48),
                if (_avatarBusy)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                // Huy hiệu máy ảnh gợi ý có thể bấm để đổi ảnh.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _email,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 16,
      endIndent: 16,
    );
  }


  /// Chọn khoảng thời gian cần xuất. Trả về null nếu người dùng hủy.
  Future<({DateTime? from, DateTime? to})?> _pickExportRange() async {
    final now = DateTime.now();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Xuất báo cáo PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final o in const [
              ('month', 'Tháng này'),
              ('lastMonth', 'Tháng trước'),
              ('all', 'Tất cả'),
              ('custom', 'Chọn khoảng thời gian...'),
            ])
              ListTile(title: Text(o.$2), onTap: () => Navigator.pop(ctx, o.$1)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return null;

    DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);
    switch (choice) {
      case 'month':
        return (from: DateTime(now.year, now.month, 1), to: endOfDay(DateTime(now.year, now.month + 1, 0)));
      case 'lastMonth':
        return (from: DateTime(now.year, now.month - 1, 1), to: endOfDay(DateTime(now.year, now.month, 0)));
      case 'custom':
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 1, 12, 31),
          initialDateRange: DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
        );
        if (range == null) return null;
        return (from: range.start, to: endOfDay(range.end));
      default:
        return (from: null, to: null);
    }
  }

  Future<void> _exportPdf() async {
    final range = await _pickExportRange();
    if (range == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final isar = getIt<Isar>();
      final txs = await isar.transactionModels.filter().deletedAtIsNull().findAll();
      final inRange = txs.where((t) =>
          (range.from == null || !t.transactionAt.isBefore(range.from!)) &&
          (range.to == null || !t.transactionAt.isAfter(range.to!)));
      if (inRange.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Không có giao dịch nào trong khoảng thời gian này.')));
        return;
      }

      final file = await PdfExportService().export(
        transactions: txs,
        categories: await getIt<CategoryRepository>().getAll(),
        userName: await getIt<SecureStorageService>().getDisplayName(),
        from: range.from,
        to: range.to,
      );

      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Báo cáo giao dịch',
      ));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Xuất dữ liệu thất bại: $e'), backgroundColor: Colors.red),
      );
    }
  }


  Future<void> _toggleReminder(bool value) async {
    final ok = await getIt<TransactionReminderService>().setEnabled(value);
    if (!mounted) return;
    setState(() => _reminderEnabled = value && ok);
    if (value && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần cấp quyền thông báo để bật nhắc nhở.')),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Chọn giờ nhắc ghi giao dịch',
    );
    if (picked == null) return;
    await getIt<TransactionReminderService>().setTime(picked.hour, picked.minute);
    if (mounted) setState(() => _reminderTime = picked);
  }

  Widget _buildPreferencesSection() {
    final chevron = Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('TÙY CHỌN'),
        _buildCardContainer(
          children: [
            _buildSettingRow(
              title: 'Quản lý danh mục',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
                );
              },
              trailing: chevron,
            ),
            _buildDivider(),
            _buildSettingRow(
              title: 'Nhắc ghi giao dịch hằng ngày',
              trailing: Switch.adaptive(
                value: _reminderEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: _toggleReminder,
              ),
            ),
            if (_reminderEnabled) ...[
              _buildDivider(),
              _buildSettingRow(
                title: 'Giờ nhắc',
                onTap: _pickReminderTime,
                trailing: Text(
                  _reminderTime.format(context),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
            _buildDivider(),
            _buildSettingRow(
              title: 'Xuất dữ liệu (PDF)',
              onTap: _exportPdf,
              trailing: chevron,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          context.read<AuthCubit>().logout();
          context.go('/login');
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: AppColors.expense,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Đăng xuất',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
