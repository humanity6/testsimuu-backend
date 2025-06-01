import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/language_selector.dart';
import '../../../utils/responsive_utils.dart';

// FAQ Category model
class FAQCategory {
  final String id;
  final String name;
  final String value; // Original backend value
  final String? description;
  final int? count;

  FAQCategory({
    required this.id,
    required this.name,
    required this.value,
    this.description,
    this.count,
  });

  factory FAQCategory.fromJson(Map<String, dynamic> json) {
    return FAQCategory(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      count: json['count'] as int?,
    );
  }
}

// FAQ Item model
class FAQItem {
  final String id;
  final String category; // Backend category value
  final String question;
  final String answer;
  final int? displayOrder;

  FAQItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.displayOrder,
  });

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      id: json['id'].toString(),
      category: json['category']?.toString() ?? '',
      question: json['question_text']?.toString() ?? '',
      answer: json['answer_text']?.toString() ?? '',
      displayOrder: json['display_order'] as int?,
    );
  }
}

class FAQManagementScreen extends StatefulWidget {
  const FAQManagementScreen({Key? key}) : super(key: key);

  @override
  State<FAQManagementScreen> createState() => _FAQManagementScreenState();
}

class _FAQManagementScreenState extends State<FAQManagementScreen> {
  bool _isLoading = true;
  List<FAQCategory> _categories = [];
  List<FAQItem> _faqs = [];
  List<FAQItem> _filteredFaqs = [];
  String? _errorMessage;
  
  FAQCategory? _selectedCategory;
  FAQItem? _selectedFaq;
  bool _showAddEditForm = false;
  bool _isAddingCategory = false;
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadData();
    
