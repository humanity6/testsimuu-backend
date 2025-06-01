from django.apps import AppConfig


class AffiliatesConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'affiliates'
    verbose_name = 'Affiliates'
    
    def ready(self):
        # Import signals if needed
        # import affiliates.signals
        pass 