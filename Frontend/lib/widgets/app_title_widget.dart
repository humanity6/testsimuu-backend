import 'package:flutter/material.dart';
import '../theme.dart';
import '../providers/app_providers.dart';

class AppTitleWidget extends StatelessWidget {
  final bool isDarkGreenBackground;
  final double fontSize;
  
  const AppTitleWidget({
    Key? key,
    this.isDarkGreenBackground = false,
    this.fontSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isDarkGreenBackground) {
      // White font with black borderline for dark green backgrounds
      return Text(
        context.tr('app_title'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          shadows: [
            Shadow(
              offset: const Offset(-1.0, -1.0),
              blurRadius: 0.0,
              color: Colors.black,
            ),
            Shadow(
              offset: const Offset(1.0, -1.0),
              blurRadius: 0.0,
              color: Colors.black,
            ),
            Shadow(
              offset: const Offset(1.0, 1.0),
              blurRadius: 0.0,
              color: Colors.black,
            ),
            Shadow(
              offset: const Offset(-1.0, 1.0),
              blurRadius: 0.0,
              color: Colors.black,
            ),
          ],
        ),
      );
    } else {
      // Default styling for other backgrounds
      return Text(
        context.tr('app_title'),
        style: TextStyle(
          color: AppColors.darkBlue,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      );
    }
  }
} 