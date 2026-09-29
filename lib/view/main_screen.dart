// Directory: lib/view/
// File: main_screen.dart

import 'package:flutter/material.dart';

import '../control/app_preferences.dart';
import '../control/account_controller.dart';
import '../l10n/app_text.dart';
import '../service/auth_service.dart';
import 'category_summary_view.dart';
import 'dashboard_view.dart';
import 'review_view.dart';
import 'roi_analytics_view.dart';
import 'settings_view.dart';
import 'wallet_budget_view.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  final AppPreferences preferences;

  const MainScreen({
    super.key,
    required this.userId,
    required this.preferences,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AccountController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AccountController(userId: widget.userId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pages = [
          DashboardView(
            controller: _controller,
            onOpenReviewPending: () => _showReviewSheet(context),
            preferences: widget.preferences,
          ),
          CategorySummaryView(controller: _controller, type: 'all'),
          WalletBudgetView(controller: _controller),
          SettingsView(
            controller: _controller,
            preferences: widget.preferences,
          ),
        ];

        final titles = [
          'Dashboard บัญชี AI',
          'วิเคราะห์',
          'กระเป๋าเงิน & งบประมาณ',
          'ตั้งค่า',
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(AppText.tr(context, titles[_currentIndex])),
            actions: [
              if (_currentIndex == 1)
                IconButton(
                  tooltip: AppText.tr(context, 'ดูกราฟและแนวโน้ม'),
                  icon: const Icon(Icons.bar_chart_outlined),
                  onPressed: () => _showAnalyticsSheet(context),
                ),
              PopupMenuButton<String>(
                tooltip: AppText.tr(context, 'เลือกสมุดบัญชี'),
                icon: const Icon(Icons.menu_book_outlined),
                onSelected: (value) {
                  if (value == '__create_booklet__') {
                    _showCreateBookletDialog(context);
                  } else {
                    _controller.selectBooklet(value);
                  }
                },
                itemBuilder: (context) => [
                  ..._controller.booklets.map(
                    (booklet) => PopupMenuItem(
                      value: booklet.id,
                      child: Row(
                        children: [
                          Expanded(child: Text(booklet.name)),
                          if (booklet.id == _controller.selectedBookletId)
                            const Icon(Icons.check, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: '__create_booklet__',
                    child: Text(AppText.tr(context, 'สร้างสมุดบัญชีใหม่')),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => AuthService().signOut(),
              ),
            ],
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: AppText.tr(context, 'Dashboard'),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.business_center_outlined),
                label: AppText.tr(context, 'วิเคราะห์'),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: AppText.tr(context, 'Wallet'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                label: AppText.tr(context, 'ตั้งค่า'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnalyticsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: RoiAnalyticsView(
          controller: _controller,
          preferences: widget.preferences,
        ),
      ),
    );
  }

  void _showReviewSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: ReviewView(controller: _controller),
      ),
    );
  }

  void _showCreateBookletDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.tr(context, 'สร้างสมุดบัญชี')),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppText.tr(
              context,
              'ชื่อสมุด เช่น เงินส่วนตัว หรือ ทริปเชียงใหม่',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppText.tr(context, 'ยกเลิก')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await _controller.createBooklet(name);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(AppText.tr(context, 'สร้าง')),
          ),
        ],
      ),
    );
  }
}
