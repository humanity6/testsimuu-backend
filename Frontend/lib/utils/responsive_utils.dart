import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double wideDesktopBreakpoint = 1600;

  // Screen type detection
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < wideDesktopBreakpoint;
  }

  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= wideDesktopBreakpoint;
  }

  // Screen type from constraints
  static bool isMobileConstraints(BoxConstraints constraints) {
    return constraints.maxWidth < mobileBreakpoint;
  }

  static bool isTabletConstraints(BoxConstraints constraints) {
    return constraints.maxWidth >= mobileBreakpoint && constraints.maxWidth < tabletBreakpoint;
  }

  static bool isDesktopConstraints(BoxConstraints constraints) {
    return constraints.maxWidth >= tabletBreakpoint && constraints.maxWidth < wideDesktopBreakpoint;
  }

  static bool isWideDesktopConstraints(BoxConstraints constraints) {
    return constraints.maxWidth >= wideDesktopBreakpoint;
  }

  // Responsive spacing
  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    if (isDesktop(context)) return 32.0;
    return 40.0; // Wide desktop
  }

  static double getVerticalSpacing(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 20.0;
    if (isDesktop(context)) return 24.0;
    return 32.0; // Wide desktop
  }

  static double getCardSpacing(BuildContext context) {
    if (isMobile(context)) return 8.0;
    if (isTablet(context)) return 12.0;
    return 16.0; // Desktop and above
  }

  // Responsive grid columns
  static int getGridColumns(BuildContext context, {int? mobileColumns, int? tabletColumns, int? desktopColumns}) {
    if (isMobile(context)) return mobileColumns ?? 1;
    if (isTablet(context)) return tabletColumns ?? 2;
    if (isDesktop(context)) return desktopColumns ?? 3;
    return desktopColumns ?? 4; // Wide desktop
  }

  static int getGridColumnsFromConstraints(BoxConstraints constraints, {int? mobileColumns, int? tabletColumns, int? desktopColumns}) {
    if (isMobileConstraints(constraints)) return mobileColumns ?? 1;
    if (isTabletConstraints(constraints)) return tabletColumns ?? 2;
    if (isDesktopConstraints(constraints)) return desktopColumns ?? 3;
    return desktopColumns ?? 4; // Wide desktop
  }

  // Responsive font sizes
  static double getHeadingFontSize(BuildContext context) {
    if (isMobile(context)) return 20.0;
    if (isTablet(context)) return 24.0;
    return 28.0; // Desktop and above
  }

  static double getSubheadingFontSize(BuildContext context) {
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 18.0;
    return 20.0; // Desktop and above
  }

  static double getBodyFontSize(BuildContext context) {
    if (isMobile(context)) return 14.0;
    if (isTablet(context)) return 15.0;
    return 16.0; // Desktop and above
  }

  static double getCaptionFontSize(BuildContext context) {
    if (isMobile(context)) return 12.0;
    if (isTablet(context)) return 13.0;
    return 14.0; // Desktop and above
  }

  // Responsive icon sizes
  static double getIconSize(BuildContext context, {double? mobileSize, double? tabletSize, double? desktopSize}) {
    if (isMobile(context)) return mobileSize ?? 20.0;
    if (isTablet(context)) return tabletSize ?? 24.0;
    return desktopSize ?? 28.0; // Desktop and above
  }

  // Responsive button heights
  static double getButtonHeight(BuildContext context) {
    if (isMobile(context)) return 44.0; // Touch-friendly
    if (isTablet(context)) return 48.0;
    return 52.0; // Desktop and above
  }

  // Responsive table configurations
  static bool shouldUseDataTable(BuildContext context) {
    return !isMobile(context);
  }

  static bool shouldUseHorizontalScroll(BuildContext context) {
    return isMobile(context) || isTablet(context);
  }

  // Responsive modal configurations
  static bool shouldUseFullScreenModal(BuildContext context) {
    return isMobile(context);
  }

  static double getModalMaxWidth(BuildContext context) {
    if (isMobile(context)) return double.infinity;
    if (isTablet(context)) return 600.0;
    if (isDesktop(context)) return 800.0;
    return 1000.0; // Wide desktop
  }

  // Responsive card aspect ratios
  static double getCardAspectRatio(BuildContext context, {double? mobileRatio, double? tabletRatio, double? desktopRatio}) {
    if (isMobile(context)) return mobileRatio ?? 1.2;
    if (isTablet(context)) return tabletRatio ?? 1.4;
    return desktopRatio ?? 1.6; // Desktop and above
  }

  // Responsive layout helpers
  static Widget buildResponsiveRow({
    required BuildContext context,
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool forceColumn = false,
  }) {
    if (forceColumn || isMobile(context)) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
    }
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  static Widget buildResponsiveWrap({
    required BuildContext context,
    required List<Widget> children,
    double spacing = 8.0,
    double runSpacing = 8.0,
    WrapAlignment alignment = WrapAlignment.start,
  }) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      children: children,
    );
  }

  // Responsive container constraints
  static BoxConstraints getContentConstraints(BuildContext context) {
    if (isMobile(context)) {
      return const BoxConstraints(maxWidth: double.infinity);
    }
    if (isTablet(context)) {
      return const BoxConstraints(maxWidth: 800);
    }
    if (isDesktop(context)) {
      return const BoxConstraints(maxWidth: 1200);
    }
    return const BoxConstraints(maxWidth: 1600); // Wide desktop
  }

  // Responsive safe area
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final horizontalPadding = getHorizontalPadding(context);
    final verticalPadding = getVerticalSpacing(context);
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );
  }

  // Responsive form field configurations
  static int getFormFieldsPerRow(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    return 3; // Desktop and above
  }

  // Responsive table column widths
  static double getTableColumnWidth(BuildContext context, String columnType) {
    final baseWidth = isMobile(context) ? 100.0 : (isTablet(context) ? 120.0 : 150.0);
    
    switch (columnType) {
      case 'id':
        return baseWidth * 0.6;
      case 'name':
        return baseWidth * 1.5;
      case 'description':
        return baseWidth * 2.0;
      case 'status':
        return baseWidth * 0.8;
      case 'date':
        return baseWidth * 1.0;
      case 'actions':
        return baseWidth * 1.2;
      default:
        return baseWidth;
    }
  }

  // Responsive animation durations
  static Duration getAnimationDuration(BuildContext context) {
    if (isMobile(context)) return const Duration(milliseconds: 200);
    return const Duration(milliseconds: 300);
  }

  // Responsive elevation
  static double getCardElevation(BuildContext context) {
    if (isMobile(context)) return 2.0;
    if (isTablet(context)) return 4.0;
    return 6.0; // Desktop and above
  }

  // Responsive border radius
  static double getBorderRadius(BuildContext context) {
    if (isMobile(context)) return 8.0;
    if (isTablet(context)) return 12.0;
    return 16.0; // Desktop and above
  }

  // Additional responsive methods for admin panel
  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.all(getHorizontalPadding(context));
  }

  static double getSpacing(BuildContext context, {required double base}) {
    final multiplier = isMobile(context) ? 0.8 : (isTablet(context) ? 0.9 : 1.0);
    return base * multiplier;
  }

  static double getFontSize(BuildContext context, {required double base}) {
    final multiplier = isMobile(context) ? 0.9 : (isTablet(context) ? 0.95 : 1.0);
    return base * multiplier;
  }

  static EdgeInsets getInputPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (isTablet(context)) return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  static EdgeInsets getCardPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(16);
    return const EdgeInsets.all(20);
  }
}

// Extension for easier access
extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  bool get isWideDesktop => ResponsiveUtils.isWideDesktop(this);
  
  double get horizontalPadding => ResponsiveUtils.getHorizontalPadding(this);
  double get verticalSpacing => ResponsiveUtils.getVerticalSpacing(this);
  double get cardSpacing => ResponsiveUtils.getCardSpacing(this);
  
  double get headingFontSize => ResponsiveUtils.getHeadingFontSize(this);
  double get subheadingFontSize => ResponsiveUtils.getSubheadingFontSize(this);
  double get bodyFontSize => ResponsiveUtils.getBodyFontSize(this);
  double get captionFontSize => ResponsiveUtils.getCaptionFontSize(this);
  
  double get buttonHeight => ResponsiveUtils.getButtonHeight(this);
  double get cardElevation => ResponsiveUtils.getCardElevation(this);
  double get borderRadius => ResponsiveUtils.getBorderRadius(this);
  
  EdgeInsets get responsivePadding => ResponsiveUtils.getResponsivePadding(this);
  BoxConstraints get contentConstraints => ResponsiveUtils.getContentConstraints(this);
} 