    _searchController.addListener(() {
      _filterFaqs();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final adminService = context.adminService;
      
      // Fetch categories and FAQs from the API
      final categoriesData = await adminService.getFAQCategories();
      final faqsData = await adminService.getFAQs();
      
      // Parse categories
      final categories = categoriesData.map((cat) => FAQCategory.fromJson(cat)).toList();
      
      // Add "All" category at the beginning
      final allCategory = FAQCategory(
        id: 'all', 
        name: context.tr('all_categories'),
        value: 'all',
        description: 'All FAQ categories',
        count: faqsData.length,
      );
      
      // Parse FAQs
      final faqs = faqsData.map((faq) => FAQItem.fromJson(faq)).toList();
      
      setState(() {
        _categories = [allCategory, ...categories];
        _faqs = faqs;
        _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
        _filterFaqs();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load FAQs: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _filterFaqs() {
    setState(() {
      final searchTerm = _searchController.text.toLowerCase();
      
      _filteredFaqs = _faqs.where((faq) {
        final matchesSearch = 
            faq.question.toLowerCase().contains(searchTerm) ||
            faq.answer.toLowerCase().contains(searchTerm);
            
        final matchesCategory = _selectedCategory == null || 
            _selectedCategory!.value == 'all' ||
            faq.category == _selectedCategory!.value;
            
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }
  
  void _selectCategory(FAQCategory category) {
    setState(() {
      _selectedCategory = category;
      _filterFaqs();
    });
  }
  
  void _addNewFaq() {
    setState(() {
      _selectedFaq = null;
      _showAddEditForm = true;
    });
  }
  
  void _editFaq(FAQItem faq) {
    setState(() {
      _selectedFaq = faq;
      _showAddEditForm = true;
    });
  }
  
  void _deleteFaq(FAQItem faq) async {
    try {
      final adminService = context.adminService;
      await adminService.deleteFAQ(faq.id);
      
      // Remove from local list and update UI
      if (mounted) {
        setState(() {
          _faqs.removeWhere((item) => item.id == faq.id);
          _filterFaqs();
        });
        
        // Use a delayed approach to ensure context is still valid
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('faq_deleted')),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting FAQ: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }
  
  void _showAddCategoryDialog() {
    setState(() {
      _isAddingCategory = true;
      _categoryNameController.text = '';
    });
  }
  
  void _addCategory() {
    if (_categoryNameController.text.trim().isEmpty) return;
    
    final newCategory = FAQCategory(
      id: 'cat-${DateTime.now().millisecondsSinceEpoch}',
      name: _categoryNameController.text.trim(),
      value: _categoryNameController.text.trim().toLowerCase(),
    );
    
    if (mounted) {
      setState(() {
        _categories.add(newCategory);
        _isAddingCategory = false;
        _categoryNameController.text = '';
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('category_added')),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }
  
  void _deleteCategory(FAQCategory category) {
    // Don't allow deleting the "All" category
    if (category.value == 'all') return;
    
    if (mounted) {
      setState(() {
        _categories.removeWhere((item) => item.id == category.id);
        if (_selectedCategory?.id == category.id) {
          _selectedCategory = _categories.first; // Default to "All"
          _filterFaqs();
        }
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('category_deleted')),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  String _getCategoryDisplayName(String categoryValue) {
    final category = _categories.firstWhere(
      (cat) => cat.value == categoryValue,
      orElse: () => FAQCategory(
        id: 'unknown',
        name: categoryValue.isEmpty ? 'Unknown' : categoryValue.split(' ').map((word) => 
            word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()
        ).join(' '),
        value: categoryValue,
      ),
    );
    return category.name;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('faq_management')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(context.tr('retry')),
                      ),
                    ],
                  ),
                )
              : isMobile
                  ? _buildMobileLayout()
                  : _buildDesktopLayout(),
      floatingActionButton: !_showAddEditForm
          ? FloatingActionButton(
              onPressed: _addNewFaq,
              backgroundColor: AppColors.darkBlue,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildMobileLayout() {
    if (_showAddEditForm) {
      return _buildAddEditForm();
    }
    
    return Column(
      children: [
        // Category selector for mobile
        Container(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<FAQCategory>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: context.tr('category'),
              border: const OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem<FAQCategory>(
                value: category,
                child: Text('${category.name}${category.count != null ? ' (${category.count})' : ''}'),
              );
            }).toList(),
            onChanged: (category) {
              if (category != null) {
                _selectCategory(category);
              }
            },
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('search_faqs'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // FAQ list
        Expanded(child: _buildFaqsList()),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Categories sidebar
        SizedBox(
          width: 250,
          child: _buildCategoriesSidebar(),
        ),
        // Vertical divider
        const VerticalDivider(width: 1, thickness: 1),
        // FAQ content
        Expanded(
          child: _showAddEditForm
              ? _buildAddEditForm()
              : _buildFaqsList(),
        ),
      ],
    );
  }

  Widget _buildCategoriesSidebar() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('categories'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddCategoryDialog,
                  tooltip: context.tr('add_category'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Add category form
          if (_isAddingCategory)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _categoryNameController,
                    decoration: InputDecoration(
                      labelText: context.tr('category_name'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _addCategory,
                        child: Text(context.tr('add')),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isAddingCategory = false;
                            _categoryNameController.text = '';
                          });
                        },
                        child: Text(context.tr('cancel')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Search bar for desktop
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search_faqs'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          
          // Categories list
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory?.id == category.id;
                
                return ListTile(
                  title: Text(category.name),
                  subtitle: category.count != null ? Text('${category.count} items') : null,
                  selected: isSelected,
                  onTap: () {
                    _selectCategory(category);
                  },
                  trailing: category.value != 'all'
                      ? PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.tr('delete')),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteCategory(category);
                            }
                          },
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCategory == null
                          ? context.tr('all_faqs')
                          : _selectedCategory!.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${_filteredFaqs.length} ${context.tr('items')}',
                      style: const TextStyle(color: AppColors.mediumGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredFaqs.isEmpty
              ? Center(
                  child: Text(context.tr('no_faqs_found')),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredFaqs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final faq = _filteredFaqs[index];
                    return _buildFaqItem(faq);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildFaqItem(FAQItem faq) {
    final categoryDisplayName = _getCategoryDisplayName(faq.category);
    
    return ExpansionTile(
      title: Text(
        faq.question,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        categoryDisplayName,
        style: TextStyle(
          color: AppColors.mediumGrey,
          fontSize: 12,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                faq.answer,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editFaq(faq),
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(context.tr('edit')),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteFaq(faq),
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: Text(
                      context.tr('delete'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddEditForm() {
    final isEditing = _selectedFaq != null;
    final formKey = GlobalKey<FormState>();
    
    // Form controllers
    final questionController = TextEditingController(text: isEditing ? _selectedFaq!.question : '');
    final answerController = TextEditingController(text: isEditing ? _selectedFaq!.answer : '');
    
    // Get valid categories (not 'all')
    final validCategories = _categories.where((cat) => cat.value != 'all').toList();
    
    return StatefulBuilder(
      builder: (context, setFormState) {
        String? selectedCategoryValue = isEditing ? _selectedFaq!.category : (validCategories.isNotEmpty ? validCategories.first.value : null);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _showAddEditForm = false;
                          _selectedFaq = null;
                        });
                      },
                    ),
                    Text(
                      isEditing ? context.tr('edit_faq') : context.tr('add_new_faq'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Category dropdown
                DropdownButtonFormField<String>(
                  value: validCategories.any((cat) => cat.value == selectedCategoryValue) ? selectedCategoryValue : null,
                  decoration: InputDecoration(
                    labelText: context.tr('category'),
                    border: const OutlineInputBorder(),
                  ),
                  items: validCategories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category.value,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setFormState(() {
                        selectedCategoryValue = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('category_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Question field
                TextFormField(
                  controller: questionController,
                  decoration: InputDecoration(
                    labelText: context.tr('question'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('question_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Answer field
                TextFormField(
                  controller: answerController,
                  decoration: InputDecoration(
                    labelText: context.tr('answer'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('answer_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate() && selectedCategoryValue != null) {
                          try {
                            final adminService = context.adminService;
                            
                            final faqData = {
                              'question_text': questionController.text.trim(),
                              'answer_text': answerController.text.trim(),
                              'category': selectedCategoryValue!, // Use the backend category value
                              'display_order': _selectedFaq?.displayOrder ?? 0,
                            };
                            
                            if (isEditing) {
                              // Update existing FAQ
                              await adminService.updateFAQ(_selectedFaq!.id, faqData);
                            } else {
                              // Create new FAQ
                              await adminService.createFAQ(faqData);
                            }
                            
                            // Reload data and hide form
                            await _loadData();
                            setState(() {
                              _showAddEditForm = false;
                              _selectedFaq = null;
                            });
                            
                            // Show success message
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEditing 
                                          ? context.tr('faq_updated_successfully') 
                                          : context.tr('faq_created_successfully')
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              });
                            }
                          } catch (e) {
                            // Show error message
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              });
                            }
                          }
                        }
                      },
                      child: Text(isEditing ? context.tr('update') : context.tr('create')),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAddEditForm = false;
                          _selectedFaq = null;
                        });
                      },
                      child: Text(context.tr('cancel')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 
