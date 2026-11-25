import '../transaction/photo_viewer_screen.dart';
import '../../shared/widgets/summary_hero_card.dart';
import '../../shared/widgets/photo_caption.dart';
import '../../core/repositories/category_repository.dart';
import '../../models/category_model.dart';
import '../category/category_style.dart';
import '../category/cubit/category_cubit.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/transaction_image.dart';
import '../../shared/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/currency/currency_format.dart';

import 'package:table_calendar/table_calendar.dart';
import '../../core/di/injection.dart';
import '../../models/transaction_model.dart';
import '../../models/enums.dart';
import '../transaction/daily_transactions_screen.dart';
import '../transaction/list/transaction_list_screen.dart';
import '../transaction/edit_transaction_screen.dart';
import 'cubit/home_cubit.dart';

import '../../core/services/secure_storage_service.dart';
import '../../core/repositories/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeCubit(getIt())),
        BlocProvider(create: (_) => CategoryCubit(getIt<CategoryRepository>())),
      ],
      child: const _HomeScreenView(),
    );
  }
}

class _HomeScreenView extends StatefulWidget {
  const _HomeScreenView();

  @override
  State<_HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<_HomeScreenView> {
  bool isCalendarView = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final storage = getIt<SecureStorageService>();
    await getIt<AuthRepository>().refreshProfile();
    final name = await storage.getDisplayName();
    if (!mounted) return;
    setState(() {
      _name = name.split(' ').last;
    });
  }

  String _formatMoney(double amount) => CurrencyFormat.vnd.format(amount);

  // categoryId (UUID hoặc tên cũ) -> CategoryModel, cập nhật mỗi lần build từ CategoryCubit.
  Map<String, CategoryModel> _cats = {};

  CategoryModel? _categoryOf(String id) => _cats[id] ?? _cats[CategoryRepository.legacyNameToId[id]];

  // Các giao dịch có ảnh (mới nhất trước), dùng làm danh sách lướt trong màn xem ảnh.
  List<TransactionModel> _photoTxs = [];

  void _openViewer(List<TransactionModel> items, TransactionModel tx, String heroPrefix) {
    final i = items.indexWhere((t) => t.id == tx.id);
    openPhotoViewer(
      context,
      items: items,
      initialIndex: i < 0 ? 0 : i,
      categories: _cats,
      heroPrefix: heroPrefix,
    );
  }

