from django.apps import AppConfig


class AIIntegrationConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ai_integration'
    
    def ready(self):
        import ai_integration.signals 