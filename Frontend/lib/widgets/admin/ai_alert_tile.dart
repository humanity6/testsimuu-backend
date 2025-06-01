import 'package:flutter/material.dart';
import '../../models/ai_alert.dart';
import '../../theme.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/app_providers.dart';

class AIAlertTile extends StatelessWidget {
  final AIAlert alert;
  final VoidCallback onTap;
  final bool showDetails;
  final bool isCompact;

  const AIAlertTile({
    Key? key,
    required this.alert,
    required this.onTap,
    this.showDetails = true,
    this.isCompact = false,
  }) : super(key: key);

  Color _getPriorityColor() {
    switch (alert.priority.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor() {
    switch (alert.status.toUpperCase()) {
      case 'NEW':
        return Colors.amber;
      case 'UNDER_REVIEW':
        return Colors.blue;
      case 'ACTION_TAKEN':
        return Colors.green;
      case 'DISMISSED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final statusColor = _getStatusColor();
    
    if (isCompact) {
      return _buildCompactTile(context, priorityColor, statusColor);
    }
    
    return _buildFullTile(context, priorityColor, statusColor);
  }

  Widget _buildCompactTile(BuildContext context, Color priorityColor, Color statusColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Adjust padding and text size based on screen dimensions
    // Make compact mode even more compact for very small screens, but ensure it's always visible
    final isVerySmallScreen = screenHeight < 600 || screenWidth < 350;
    final verticalPadding = isVerySmallScreen ? 3.0 : 6.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.getSpacing(context, base: 3), // Reduce vertical margin
        horizontal: ResponsiveUtils.getSpacing(context, base: 2), // Reduce horizontal margin
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getSpacing(context, base: 8),
            vertical: ResponsiveUtils.getSpacing(context, base: verticalPadding),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: isVerySmallScreen ? 12 : 13),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Make the alert visible even on smallest screens by always showing at least 1 line
                        Text(
                          alert.summaryOfPotentialChange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: isVerySmallScreen ? 10 : 11),
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullTile(BuildContext context, Color priorityColor, Color statusColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.getSpacing(context, base: 8),
        horizontal: ResponsiveUtils.getSpacing(context, base: 0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          '${context.tr('source')}: ${alert.source}',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getSpacing(context, base: 8),
                      vertical: ResponsiveUtils.getSpacing(context, base: 4),
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      alert.status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 11),
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (showDetails) ...[
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                Divider(height: 1),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                Text(
                  alert.summaryOfPotentialChange,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 14, desktopSize: 14),
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          _formatDate(alert.createdAt),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 8),
                        vertical: ResponsiveUtils.getSpacing(context, base: 4),
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 14, desktopSize: 14),
                            color: priorityColor,
                          ),
                          SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
                          Text(
                            alert.priority,
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AIAlertsList extends StatelessWidget {
  final List<AIAlert> alerts;
  final Function(AIAlert) onAlertTap;
  final bool isCompact;
  final int maxAlerts;

  const AIAlertsList({
    Key? key,
    required this.alerts,
    required this.onAlertTap,
    this.isCompact = false,
    this.maxAlerts = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayAlerts = alerts.take(maxAlerts).toList();
    
    if (displayAlerts.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return Column(
      children: [
        ...displayAlerts.map((alert) => AIAlertTile(
          alert: alert,
          onTap: () => onAlertTap(alert),
          showDetails: !isCompact,
          isCompact: isCompact,
        )),
        if (alerts.length > maxAlerts)
          Padding(
            padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, base: 8)),
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/admin-panel/ai-alerts');
              },
              icon: Icon(Icons.arrow_forward, size: 16),
              label: Text(
                context.tr('View all ${alerts.length} alerts'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 48, tabletSize: 48, desktopSize: 48),
              color: Colors.grey[400],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
            Text(
              context.tr('No AI alerts at the moment'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 