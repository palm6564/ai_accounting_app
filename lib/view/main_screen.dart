// Directory: lib/view/
// File: main_screen.dart

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import '../service/auth_service.dart';
import 'category_summary_view.dart';
import 'dashboard_view.dart';
import 'review_view.dart';
import 'roi_analytics_view.dart';
import 'wallet_budget_view.dart';

class MainScreen extends StatefulWidget {
  final String userId;
  const MainScreen({super.key, required this.userId});

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
          DashboardView(controller: _controller),
          CategorySummaryView(controller: _controller, type: 'all'),
          RoiAnalyticsView(controller: _controller),
          WalletBudgetView(controller: _controller),
          ReviewView(controller: _controller),
        ];

        final titles = [
          'Dashboard บัญชี AI',
          'ธุรกิจรายย่อย',
          'วิเคราะห์การใช้เงิน',
          'กระเป๋าเงิน & งบประมาณ',
          'งานที่ต้องทำ',
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_currentIndex]),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'เลือกสมุดบัญชี',
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
                  const PopupMenuItem(
                    value: '__create_booklet__',
                    child: Text('สร้างสมุดบัญชีใหม่'),
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
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.business_center_outlined),
                label: 'ธุรกิจรายย่อย',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                label: 'วิเคราะห์เงิน',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Wallet',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  label: Text('${_controller.actionCount}'),
                  isLabelVisible: _controller.actionCount > 0,
                  child: const Icon(Icons.fact_check),
                ),
                label: 'งาน',
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateBookletDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('สร้างสมุดบัญชี'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อสมุด เช่น เงินส่วนตัว หรือ ทริปเชียงใหม่',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await _controller.createBooklet(name);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('สร้าง'),
          ),
        ],
      ),
    );
  }
}
