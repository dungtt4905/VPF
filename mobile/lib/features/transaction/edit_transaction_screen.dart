import '../../core/theme/app_colors.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'payment_methods.dart';
import '../../core/currency/amount_input_formatter.dart';
import '../../shared/widgets/transaction_image.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/budget/budget_impact_service.dart';
import '../../core/di/injection.dart';
import '../budget/budget_save_guard.dart';
import '../budget/widgets/budget_impact_banner.dart';
import '../../models/enums.dart';
import '../../core/repositories/category_repository.dart';
import '../../models/category_model.dart';
import '../category/category_style.dart';
import '../category/cubit/category_cubit.dart';
import 'cubit/transaction_form_cubit.dart';

class EditTransactionScreen extends StatelessWidget {
  final int? id;
  final String? syncId;
  final String title;
  final String category;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String? imageUrl;
  final String? localImagePath;
  final String? localThumbnailPath;
  final DateTime? date;
  final TransactionType type;

  const EditTransactionScreen({
    super.key,
    this.id,
    this.syncId,
    this.title = 'Giao dịch',
    this.category = '',
    this.amount = 0,
    this.paymentMethod = 'Cash',
    this.note,
    this.imageUrl,
    this.localImagePath,
    this.localThumbnailPath,
    this.date,
    this.type = TransactionType.expense,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TransactionFormCubit(getIt(), getIt())),
        BlocProvider(create: (_) => CategoryCubit(getIt<CategoryRepository>())),
      ],
      child: _EditTransactionView(
        id: id,
        syncId: syncId,
        title: title,
        category: category,
        amount: amount,
        paymentMethod: paymentMethod,
        note: note,
        imageUrl: imageUrl,
        localImagePath: localImagePath,
        localThumbnailPath: localThumbnailPath,
        date: date,
        type: type,
      ),
    );
  }
}

class _EditTransactionView extends StatefulWidget {
  final int? id;
  final String? syncId;
  final String title;
  final String category;
  final double amount;
  final String paymentMethod;
  final String? note;
  final String? imageUrl;
  final String? localImagePath;
  final String? localThumbnailPath;
  final DateTime? date;
  final TransactionType type;

  const _EditTransactionView({
    this.id,
    this.syncId,
    required this.title,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    this.note,
    this.imageUrl,
    this.localImagePath,
    this.localThumbnailPath,
    this.date,
    this.type = TransactionType.expense,
  });

  @override
  State<_EditTransactionView> createState() => _EditTransactionViewState();
}

