from django.core.management.base import BaseCommand
from django.db.models import Q
from assessment.models import ExamSession
from exams.models import Exam
from questions.models import Question


class Command(BaseCommand):
    help = 'Set exam field for existing ExamSession records based on their questions'

    def handle(self, *args, **options):
        # Get or create a default exam
        default_exam = Exam.objects.filter(
            Q(name__icontains='default') | Q(slug='default')
        ).first()
        
        if not default_exam:
            self.stdout.write(self.style.WARNING('Creating default exam...'))
            default_exam = Exam.objects.create(
                name='Default Exam',
                slug='default',
                description='Default exam for legacy data',
                is_active=True
            )
        
        # Process each ExamSession without an explicit exam set
        count = 0
        sessions = ExamSession.objects.filter(exam=default_exam)
        total = sessions.count()
        
        self.stdout.write(f'Found {total} exam sessions with default exam. Setting proper exam_id...')
        
        for session in sessions:
            # Get the first question's exam as the exam for the session
            first_question = Question.objects.filter(
                examsessionquestion__exam_session=session
            ).first()
            
            if first_question and first_question.exam_id != default_exam.id:
                session.exam_id = first_question.exam_id
                session.save(update_fields=['exam_id'])
                count += 1
                
        self.stdout.write(
            self.style.SUCCESS(f'Successfully updated {count} out of {total} exam sessions.')
        ) 