import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../models/user.dart';
import 'content/topics_screen.dart';
import 'content/questions_screen.dart';
import 'content/ai_templates_screen.dart';

class AdminContentScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminContentScreen({
    Key? key,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
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
    // Check if user is admin, redirect if not
    final user = context.authService.currentUser;
    
    if (user == null || !user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_content_management')),
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: ModalRoute.of(context)?.canPop == true 
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: context.tr('back'),
            )
          : null,
        actions: const [
          LanguageSelector(isCompact: true),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: context.tr('topics')),
            Tab(text: context.tr('questions')),
            Tab(text: context.tr('ai_templates')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TopicsScreen(),
          QuestionsScreen(),
          AITemplatesScreen(),
        ],
      ),
    );
  }
} 