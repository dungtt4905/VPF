import '../../shared/widgets/summary_compact_bar.dart';
import 'photo_viewer_screen.dart';
import '../../shared/widgets/summary_hero_card.dart';
import '../../shared/widgets/photo_caption.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/transaction_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/currency/currency_format.dart';
import '../home/cubit/home_cubit.dart';
import '../../models/transaction_model.dart';
import '../../models/enums.dart';
import '../../core/di/injection.dart';
import '../../core/repositories/category_repository.dart';
import '../../models/category_model.dart';
import '../category/category_style.dart';
import '../category/cubit/category_cubit.dart';
import 'edit_transaction_screen.dart';
import 'payment_methods.dart';

class DailyTransactionsScreen extends StatefulWidget {
  final DateTime selectedDate;

  const DailyTransactionsScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DailyTransactionsScreen> createState() => _DailyTransactionsScreenState();
}

class _DailyTransactionsScreenState extends State<DailyTransactionsScreen> {
  late DateTime _currentDate;

  // Khi thẻ tổng cuộn khuất (quá ngưỡng này) thì hiện thanh tổng thu gọn ghim ở đầu danh sách.
  static const _collapseOffset = 150.0;
  final ScrollController _scroll = ScrollController();
  bool _showCompact = false;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > _collapseOffset;
      if (show != _showCompact) setState(() => _showCompact = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _formatMoney(double amount) => CurrencyFormat.vnd.format(amount);

  // categoryId (UUID hoặc tên cũ) -> CategoryModel, cập nhật mỗi lần build từ CategoryCubit.
  Map<String, CategoryModel> _cats = {};

  CategoryModel? _categoryOf(String id) =>
      _cats[id] ?? _cats[CategoryRepository.legacyNameToId[id]];

  String _categoryName(String id) {
    final c = _categoryOf(id);
    if (c != null) return c.name;
    // Chưa tìm thấy: không hiện UUID thô.
    final looksLikeUuid = id.length >= 32 && id.contains('-');
    return looksLikeUuid ? 'Chưa phân loại' : id;
  }

  IconData _getCategoryIcon(String id) => categoryIcon(_categoryOf(id)?.icon);

  // Giao dịch có ảnh trong ngày đang xem, dùng cho màn xem ảnh toàn màn hình.
  List<TransactionModel> _dayPhotos = [];

  void _openViewer(TransactionModel tx, String heroPrefix) {
    final i = _dayPhotos.indexWhere((t) => t.id == tx.id);
    openPhotoViewer(
      context,
      items: _dayPhotos,
      initialIndex: i < 0 ? 0 : i,
      categories: _cats,
      heroPrefix: heroPrefix,
    );
  }

  Widget _photoCaption(TransactionModel tx) {
    final cat = _categoryOf(tx.categoryId);
    return PhotoCaption(
      icon: categoryIcon(cat?.icon),
      iconColor: categoryColor(cat?.color),
      amountText: _formatMoney(tx.amount),
      isIncome: tx.type == TransactionType.income,
      label: _categoryName(tx.categoryId),
    );
  }

  Color _getCategoryColor(String id) => categoryColor(_categoryOf(id)?.color);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CategoryCubit(getIt<CategoryRepository>()),
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildDateBar(),
            Expanded(
              child: BlocBuilder<HomeCubit, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is! HomeLoaded) return const SizedBox.shrink();

                  final catState = context.watch<CategoryCubit>().state;
                  _cats = catState is CategoryLoaded
                      ? {for (final c in catState.categories) c.syncId: c}
                      : {};

                  // Lọc giao dịch trong ngày
                  final transactions = state.transactions.where((t) => isSameDay(t.transactionAt, _currentDate)).toList();
                  final totalSpent = transactions.where((t) => t.type == TransactionType.expense).fold<double>(0, (sum, item) => sum + item.amount);
                  final totalIncome = transactions.where((t) => t.type == TransactionType.income).fold<double>(0, (sum, item) => sum + item.amount);
                  _dayPhotos = transactions.where(txHasPhoto).toList();
                  final formattedDateStr = DateFormat('EEEE, d MMMM yyyy', 'vi').format(_currentDate);

                  final list = SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDailySummaryCard(formattedDateStr, totalSpent, totalIncome, transactions.length),
                        const SizedBox(height: AppSpacing.xl),
                        _buildVisualHighlightsHeader(transactions),
                        const SizedBox(height: AppSpacing.xl),
                        const Text('Tất cả giao dịch', style: AppText.sectionTitle),
                        const SizedBox(height: AppSpacing.md),
                        if (transactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                                    child: const Icon(Icons.event_available_outlined, color: AppColors.primary, size: 30),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  const Text('Không có giao dịch trong ngày này', style: AppText.caption),
                                ],
                              ),
                            ),
                          ),
                        _buildTimeline(transactions),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );

                  return Stack(
                    children: [
                      list,
                      Positioned(
                        top: 8,
                        left: 20,
                        right: 20,
                        child: IgnorePointer(
                          ignoring: !_showCompact,
                          child: AnimatedSlide(
                            offset: _showCompact ? Offset.zero : const Offset(0, -1.4),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: AnimatedOpacity(
                              opacity: _showCompact ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: SummaryCompactBar(expense: totalSpent, income: totalIncome),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.hero),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
              ),
            ),
          ),
          const Text('Chi tiêu trong ngày', style: AppText.sectionTitle),
        ],
      ),
    );
  }

  Widget _buildDateBar() {
    final dateDisplay = DateFormat('d MMMM yyyy', 'vi').format(_currentDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
            onPressed: () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 1))),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(dateDisplay, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
            onPressed: () => setState(() => _currentDate = _currentDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard(String formattedDate, double totalSpent, double totalIncome, int count) {
    return SummaryHeroCard(
      title: formattedDate,
      badge: '$count giao dịch',
      expense: totalSpent,
      income: totalIncome,
    );
  }

  Widget _buildVisualHighlightsHeader(List<TransactionModel> transactions) {
    final itemsWithPhoto = transactions.where((t) => t.localThumbnailPath != null || t.localImagePath != null || t.cloudImageUrl != null).toList();
    if (itemsWithPhoto.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ảnh trong ngày', style: AppText.sectionTitle),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: itemsWithPhoto.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final tx = itemsWithPhoto[index];
              Widget? imageWidget;
              if (tx.localThumbnailPath != null) {
                imageWidget = SafeFileImage(path: tx.localThumbnailPath, fallbackPath: tx.localImagePath, cacheWidth: 250, fit: BoxFit.cover);
              } else if (tx.localImagePath != null) {
                imageWidget = SafeFileImage(path: tx.localImagePath, cacheWidth: 250, fit: BoxFit.cover);
              } else if (tx.cloudImageUrl != null) {
                imageWidget = Image.network(tx.cloudImageUrl!, errorBuilder: (_, __, ___) => const SafeFileImage(path: null), fit: BoxFit.cover);
              }

              return GestureDetector(
                onTap: () => _openViewer(tx, 'snap'),
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageWidget != null) Hero(tag: txPhotoHeroTag('snap', tx), child: imageWidget),
                      _photoCaption(tx),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---- Dòng thời gian: nhóm theo buổi, mỗi giao dịch có mốc giờ + chấm + đường kẻ dọc ----
  static const _periods = <({String label, IconData icon, int from, int to})>[
    (label: 'Đêm khuya', icon: Icons.bedtime_outlined, from: 0, to: 4),
    (label: 'Buổi sáng', icon: Icons.wb_sunny_outlined, from: 5, to: 11),
    (label: 'Buổi chiều', icon: Icons.wb_twilight, from: 12, to: 17),
    (label: 'Buổi tối', icon: Icons.nights_stay_outlined, from: 18, to: 23),
  ];

  Widget _buildTimeline(List<TransactionModel> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();
    final sorted = [...transactions]..sort((a, b) => a.transactionAt.compareTo(b.transactionAt));

    final children = <Widget>[];
    for (final p in _periods) {
      final items = sorted.where((t) => t.transactionAt.hour >= p.from && t.transactionAt.hour <= p.to).toList();
      if (items.isEmpty) continue;
      final spent = items.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);
      children.add(_buildPeriodHeader(p.label, p.icon, items.length, spent));
      for (var i = 0; i < items.length; i++) {
        children.add(_buildTimelineRow(items[i], isLast: i == items.length - 1));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildPeriodHeader(String label, IconData icon, int count, double spent) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(width: AppSpacing.sm),
          Text('$count giao dịch', style: AppText.caption),
          const Spacer(),
          if (spent > 0)
            Text('-${CurrencyFormat.vnd.compact(spent)}',
                style: AppText.moneySmall.copyWith(color: AppColors.expense)),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(TransactionModel item, {required bool isLast}) {
    final dotColor = item.type == TransactionType.income ? AppColors.income : _getCategoryColor(item.categoryId);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(item.transactionAt),
                  style: AppText.moneySmall.copyWith(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _buildTransactionCard(item)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel item) {
    
    Widget? imageWidget;
    if (item.localThumbnailPath != null) {
      imageWidget = SafeFileImage(path: item.localThumbnailPath, fallbackPath: item.localImagePath, cacheWidth: 150, fit: BoxFit.cover);
    } else if (item.localImagePath != null) {
      imageWidget = SafeFileImage(path: item.localImagePath, cacheWidth: 150, fit: BoxFit.cover);
    } else if (item.cloudImageUrl != null) {
      imageWidget = Image.network(item.cloudImageUrl!, errorBuilder: (_, __, ___) => const SafeFileImage(path: null), fit: BoxFit.cover);
    }

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => EditTransactionScreen(
            id: item.id,
            syncId: item.syncId,
            title: item.title,
            category: item.categoryId,
            amount: item.amount,
            paymentMethod: item.paymentMethod,
            note: item.note,
            imageUrl: item.cloudImageUrl,
            localImagePath: item.localImagePath,
            localThumbnailPath: item.localThumbnailPath,
            date: item.transactionAt,
            type: item.type,
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            if (imageWidget != null)
              GestureDetector(
                onTap: () => _openViewer(item, 'row'),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), color: Colors.grey.shade200),
                  clipBehavior: Clip.hardEdge,
                  child: Hero(tag: txPhotoHeroTag('row', item), child: imageWidget),
                ),
              )
            else
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: _getCategoryColor(item.categoryId).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(_getCategoryIcon(item.categoryId), color: _getCategoryColor(item.categoryId), size: 26),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(AppRadius.xs)),
                          child: Text(_categoryName(item.categoryId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        ),
                      ),
                    ],
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.note!, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                  item.type == TransactionType.expense ? '-${_formatMoney(item.amount)}' : '+${_formatMoney(item.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: item.type == TransactionType.expense ? AppColors.expense : AppColors.primary,
                  ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.xs)),
                  child: Text(paymentLabel(item.paymentMethod),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}