class _EditTransactionViewState extends State<_EditTransactionView> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  File? _selectedImageFile;
  bool _removeImage = false;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  // Ảnh hưởng ngân sách của giao dịch đang lưu, dùng để cảnh báo/thông báo sau khi lưu xong.
  List<BudgetImpact> _pendingImpacts = const [];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: AmountInputFormatter.format(widget.amount));
    _noteController = TextEditingController(text: widget.note ?? '');
    _selectedCategory = widget.category;
    // Giao dịch cũ dùng phương thức đã bỏ (vd. Ví điện tử) -> mặc định về Tiền mặt khi sửa.
    _selectedPaymentMethod =
        kPaymentMethodLabels.containsKey(widget.paymentMethod) ? widget.paymentMethod : 'Cash';
    _selectedDate = widget.date ?? DateTime(2026, 9, 5, 12, 30);
    _imageUrl = widget.imageUrl;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await pickTransactionImage(context, _picker);
    if (file != null) {
      setState(() {
        _selectedImageFile = file;
        _removeImage = false;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageFile = null;
      _removeImage = true;
      _imageUrl = null;
    });
  }


  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _showCategoryPicker() {
    final state = context.read<CategoryCubit>().state;
    final categories = state is CategoryLoaded
        ? selectableCategories(state.categories, widget.type)
        : <CategoryModel>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn danh mục',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: categories.map((cat) {
                        return ListTile(
                          leading: Icon(categoryIcon(cat.icon), color: categoryColor(cat.color)),
                          title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: _selectedCategory == cat.syncId
                              ? const Icon(Icons.check_circle, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setState(() => _selectedCategory = cat.syncId);
                            Navigator.pop(sheetContext);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete() {
    // Lấy cubit từ context của màn hình: dialog nằm ở route khác nên không thấy Provider.
    final formCubit = context.read<TransactionFormCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Xóa giao dịch?'),
        content: const Text('Bạn có chắc muốn xóa giao dịch này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
            ElevatedButton(
              onPressed: () {
                if (widget.id != null) {
                  formCubit.deleteTransaction(widget.id!);
                }
                Navigator.pop(dialogContext); // Close dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
              ),
              child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageArea(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSectionLabel('SỐ TIỀN'),
                    _buildAmountInput(),
                    BudgetImpactBanner(
                      amountController: _amountController,
                      categoryId: _selectedCategory,
                      date: _selectedDate,
                      isExpense: widget.type == TransactionType.expense,
                      excludeTxId: widget.id,
                    ),
                    const Divider(height: 32, color: Colors.black12),
                    _buildSectionLabel('DANH MỤC'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildCategoryField(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('NGÀY GIỜ'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildDateTimeField(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('PHƯƠNG THỨC THANH TOÁN'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildPaymentMethodSegment(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('GHI CHÚ'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNoteInput(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSaveButton(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildDeleteButton(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.close, size: 20, color: Colors.black87),
              ),
            ),
          ),
          const Text(
            'Sửa giao dịch',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    final localPath = _removeImage ? null : usableImagePath(widget.localImagePath, widget.localThumbnailPath);
    final hasImage = _selectedImageFile != null || localPath != null || _imageUrl != null;

    Widget? image;
    if (_selectedImageFile != null) {
      image = SafeFileImage(path: _selectedImageFile!.path);
    } else if (localPath != null) {
      image = SafeFileImage(path: localPath);
    } else if (_imageUrl != null) {
      image = Image.network(_imageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SafeFileImage(path: null));
    }

    return Container(
      width: double.infinity,
      height: 230,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            image
          else
            GestureDetector(
              onTap: _pickImage,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 36),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Thêm ảnh minh chứng',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (hasImage)
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  _imageActionButton(Icons.refresh, 'Đổi ảnh', _pickImage),
                  const SizedBox(width: AppSpacing.sm),
                  _imageActionButton(Icons.delete_outline, 'Xóa ảnh', _clearImage),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAmountInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'đ',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: const [AmountInputFormatter()],
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return BlocBuilder<CategoryCubit, CategoryState>(
      builder: (context, state) {
        final all = state is CategoryLoaded ? state.categories : <CategoryModel>[];
        CategoryModel? selected;
        for (final c in all) {
          if (c.syncId == _selectedCategory) selected = c;
        }
        return InkWell(
          onTap: _showCategoryPicker,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  categoryIcon(selected?.icon),
                  size: 20,
                  color: selected != null ? categoryColor(selected.color) : Colors.black54,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    selected?.name ?? 'Chọn danh mục',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateTimeField() {
    final formattedDate = DateFormat('dd/MM/yyyy · HH:mm').format(_selectedDate);

    return InkWell(
      onTap: _selectDateTime,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSegment() {
    final methods = kPaymentMethodLabels.keys.toList();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: methods.map((method) {
          final isSelected = _selectedPaymentMethod == method;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPaymentMethod = method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  paymentLabel(method),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.edit_outlined, size: 20, color: Colors.black54),
        hintText: 'Thêm ghi chú...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: BlocConsumer<TransactionFormCubit, TransactionFormState>(
        listener: (context, state) {
          if (state is TransactionFormSuccess) {
            final warning = BudgetImpactService.warningMessage(_pendingImpacts);
            ScaffoldMessenger.of(context).showSnackBar(
              warning != null
                  ? SnackBar(content: Text('Đã lưu. $warning'), backgroundColor: const Color(0xFFB26B00))
                  : const SnackBar(content: Text('Đã lưu giao dịch thành công'), backgroundColor: AppColors.primary),
            );
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final isLoading = state is TransactionFormLoading;
          return ElevatedButton(
            onPressed: isLoading ? null : () async {
              final catState = context.read<CategoryCubit>().state;
              final cubit = context.read<TransactionFormCubit>();
              String? categoryName;
              if (catState is CategoryLoaded) {
                for (final c in catState.categories) {
                  if (c.syncId == _selectedCategory) categoryName = c.name;
                }
              }
              final amount = parseAmount(_amountController.text) ?? 0;

              // Khoản chi làm vượt ngân sách -> hỏi xác nhận trước khi lưu.
              var impacts = const <BudgetImpact>[];
              if (widget.type == TransactionType.expense) {
                impacts = await getIt<BudgetImpactService>().evaluate(
                  categoryId: _selectedCategory,
                  amount: amount,
                  txDate: _selectedDate,
                  excludeTxId: widget.id,
                );
                if (!context.mounted) return;
                if (!await confirmBudgetExceed(context, impacts)) return;
              }
              _pendingImpacts = impacts;

              cubit.saveTransaction(
                id: widget.id,
                categoryName: categoryName,
                syncId: widget.syncId,
                amount: amount,
                categoryId: _selectedCategory,
                paymentMethod: _selectedPaymentMethod,
                note: _noteController.text,
                type: widget.type,
                transactionAt: _selectedDate,
                rawImageFile: _selectedImageFile,
                existingImagePath: widget.localImagePath,
                existingThumbnailPath: widget.localThumbnailPath,
                removeImage: _removeImage,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              elevation: 0,
            ),
            child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          );
        }
      ),
    );
  }

  Widget _buildDeleteButton() {
    if (widget.id == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _confirmDelete,
        child: const Text('Xóa giao dịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.expense)),
      ),
    );
  }
}
