from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db import transaction
from decimal import Decimal, ROUND_HALF_UP
from analytics.models import UserPerformanceRecord
from analytics.services import AnalyticsService
from assessment.models import ExamSession, UserAnswer
from questions.models import Question, Topic
import random

User = get_user_model()


class Command(BaseCommand):
    help = 'Test analytics calculations by creating a sample exam session and verifying results'

    def add_arguments(self, parser):
        parser.add_argument(
            '--user-id',
            type=int,
            help='User ID to create test data for (default: creates or uses test user)',
        )

    def handle(self, *args, **options):
        self.stdout.write(
            self.style.SUCCESS('Starting analytics calculation test...')
        )

        # Get or create test user
        user_id = options.get('user_id')
        if user_id:
            try:
                user = User.objects.get(id=user_id)
                self.stdout.write(f"Using existing user: {user.username} (ID: {user_id})")
            except User.DoesNotExist:
                self.stdout.write(
                    self.style.ERROR(f'User with ID {user_id} does not exist')
                )
                return
        else:
            user, created = User.objects.get_or_create(
                username='analytics_test_user',
                defaults={
                    'email': 'analytics_test@example.com',
                    'first_name': 'Analytics',
                    'last_name': 'Test'
                }
            )
            if created:
                self.stdout.write(f"Created test user: {user.username}")
            else:
                self.stdout.write(f"Using existing test user: {user.username}")

        # Get some questions for testing
        questions = list(Question.objects.filter(is_active=True)[:10])
        if not questions:
            self.stdout.write(
                self.style.ERROR('No active questions found. Please ensure you have questions in the database.')
            )
            return

        self.stdout.write(f"Found {len(questions)} questions for testing")

        # Create a test exam session
        try:
            with transaction.atomic():
                exam_session = ExamSession.objects.create(
                    user=user,
                    exam=questions[0].exam,
                    session_type='PRACTICE',
                    status='COMPLETED',
                    start_time=timezone.now() - timezone.timedelta(hours=1),
                    end_time_expected=timezone.now() + timezone.timedelta(hours=1),
                    actual_end_time=timezone.now(),
                    total_possible_score=sum(q.points for q in questions),
                    pass_threshold=0.7,
                    time_limit_seconds=3600
                )

                self.stdout.write(f"Created test exam session: {exam_session.id}")

                # Create test answers with known values
                total_correct = 0
                total_questions = len(questions)
                total_points_earned = Decimal('0.0')
                total_points_possible = Decimal('0.0')

                for i, question in enumerate(questions):
                    # Alternate between correct and incorrect answers for predictable results
                    is_correct = i % 2 == 0
                    
                    if is_correct:
                        raw_score = Decimal(str(question.points))
                        total_correct += 1
                    else:
                        raw_score = Decimal('0.0')

                    total_points_earned += raw_score
                    total_points_possible += Decimal(str(question.points))

                    answer = UserAnswer.objects.create(
                        user=user,
                        question=question,
                        exam_session=exam_session,
                        submitted_answer_text=f"Test answer {i+1}",
                        raw_score=raw_score,
                        max_possible_score=Decimal(str(question.points)),
                        is_correct=is_correct,
                        time_spent_seconds=60 + (i * 10),  # Varying time
                        evaluation_status='COMPLETED',
                        submission_time=timezone.now()
                    )

                # Update exam session totals
                exam_session.total_score_achieved = total_points_earned
                exam_session.passed = total_points_earned >= (total_points_possible * Decimal('0.7'))
                exam_session.save()

                self.stdout.write(f"Created {total_questions} test answers")
                self.stdout.write(f"Expected accuracy: {total_correct}/{total_questions} = {total_correct/total_questions:.4f}")
                self.stdout.write(f"Expected points: {total_points_earned}/{total_points_possible}")

                # Clear any existing analytics for this user to avoid conflicts
                UserPerformanceRecord.objects.filter(user=user).delete()
                self.stdout.write("Cleared existing analytics records for test user")

                # Now create analytics records using the service
                records_created = AnalyticsService.create_performance_records_from_session(exam_session)
                self.stdout.write(f"Service created {records_created} analytics records")

                # Verify the analytics calculations
                analytics_records = UserPerformanceRecord.objects.filter(user=user)
                
                self.stdout.write("\n" + "="*60)
                self.stdout.write(self.style.SUCCESS("ANALYTICS VERIFICATION"))
                self.stdout.write("="*60)

                total_analytics_questions = 0
                total_analytics_correct = 0
                
                for record in analytics_records:
                    # Calculate expected accuracy for this record
                    if record.questions_answered > 0:
                        calculated_accuracy = record.correct_answers / record.questions_answered
                        calculated_accuracy_rounded = float(
                            Decimal(str(calculated_accuracy)).quantize(Decimal('0.0001'), rounding=ROUND_HALF_UP)
                        )
                        
                        accuracy_match = abs(record.accuracy - calculated_accuracy_rounded) < 0.0001
                        
                        self.stdout.write(f"\nRecord ID: {record.id}")
                        self.stdout.write(f"  Topic: {record.topic.name if record.topic else 'No Topic'}")
                        self.stdout.write(f"  Difficulty: {record.difficulty}")
                        self.stdout.write(f"  Question Type: {record.question_type}")
                        self.stdout.write(f"  Questions: {record.questions_answered}")
                        self.stdout.write(f"  Correct: {record.correct_answers}")
                        self.stdout.write(f"  Stored Accuracy: {record.accuracy:.4f}")
                        self.stdout.write(f"  Calculated Accuracy: {calculated_accuracy_rounded:.4f}")
                        
                        if accuracy_match:
                            self.stdout.write(f"  ✓ Accuracy calculation is correct")
                        else:
                            self.stdout.write(f"  ✗ Accuracy calculation mismatch!")
                        
                        total_analytics_questions += record.questions_answered
                        total_analytics_correct += record.correct_answers

                # Overall verification
                self.stdout.write(f"\n" + "="*60)
                self.stdout.write("OVERALL VERIFICATION")
                self.stdout.write("="*60)
                self.stdout.write(f"Original exam session:")
                self.stdout.write(f"  Total questions: {total_questions}")
                self.stdout.write(f"  Total correct: {total_correct}")
                self.stdout.write(f"  Expected accuracy: {total_correct/total_questions:.4f}")
                
                self.stdout.write(f"\nAggregated analytics:")
                self.stdout.write(f"  Total questions: {total_analytics_questions}")
                self.stdout.write(f"  Total correct: {total_analytics_correct}")
                if total_analytics_questions > 0:
                    analytics_accuracy = total_analytics_correct / total_analytics_questions
                    self.stdout.write(f"  Calculated accuracy: {analytics_accuracy:.4f}")
                    
                    if abs((total_correct/total_questions) - analytics_accuracy) < 0.0001:
                        self.stdout.write(f"  ✓ Overall accuracy matches!")
                    else:
                        self.stdout.write(f"  ✗ Overall accuracy mismatch!")
                else:
                    self.stdout.write(f"  ✗ No analytics questions found!")

                # Test API endpoints
                self.stdout.write(f"\n" + "="*60)
                self.stdout.write("API ENDPOINT TEST")
                self.stdout.write("="*60)
                
                # Import here to avoid circular import
                from django.test import RequestFactory
                from analytics.views import PerformanceSummaryView
                
                factory = RequestFactory()
                request = factory.get('/api/analytics/performance-summary/')
                request.user = user
                
                view = PerformanceSummaryView()
                response = view.get(request)
                
                if response.status_code == 200:
                    api_data = response.data
                    self.stdout.write(f"✓ Performance summary API returned successfully")
                    self.stdout.write(f"  API Total Questions: {api_data.get('total_questions', 'N/A')}")
                    self.stdout.write(f"  API Correct Answers: {api_data.get('correct_answers', 'N/A')}")
                    self.stdout.write(f"  API Accuracy: {api_data.get('accuracy', 'N/A')}%")
                    
                    api_accuracy_decimal = (api_data.get('accuracy', 0) / 100.0)
                    expected_accuracy = total_correct / total_questions
                    
                    if abs(api_accuracy_decimal - expected_accuracy) < 0.01:
                        self.stdout.write(f"  ✓ API accuracy matches expected value!")
                    else:
                        self.stdout.write(f"  ✗ API accuracy mismatch! Expected: {expected_accuracy:.4f}, Got: {api_accuracy_decimal:.4f}")
                else:
                    self.stdout.write(f"✗ Performance summary API failed with status {response.status_code}")

        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error during test: {e}')
            )
            import traceback
            self.stdout.write(traceback.format_exc())
            return

        self.stdout.write(
            self.style.SUCCESS('\nAnalytics calculation test completed!')
        ) 