  void _openEdit(TransactionModel tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => EditTransactionScreen(
        id: tx.id,
        syncId: tx.syncId,
        title: tx.title,
        category: tx.categoryId,
        amount: tx.amount,
        paymentMethod: tx.paymentMethod,
        note: tx.note,
        imageUrl: tx.cloudImageUrl,
        localImagePath: tx.localImagePath,
        localThumbnailPath: tx.localThumbnailPath,
        date: tx.transactionAt,
        type: tx.type,
      ),
    );
  }

  Widget _photoCaption(TransactionModel tx, {bool compact = false}) {
    final cat = _categoryOf(tx.categoryId);
    return PhotoCaption(
      icon: categoryIcon(cat?.icon),
      iconColor: categoryColor(cat?.color),
      amountText: _formatMoney(tx.amount),
      isIncome: tx.type == TransactionType.income,
      label: cat?.name,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is! HomeLoaded) return const SizedBox.shrink();

            final catState = context.watch<CategoryCubit>().state;
            _cats = catState is CategoryLoaded ? {for (final c in catState.categories) c.syncId: c} : {};

            final transactions = state.transactions;
            
            // Tính tổng chi tiêu tháng hiện tại
            final currentMonthTx = transactions.where((t) => t.transactionAt.year == _focusedDay.year && t.transactionAt.month == _focusedDay.month).toList();
            final totalExpense = currentMonthTx.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);
            final totalIncome = currentMonthTx.where((t) => t.type == TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
            final avgPerDay = currentMonthTx.isNotEmpty ? (totalExpense / DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day) : 0.0;

            // Xây dựng Map ảnh cho Lịch
            final photoTxMap = <DateTime, List<TransactionModel>>{};
            // Gom giao dịch có ảnh theo ngày, mới nhất trước.
            final sortedTx = [...transactions]..sort((a, b) => b.transactionAt.compareTo(a.transactionAt));
            for (final tx in sortedTx) {
              if (tx.localThumbnailPath != null || tx.localImagePath != null || tx.cloudImageUrl != null) {
                final key = DateTime.utc(tx.transactionAt.year, tx.transactionAt.month, tx.transactionAt.day);
                photoTxMap.putIfAbsent(key, () => []).add(tx);
              }
            }

            final txWithPhotos = transactions.where((t) => t.localThumbnailPath != null || t.localImagePath != null || t.cloudImageUrl != null).toList();
            _photoTxs = txWithPhotos;
            final recentTx = transactions.take(5).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildToggle(),
                  const SizedBox(height: AppSpacing.xl),

                  if (isCalendarView) ...[
                    _buildCalendar(photoTxMap),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSummaryCard(totalExpense, totalIncome, avgPerDay),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text('Giao dịch gần đây', style: AppText.sectionTitle),
                    const SizedBox(height: AppSpacing.lg),
                    _buildRecentExpenses(recentTx),
                  ] else ...[
                    _buildSummaryCard(totalExpense, totalIncome, avgPerDay),
                    const SizedBox(height: AppSpacing.xl),
                    _buildPhotoGrid(txWithPhotos),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final monthStr = 'Tháng ${_focusedDay.month}, ${_focusedDay.year}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào, $_name 👋', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: AppSpacing.xs),
            Text(monthStr, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
          ],
        ),
        const UserAvatar(radius: 24),
      ],
    );
  }


  Widget _buildToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(AppRadius.hero)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isCalendarView = false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isCalendarView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.hero),
                  boxShadow: !isCalendarView ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Text('Lưới ảnh', style: TextStyle(fontWeight: FontWeight.bold, color: !isCalendarView ? AppColors.primary : Colors.grey)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isCalendarView = true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCalendarView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.hero),
                  boxShadow: isCalendarView ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Text('Lịch', style: TextStyle(fontWeight: FontWeight.bold, color: isCalendarView ? AppColors.primary : Colors.grey)),
              ),
            ),
          ),
          // "Danh sách" không phải chế độ xem trong trang này: bấm để mở màn danh sách giao dịch.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionListScreen())),
              child: const Center(
                child: Text('Danh sách', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<TransactionModel>> photoTxMap) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      rowHeight: 84,
      locale: 'vi',
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      headerVisible: false,
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
        weekendStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
      ),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        
        // Pass HomeCubit value so DailyTransactionsScreen can continue listening
        final homeCubit = context.read<HomeCubit>();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlocProvider.value(
              value: homeCubit,
              child: DailyTransactionsScreen(selectedDate: selectedDay),
            ),
          ),
        );
      },
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day, photoTxMap),
        todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, photoTxMap, isToday: true),
        selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, photoTxMap, isSelected: true),
        outsideBuilder: (context, day, focusedDay) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCalendarCell(DateTime day, Map<DateTime, List<TransactionModel>> photoTxMap, {bool isToday = false, bool isSelected = false}) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final photos = photoTxMap[normalizedDay] ?? const <TransactionModel>[];
    final shown = photos.take(2).toList(); // đã sắp mới nhất trước
    final extra = photos.length - shown.length;
    const green = AppColors.primary;

    Widget thumb(TransactionModel tx) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
        ),
        clipBehavior: Clip.antiAlias,
        child: tx.localThumbnailPath != null || tx.localImagePath != null
            ? SafeFileImage(
                path: tx.localThumbnailPath,
                fallbackPath: tx.localImagePath,
                cacheWidth: 120,
                fit: BoxFit.cover,
              )
            : Image.network(tx.cloudImageUrl!,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SafeFileImage(path: null)),
      );
    }

    Widget cluster;
    if (shown.isEmpty) {
      cluster = const SizedBox.shrink();
    } else {
      cluster = LayoutBuilder(builder: (context, c) {
        final size = (c.maxHeight < c.maxWidth ? c.maxHeight : c.maxWidth) * (shown.length == 1 ? 0.92 : 0.72);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Ảnh mới nhất nằm trên cùng, ảnh thứ hai lệch nhẹ phía sau.
            if (shown.length > 1)
              Positioned(left: 1, bottom: 0, width: size, height: size, child: thumb(shown[1])),
            Positioned(
              right: shown.length > 1 ? 1 : null,
              left: shown.length > 1 ? null : (c.maxWidth - size) / 2,
              top: shown.length > 1 ? 0 : (c.maxHeight - size) / 2,
              width: size,
              height: size,
              child: thumb(shown[0]),
            ),
            if (extra > 0)
              Positioned(
                top: -4,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(AppRadius.xs)),
                  child: Text('+$extra', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      });
    }

    final highlighted = isToday || isSelected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        children: [
          Expanded(child: SizedBox(width: double.infinity, child: cluster)),
          const SizedBox(height: 2),
          Container(
            width: 22,
            height: 18,
            alignment: Alignment.center,
            decoration: highlighted
                ? BoxDecoration(color: isSelected ? green : green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xs))
                : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : (isToday ? green : Colors.black87),
                fontWeight: highlighted || shown.isNotEmpty ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalExpense, double totalIncome, double avgPerDay) {
    return SummaryHeroCard(
      title: 'Tổng chi tháng ${_focusedDay.month}',
      badge: 'TB ${CurrencyFormat.vnd.compact(avgPerDay)}/ngày',
      expense: totalExpense,
      income: totalIncome,
    );
  }

  Widget _buildPhotoGrid(List<TransactionModel> txWithPhotos) {
    if (txWithPhotos.isEmpty) {
      return const Center(child: Text("Chưa có ảnh nào.", style: TextStyle(color: Colors.grey)));
    }
    final leftColumnData = <TransactionModel>[];
    final rightColumnData = <TransactionModel>[];

    for (int i = 0; i < txWithPhotos.length; i++) {
      if (i % 2 == 0) leftColumnData.add(txWithPhotos[i]);
      else rightColumnData.add(txWithPhotos[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: leftColumnData.map((t) => _buildGridItem(t)).toList())),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: Column(children: rightColumnData.map((t) => _buildGridItem(t, offsetHeight: true)).toList())),
      ],
    );
  }

  Widget _buildGridItem(TransactionModel tx, {bool offsetHeight = false}) {
    final height = offsetHeight ? 240.0 : 180.0;
    
    Widget? imageWidget;
    if (tx.localThumbnailPath != null) {
      imageWidget = SafeFileImage(path: tx.localThumbnailPath, fallbackPath: tx.localImagePath, cacheWidth: 300, fit: BoxFit.cover);
    } else if (tx.localImagePath != null) {
      imageWidget = SafeFileImage(path: tx.localImagePath, cacheWidth: 300, fit: BoxFit.cover);
    } else if (tx.cloudImageUrl != null) {
      imageWidget = Image.network(tx.cloudImageUrl!, errorBuilder: (_, __, ___) => const SafeFileImage(path: null), fit: BoxFit.cover);
    }

    return GestureDetector(
      onTap: () => _openViewer(_photoTxs, tx, 'grid'),
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageWidget != null) Hero(tag: txPhotoHeroTag('grid', tx), child: imageWidget),
            _photoCaption(tx),
          ],
        ),
      ),
    );
  }

  /// Nền cho giao dịch không có ảnh: gradient theo màu danh mục kèm biểu tượng danh mục mờ,
  /// thay cho nền xám trống.
  Widget _noPhotoBackground(TransactionModel tx) {
    final cat = _categoryOf(tx.categoryId);
    final color = categoryColor(cat?.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.95)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Icon(categoryIcon(cat?.icon), size: 56, color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _buildRecentExpenses(List<TransactionModel> recentTx) {
    if (recentTx.isEmpty) return const Center(child: Text("Chưa có giao dịch nào.", style: TextStyle(color: Colors.grey)));

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recentTx.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (context, index) {
          final tx = recentTx[index];
          
          Widget? imageWidget;
          if (tx.localThumbnailPath != null) {
            imageWidget = SafeFileImage(path: tx.localThumbnailPath, fallbackPath: tx.localImagePath, cacheWidth: 300, fit: BoxFit.cover);
          } else if (tx.localImagePath != null) {
            imageWidget = SafeFileImage(path: tx.localImagePath, cacheWidth: 300, fit: BoxFit.cover);
          } else if (tx.cloudImageUrl != null) {
            imageWidget = Image.network(tx.cloudImageUrl!, errorBuilder: (_, __, ___) => const SafeFileImage(path: null), fit: BoxFit.cover);
          }

          return GestureDetector(
            onTap: () => txHasPhoto(tx)
                ? _openViewer(recentTx.where(txHasPhoto).toList(), tx, 'recent')
                : _openEdit(tx),
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageWidget != null)
                    Hero(tag: txPhotoHeroTag('recent', tx), child: imageWidget)
                  else
                    _noPhotoBackground(tx),
                  _photoCaption(tx, compact: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
