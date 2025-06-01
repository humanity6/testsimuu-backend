import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import 'dart:async';

class TestPaymentScreen extends StatefulWidget {
  final String checkoutId;
  
  const TestPaymentScreen({
    Key? key,
    required this.checkoutId,
  }) : super(key: key);

  @override
  State<TestPaymentScreen> createState() => _TestPaymentScreenState();
}

class _TestPaymentScreenState extends State<TestPaymentScreen> {
  bool _isProcessing = false;
  bool _paymentComplete = false;
  String? _paymentError;
  int _countdown = 5;
  Timer? _countdownTimer;
  
  @override
  void initState() {
    super.initState();
    _startCountdown();
  }
  
  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
        });
        
        if (_countdown <= 0) {
          timer.cancel();
          _simulatePayment();
        }
      }
    });
  }
  
  Future<void> _simulatePayment() async {
    setState(() {
      _isProcessing = true;
      _paymentError = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      
      if (authService.accessToken == null) {
        throw Exception('Authentication required');
      }
      
      // Verify the payment with the backend
      final success = await paymentService.verifyPayment(
        authService.accessToken!,
        widget.checkoutId,
      );
      
      setState(() {
        _isProcessing = false;
        _paymentComplete = success;
        if (!success) {
          _paymentError = 'Payment verification failed';
        }
      });
      
      // Auto redirect to success page after 2 seconds
      if (success) {
        Timer(const Duration(seconds: 2), () {
          Navigator.of(context).pushReplacementNamed('/subscription/success');
        });
      }
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _paymentError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
  
  void _simulateFailure() {
    setState(() {
      _paymentComplete = false;
      _paymentError = 'Payment cancelled by user';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(
              context.tr('app_title'),
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const Spacer(),
            const LanguageSelector(isCompact: true),
          ],
        ),
        leading: _paymentComplete ? null : IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (_paymentComplete) {
      return _buildSuccessContent();
    } else if (_paymentError != null) {
      return _buildErrorContent();
    } else if (_isProcessing) {
      return _buildProcessingContent();
    } else {
      return _buildSimulationContent();
    }
  }
  
  Widget _buildSimulationContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.payment,
            size: 80,
            color: AppColors.darkBlue,
          ),
          const SizedBox(height: 24),
          Text(
            'Test Payment Gateway',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'This is a simulated payment environment for testing purposes.',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.limeYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.limeYellow),
            ),
            child: Column(
              children: [
                Text(
                  'Transaction ID: ${widget.checkoutId}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: AppColors.darkGrey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Auto-processing payment in $_countdown seconds...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (5 - _countdown) / 5,
                  backgroundColor: AppColors.lightGrey,
                  color: AppColors.darkBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _simulatePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Complete Payment Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _simulateFailure,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildProcessingContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
          ),
          const SizedBox(height: 24),
          Text(
            'Processing Payment...',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please wait while we verify your payment.',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Successful!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your subscription has been activated successfully.',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Redirecting to dashboard...',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Failed',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _paymentError ?? 'An error occurred during payment processing.',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkBlue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (route) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkBlue,
                    side: const BorderSide(color: AppColors.darkBlue),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 