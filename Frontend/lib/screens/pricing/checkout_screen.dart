import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../models/exam.dart';
import '../../models/pricing_plan.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import 'test_payment_screen.dart';
import 'dart:async';

class CheckoutScreen extends StatefulWidget {
  final PricingPlan pricingPlan;
  final Exam? exam;

  const CheckoutScreen({
    Key? key,
    required this.pricingPlan,
    this.exam,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderNameController = TextEditingController();
  
  // Payment state
  bool _isProcessing = false;
  bool _paymentComplete = false;
  String? _paymentError;
  
  // Payment method selection
  String _selectedPaymentMethod = 'card';
  
  // Add getters for compatibility
  String get planPrice => widget.pricingPlan.formattedPrice;
  bool get isSubscription => widget.pricingPlan.isSubscription;
  
  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardHolderNameController.dispose();
    super.dispose();
  }
  
  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _paymentError = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      
      // Check if user is authenticated
      if (authService.accessToken == null) {
        throw Exception('Please log in to continue with payment');
      }
      
      // Create subscription through the backend - this returns a checkout URL
      final result = await paymentService.createSubscription(
        authService.accessToken!,
        widget.pricingPlan.id,
      );
      
      setState(() {
        _isProcessing = false;
      });
      
      // Check if we got a checkout URL (for real SumUp) or mock response
      if (result.containsKey('checkout_url')) {
        final checkoutUrl = result['checkout_url'] as String;
        
        if (checkoutUrl.contains('/test-payment/')) {
          // This is a test/mock checkout - navigate to our test payment screen
          final checkoutId = checkoutUrl.split('/').last;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TestPaymentScreen(checkoutId: checkoutId),
            ),
          );
        } else {
          // This is a real SumUp checkout - open in browser/webview
          await _openCheckoutUrl(checkoutUrl);
        }
      } else {
        // Legacy flow or immediate success
        setState(() {
          _paymentComplete = true;
        });
      }
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _paymentError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
  
  Future<void> _openCheckoutUrl(String url) async {
    // For web platform, we can redirect directly
    // For mobile, we'd typically use url_launcher or in-app browser
    try {
      // Import url_launcher package for real implementation
      // await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      
      // For now, show a dialog with the URL for testing
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open Payment Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please open the following URL to complete your payment:'),
              const SizedBox(height: 16),
              SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Simulate successful payment for testing
                setState(() {
                  _paymentComplete = true;
                });
              },
              child: const Text('Mark as Paid (Test)'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _paymentError = 'Failed to open payment page: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('checkout')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: _paymentComplete ? _buildPaymentSuccess() : _buildCheckoutForm(),
    );
  }
  
  Widget _buildCheckoutForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummary(),
          const SizedBox(height: 32),
          _buildPaymentMethodSelector(),
          const SizedBox(height: 24),
          _buildPaymentForm(),
          const SizedBox(height: 24),
          _buildPaymentButton(),
          if (_paymentError != null) 
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _paymentError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('order_summary'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryItem(
              title: widget.pricingPlan.name,
              value: widget.pricingPlan.formattedPrice,
              isTotal: false,
            ),
            if (widget.exam != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  widget.exam!.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkGrey,
                  ),
                ),
              ),
            if (widget.pricingPlan.examName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'For: ${widget.pricingPlan.examName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkGrey,
                  ),
                ),
              ),
            const Divider(height: 24),
            _buildSummaryItem(
              title: 'Total',
              value: widget.pricingPlan.formattedPrice,
              isTotal: true,
            ),
            const SizedBox(height: 8),
            Text(
              widget.pricingPlan.isSubscription 
                ? 'Recurring ${widget.pricingPlan.billingCycle.toLowerCase()} billing' 
                : 'One-time payment',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
            if (widget.pricingPlan.trialDays > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${widget.pricingPlan.trialDays}-day free trial included',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required String title,
    required String value,
    required bool isTotal,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.darkBlue : AppColors.darkGrey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.darkBlue : AppColors.darkGrey,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('payment_method'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPaymentMethodOption(
                title: context.tr('credit_card'),
                icon: Icons.credit_card,
                value: 'card',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaymentMethodOption(
                title: 'PayPal',
                icon: Icons.payment,
                value: 'paypal',
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPaymentMethodOption({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.limeYellow.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.darkBlue : Colors.grey.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.darkBlue : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.darkBlue : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentForm() {
    if (_selectedPaymentMethod == 'paypal') {
      return _buildPayPalForm();
    }
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('card_details'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cardNumberController,
            decoration: InputDecoration(
              labelText: context.tr('card_number'),
              hintText: 'XXXX XXXX XXXX XXXX',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.credit_card),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.tr('required_field');
              }
              if (value.replaceAll(' ', '').length < 16) {
                return context.tr('invalid_card_number');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryDateController,
                  decoration: InputDecoration(
                    labelText: context.tr('expiry_date'),
                    hintText: 'MM/YY',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('required_field');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  decoration: InputDecoration(
                    labelText: context.tr('cvv'),
                    hintText: 'XXX',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('required_field');
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cardHolderNameController,
            decoration: InputDecoration(
              labelText: context.tr('card_holder_name'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.tr('required_field');
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildPayPalForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.payment,
            size: 48,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('paypal_redirect_message'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _selectedPaymentMethod == 'paypal'
                    ? context.tr('continue_to_paypal')
                    : context.tr('pay_now', params: {'amount': planPrice}),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
  
  Widget _buildPaymentSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('payment_successful'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSubscription
                ? context.tr('subscription_success_message')
                : context.tr('purchase_success_message'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to subscription success screen
                Navigator.of(context).pushReplacementNamed('/subscription/success');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                context.tr('continue_to_dashboard'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 