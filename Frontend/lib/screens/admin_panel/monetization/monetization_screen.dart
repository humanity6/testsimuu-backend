import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/language_selector.dart';
import 'plans_screen.dart';
import 'subscriptions_screen.dart';
import 'referrals_screen.dart';
import 'payments_screen.dart';

class MonetizationScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const MonetizationScreen({
    Key? key,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends State<MonetizationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('monetization')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.view_list),
              text: context.tr('plans'),
            ),
            Tab(
              icon: const Icon(Icons.subscriptions),
              text: context.tr('subscriptions'),
            ),
            Tab(
              icon: const Icon(Icons.people),
              text: context.tr('referrals'),
            ),
            Tab(
              icon: const Icon(Icons.payment),
              text: context.tr('payments'),
            ),
          ],
          labelColor: AppColors.darkBlue,
          unselectedLabelColor: AppColors.mediumGrey,
          indicatorColor: AppColors.darkBlue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PlanManagementScreen(),
          SubscriptionManagementScreen(),
          ReferralProgramsScreen(),
          PaymentsScreen(),
        ],
      ),
    );
  }
} 