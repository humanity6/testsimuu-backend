import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../utils/auth_navigation.dart';
import 'checkout_screen.dart';
import '../../models/exam.dart';
import '../../models/pricing_plan.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';

class PricingScreen extends StatefulWidget {
  final Exam? selectedExam;
  
  const PricingScreen({
    Key? key,
    this.selectedExam,
  }) : super(key: key);

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isSubscriptionSelected = false;
  List<PricingPlan> _pricingPlans = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPricingPlans();
  }

  Future<void> _loadPricingPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Get token if user is authenticated (but it's not required anymore)
      String? token = authService.accessToken;
      
      // Load pricing plans with optional exam filter
      final plans = await paymentService.getPricingPlans(
        token: token,
        examId: widget.selectedExam?.id != null ? int.tryParse(widget.selectedExam!.id) : null,
      );

      if (mounted) {
        setState(() {
          _pricingPlans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(
              context.tr('app_title'),
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const Spacer(),
            const LanguageSelector(isCompact: true),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildPricingModel(context),
            _buildPricingPlans(context),
            _buildBenefits(context),
            _buildFAQ(context),
            _buildCTA(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.limeYellow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectedExam != null
                ? context.tr('pricing_exam_title', params: {'examName': widget.selectedExam!.title})
                : context.tr('pricing_title'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('pricing_subtitle'),
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.darkGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingModel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('pricing_model_title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('pricing_model_description'),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildPricingTab(
                  context.tr('pricing_per_exam'),
                  isSelected: !_isSubscriptionSelected,
                  onTap: () {
                    setState(() {
                      _isSubscriptionSelected = false;
                    });
                  },
                ),
              ),
              Expanded(
                child: _buildPricingTab(
                  context.tr('pricing_subscription'),
                  isSelected: _isSubscriptionSelected,
                  onTap: () {
                    setState(() {
                      _isSubscriptionSelected = true;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingTab(String title, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBlue : AppColors.white,
          border: Border.all(
            color: AppColors.darkBlue,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.darkBlue,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPricingPlans(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load pricing plans',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPricingPlans,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pricingPlans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'No pricing plans available',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
          ),
        ),
      );
    }

    // Filter plans based on subscription type selection
    final filteredPlans = _pricingPlans.where((plan) {
      if (_isSubscriptionSelected) {
        return plan.isSubscription;
      } else {
        return !plan.isSubscription;
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filteredPlans.map((plan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildPricingCardFromPlan(context, plan),
          );
        }).toList(),
      ),
    );
  }



  Widget _buildPricingCardFromPlan(BuildContext context, PricingPlan plan) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: plan.isPopular ? AppColors.darkBlue : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isPopular ? Colors.transparent : AppColors.darkBlue.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isPopular || plan.isBestValue)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: plan.isPopular ? Colors.orange : AppColors.limeYellow,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  plan.isPopular ? 'Popular' : 'Best Value',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: plan.isPopular ? Colors.white : AppColors.darkBlue,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: plan.isPopular ? Colors.white : AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: plan.isPopular ? Colors.white : AppColors.darkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  plan.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: plan.isPopular ? Colors.white.withOpacity(0.8) : AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 24),
                ...plan.featuresList.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: plan.isPopular ? Colors.white : AppColors.limeYellow,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature.trim(),
                              style: TextStyle(
                                fontSize: 14,
                                color: plan.isPopular ? Colors.white : AppColors.darkGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _navigateToCheckout(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isPopular ? AppColors.limeYellow : AppColors.darkBlue,
                      foregroundColor: plan.isPopular ? AppColors.darkBlue : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      plan.trialDays > 0 ? 'Start ${plan.trialDays}-day trial' : 'Get Started',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCheckout(PricingPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          pricingPlan: plan,
          exam: widget.selectedExam,
        ),
      ),
    );
  }

  Widget _buildBenefits(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.limeYellow.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('pricing_benefits_title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.all_inclusive,
            title: context.tr('pricing_benefit_1_title'),
            description: context.tr('pricing_benefit_1_desc'),
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.lightbulb_outline,
            title: context.tr('pricing_benefit_2_title'),
            description: context.tr('pricing_benefit_2_desc'),
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.analytics_outlined,
            title: context.tr('pricing_benefit_3_title'),
            description: context.tr('pricing_benefit_3_desc'),
          ),
          const SizedBox(height: 24),
          _buildBenefitItem(
            context,
            icon: Icons.devices,
            title: context.tr('pricing_benefit_4_title'),
            description: context.tr('pricing_benefit_4_desc'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.darkGrey,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFAQ(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('pricing_faq_title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 24),
          _buildFAQItem(
            context.tr('pricing_faq_1_q'),
            context.tr('pricing_faq_1_a'),
          ),
          const Divider(height: 32),
          _buildFAQItem(
            context.tr('pricing_faq_2_q'),
            context.tr('pricing_faq_2_a'),
          ),
          const Divider(height: 32),
          _buildFAQItem(
            context.tr('pricing_faq_3_q'),
            context.tr('pricing_faq_3_a'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          answer,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.darkGrey,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCTA(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.darkBlue,
      child: Column(
        children: [
          Text(
            context.tr('pricing_cta'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => AuthNavigation.navigateToSignup(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.limeYellow,
                foregroundColor: AppColors.darkBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                context.tr('sign_up'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 