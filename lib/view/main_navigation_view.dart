// Directory: lib/view/
// File: lib/view/main_navigation_view.dart
// คำอธิบาย: โครงสร้าง Navigation ด้านล่าง รวมหน้า Dashboard, หน้าวิเคราะห์ ROI และหน้ากระเป๋าเงิน/งบประมาณ

import 'package:flutter/material.dart';

import '../control/account_controller.dart';
import 'dashboard_view.dart';
import 'roi_analytics_view.dart';
import 'wallet_budget_view.dart';

class MainNavigationView extends StatefulWidget {
  final AccountController controller;

  const MainNavigationView({super.key, required this.controller});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardView(controller: widget.controller),
      RoiAnalyticsView(controller: widget.controller),
      WalletBudgetView(controller: widget.controller),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'วิเคราะห์ ROI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'กระเป๋า & งบ',
          ),
        ],
      ),
    );
  }
}
