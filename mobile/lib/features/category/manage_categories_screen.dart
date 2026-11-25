import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/repositories/category_repository.dart';
import '../../models/category_model.dart';
import '../../models/enums.dart';
import 'category_style.dart';
import 'cubit/category_cubit.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CategoryCubit(getIt<CategoryRepository>()),
      child: const _ManageCategoriesView(),
    );
  }
}

class _ManageCategoriesView extends StatefulWidget {
  const _ManageCategoriesView();

  @override
  State<_ManageCategoriesView> createState() => _ManageCategoriesViewState();
}

class _ManageCategoriesViewState extends State<_ManageCategoriesView> {
  TransactionType _selectedTab = TransactionType.expense;

  // Track expanded states (using syncId for uniqueness)
  final Set<String> _expandedCategoryIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildSegmentedTab(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: BlocBuilder<CategoryCubit, CategoryState>(
                builder: (context, state) {
                  if (state is! CategoryLoaded) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = state.categories.where((c) => c.type == _selectedTab).toList();
                  final parentCategories = categories.where((c) => c.parentId == null).toList();

                  if (parentCategories.isEmpty) {
                    return const Center(child: Text('Chưa có danh mục nào.'));
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: parentCategories.map((parent) {
                        final children = categories.where((c) => c.parentId == parent.syncId).toList();
                        return _buildCategoryTile(parent, children, context);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildAddCategoryButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
              ),
            ),
          ),
          const Text(
            'Quản lý danh mục',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Row(
        children: [
          _buildTabButton('Chi tiêu', TransactionType.expense),
          _buildTabButton('Thu nhập', TransactionType.income),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, TransactionType type) {
    final isSelected = _selectedTab == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(CategoryModel category, List<CategoryModel> subcategories, BuildContext context) {
    final isExpanded = _expandedCategoryIds.contains(category.syncId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor(category.color).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(categoryIcon(category.icon), color: categoryColor(category.color), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    category.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showCategoryForm(context, existing: category),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.edit_outlined, color: Colors.grey.shade600, size: 20),
                  ),
                ),
                if (subcategories.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedCategoryIds.remove(category.syncId);
                        } else {
                          _expandedCategoryIds.add(category.syncId);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 22),
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () {
                    // Xoá logic: Ở bản production ta sẽ show dialog xác nhận, hoặc form sửa.
                    context.read<CategoryCubit>().deleteCategory(category.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded && subcategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24.0, top: 6.0),
              child: Column(
                children: subcategories.map((sub) => _buildSubcategoryTile(sub, context)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryTile(CategoryModel subcategory, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(categoryIcon(subcategory.icon), color: categoryColor(subcategory.color), size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              subcategory.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          GestureDetector(
            onTap: () => _showCategoryForm(context, existing: subcategory),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.edit_outlined, color: Colors.grey.shade600, size: 18),
            ),
          ),
          GestureDetector(
            onTap: () {
              context.read<CategoryCubit>().deleteCategory(subcategory.id);
            },
            child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 18),
          ),
        ],
      ),
    );
  }

  void _showCategoryForm(BuildContext context, {CategoryModel? existing}) {
    final cubit = context.read<CategoryCubit>();
    final state = cubit.state;
    final all = state is CategoryLoaded ? state.categories : <CategoryModel>[];
    final type = existing?.type ?? _selectedTab;
    final parents = all
        .where((c) => c.type == type && c.parentId == null && c.syncId != existing?.syncId)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero))),
      builder: (sheetContext) => _CategoryFormSheet(
        existing: existing,
        parents: parents,
        onSubmit: (name, icon, color, parentId) {
          if (existing == null) {
            cubit.addCategory(name, icon, color, type, parentId: parentId);
          } else {
            cubit.updateCategory(existing, name: name, icon: icon, color: color, parentId: parentId);
          }
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  Widget _buildAddCategoryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _showCategoryForm(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
          elevation: 0,
        ),
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text('Thêm danh mục mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final CategoryModel? existing;
  final List<CategoryModel> parents;
  final void Function(String name, String icon, String color, String? parentId) onSubmit;

  const _CategoryFormSheet({required this.existing, required this.parents, required this.onSubmit});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  late final TextEditingController _nameController;
  late String _icon;
  late String _color;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _icon = kCategoryIcons.containsKey(e?.icon) ? e!.icon! : 'category';
    _color = e?.color ?? kCategoryColors.first;
    // Chỉ giữ parentId nếu còn nằm trong danh sách cha hợp lệ.
    _parentId = widget.parents.any((p) => p.syncId == e?.parentId) ? e?.parentId : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên danh mục')));
      return;
    }
    widget.onSubmit(name, _icon, _color, _parentId);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final selectedColor = categoryColor(_color);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Sửa danh mục' : 'Thêm danh mục',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tên danh mục',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Biểu tượng', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategoryIcons.entries.map((e) {
                final selected = e.key == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e.key),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? selectedColor.withValues(alpha: 0.15) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? selectedColor : Colors.transparent, width: 2),
                    ),
                    child: Icon(e.value, size: 22, color: selected ? selectedColor : Colors.grey.shade600),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kCategoryColors.map((hex) {
                final selected = hex.toLowerCase() == _color.toLowerCase();
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: categoryColor(hex), shape: BoxShape.circle),
                    child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              decoration: InputDecoration(
                labelText: 'Danh mục cha (tùy chọn)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Không có')),
                ...widget.parents.map((p) => DropdownMenuItem<String?>(value: p.syncId, child: Text(p.name))),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  elevation: 0,
                ),
                child: Text(isEdit ? 'Lưu thay đổi' : 'Thêm danh mục',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
