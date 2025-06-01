import 'package:flutter/material.dart';
import '../../models/ai_alert.dart';
import '../../theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/app_providers.dart';
import 'ai_alert_tile.dart';

class AIAlertsDashboardWidget extends StatelessWidget {
  final List<AIAlert> alerts;
  final Function(AIAlert)? onAlertTap;
  final VoidCallback? onViewAllTap;

  const AIAlertsDashboardWidget({
    Key? key,
    required this.alerts,
    this.onAlertTap,
    this.onViewAllTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              _buildAlertStats(context),
              _buildDivider(),
              Flexible(
                child: _buildAlertsList(context),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Colors.orange,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
                ),
              ),
              SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('ai_alerts'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr('content_change_suggestions'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onViewAllTap ?? () {
              Navigator.of(context).pushNamed('/admin-panel/ai-alerts');
            },
            icon: Icon(
              Icons.dashboard_customize,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
            ),
            label: Text(
              context.tr('manage'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getSpacing(context, base: 12),
                vertical: ResponsiveUtils.getSpacing(context, base: 8),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStats(BuildContext context) {
    // Count alerts by status and priority
    int newAlerts = 0;
    int reviewAlerts = 0;
    int highPriority = 0;
    
    for (var alert in alerts) {
      if (alert.status.toUpperCase() == 'NEW') {
        newAlerts++;
      } else if (alert.status.toUpperCase() == 'UNDER_REVIEW') {
        reviewAlerts++;
      }
      
      if (alert.priority.toUpperCase() == 'HIGH') {
        highPriority++;
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
        vertical: ResponsiveUtils.getSpacing(context, base: 8),
      ),
      child: ResponsiveUtils.isMobile(context)
          ? Column(
              children: [
                _buildStatItem(
                  context, 
                  Icons.notifications_active, 
                  context.tr('total_alerts'), 
                  alerts.length.toString(),
                  Colors.orange,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                _buildStatItem(
                  context, 
                  Icons.new_releases, 
                  context.tr('new_alerts'), 
                  newAlerts.toString(),
                  Colors.amber,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                _buildStatItem(
                  context, 
                  Icons.priority_high, 
                  context.tr('high_priority'), 
                  highPriority.toString(),
                  Colors.red,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildStatItem(
                    context, 
                    Icons.notifications_active, 
                    context.tr('total_alerts'), 
                    alerts.length.toString(),
                    Colors.orange,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                Expanded(
                  child: _buildStatItem(
                    context, 
                    Icons.new_releases, 
                    context.tr('new_alerts'), 
                    newAlerts.toString(),
                    Colors.amber,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                Expanded(
                  child: _buildStatItem(
                    context, 
                    Icons.priority_high, 
                    context.tr('high_priority'), 
                    highPriority.toString(),
                    Colors.red,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 12)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 22, desktopSize: 24),
          ),
          SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.2));
  }

  Widget _buildAlertsList(BuildContext context) {
    if (alerts.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 48, tabletSize: 64, desktopSize: 64),
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                    Text(
                      context.tr('no_alerts'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                    Text(
                      context.tr('no_alerts_description'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      );
    }

    // Calculate the appropriate number of items to show based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 1200;
    
    // Always show at least 1 alert regardless of screen size
    int itemsToShow = 1;
    
    // Adjust the number of visible alerts based on screen height, but ensure at least 1 is visible
    if (screenHeight >= 600) {
      itemsToShow = 2;
    }
    if (screenHeight >= 800) {
      itemsToShow = 3;
    }
    if (isWideScreen && screenHeight >= 900) {
      itemsToShow = 4;
    }
    
    // Limit the items to show
    final displayAlerts = alerts.length > itemsToShow
        ? alerts.sublist(0, itemsToShow)
        : alerts;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a scrollable column if space is limited
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight - (alerts.length > itemsToShow ? 60 : 0),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                    vertical: ResponsiveUtils.getSpacing(context, base: 8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayAlerts.length,
                    itemBuilder: (context, index) {
                      return AIAlertTile(
                        alert: displayAlerts[index],
                        onTap: () {
                          if (onAlertTap != null) {
                            onAlertTap!(displayAlerts[index]);
                          }
                        },
                        isCompact: ResponsiveUtils.isMobile(context) || screenHeight < 800,
                      );
                    },
                  ),
                ),
              ),
            ),
            if (alerts.length > itemsToShow)
              Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onViewAllTap ?? () {
                      Navigator.of(context).pushNamed('/admin-panel/ai-alerts');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      context.tr('view_all_alerts'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
    );
  }
} 