import 'package:flutter/material.dart';
import '../../models/affiliate.dart';
import '../../services/affiliate_service.dart';
import '../../providers/app_providers.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';

class AffiliateApplicationScreen extends StatefulWidget {
  final List<AffiliatePlan> availablePlans;

  const AffiliateApplicationScreen({
    Key? key,
    required this.availablePlans,
  }) : super(key: key);

  @override
  State<AffiliateApplicationScreen> createState() => _AffiliateApplicationScreenState();
}

class _AffiliateApplicationScreenState extends State<AffiliateApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AffiliateService _affiliateService = AffiliateService();
  
  // Form controllers
  final _businessNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _audienceDescriptionController = TextEditingController();
  final _promotionStrategyController = TextEditingController();
  final _followerCountController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _twitterController = TextEditingController();
  
  AffiliatePlan? _selectedPlan;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _websiteController.dispose();
    _audienceDescriptionController.dispose();
    _promotionStrategyController.dispose();
    _followerCountController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = context.authService;
      if (authService.isAuthenticated && authService.accessToken != null) {
        // Prepare social media links
        final socialMediaLinks = <String, String>{};
        if (_instagramController.text.isNotEmpty) {
          socialMediaLinks['instagram'] = _instagramController.text;
        }
        if (_tiktokController.text.isNotEmpty) {
          socialMediaLinks['tiktok'] = _tiktokController.text;
        }
        if (_youtubeController.text.isNotEmpty) {
          socialMediaLinks['youtube'] = _youtubeController.text;
        }
        if (_twitterController.text.isNotEmpty) {
          socialMediaLinks['twitter'] = _twitterController.text;
        }

        final applicationData = {
          'requested_plan': _selectedPlan!.id,
          'business_name': _businessNameController.text.trim(),
          'website_url': _websiteController.text.trim(),
          'social_media_links': socialMediaLinks,
          'audience_description': _audienceDescriptionController.text.trim(),
          'promotion_strategy': _promotionStrategyController.text.trim(),
          'follower_count': int.parse(_followerCountController.text),
        };

        await _affiliateService.submitApplication(
          authService.accessToken!,
          applicationData,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted successfully! We\'ll review it and get back to you.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit application: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.limeYellow,
      appBar: AppBar(
        title: const Text('Apply for Affiliate Program'),
        backgroundColor: AppColors.limeYellow,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildPlanSelection(),
              const SizedBox(height: 24),
              _buildBusinessInfo(),
              const SizedBox(height: 24),
              _buildSocialMediaLinks(),
              const SizedBox(height: 24),
              _buildAudienceInfo(),
              const SizedBox(height: 24),
              _buildPromotionStrategy(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Affiliate Application',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about yourself and how you plan to promote our app.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Plan *',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.availablePlans.map((plan) => _buildPlanOption(plan)).toList(),
      ],
    );
  }

  Widget _buildPlanOption(AffiliatePlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBlue.withOpacity(0.1) : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.darkBlue : AppColors.lightGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<AffiliatePlan>(
                  value: plan,
                  groupValue: _selectedPlan,
                  onChanged: (value) {
                    setState(() {
                      _selectedPlan = value;
                    });
                  },
                  activeColor: AppColors.darkBlue,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      Text(
                        plan.commissionSummary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (plan.minimumFollowers > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Minimum followers: ${plan.minimumFollowers}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _businessNameController,
          decoration: const InputDecoration(
            labelText: 'Business/Channel Name',
            hintText: 'Your business or channel name',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business or channel name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _websiteController,
          decoration: const InputDecoration(
            labelText: 'Website URL (Optional)',
            hintText: 'https://yourwebsite.com',
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'Please enter a valid URL starting with http:// or https://';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSocialMediaLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Social Media Profiles',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your social media profiles to help us understand your reach.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _instagramController,
          decoration: const InputDecoration(
            labelText: 'Instagram',
            hintText: '@yourusername or full URL',
            prefixIcon: Icon(Icons.camera_alt),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tiktokController,
          decoration: const InputDecoration(
            labelText: 'TikTok',
            hintText: '@yourusername or full URL',
            prefixIcon: Icon(Icons.music_note),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _youtubeController,
          decoration: const InputDecoration(
            labelText: 'YouTube',
            hintText: 'Channel name or URL',
            prefixIcon: Icon(Icons.play_circle),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _twitterController,
          decoration: const InputDecoration(
            labelText: 'Twitter/X',
            hintText: '@yourusername or full URL',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audience Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _followerCountController,
          decoration: const InputDecoration(
            labelText: 'Total Follower Count *',
            hintText: 'Total followers across all platforms',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your total follower count';
            }
            final count = int.tryParse(value);
            if (count == null || count < 0) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _audienceDescriptionController,
          decoration: const InputDecoration(
            labelText: 'Audience Description *',
            hintText: 'Describe your audience demographics, interests, and engagement',
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe your audience';
            }
            if (value.trim().length < 50) {
              return 'Please provide a more detailed description (at least 50 characters)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPromotionStrategy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Promotion Strategy',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _promotionStrategyController,
          decoration: const InputDecoration(
            labelText: 'How will you promote our app? *',
            hintText: 'Describe your content strategy, posting frequency, and promotional methods',
          ),
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe your promotion strategy';
            }
            if (value.trim().length < 50) {
              return 'Please provide a more detailed strategy (at least 50 characters)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        CustomButton(
          text: _isSubmitting ? 'Submitting...' : 'Submit Application',
          onPressed: _isSubmitting ? null : _submitApplication,
          type: ButtonType.primary,
          icon: Icons.send,
          isFullWidth: true,
        ),
        const SizedBox(height: 16),
        Text(
          'By submitting this application, you agree to our affiliate terms and conditions.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.darkGrey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 