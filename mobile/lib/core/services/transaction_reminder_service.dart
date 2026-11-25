import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Nhắc người dùng ghi lại các giao dịch trong ngày vào giờ do họ chọn, lặp lại mỗi ngày.
/// Luôn nhắc đúng giờ mỗi ngày, kể cả khi hôm nay người dùng đã ghi giao dịch.
///
/// Mọi lời gọi plugin đều bọc try/catch: thông báo là tính năng phụ, không được làm app lỗi.
class TransactionReminderService {
  static const _kEnabled = 'reminder_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  static const _reminderId = 1002;
  static const _defaultHour = 21;
  static const _defaultMinute = 0;
  static const _channel = AndroidNotificationDetails(
    'transaction_reminder',
    'Nhắc ghi giao dịch',
    channelDescription: 'Nhắc ghi lại các giao dịch trong ngày',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

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
      // Tạo sẵn channel: nếu không, Android chỉ tạo nó khi thông báo đầu tiên được hiển thị,
      // nên mục này không xuất hiện trong Cài đặt > Thông báo của app trước đó.
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'transaction_reminder',
            'Nhắc ghi giao dịch',
            description: 'Nhắc ghi lại các giao dịch trong ngày',
            importance: Importance.defaultImportance,
          ));
      _ready = true;
    } catch (e) {
      debugPrint('Không khởi tạo được nhắc giao dịch: $e');
    }
  }

  // ---- Cài đặt ----

  Future<bool> isEnabled() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<({int hour, int minute})> getTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (hour: prefs.getInt(_kHour) ?? _defaultHour, minute: prefs.getInt(_kMinute) ?? _defaultMinute);
    } catch (_) {
      return (hour: _defaultHour, minute: _defaultMinute);
    }
  }

  /// Bật/tắt nhắc. Trả về false nếu người dùng từ chối quyền thông báo (khi đó giữ trạng thái tắt).
  Future<bool> setEnabled(bool value) async {
    if (value && !await requestPermission()) return false;
    try {
      await (await SharedPreferences.getInstance()).setBool(_kEnabled, value);
    } catch (_) {}
    await reschedule();
    return true;
  }

  Future<void> setTime(int hour, int minute) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kHour, hour);
      await prefs.setInt(_kMinute, minute);
    } catch (_) {}
    await reschedule();
  }

  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('Xin quyền thông báo lỗi: $e');
    }
    return false;
  }

  // ---- Lịch nhắc ----

  /// Thời điểm nhắc đầu tiên: giờ đã chọn hôm nay nếu chưa qua, ngược lại là ngày mai.
  /// Sau đó thông báo tự lặp lại mỗi ngày.
  static DateTime firstFire(DateTime now, int hour, int minute) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// Đặt lại lịch nhắc theo cài đặt hiện tại (gọi khi mở app và khi người dùng đổi cài đặt).
  Future<void> reschedule() async {
    await init();
    if (!_ready) return;
    await _safe(() => _plugin.cancel(id: _reminderId));
    if (!await isEnabled()) return;

    final time = await getTime();
    final now = DateTime.now();
    final fire = firstFire(now, time.hour, time.minute);

    // Mốc tuyệt đối (UTC) + lặp theo giờ trong ngày => nhắc mỗi ngày đúng giờ đã chọn.
    final when = tz.TZDateTime.from(fire, tz.UTC);

    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: _reminderId,
          title: 'Đừng quên ghi giao dịch hôm nay',
          body: 'Bạn đã ghi lại các khoản thu chi trong ngày chưa? Thêm ngay để theo dõi chính xác nhé.',
          scheduledDate: when,
          notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
        );

    // Chế độ "không chính xác" của Android có thể trễ tới ~1 giờ, nên ưu tiên báo thức chính xác;
    // nếu hệ thống không cho phép thì dùng chế độ không chính xác thay vì mất thông báo.
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      debugPrint('Không đặt được báo thức chính xác, dùng chế độ gần đúng: $e');
      await _safe(() => schedule(AndroidScheduleMode.inexactAllowWhileIdle));
    }
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Nhắc giao dịch lỗi: $e');
    }
  }
}
