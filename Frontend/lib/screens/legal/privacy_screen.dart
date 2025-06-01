import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('privacy_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('last_updated', params: {'date': '2023-07-01'}),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.darkGrey,
                ),
              ),
              const SizedBox(height: 24),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_1_title'),
                content: context.tr('privacy_section_1_content'),
              ),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_2_title'),
                content: context.tr('privacy_section_2_content'),
              ),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_3_title'),
                content: context.tr('privacy_section_3_content'),
              ),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_4_title'),
                content: context.tr('privacy_section_4_content'),
              ),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_5_title'),
                content: context.tr('privacy_section_5_content'),
              ),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_6_title'),
                content: context.tr('privacy_section_6_content'),
              ),
              _buildPrivacySection(
                context: context,
                title: context.tr('privacy_section_7_title'),
                content: context.tr('privacy_section_7_content'),
              ),
              const SizedBox(height: 32),
              Text(
                context.tr('privacy_contact_us'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'privacy@testsimu.com',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
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
            content,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
} 