import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../services/user_service.dart';
import '../../utils/api_config.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({Key? key}) : super(key: key);

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _faqs = [];
  String? _error;
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFAQs();
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userService = UserService();
      final faqs = await userService.fetchFAQs();
      final categories = await userService.fetchFAQCategories();
      
      if (mounted) {
        setState(() {
          _faqs = faqs;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredFAQs() {
    if (_searchQuery.isEmpty) {
      return _faqs;
    }
    
    final query = _searchQuery.toLowerCase();
    return _faqs.where((faq) {
      final question = faq['question']?.toString()?.toLowerCase() ?? '';
      final answer = faq['answer']?.toString()?.toLowerCase() ?? '';
      final category = _getCategoryName(faq['category_id']?.toString() ?? '').toLowerCase();
      
      return question.contains(query) || 
             answer.contains(query) || 
             category.contains(query);
    }).toList();
  }

  String _getCategoryName(String categoryId) {
    if (categoryId.isEmpty) return 'General';
    
    final category = _categories.firstWhere(
      (cat) => cat['id']?.toString() == categoryId,
      orElse: () => {'name': 'General'},
    );
    
    return category['name']?.toString() ?? 'General';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('faq')),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null 
              ? _buildErrorState() 
              : _buildFAQList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('failed_to_load_faqs'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadFAQs,
            child: Text(context.tr('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQList() {
    final filteredFAQs = _getFilteredFAQs();
    
    return Column(
      children: [
        // Search box
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('search_faqs'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ),
        
        // FAQ list
        Expanded(
          child: filteredFAQs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? context.tr('no_faqs_available')
                            : context.tr('no_matching_faqs'),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: filteredFAQs.length,
                  itemBuilder: (context, index) {
                    final faq = filteredFAQs[index];
                    final categoryId = faq['category_id']?.toString() ?? '';
                    final categoryName = _getCategoryName(categoryId);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: ExpansionTile(
                        title: Text(
                          faq['question']?.toString() ?? 'No question available',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              faq['answer']?.toString() ?? 'No answer available',
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
} 