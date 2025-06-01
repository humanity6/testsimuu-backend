import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/language_selector.dart';
import '../../services/localization_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Simulating API call
        await Future.delayed(const Duration(seconds: 1));
        
        // In a real app, send data to backend
        // final response = await http.post(
        //   Uri.parse('${ApiConfig.baseUrl}/api/v1/support'),
        //   body: {
        //     'email': _emailController.text,
        //     'message': _messageController.text,
        //   },
        // );
        
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting form: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('help_and_support')),
        actions: const [
          LanguageSelector(),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _submitted ? _buildSuccessMessage(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            localizationService.translate('message_sent_successfully'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            localizationService.translate('we_will_get_back_to_you'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _submitted = false;
                _emailController.clear();
                _messageController.clear();
              });
            },
            child: Text(localizationService.translate('send_another_message')),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizationService.translate('how_can_we_help'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: localizationService.translate('your_email'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizationService.translate('please_enter_your_email');
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return localizationService.translate('please_enter_valid_email');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: localizationService.translate('your_message'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizationService.translate('please_enter_your_message');
                  }
                  if (value.length < 10) {
                    return localizationService.translate('message_too_short');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text(localizationService.translate('submit')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Text(
          localizationService.translate('or_contact_us'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.email),
            title: Text(localizationService.translate('email')),
            subtitle: const Text('support@testsimu.com'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(localizationService.translate('faq')),
            subtitle: Text(localizationService.translate('browse_common_questions')),
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/faq');
              },
              child: Text(localizationService.translate('view_faqs')),
            ),
          ),
        ),
      ],
    );
  }
} 