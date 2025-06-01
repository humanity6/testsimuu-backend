import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/affiliate.dart';
import '../../services/affiliate_service.dart';
import '../../providers/app_providers.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';

class AffiliateDashboardScreen extends StatefulWidget {
  final Affiliate affiliate;

  const AffiliateDashboardScreen({
    Key? key,
    required this.affiliate,
  }) : super(key: key);

  @override
  State<AffiliateDashboardScreen> createState() => _AffiliateDashboardScreenState();
}

class _AffiliateDashboardScreenState extends State<AffiliateDashboardScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  bool _isLoading = true;
  String? _error;
  
  AffiliateStatistics? _statistics;
  List<AffiliateLink> _links = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.authService;
      if (authService.isAuthenticated && authService.accessToken != null) {
        final results = await Future.wait([
          _affiliateService.getAffiliateStatistics(authService.accessToken!),
          _affiliateService.getAffiliateLinks(authService.accessToken!),
        ]);

        if (mounted) {
          setState(() {
            _statistics = results[0] as AffiliateStatistics;
            _links = results[1] as List<AffiliateLink>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.limeYellow,
      appBar: AppBar(
        title: const Text('Affiliate Dashboard'),
        backgroundColor: AppColors.limeYellow,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null 
              ? _buildErrorState() 
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Welcome Card
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back, ${widget.affiliate.name}!',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Tracking Code: ${widget.affiliate.trackingCode}'),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _copyToClipboard(
                                    widget.affiliate.trackingCode,
                                    'Tracking code copied to clipboard',
                                  ),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy Code'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Earnings Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildSimpleCard(
                                'Total Earnings',
                                '€${widget.affiliate.totalEarnings.toStringAsFixed(2)}',
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSimpleCard(
                                'Pending',
                                '€${widget.affiliate.pendingEarnings.toStringAsFixed(2)}',
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Stats Title
                        if (_statistics != null) ...[
                          const Text(
                            'Performance (Last 30 Days)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Stats Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleStatCard(
                                  'Clicks',
                                  _statistics!.totalClicks.toString(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSimpleStatCard(
                                  'Conversions',
                                  _statistics!.totalConversions.toString(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSimpleStatCard(
                                  'Rate',
                                  '${_statistics!.conversionRate.toStringAsFixed(1)}%',
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                        ],
                        
                        // Quick Actions
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _copyToClipboard(
                                      'https://yourapp.com?ref=${widget.affiliate.trackingCode}',
                                      'Affiliate link copied to clipboard',
                                    ),
                                    icon: const Icon(Icons.share, size: 16),
                                    label: const Text('Share Link'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.darkBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Create link feature coming soon')),
                                      );
                                    },
                                    icon: const Icon(Icons.add_link, size: 16),
                                    label: const Text('Create Link'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Affiliate Links
                        const Text(
                          'Your Affiliate Links',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        if (_links.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Icon(Icons.link_off, size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No affiliate links yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Create your first affiliate link to start tracking clicks and conversions.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          for (var link in _links)
                            _buildSimpleLinkCard(link),
                            
                        // Add padding at the bottom
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard(String title, String value, Color valueColor) {
    return Card(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStatCard(String title, String value) {
    return Card(
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLinkCard(AffiliateLink link) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    link.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(
                    link.fullUrl,
                    'Link copied to clipboard',
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              link.fullUrl,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.clickCount.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Clicks', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${link.conversionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('Rate', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: link.isActive ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    link.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: link.isActive ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 