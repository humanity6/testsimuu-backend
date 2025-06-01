from django.utils import timezone
from django.db import transaction
from collections import defaultdict
from .models import UserPerformanceRecord
from assessment.models import UserAnswer
import logging
from decimal import Decimal, ROUND_HALF_UP

logger = logging.getLogger(__name__)


class AnalyticsService:
    """Service for managing analytics data creation and updates."""
    
    @staticmethod
    @transaction.atomic
    def create_performance_records_from_session(exam_session):
        """
        Create UserPerformanceRecord entries from a completed exam session.
        Groups performance data by topic, question type, and difficulty.
        """
        if exam_session.status != 'COMPLETED':
            logger.warning(f"Cannot create performance records for incomplete session {exam_session.id}")
            return 0

        # Get all answers for this session
        answers = UserAnswer.objects.filter(
            exam_session=exam_session,
            user=exam_session.user
        ).select_related('question', 'question__topic')

        if not answers.exists():
            logger.warning(f"No answers found for session {exam_session.id}")
            return 0

        # Group answers by (topic, question_type, difficulty)
        performance_groups = defaultdict(list)

        for answer in answers:
            question = answer.question
            topic = question.topic
            question_type = question.question_type
            difficulty = question.difficulty

            # Create a unique key for grouping
            key = (
                topic.id if topic else None,
                question_type,
                difficulty
            )
            performance_groups[key].append(answer)

        # Create or update performance records for each group
        records_created = 0
        date_recorded = exam_session.actual_end_time.date() if exam_session.actual_end_time else timezone.now().date()

        for (topic_id, question_type, difficulty), grouped_answers in performance_groups.items():
            try:
                # Calculate metrics for this group with proper validation
                questions_answered = len(grouped_answers)
                
                # Ensure we have valid answers to process
                if questions_answered == 0:
                    continue
                
                # Count correct and partially correct answers
                correct_answers = 0
                partially_correct_answers = 0
                
                for answer in grouped_answers:
                    if answer.is_correct is True:
                        correct_answers += 1
                    elif answer.is_correct is None:  # Partially correct
                        partially_correct_answers += 1

                # Calculate point totals with validation
                total_points_earned = Decimal('0.0')
                total_points_possible = Decimal('0.0')
                total_time_spent = 0

                for answer in grouped_answers:
                    # Safely handle None values for scores and convert to Decimal
                    raw_score = answer.raw_score if answer.raw_score is not None else 0
                    max_score = answer.max_possible_score if answer.max_possible_score is not None else 0
                    time_spent = answer.time_spent_seconds if answer.time_spent_seconds is not None else 0

                    # Convert to Decimal to ensure consistent types
                    total_points_earned += Decimal(str(raw_score))
                    total_points_possible += Decimal(str(max_score))
                    total_time_spent += time_spent

                # Calculate derived metrics with proper validation
                accuracy = (correct_answers / questions_answered) if questions_answered > 0 else 0.0
                avg_time_per_question = (total_time_spent / questions_answered) if questions_answered > 0 else 0.0

                # Round accuracy to 4 decimal places to avoid floating point issues
                accuracy = float(Decimal(str(accuracy)).quantize(Decimal('0.0001'), rounding=ROUND_HALF_UP))
                avg_time_per_question = float(Decimal(str(avg_time_per_question)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))

                # Validate that accuracy is between 0 and 1
                accuracy = max(0.0, min(1.0, accuracy))

                # Get or create the performance record for this date
                topic_obj = None
                if topic_id:
                    from questions.models import Topic
                    try:
                        topic_obj = Topic.objects.get(id=topic_id)
                    except Topic.DoesNotExist:
                        logger.warning(f"Topic {topic_id} not found")

                # Try to get existing record for this combination
                performance_record, created = UserPerformanceRecord.objects.get_or_create(
                    user=exam_session.user,
                    topic=topic_obj,
                    question_type=question_type,
                    difficulty=difficulty,
                    date_recorded=date_recorded,
                    defaults={
                        'questions_answered': questions_answered,
                        'correct_answers': correct_answers,
                        'partially_correct_answers': partially_correct_answers,
                        'total_points_earned': float(total_points_earned),
                        'total_points_possible': float(total_points_possible),
                        'total_time_spent_seconds': total_time_spent,
                        'accuracy': accuracy,
                        'average_time_per_question': avg_time_per_question,
                    }
                )

                if not created:
                    # Update existing record by adding the new data
                    performance_record.questions_answered += questions_answered
                    performance_record.correct_answers += correct_answers
                    performance_record.partially_correct_answers += partially_correct_answers
                    performance_record.total_points_earned += float(total_points_earned)
                    performance_record.total_points_possible += float(total_points_possible)
                    performance_record.total_time_spent_seconds += total_time_spent

                    # Recalculate derived metrics with proper validation
                    if performance_record.questions_answered > 0:
                        new_accuracy = (performance_record.correct_answers / performance_record.questions_answered)
                        new_avg_time = (performance_record.total_time_spent_seconds / performance_record.questions_answered)
                        
                        # Round and validate the new values
                        performance_record.accuracy = float(Decimal(str(new_accuracy)).quantize(Decimal('0.0001'), rounding=ROUND_HALF_UP))
                        performance_record.average_time_per_question = float(Decimal(str(new_avg_time)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))
                        
                        # Ensure accuracy is between 0 and 1
                        performance_record.accuracy = max(0.0, min(1.0, performance_record.accuracy))
                    else:
                        performance_record.accuracy = 0.0
                        performance_record.average_time_per_question = 0.0

                    performance_record.save()
                    logger.info(f"Updated performance record for user {exam_session.user.id}, topic {topic_id}, type {question_type}, difficulty {difficulty}")
                else:
                    logger.info(f"Created performance record for user {exam_session.user.id}, topic {topic_id}, type {question_type}, difficulty {difficulty}")

                records_created += 1

            except Exception as e:
                logger.error(f"Error creating performance record for group {(topic_id, question_type, difficulty)}: {e}")
                continue

        logger.info(f"Created/updated {records_created} performance records for session {exam_session.id}")
        return records_created

    @staticmethod
    def validate_and_fix_analytics_consistency():
        """
        Validate and fix any inconsistencies in analytics data.
        This method ensures that calculated fields match the raw data.
        """
        logger.info("Starting analytics data validation and consistency check...")
        
        fixed_records = 0
        total_records = UserPerformanceRecord.objects.count()
        
        for record in UserPerformanceRecord.objects.all():
            try:
                original_accuracy = record.accuracy
                original_avg_time = record.average_time_per_question
                
                # Recalculate accuracy
                if record.questions_answered > 0:
                    calculated_accuracy = record.correct_answers / record.questions_answered
                    calculated_avg_time = record.total_time_spent_seconds / record.questions_answered
                    
                    # Round and validate
                    calculated_accuracy = float(Decimal(str(calculated_accuracy)).quantize(Decimal('0.0001'), rounding=ROUND_HALF_UP))
                    calculated_avg_time = float(Decimal(str(calculated_avg_time)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))
                    
                    # Ensure accuracy is between 0 and 1
                    calculated_accuracy = max(0.0, min(1.0, calculated_accuracy))
                    
                    # Check if values need updating (with small tolerance for floating point differences)
                    if abs(calculated_accuracy - original_accuracy) > 0.0001 or abs(calculated_avg_time - original_avg_time) > 0.01:
                        record.accuracy = calculated_accuracy
                        record.average_time_per_question = calculated_avg_time
                        record.save()
                        fixed_records += 1
                        
                        logger.info(f"Fixed record {record.id}: accuracy {original_accuracy} -> {calculated_accuracy}, avg_time {original_avg_time} -> {calculated_avg_time}")
                
            except Exception as e:
                logger.error(f"Error validating record {record.id}: {e}")
                continue
        
        logger.info(f"Analytics validation completed: {fixed_records}/{total_records} records fixed")
        return fixed_records 