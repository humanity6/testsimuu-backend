import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';
import '../../main.dart';
import '../../providers/app_providers.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int _currentPage = 0;

  List<OnboardingPage> _getPages(BuildContext context) {
    return [
      OnboardingPage(
        title: 'Willkommen bei Quizzax',
        description:
            'Deine intelligente Lernplattform für interaktive Quizze und personalisierte Übungen.',
        image: 'assets/images/onboarding1.png',
        color: AppColors.limeYellow,
      ),
      OnboardingPage(
        title: 'Lerne mit KI-generierten Quizzen',
        description:
            'Unsere KI erstellt personalisierte Fragen basierend auf deinem Wissensstand und Lernzielen.',
        image: 'assets/images/onboarding2.png',
        color: AppColors.white,
      ),
      OnboardingPage(
        title: 'Verfolge deinen Fortschritt',
        description:
            'Behalte den Überblick über deine Leistung und identifiziere Bereiche, die du verbessern kannst.',
        image: 'assets/images/onboarding3.png',
        color: AppColors.limeYellow,
      ),
    ];
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: controller,
                onPageChanged: _onPageChanged,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(pages[index]);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: controller,
                    count: pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.darkBlue,
                      dotColor: AppColors.darkBlue.withOpacity(0.2),
                      dotHeight: 8,
                      dotWidth: 8,
                      spacing: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        CustomButton(
                          text: context.tr('skip'),
                          onPressed: () {
                            controller.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          type: ButtonType.outline,
                        )
                      else
                        const SizedBox(width: 80),
                      CustomButton(
                        text: _currentPage == pages.length - 1
                            ? context.tr('get_started')
                            : context.tr('next'),
                        onPressed: _currentPage == pages.length - 1
                            ? _finishOnboarding
                            : () {
                                controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                        type: ButtonType.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Container(
      color: page.color,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Placeholder for image
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: AppColors.darkBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(
                Icons.school,
                size: 80,
                color: AppColors.darkBlue,
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String image;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
  });
} 