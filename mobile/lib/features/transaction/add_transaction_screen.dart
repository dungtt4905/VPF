import '../../core/theme/app_colors.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
import 'payment_methods.dart';
import '../../core/currency/amount_input_formatter.dart';
import '../../shared/widgets/transaction_image.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => TransactionFormCubit(getIt(), getIt())),
        BlocProvider(create: (_) => CategoryCubit(getIt<CategoryRepository>())),
      ],
      child: const _AddTransactionView(),
    );
  }
}

class _AddTransactionView extends StatefulWidget {
  const _AddTransactionView();

  @override
  State<_AddTransactionView> createState() => _AddTransactionViewState();
}

class _AddTransactionViewState extends State<_AddTransactionView> {
  String? _selectedCategoryId; // syncId (UUID) của category
  String? _selectedCategoryName;
  String _selectedPayment = 'Cash';
  TransactionType _type = TransactionType.expense;
  DateTime _selectedDate = DateTime.now(); // mặc định hôm nay, người dùng có thể đổi

  // Khai báo thêm biến này
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Ảnh hưởng ngân sách của giao dịch đang lưu, dùng để cảnh báo/thông báo sau khi lưu xong.
  List<BudgetImpact> _pendingImpacts = const [];

  // Thêm controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Chọn ảnh: chụp mới hoặc từ thư viện
  Future<void> _pickImage() async {
    final file = await pickTransactionImage(context, _picker);
    if (file != null) setState(() => _selectedImage = file);
  }

  Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      );

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: _pickerTheme,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: _pickerTheme,
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute,
      );
    });
  }

  Widget _buildDateTimeField() {
    return InkWell(
      onTap: _selectDateTime,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.black54),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy · HH:mm').format(_selectedDate),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
          ],
        ),
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
                    const SizedBox(height: AppSpacing.lg),
                    _buildImageCaptureArea(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTypeToggle(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('SỐ TIỀN'),
                    _buildAmountInput(),
                    BudgetImpactBanner(
                      amountController: _amountController,
                      categoryId: _selectedCategoryId,
                      date: _selectedDate,
                      isExpense: _type == TransactionType.expense,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionLabel('NGÀY GIỜ'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildDateTimeField(),
                    const Divider(height: 32, color: Colors.black12),
                    _buildCategorySection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildPaymentSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildSectionLabel('GHI CHÚ'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNoteInput(),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSaveButton(),
                    const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(16.0),
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
            'Thêm giao dịch',
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

  Widget _buildImageCaptureArea() {
    return GestureDetector(
      onTap: _selectedImage == null ? _pickImage : null,
      child: _selectedImage == null
      // Trạng thái chưa có ảnh: Hiển thị viền nét đứt
          ? DottedBorder(
        options: const RoundedRectDottedBorderOptions(
          color: AppColors.primary,
          strokeWidth: 1.5,
          dashPattern: [8, 4],
          radius: Radius.circular(AppRadius.hero),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.hero),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Chạm để chụp hoặc tải ảnh lên',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ảnh hóa đơn hoặc món đồ',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      )
      // Trạng thái đã có ảnh: xem trước, đổi hoặc xóa
          : Container(
        width: double.infinity,
        height: 250,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.hero),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeFileImage(path: _selectedImage!.path),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  _imageActionButton(Icons.refresh, 'Đổi ảnh', _pickImage),
                  const SizedBox(width: AppSpacing.sm),
                  _imageActionButton(Icons.delete_outline, 'Xóa ảnh', () => setState(() => _selectedImage = null)),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildTypeToggle() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TransactionType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: TransactionType.expense, label: Text('Chi tiêu'), icon: Icon(Icons.arrow_upward, size: 18)),
          ButtonSegment(value: TransactionType.income, label: Text('Thu nhập'), icon: Icon(Icons.arrow_downward, size: 18)),
        ],
        selected: {_type},
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
        ),
        onSelectionChanged: (s) => setState(() {
          _type = s.first;
          _selectedCategoryId = null; // buộc chọn lại danh mục theo loại mới
          _selectedCategoryName = null;
        }),
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
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: Colors.black87),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return BlocBuilder<CategoryCubit, CategoryState>(
      builder: (context, state) {
        final categories = state is CategoryLoaded
            ? selectableCategories(state.categories, _type)
            : <CategoryModel>[];

        // Chọn mặc định danh mục đầu tiên khi chưa chọn (hoặc danh mục đã bị xóa).
        if (categories.isNotEmpty && !categories.any((c) => c.syncId == _selectedCategoryId)) {
          _selectedCategoryId = categories.first.syncId;
          _selectedCategoryName = categories.first.name;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionLabel('DANH MỤC'),
                if (_selectedCategoryName != null)
                  Text(
                    _selectedCategoryName!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (categories.isEmpty)
              Text('Chưa có danh mục', style: TextStyle(color: Colors.grey.shade500))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map(_buildCategoryChip).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(CategoryModel category) {
    final isSelected = _selectedCategoryId == category.syncId;
    final color = categoryColor(category.color);
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategoryId = category.syncId;
        _selectedCategoryName = category.name;
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.hero),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              categoryIcon(category.icon),
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('PHƯƠNG THỨC THANH TOÁN'),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPaymentChip('Cash'),
              _buildPaymentChip('Bank Transfer'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentChip(String label) {
    final isSelected = _selectedPayment == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.hero),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          paymentLabel(label),
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      decoration: InputDecoration(
        hintText: 'Ví dụ: Ăn trưa với đồng nghiệp...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      height: 56,
      child: BlocConsumer<TransactionFormCubit, TransactionFormState>(
        listener: (context, state) {
          if (state is TransactionFormSuccess) {
            // Cảnh báo ngân sách (nếu có) thay cho thông báo thành công thường.
            final warning = BudgetImpactService.warningMessage(_pendingImpacts);
            ScaffoldMessenger.of(context).showSnackBar(
              warning != null
                  ? SnackBar(content: Text('Đã lưu. $warning'), backgroundColor: const Color(0xFFB26B00))
                  : const SnackBar(content: Text('Đã lưu giao dịch thành công!')),
            );
            Navigator.pop(context);
          } else if (state is TransactionFormFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${state.error}')),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is TransactionFormLoading;
          
          return ElevatedButton(
            onPressed: isLoading ? null : () async {
              final amount = parseAmount(_amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ!')),
                );
                return;
              }
              if (_selectedCategoryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn danh mục!')),
                );
                return;
              }

              // Khoản chi làm vượt ngân sách -> hỏi xác nhận trước khi lưu.
              final cubit = context.read<TransactionFormCubit>();
              var impacts = const <BudgetImpact>[];
              if (_type == TransactionType.expense) {
                impacts = await getIt<BudgetImpactService>().evaluate(
                  categoryId: _selectedCategoryId!,
                  amount: amount,
                  txDate: _selectedDate,
                );
                if (!context.mounted) return;
                if (!await confirmBudgetExceed(context, impacts)) return;
              }
              _pendingImpacts = impacts;

              cubit.saveTransaction(
                amount: amount,
                categoryId: _selectedCategoryId!,
                categoryName: _selectedCategoryName,
                paymentMethod: _selectedPayment,
                note: _noteController.text,
                type: _type,
                transactionAt: _selectedDate,
                rawImageFile: _selectedImage,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              elevation: 0,
            ),
            child: isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Lưu giao dịch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
          );
        },
      ),
    );
  }
}