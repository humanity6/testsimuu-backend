import 'package:flutter/material.dart';
import '../models/user_exam.dart';
import '../theme.dart';
import '../providers/app_providers.dart';
import 'package:intl/intl.dart';

class UserExamCard extends StatelessWidget {
  final UserExam userExam;
  final VoidCallback? onOpenTap;
  final VoidCallback? onRenewTap;
  final bool isCompact;

  const UserExamCard({
    Key? key,
    required this.userExam,
    this.onOpenTap,
    this.onRenewTap,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final isExpired = userExam.isExpired;
    final isExpiringSoon = userExam.isExpiringSoon;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust sizes based on available width and height
        final isVerySmall = constraints.maxWidth < 160;
        final isExtremelySmall = constraints.maxWidth < 140;
        final isHeightConstrained = constraints.maxHeight < 120; // New: check for height constraints
        
        // Use even more compact sizing when height is very limited
        final titleFontSize = isHeightConstrained ? 10.0 : (isExtremelySmall ? 11.0 : (isVerySmall ? 12.0 : 14.0));
        final subjectFontSize = isHeightConstrained ? 8.0 : (isExtremelySmall ? 9.0 : (isVerySmall ? 10.0 : 12.0));
        final dateFontSize = isHeightConstrained ? 6.0 : (isExtremelySmall ? 7.0 : (isVerySmall ? 8.0 : 10.0));
        final buttonFontSize = isHeightConstrained ? 8.0 : (isExtremelySmall ? 9.0 : (isVerySmall ? 10.0 : 12.0));
        final imageHeight = isHeightConstrained ? 60.0 : (isExtremelySmall ? 70.0 : (isVerySmall ? 80.0 : 100.0));
        final iconSize = isHeightConstrained ? 24.0 : (isExtremelySmall ? 28.0 : (isVerySmall ? 32.0 : 40.0));
        final padding = isHeightConstrained ? 4.0 : (isExtremelySmall ? 6.0 : (isVerySmall ? 8.0 : 12.0));
        final verticalSpacing = isHeightConstrained ? 1.0 : (isExtremelySmall ? 2.0 : (isVerySmall ? 3.0 : 6.0));
        final buttonHeight = isHeightConstrained ? 24.0 : (isExtremelySmall ? 28.0 : (isVerySmall ? 32.0 : 36.0));
        
        return Container(
          width: isCompact ? 280 : double.infinity,
          constraints: const BoxConstraints(
            minHeight: 200,
            maxHeight: 350, // Add max height constraint for mobile
          ),
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
            border: isExpiringSoon && !isExpired
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exam image or placeholder with status indicator
              Stack(
                children: [
                  Container(
                    height: imageHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.darkBlueTransparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      image: userExam.exam.imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(userExam.exam.imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: userExam.exam.imageUrl.isEmpty
                        ? Center(
                            child: Icon(
                              _getSubjectIcon(userExam.exam.subject),
                              size: iconSize,
                              color: AppColors.darkBlue,
                            ),
                          )
                        : null,
                  ),
                  
                  // Status badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isExtremelySmall ? 4 : 6,
                        vertical: isExtremelySmall ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: userExam.getStatusColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        userExam.status,
                        style: TextStyle(
                          fontSize: isExtremelySmall ? 7 : (isVerySmall ? 8 : 10),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Progress indicator if available
                  if (userExam.progress != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: _parseProgress(userExam.progress!),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.limeYellow,
                        ),
                        minHeight: isExtremelySmall ? 3 : 4,
                      ),
                    ),
                ],
              ),
              
              // Exam details - Make this flexible to prevent overflow
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Important: minimize main axis size
                    children: [
                      // Title
                      Text(
                        userExam.exam.title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                          height: 1.1, // Reduce line height for compact display
                        ),
                        maxLines: isExtremelySmall ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: verticalSpacing),
                      
                      // Subject
                      Text(
                        userExam.exam.subject,
                        style: TextStyle(
                          fontSize: subjectFontSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mediumGrey,
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: verticalSpacing + 2),
                      
                      // Subscription period
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: isExtremelySmall ? 8 : (isVerySmall ? 10 : 12),
                            color: AppColors.mediumGrey,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${dateFormatter.format(userExam.startDate)} - ${dateFormatter.format(userExam.endDate)}',
                              style: TextStyle(
                                fontSize: dateFontSize,
                                color: AppColors.darkGrey,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // Expiry indicator - Make this flexible and conditional
                      if (isExpiringSoon && !isExpired && !isExtremelySmall && !isHeightConstrained) ...[
                        SizedBox(height: verticalSpacing),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmall ? 4 : 6,
                            vertical: isVerySmall ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: isVerySmall ? 8 : 10,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  userExam.daysRemaining == 0
                                      ? 'Expires today'
                                      : userExam.daysRemaining == 1
                                          ? 'Tomorrow'
                                          : '${userExam.daysRemaining}d',
                                  style: TextStyle(
                                    fontSize: isVerySmall ? 7 : 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const Spacer(), // Push button to bottom
                      
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: isExpired
                            ? ElevatedButton(
                                onPressed: onRenewTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.darkBlue,
                                  foregroundColor: Colors.white,
                                  textStyle: TextStyle(fontSize: buttonFontSize),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isExtremelySmall ? 4 : 8,
                                    vertical: 0,
                                  ),
                                ),
                                child: Text(
                                  isHeightConstrained ? 'Renew' : (isExtremelySmall ? 'Renew' : context.tr('renew_subscription')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: onOpenTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.darkBlue,
                                  textStyle: TextStyle(fontSize: buttonFontSize),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isExtremelySmall ? 4 : 8,
                                    vertical: 0,
                                  ),
                                ),
                                child: Text(
                                  isHeightConstrained
                                      ? (userExam.progress != null && userExam.progress != '0%' ? 'Continue' : 'Open')
                                      : (isExtremelySmall 
                                          ? (userExam.progress != null && userExam.progress != '0%' ? 'Continue' : 'Open')
                                          : (userExam.progress != null && userExam.progress != '0%'
                                              ? context.tr('continue_studying')
                                              : context.tr('open_exam'))),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  double _parseProgress(String progress) {
    try {
      final percentage = double.parse(progress.replaceAll('%', ''));
      return percentage / 100;
    } catch (e) {
      return 0.0;
    }
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Icons.functions;
      case 'physics':
        return Icons.science;
      case 'chemistry':
        return Icons.science_outlined;
      case 'biology':
        return Icons.biotech;
      case 'computer science':
        return Icons.computer;
      case 'history':
        return Icons.history_edu;
      default:
        return Icons.school;
    }
  }
} 