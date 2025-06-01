import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/language_selector.dart';
import '../../../models/pricing_plan.dart' as pricing;
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';

class PlanManagementScreen extends StatefulWidget {
  const PlanManagementScreen({Key? key}) : super(key: key);

  @override
  State<PlanManagementScreen> createState() => _PlanManagementScreenState();
}

class _PlanManagementScreenState extends State<PlanManagementScreen> {
  List<pricing.PricingPlan> _plans = [];
  bool _isLoading = true;
  String? _error;
  bool _showAddEditForm = false;
  pricing.PricingPlan? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final adminService = context.adminService;
      final authService = context.authService;
      
      if (authService.accessToken == null) {
        throw Exception('Authentication required');
      }
      
      final plans = await adminService.getPricingPlans();
      
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _addNewPlan() {
    setState(() {
      _selectedPlan = null;
      _showAddEditForm = true;
    });
  }

  void _editPlan(pricing.PricingPlan plan) {
    setState(() {
      _selectedPlan = plan;
      _showAddEditForm = true;
    });
  }

  Future<void> _togglePlanStatus(String planId, bool isActive) async {
    try {
      final adminService = context.adminService;
      final authService = context.authService;
      
      if (authService.accessToken == null) {
        throw Exception('Authentication required');
      }
      
      await adminService.updatePricingPlan(
        planId,
        {'is_active': isActive},
      );
      
      // Reload plans to get updated data
      await _loadPlans();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan ${isActive ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating plan: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAdminScaffold(
      title: context.tr('pricing_plans'),
      floatingActionButton: (!_showAddEditForm && _error == null && !_isLoading)
          ? FloatingActionButton(
              onPressed: _addNewPlan,
              backgroundColor: AppColors.darkBlue,
              child: Icon(
                Icons.add,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _showAddEditForm
                  ? _buildAddEditForm()
                  : _buildPlansList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: ResponsiveUtils.getScreenPadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 64, tabletSize: 64, desktopSize: 64),
              color: Colors.red,
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Text(
              'Error loading pricing plans',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            ElevatedButton(
              onPressed: _loadPlans,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansList() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    
    return SingleChildScrollView(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            context.tr('manage_pricing_plans'),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 24),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
          
          // Stats Card
          Card(
            elevation: 2,
            child: Padding(
              padding: ResponsiveUtils.getCardPadding(context),
              child: isMobile
                  ? _buildMobileStatsCard()
                  : _buildDesktopStatsCard(),
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
          
          // Plans List
          if (_plans.isEmpty)
            Card(
              child: Container(
                width: double.infinity,
                padding: ResponsiveUtils.getCardPadding(context).copyWith(
                  top: ResponsiveUtils.getSpacing(context, base: 48),
                  bottom: ResponsiveUtils.getSpacing(context, base: 48),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 64, tabletSize: 64, desktopSize: 64),
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                    Text(
                      context.tr('no_plans_found'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                    Text(
                      context.tr('create_first_plan'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            // Responsive Grid/List
            isMobile 
              ? _buildPlansListView()
              : isTablet
                ? _buildPlansGrid(crossAxisCount: 2)
                : _buildPlansGrid(crossAxisCount: 3),
        ],
      ),
    );
  }

  Widget _buildMobileStatsCard() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context.tr('total_plans'),
                '${_plans.length}',
                AppColors.darkBlue,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
            Expanded(
              child: _buildStatItem(
                context.tr('active_plans'),
                '${_plans.where((p) => p.isActive).length}',
                Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr('export_feature_coming_soon'))),
              );
            },
            icon: Icon(
              Icons.download,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
            ),
            label: Text(
              context.tr('export'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopStatsCard() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            context.tr('total_plans'),
            '${_plans.length}',
            AppColors.darkBlue,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            context.tr('active_plans'),
            '${_plans.where((p) => p.isActive).length}',
            Colors.green,
          ),
        ),
        TextButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('export_feature_coming_soon'))),
            );
          },
          icon: Icon(
            Icons.download,
            size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
          ),
          label: Text(
            context.tr('export'),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
            color: AppColors.mediumGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 24),
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPlansGrid({int crossAxisCount = 3}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: ResponsiveUtils.isMobile(context) ? 0.9 : 0.8,
        crossAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
        mainAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
      ),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  Widget _buildPlansListView() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _plans.length,
      separatorBuilder: (context, index) => SizedBox(
        height: ResponsiveUtils.getSpacing(context, base: 16),
      ),
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  Widget _buildPlanCard(pricing.PricingPlan plan) {
    return Card(
      elevation: plan.isPopular ? 8 : 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: plan.isPopular 
            ? Border.all(color: AppColors.darkBlue, width: 2)
            : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status toggle
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (plan.isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.darkBlue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  context.tr('popular'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan.price} ${plan.currency} / ${_formatBillingCycle(plan.billingCycle)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: plan.isActive,
                    onChanged: (value) => _togglePlanStatus(plan.id.toString(), value),
                    activeColor: AppColors.darkBlue,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Plan details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('trial_days'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan.trialDays}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('status'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: plan.isActive ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            plan.isActive ? context.tr('active') : context.tr('inactive'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Features
              if (plan.featuresList.isNotEmpty) ...[
                Text(
                  context.tr('features'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...plan.featuresList.take(3).map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
                if (plan.featuresList.length > 3)
                  Text(
                    '+ ${plan.featuresList.length - 3} ${context.tr('more_features')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editPlan(plan),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(
                        context.tr('edit'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      onPressed: () => _showDeleteConfirmation(plan),
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      tooltip: context.tr('delete'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddEditForm() {
    final isEditing = _selectedPlan != null;
    final formKey = GlobalKey<FormState>();
    
    // Form controllers
    final nameController = TextEditingController(text: isEditing ? _selectedPlan!.name : '');
    final priceController = TextEditingController(text: isEditing ? _selectedPlan!.price.toString() : '');
    final trialDaysController = TextEditingController(text: isEditing ? _selectedPlan!.trialDays.toString() : '0');
    final featuresController = TextEditingController(
      text: isEditing ? _selectedPlan!.featuresList.join('\n') : '',
    );
    
    // Form values
    String selectedCurrency = isEditing ? _selectedPlan!.currency : 'USD';
    String selectedBillingCycle = isEditing ? _selectedPlan!.billingCycle : 'MONTHLY';
    bool isActive = true;
    bool isPopular = isEditing ? _selectedPlan!.isPopular : false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? context.tr('edit_plan') : context.tr('add_new_plan'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            
            // Name field
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.tr('plan_name'),
                hintText: context.tr('enter_plan_name'),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('plan_name_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Price and Currency
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: context.tr('price'),
                      hintText: '19.99',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('price_required');
                      }
                      if (double.tryParse(value) == null) {
                        return context.tr('invalid_price');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: selectedCurrency,
                    decoration: InputDecoration(
                      labelText: context.tr('currency'),
                    ),
                    items: ['USD', 'EUR', 'GBP'].map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedCurrency = value!;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Billing Cycle
            DropdownButtonFormField<String>(
              value: selectedBillingCycle,
              decoration: InputDecoration(
                labelText: context.tr('billing_cycle'),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: 'MONTHLY',
                  child: Text(context.tr('monthly')),
                ),
                DropdownMenuItem<String>(
                  value: 'YEARLY',
                  child: Text(context.tr('yearly')),
                ),
                DropdownMenuItem<String>(
                  value: 'ONE_TIME',
                  child: Text(context.tr('one_time')),
                ),
              ],
              onChanged: (value) {
                selectedBillingCycle = value!;
              },
            ),
            const SizedBox(height: 16),
            
            // Trial Days
            TextFormField(
              controller: trialDaysController,
              decoration: InputDecoration(
                labelText: context.tr('trial_days'),
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null;
                }
                if (int.tryParse(value) == null) {
                  return context.tr('invalid_trial_days');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Features list
            TextFormField(
              controller: featuresController,
              decoration: InputDecoration(
                labelText: context.tr('features'),
                hintText: context.tr('features_hint'),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            
            // Status and Popular toggles
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: Text(context.tr('active')),
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        isActive = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    title: Text(context.tr('popular')),
                    value: isPopular,
                    onChanged: (value) {
                      setState(() {
                        isPopular = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Form actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAddEditForm = false;
                    });
                  },
                  child: Text(context.tr('cancel')),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      // In a real app, this would save to the backend
                      // For now, just go back to the list view
                      setState(() {
                        _showAddEditForm = false;
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? context.tr('plan_updated')
                                : context.tr('plan_added'),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? context.tr('update_plan') : context.tr('save_plan')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(pricing.PricingPlan plan) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('confirm_delete')),
          content: Text(
            context.tr('delete_plan_confirmation', params: {'name': plan.name}),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // In a real app, this would delete via API
                setState(() {
                  _plans.removeWhere((p) => p.id == plan.id);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('plan_deleted')),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.tr('delete')),
            ),
          ],
        );
      },
    );
  }

  String _formatBillingCycle(String cycle) {
    switch (cycle) {
      case 'MONTHLY':
        return context.tr('monthly');
      case 'YEARLY':
        return context.tr('yearly');
      case 'ONE_TIME':
        return context.tr('one_time');
      default:
        return cycle;
    }
  }
} 
