import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.conf import settings
from assessment.models import UserAnswer
from .tasks import evaluate_user_answer

logger = logging.getLogger(__name__)

@receiver(post_save, sender=UserAnswer)
def queue_user_answer_evaluation(sender, instance, created, **kwargs):
    """
    Signal handler to automatically queue user answers for AI evaluation.
    This runs when a UserAnswer is created or updated.
    """
    # Only process if the answer is in PENDING status and is an eligible question type
    if (
        instance.evaluation_status == 'PENDING' and 
        instance.question.question_type in ['OPEN_ENDED', 'CALCULATION']
    ):
        # Check if Celery is configured and available
        # For development/testing without Celery, skip the async task
        try:
            # Try to check if Celery is available
            from celery import current_app
            # If we're in testing mode or Celery is not properly configured, skip
            if (
                hasattr(settings, 'TESTING') and settings.TESTING or
                not hasattr(settings, 'CELERY_BROKER_URL') or
                settings.CELERY_BROKER_URL == 'redis://localhost:6379'  # Default Redis that might not be running
            ):
                logger.info(f"Skipping Celery queue for user answer {instance.id} - using direct evaluation instead")
                # In development/testing, perform direct evaluation
                from .services import AIAnswerEvaluationService
                # Use a background thread to avoid blocking the request
                import threading
                thread = threading.Thread(
                    target=AIAnswerEvaluationService.evaluate_user_answer,
                    args=(instance.id,)
                )
                thread.daemon = True
                thread.start()
                return
            
            logger.info(f"Queueing evaluation for user answer {instance.id}")
            # Queue the task asynchronously via Celery
            evaluate_user_answer.delay(instance.id)
        except Exception as e:
            logger.warning(f"Failed to queue evaluation for user answer {instance.id}: {e}")
            # Fall back to direct evaluation
            try:
                from .services import AIAnswerEvaluationService
                import threading
                thread = threading.Thread(
                    target=AIAnswerEvaluationService.evaluate_user_answer,
                    args=(instance.id,)
                )
                thread.daemon = True
                thread.start()
            except Exception as fallback_error:
                logger.error(f"Failed to perform fallback evaluation for user answer {instance.id}: {fallback_error}") 