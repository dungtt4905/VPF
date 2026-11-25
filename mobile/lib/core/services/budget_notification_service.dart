import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Đã gỡ thông báo đẩy khi chi vượt ngân sách; chỉ còn dọn lịch nhắc hằng ngày cũ.
class BudgetNotificationService {
  static const _dailyId = 1001;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Không khởi tạo được thông báo: $e');
    }
  }

  /// Hủy thông báo nhắc chi tiêu hằng ngày đã được lên lịch ở các phiên bản trước (tính năng đã gỡ).
  Future<void> cancelLegacyDailyReminder() async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _dailyId);
    } catch (e) {
      debugPrint('Thông báo lỗi: $e');
    }
  }
}
