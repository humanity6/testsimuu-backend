from django.core.management.base import BaseCommand
from django.db import transaction
from analytics.services import AnalyticsService
from analytics.models import UserPerformanceRecord
from django.contrib.auth import get_user_model
import logging

logger = logging.getLogger(__name__)
User = get_user_model()


class Command(BaseCommand):
    help = 'Validate and fix analytics data to ensure accurate calculations'

    def add_arguments(self, parser):
        parser.add_argument(
            '--user-id',
            type=int,
            help='Validate analytics for a specific user ID only',
        )
        parser.add_argument(
            '--fix',
            action='store_true',
            help='Actually fix the inconsistencies (default is dry-run)',
        )
        parser.add_argument(
            '--delete-dummy',
            action='store_true',
            help='Delete analytics records that appear to be dummy data',
        )

    def handle(self, *args, **options):
        user_id = options.get('user_id')
        fix_mode = options.get('fix', False)
        delete_dummy = options.get('delete_dummy', False)

        self.stdout.write(
            self.style.SUCCESS('Starting analytics validation...')
        )

        if not fix_mode:
            self.stdout.write(
                self.style.WARNING('Running in DRY-RUN mode. Use --fix to apply changes.')
            )

        # Filter by user if specified
        queryset = UserPerformanceRecord.objects.all()
        if user_id:
            try:
                user = User.objects.get(id=user_id)
                queryset = queryset.filter(user=user)
                self.stdout.write(f"Validating analytics for user: {user.username} (ID: {user_id})")
            except User.DoesNotExist:
                self.stdout.write(
                    self.style.ERROR(f'User with ID {user_id} does not exist')
                )
                return

        total_records = queryset.count()
        self.stdout.write(f"Found {total_records} analytics records to validate")

        inconsistent_records = 0
        dummy_records = 0
        fixed_records = 0
        deleted_records = 0

        with transaction.atomic():
            for record in queryset:
                is_inconsistent = False
                is_dummy = False

                # Check for calculation inconsistencies
                if record.questions_answered > 0:
                    expected_accuracy = record.correct_answers / record.questions_answered
                    accuracy_diff = abs(expected_accuracy - record.accuracy)
                    
                    if accuracy_diff > 0.0001:  # Allow small floating point differences
                        is_inconsistent = True
                        inconsistent_records += 1
                        self.stdout.write(
                            self.style.WARNING(
                                f"Record ID {record.id}: Accuracy mismatch. "
                                f"Expected: {expected_accuracy:.4f}, Got: {record.accuracy:.4f}"
                            )
                        )

                # Check for dummy data indicators
                if self._is_dummy_data(record):
                    is_dummy = True
                    dummy_records += 1
                    self.stdout.write(
                        self.style.WARNING(
                            f"Record ID {record.id}: Appears to be dummy data"
                        )
                    )

                # Fix inconsistencies if in fix mode
                if fix_mode and is_inconsistent:
                    if record.questions_answered > 0:
                        # Recalculate accuracy
                        record.accuracy = record.correct_answers / record.questions_answered
                        # Recalculate average time
                        record.average_time_per_question = (
                            record.total_time_spent_seconds / record.questions_answered
                            if record.questions_answered > 0 else 0
                        )
                        record.save()
                        fixed_records += 1

                # Delete dummy data if requested
                if fix_mode and delete_dummy and is_dummy:
                    record.delete()
                    deleted_records += 1

        # Summary report
        self.stdout.write("\n" + "="*50)
        self.stdout.write(self.style.SUCCESS("VALIDATION SUMMARY"))
        self.stdout.write("="*50)
        self.stdout.write(f"Total records processed: {total_records}")
        self.stdout.write(f"Inconsistent records found: {inconsistent_records}")
        self.stdout.write(f"Dummy data records found: {dummy_records}")

        if fix_mode:
            self.stdout.write(f"Records fixed: {fixed_records}")
            if delete_dummy:
                self.stdout.write(f"Dummy records deleted: {deleted_records}")
        else:
            self.stdout.write(
                self.style.WARNING("No changes made (dry-run mode). Use --fix to apply changes.")
            )

        # Run the service validation method if fixing
        if fix_mode:
            self.stdout.write("\nRunning comprehensive validation...")
            service_fixed = AnalyticsService.validate_and_fix_analytics_consistency()
            self.stdout.write(f"Service validation fixed: {service_fixed} additional records")

        self.stdout.write(
            self.style.SUCCESS('\nAnalytics validation completed!')
        )

    def _is_dummy_data(self, record):
        """
        Detect if a record appears to be dummy/fake data.
        This checks for patterns typical of randomly generated data.
        """
        # Check for unrealistic accuracy patterns
        if record.accuracy and (
            record.accuracy == 0.8 or  # Common dummy value
            record.accuracy == 0.85 or  # Common dummy value
            record.accuracy == 0.9 or  # Common dummy value
            record.accuracy == 0.95  # Common dummy value
        ):
            # If accuracy is exactly these common dummy values AND
            # the calculated accuracy doesn't match, it's likely dummy
            if record.questions_answered > 0:
                actual_accuracy = record.correct_answers / record.questions_answered
                if abs(actual_accuracy - record.accuracy) > 0.01:
                    return True

        # Check for unrealistic time patterns
        if record.average_time_per_question and (
            60 <= record.average_time_per_question <= 120 and
            record.average_time_per_question % 1 == 0  # Exact whole numbers are suspicious
        ):
            return True

        # Check for unrealistic point patterns
        if (record.total_points_possible == 50 and 
            40 <= record.total_points_earned <= 50):
            # This matches the dummy data generator pattern
            return True

        return False 