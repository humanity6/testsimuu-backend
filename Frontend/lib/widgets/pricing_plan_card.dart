import 'package:flutter/material.dart';
import '../models/detailed_exam.dart';
import '../theme.dart';
import '../providers/app_providers.dart';

class PricingPlanCard extends StatelessWidget {
  final PricingPlan plan;
  final VoidCallback onSubscribe;
  final bool isAuthenticated;

  const PricingPlanCard({
    Key? key,
    required this.plan,
    required this.onSubscribe,
    this.isAuthenticated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: plan.isPopular
            ? Border.all(color: AppColors.limeYellow, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const Spacer(),
                    if (plan.isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.limeYellow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.tr('exam_detail_popular'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    if (plan.billingCycle == 'MONTHLY' || plan.billingCycle == 'YEARLY')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          plan.billingCycle == 'MONTHLY'
                              ? context.tr('exam_detail_per_month')
                              : context.tr('exam_detail_per_year'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                if (plan.trialDays > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: AppColors.limeYellow,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${plan.trialDays} ${context.tr("exam_detail_free_trial")}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.limeYellow,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('exam_detail_features'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                ...plan.features.map((feature) => _buildFeatureItem(feature)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAuthenticated ? onSubscribe : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('exam_detail_login_required')),
                          action: SnackBarAction(
                            label: context.tr('log_in'),
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAuthenticated ? AppColors.darkBlue : AppColors.mediumGrey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      plan.trialDays > 0 && isAuthenticated
                          ? context.tr('exam_detail_try_free')
                          : context.tr('exam_detail_subscribe_now'),
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

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 