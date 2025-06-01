import 'package:flutter/material.dart';
import '../theme.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const CategoryCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected ? AppColors.darkBlue : AppColors.white;
    final textColor = isSelected ? AppColors.white : AppColors.darkBlue;
    final iconColor = isSelected ? AppColors.limeYellow : AppColors.darkBlue;

    return Card(
      color: backgroundColor,
      elevation: 4,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: iconColor,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 