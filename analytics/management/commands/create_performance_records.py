from django.core.management.base import BaseCommand
from django.db import transaction
from assessment.models import ExamSession
from analytics.services import AnalyticsService
import logging

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Create UserPerformanceRecord entries from completed exam sessions'

    def add_arguments(self, parser):
        parser.add_argument(
            '--session-id',
            type=int,
            help='Process only a specific session ID',
        )
        parser.add_argument(
            '--user-id',
            type=int,
            help='Process only sessions for a specific user ID',
        )
        parser.add_argument(
            '--limit',
            type=int,
            default=100,
            help='Maximum number of sessions to process (default: 100)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be done without making changes',
        )

    def handle(self, *args, **options):
        session_id = options['session_id']
        user_id = options['user_id']
        limit = options['limit']
        dry_run = options['dry_run']

        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN MODE - No changes will be made'))

        # Build query for completed sessions
        queryset = ExamSession.objects.filter(status='COMPLETED')
        
        if session_id:
            queryset = queryset.filter(id=session_id)
        elif user_id:
            queryset = queryset.filter(user_id=user_id)
        else:
            # For bulk operations, order by most recent first
            queryset = queryset.order_by('-actual_end_time')
        
        # Limit the number of sessions to process
        sessions = queryset[:limit]
        
        total_sessions = sessions.count()
        self.stdout.write(f'Found {total_sessions} completed sessions to process')
        
        if total_sessions == 0:
            self.stdout.write(self.style.WARNING('No sessions found to process'))
            return
        
        processed = 0
        errors = 0
        total_records_created = 0
        
        for session in sessions:
            try:
                self.stdout.write(f'Processing session {session.id} (User: {session.user.email})')
                
                if not dry_run:
                    records_created = AnalyticsService.create_performance_records_from_session(session)
                    total_records_created += records_created
                    self.stdout.write(
                        self.style.SUCCESS(f'  ✓ Created {records_created} performance records')
                    )
                else:
                    # In dry run, just show what would be processed
                    from assessment.models import UserAnswer
                    answer_count = UserAnswer.objects.filter(exam_session=session).count()
                    self.stdout.write(f'  Would process {answer_count} answers')
                
                processed += 1
                
            except Exception as e:
                errors += 1
                self.stdout.write(
                    self.style.ERROR(f'  ✗ Error processing session {session.id}: {e}')
                )
                logger.error(f'Error processing session {session.id}: {e}', exc_info=True)
        
        # Summary
        self.stdout.write('\n' + '='*50)
        self.stdout.write(f'SUMMARY:')
        self.stdout.write(f'  Sessions processed: {processed}/{total_sessions}')
        self.stdout.write(f'  Errors: {errors}')
        
        if not dry_run:
            self.stdout.write(f'  Total performance records created: {total_records_created}')
            self.stdout.write(self.style.SUCCESS('✓ Performance records creation completed'))
        else:
            self.stdout.write(self.style.WARNING('✓ Dry run completed - no changes made')) 