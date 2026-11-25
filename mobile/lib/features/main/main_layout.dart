import '../../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../analytics/analytics_screen.dart';
import '../budget/budget_screen.dart';
import '../profile/profile_screen.dart';
import '../transaction/add_transaction_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 3; // Default to Profile Screen to showcase user request

  // Danh sách các màn hình tương ứng với từng tab
  final List<Widget> _screens = [
    const HomeScreen(),
    const AnalyticsScreen(),
    const BudgetScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bọc IndexedStack để giữ trạng thái màn hình Home khi chuyển tab (không bị load lại từ đầu)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // Nút Camera nổi ở giữa
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Mở màn hình AddTransaction dạng BottomSheet toàn màn hình
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Cho phép modal chiếm full màn hình
            useSafeArea: true,
            builder: (context) => const AddTransactionScreen(),
          );
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
      ),

      // Neo nút nổi vào giữa cạnh dưới
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Thanh Bottom Bar có khoảng khuyết (notch)
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias, // Cắt viền mượt mà
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, Icons.home, 'Trang chủ', 0),
              _buildNavItem(Icons.show_chart_outlined, Icons.show_chart, 'Thống kê', 1),
              const SizedBox(width: 48), // Chừa khoảng trống cho nút Camera
              _buildNavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Ngân sách', 2),
              _buildNavItem(Icons.person_outline, Icons.person, 'Cá nhân', 3),
            ],
          ),
        ),
      ),
    );
  }

  // Hàm tạo icon và nhãn trên thanh điều hướng
  Widget _buildNavItem(IconData unselectedIcon, IconData selectedIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : Colors.grey.shade400;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}