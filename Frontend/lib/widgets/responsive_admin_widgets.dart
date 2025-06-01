import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/responsive_utils.dart';
import '../providers/app_providers.dart';

class ResponsiveAdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;

  const ResponsiveAdminScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: context.headingFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: showBackButton && ModalRoute.of(context)?.canPop == true 
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: context.tr('back'),
            )
          : null,
        actions: actions,
        elevation: context.isMobile ? 2 : 4,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              constraints: context.contentConstraints,
              child: body,
            );
          },
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class ResponsiveMetricsGrid extends StatelessWidget {
  final List<MetricCardData> metrics;

  const ResponsiveMetricsGrid({
    Key? key,
    required this.metrics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveUtils.getGridColumnsFromConstraints(
          constraints,
          mobileColumns: 2,
          tabletColumns: 3,
          desktopColumns: 4,
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: ResponsiveUtils.getCardAspectRatio(
              context,
              mobileRatio: 1.1,
              tabletRatio: 1.3,
              desktopRatio: 1.5,
            ),
            crossAxisSpacing: context.cardSpacing,
            mainAxisSpacing: context.cardSpacing,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            return ResponsiveMetricCard(data: metrics[index]);
          },
        );
      },
    );
  }
}

class ResponsiveMetricCard extends StatelessWidget {
  final MetricCardData data;

  const ResponsiveMetricCard({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: context.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.isMobile ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    data.icon,
                    color: data.color,
                    size: ResponsiveUtils.getIconSize(context),
                  ),
                  SizedBox(width: context.isMobile ? 6 : 8),
                  Expanded(
                    child: Text(
                      data.title,
                      style: TextStyle(
                        fontSize: context.captionFontSize,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.isMobile ? 4 : 8),
            Flexible(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  style: TextStyle(
                    fontSize: context.isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: data.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResponsiveFiltersSection extends StatelessWidget {
  final List<Widget> filters;
  final VoidCallback? onApplyFilters;
  final VoidCallback? onClearFilters;
  final String? title;

  const ResponsiveFiltersSection({
    Key? key,
    required this.filters,
    this.onApplyFilters,
    this.onClearFilters,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.horizontalPadding),
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(Icons.filter_list, color: AppColors.darkBlue, size: ResponsiveUtils.getIconSize(context)),
                SizedBox(width: context.cardSpacing),
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: context.subheadingFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.verticalSpacing),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              if (context.isMobile) {
                return Column(
                  children: [
                    ...filters.map((filter) => Padding(
                      padding: EdgeInsets.only(bottom: context.cardSpacing),
                      child: filter,
                    )),
                  ],
                );
              } else {
                return Wrap(
                  spacing: context.cardSpacing,
                  runSpacing: context.cardSpacing,
                  children: filters.map((filter) => SizedBox(
                    width: constraints.maxWidth / ResponsiveUtils.getFormFieldsPerRow(context) - context.cardSpacing,
                    child: filter,
                  )).toList(),
                );
              }
            },
          ),
          if (onApplyFilters != null || onClearFilters != null) ...[
            SizedBox(height: context.verticalSpacing),
            ResponsiveUtils.buildResponsiveRow(
              context: context,
              children: [
                if (onApplyFilters != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApplyFilters,
                      icon: const Icon(Icons.filter_list),
                      label: Text(context.tr('apply_filters')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, context.buttonHeight),
                      ),
                    ),
                  ),
                if (onApplyFilters != null && onClearFilters != null)
                  SizedBox(width: context.cardSpacing),
                if (onClearFilters != null)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onClearFilters,
                      icon: const Icon(Icons.clear),
                      label: Text(context.tr('clear_filters')),
                      style: TextButton.styleFrom(
                        minimumSize: Size(double.infinity, context.buttonHeight),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ResponsiveDataDisplay extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<ResponsiveColumnConfig> columns;
  final Function(Map<String, dynamic>)? onRowTap;
  final String? emptyMessage;
  final IconData? emptyIcon;

  const ResponsiveDataDisplay({
    Key? key,
    required this.data,
    required this.columns,
    this.onRowTap,
    this.emptyMessage,
    this.emptyIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveUtils.shouldUseDataTable(context)) {
          return _buildDataTable(context);
        } else {
          return _buildCardList(context);
        }
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcon ?? Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: context.verticalSpacing),
          Text(
            emptyMessage ?? context.tr('no_data_found'),
            style: TextStyle(
              fontSize: context.bodyFontSize,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns.map((col) => DataColumn(
            label: Text(
              col.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.bodyFontSize,
              ),
            ),
          )).toList(),
          rows: data.map((item) => DataRow(
            cells: columns.map((col) => DataCell(
              col.builder(item, context),
              onTap: onRowTap != null ? () => onRowTap!(item) : null,
            )).toList(),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildCardList(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(context.horizontalPadding),
      itemCount: data.length,
      separatorBuilder: (context, index) => SizedBox(height: context.cardSpacing),
      itemBuilder: (context, index) {
        final item = data[index];
        return Card(
          elevation: context.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.borderRadius),
          ),
          child: InkWell(
            onTap: onRowTap != null ? () => onRowTap!(item) : null,
            borderRadius: BorderRadius.circular(context.borderRadius),
            child: Padding(
              padding: EdgeInsets.all(context.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns.map((col) => Padding(
                  padding: EdgeInsets.only(bottom: context.cardSpacing / 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          col.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: context.captionFontSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(child: col.builder(item, context)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ResponsivePaginationControls extends StatelessWidget {
  final int currentPage;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final int? totalItems;
  final int? itemsPerPage;

  const ResponsivePaginationControls({
    Key? key,
    required this.currentPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.onNextPage,
    this.onPreviousPage,
    this.totalItems,
    this.itemsPerPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ResponsiveUtils.buildResponsiveRow(
        context: context,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (totalItems != null && itemsPerPage != null)
            Text(
              context.tr('showing_items', params: {
                'start': ((currentPage - 1) * itemsPerPage! + 1).toString(),
                'end': (currentPage * itemsPerPage!).toString(),
                'total': totalItems.toString(),
              }),
              style: TextStyle(
                fontSize: context.captionFontSize,
                color: Colors.grey[600],
              ),
            )
          else
            Text(
              context.tr('page_number', params: {'page': currentPage.toString()}),
              style: TextStyle(
                fontSize: context.captionFontSize,
                color: Colors.grey[600],
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: hasPreviousPage ? onPreviousPage : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: context.tr('previous_page'),
              ),
              IconButton(
                onPressed: hasNextPage ? onNextPage : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: context.tr('next_page'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ResponsiveFormField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isRequired;

  const ResponsiveFormField({
    Key? key,
    required this.label,
    required this.child,
    this.isRequired = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: context.bodyFontSize,
              fontWeight: FontWeight.w500,
              color: AppColors.darkGrey,
            ),
            children: isRequired ? [
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ] : null,
          ),
        ),
        SizedBox(height: context.cardSpacing / 2),
        child,
      ],
    );
  }
}

// Data classes
class MetricCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class ResponsiveColumnConfig {
  final String title;
  final Widget Function(Map<String, dynamic> item, BuildContext context) builder;

  const ResponsiveColumnConfig({
    required this.title,
    required this.builder,
  });
} 