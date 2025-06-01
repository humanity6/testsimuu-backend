from celery import shared_task
from .services import AIAnswerEvaluationService, ContentUpdateService
from .models import ContentUpdateScanConfig


@shared_task
def evaluate_user_answer(user_answer_id):
    """
    Celery task to evaluate a user answer asynchronously.
    """
    AIAnswerEvaluationService.evaluate_user_answer(user_answer_id)


@shared_task
def evaluate_user_answers_batch(user_answer_ids):
    """
    Celery task to evaluate a batch of user answers asynchronously.
    """
    for user_answer_id in user_answer_ids:
        AIAnswerEvaluationService.evaluate_user_answer(user_answer_id)


@shared_task
def run_content_update_scan(scan_config_id):
    """
    Celery task to run a content update scan for a specific configuration.
    """
    return ContentUpdateService.run_content_update_scan(scan_config_id)


@shared_task
def check_and_schedule_content_update_scans():
    """
    Celery task to check for due content update scans and schedule them.
    This task should be run by Celery Beat on a schedule (e.g., hourly).
    """
    due_configs = ContentUpdateService.get_due_scan_configs()
    scheduled_count = 0
    
    for config in due_configs:
        # Queue individual scan tasks
        run_content_update_scan.delay(config.id)
        scheduled_count += 1
    
    return f"Scheduled {scheduled_count} content update scans" 