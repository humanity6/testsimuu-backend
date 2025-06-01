import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../theme.dart';

class LanguageSelector extends StatefulWidget {
  final bool isCompact;
  
  const LanguageSelector({
    Key? key,
    this.isCompact = false,
  }) : super(key: key);

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  bool _isChanging = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, _) {
        final currentLocale = localizationService.currentLocale;
        
        if (widget.isCompact) {
          return _buildCompactSelector(context, currentLocale, localizationService);
        } else {
          return _buildFullSelector(context, currentLocale, localizationService);
        }
      },
    );
  }
  
  Widget _buildCompactSelector(
    BuildContext context, 
    Locale currentLocale, 
    LocalizationService localizationService
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBlueTransparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageButton(
            context, 
            'EN', 
            const Locale('en', 'US'), 
            currentLocale, 
            localizationService,
            true
          ),
          _buildLanguageButton(
            context, 
            'DE', 
            const Locale('de', 'DE'), 
            currentLocale, 
            localizationService,
            true
          ),
        ],
      ),
    );
  }
  
  Widget _buildFullSelector(
    BuildContext context, 
    Locale currentLocale, 
    LocalizationService localizationService
  ) {
    return PopupMenuButton<Locale>(
      tooltip: localizationService.translate('select_language'),
      enabled: !_isChanging,
      onSelected: (Locale locale) {
        _changeLanguage(locale, localizationService);
      },
      itemBuilder: (BuildContext context) {
        return LocalizationService.supportedLocales.map((Locale locale) {
          final isSelected = currentLocale.languageCode == locale.languageCode;
          return PopupMenuItem<Locale>(
            value: locale,
            child: Row(
              children: [
                Text(
                  LocalizationService.getDisplayLanguage(locale),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.darkBlue : null,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: AppColors.darkBlue,
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkBlue.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isChanging) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              LocalizationService.getDisplayLanguage(currentLocale),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.darkBlue,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_drop_down,
              color: AppColors.darkBlue,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLanguageButton(
    BuildContext context, 
    String label, 
    Locale locale, 
    Locale currentLocale, 
    LocalizationService localizationService,
    bool isCompact
  ) {
    final isSelected = currentLocale.languageCode == locale.languageCode;
    
    return InkWell(
      onTap: _isChanging ? null : () {
        _changeLanguage(locale, localizationService);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 16, 
          vertical: isCompact ? 8 : 10
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isChanging && isSelected 
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSelected ? AppColors.white : AppColors.darkBlue
                ),
              ),
            )
          : Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.white : AppColors.darkBlue,
                fontSize: isCompact ? 12 : 14,
              ),
            ),
      ),
    );
  }

  Future<void> _changeLanguage(Locale locale, LocalizationService localizationService) async {
    if (_isChanging || locale.languageCode == localizationService.currentLocale.languageCode) {
      return;
    }

    setState(() {
      _isChanging = true;
    });

    try {
      await localizationService.changeLocale(locale);
      
      // Provide feedback using translation service
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizationService.translate('language_changed_to', params: {
                'language': LocalizationService.getDisplayLanguage(locale)
              }),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizationService.translate('language_change_failed', params: {
              'error': e.toString()
            })),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChanging = false;
        });
      }
    }
  }
} 