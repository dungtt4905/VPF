import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/enums.dart';
import '../../models/transaction_model.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/transaction_image.dart';
import '../category/category_style.dart';
import 'edit_transaction_screen.dart';

bool txHasPhoto(TransactionModel t) =>
    t.localThumbnailPath != null || t.localImagePath != null || t.cloudImageUrl != null;

/// Tag Hero dùng chung giữa ảnh nhỏ (nguồn) và màn xem ảnh. [prefix] giúp tránh trùng tag
/// khi cùng một giao dịch xuất hiện ở nhiều khối trên cùng màn hình.
String txPhotoHeroTag(String prefix, TransactionModel t) => '$prefix-${t.id}';

/// Mở màn xem ảnh toàn màn hình, vuốt ngang để chuyển giữa các giao dịch có ảnh.
Future<void> openPhotoViewer(
  BuildContext context, {
  required List<TransactionModel> items,
  required int initialIndex,
  required Map<String, CategoryModel> categories,
  required String heroPrefix,
}) {
  if (items.isEmpty) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => PhotoViewerScreen(
        items: items,
        initialIndex: initialIndex.clamp(0, items.length - 1),
        categories: categories,
        heroPrefix: heroPrefix,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class PhotoViewerScreen extends StatefulWidget {
  final List<TransactionModel> items;
  final int initialIndex;
  final Map<String, CategoryModel> categories;
  final String heroPrefix;

  const PhotoViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.categories,
    required this.heroPrefix,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;
  bool _chromeVisible = true;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CategoryModel? _categoryOf(String id) =>
      widget.categories[id] ?? widget.categories[CategoryRepository.legacyNameToId[id]];

  Future<void> _edit(TransactionModel tx) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditTransactionScreen(
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
    // Giao dịch có thể đã đổi/xóa: đóng viewer để danh sách phía sau hiện dữ liệu mới.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return _ZoomablePhoto(
                tx: item,
                heroTag: txPhotoHeroTag(widget.heroPrefix, item),
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                onZoomChanged: (z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
                onDismiss: () => Navigator.of(context).pop(),
              );
            },
          ),
          AnimatedOpacity(
            opacity: _chromeVisible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildTopBar(tx),
                  _buildBottomInfo(tx),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(TransactionModel tx) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _roundButton(Icons.close, 'Đóng', () => Navigator.of(context).pop()),
                const Spacer(),
                if (widget.items.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text('${_index + 1}/${widget.items.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                const Spacer(),
                _roundButton(Icons.edit_outlined, 'Sửa giao dịch', () => _edit(tx)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(TransactionModel tx) {
    final cat = _categoryOf(tx.categoryId);
    final isIncome = tx.type == TransactionType.income;
    final dateStr = DateFormat('EEEE, d MMMM yyyy · HH:mm', 'vi').format(tx.transactionAt);
    final note = (tx.note ?? '').trim();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: categoryColor(cat?.color), shape: BoxShape.circle),
                      child: Icon(categoryIcon(cat?.icon), size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        cat?.name ?? 'Chưa phân loại',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    tx.amount,
                    prefix: isIncome ? '+' : '',
                    style: AppText.moneyHero.copyWith(
                      fontSize: 32,
                      color: isIncome ? const Color(0xFF7FE3C4) : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tx.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (note.isNotEmpty && note != tx.title) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Một trang ảnh: chụm để phóng to, chạm đúp để zoom, vuốt xuống để đóng (khi chưa zoom).
class _ZoomablePhoto extends StatefulWidget {
  final TransactionModel tx;
  final String heroTag;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onDismiss;

  const _ZoomablePhoto({
    required this.tx,
    required this.heroTag,
    required this.onTap,
    required this.onZoomChanged,
    required this.onDismiss,
  });

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final TransformationController _tc = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _syncZoom() {
    final z = _tc.value.getMaxScaleOnAxis() > 1.02;
    if (z != _zoomed) {
      _zoomed = z;
      widget.onZoomChanged(z);
    }
  }

  void _toggleZoom(Size size) {
    if (_zoomed) {
      _tc.value = Matrix4.identity();
    } else {
      const s = 2.5;
      _tc.value = Matrix4.identity()
        ..translateByDouble(-(s - 1) * size.width / 2, -(s - 1) * size.height / 2, 0, 1)
        ..scaleByDouble(s, s, 1, 1);
    }
    _syncZoom();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    Widget image;
    if (tx.localImagePath != null || tx.localThumbnailPath != null) {
      image = SafeFileImage(path: tx.localImagePath, fallbackPath: tx.localThumbnailPath, fit: BoxFit.contain);
    } else if (tx.cloudImageUrl != null) {
      image = Image.network(
        tx.cloudImageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SafeFileImage(path: null),
      );
    } else {
      image = const SafeFileImage(path: null);
    }

    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return Dismissible(
        key: ValueKey('dismiss-${tx.id}'),
        direction: _zoomed ? DismissDirection.none : DismissDirection.vertical,
        resizeDuration: null,
        onDismissed: (_) => widget.onDismiss(),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: () => _toggleZoom(size),
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 1,
            maxScale: 5,
            onInteractionUpdate: (_) => _syncZoom(),
            onInteractionEnd: (_) => _syncZoom(),
            child: SizedBox.expand(
              child: Hero(tag: widget.heroTag, child: image),
            ),
          ),
        ),
      );
    });
  }
}
