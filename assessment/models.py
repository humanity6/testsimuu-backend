from django.db import models
from users.models import User
from questions.models import Question, MCQChoice
from exams.models import Exam
from django.db.models import Q

class ExamSession(models.Model):
    """Model for exam sessions."""
    SESSION_TYPE_CHOICES = (
        ('PRACTICE', 'Practice Mode'),
        ('REAL_EXAM', 'Real Exam Mode'),
        ('TIMED_EXAM', 'Timed Exam'),  # Legacy support
        ('ASSESSMENT', 'Assessment'),   # Legacy support
    )
    
    EXAM_TYPE_CHOICES = (
        ('FULL', 'Full Exam'),
        ('TOPIC_BASED', 'Topic-Based Exam'),
    )
    
    STATUS_CHOICES = (
        ('IN_PROGRESS', 'In Progress'),
        ('COMPLETED', 'Completed'),
        ('ABANDONED', 'Abandoned'),
    )

    EVALUATION_MODE_CHOICES = (
        ('REAL_TIME', 'Real-time Evaluation'),
        ('END_OF_EXAM', 'End of Exam Evaluation'),
    )

    def get_default_exam():
        """Get or create a default exam for legacy data."""
        # Try to find an exam with 'Default' in the name
        default_exam = Exam.objects.filter(
            Q(name__icontains='default') | Q(slug='default')
        ).first()
        
        # If no default exam exists, create one
        if not default_exam:
            default_exam = Exam.objects.create(
                name='Default Exam',
                slug='default',
                description='Default exam for legacy data',
                is_active=True
            )
        return default_exam.id

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='exam_sessions')
    exam = models.ForeignKey(Exam, on_delete=models.PROTECT, related_name='exam_sessions', db_index=True,
                           help_text="The exam or category this session belongs to.",
                           default=get_default_exam)
    title = models.CharField(max_length=255, null=True, blank=True)
    session_type = models.CharField(max_length=20, choices=SESSION_TYPE_CHOICES, db_index=True)
    exam_type = models.CharField(max_length=20, choices=EXAM_TYPE_CHOICES, default='FULL', db_index=True,
                                help_text="Whether this is a full exam or topic-based exam")
    evaluation_mode = models.CharField(max_length=20, choices=EVALUATION_MODE_CHOICES, default='REAL_TIME', db_index=True,
                                     help_text="When AI evaluation should occur")
    topic_ids = models.JSONField(null=True, blank=True, 
                               help_text="List of topic IDs for topic-based exams")
    start_time = models.DateTimeField(db_index=True)
    end_time_expected = models.DateTimeField()
    actual_end_time = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, db_index=True)
    total_score_achieved = models.FloatField(null=True, blank=True)
    total_possible_score = models.FloatField()
    pass_threshold = models.FloatField()
    passed = models.BooleanField(null=True, blank=True)
    time_limit_seconds = models.IntegerField()
    is_timed = models.BooleanField(default=True, 
                                 help_text="Whether this exam has a time limit (False for Practice Mode)")
    learning_material_viewed = models.BooleanField(default=False,
                                                 help_text="Whether user has viewed learning material before starting")
    metadata = models.JSONField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    questions = models.ManyToManyField(Question, through='ExamSessionQuestion')

    class Meta:
        db_table = 'assessment_examsession'
        indexes = [
            models.Index(fields=['user', 'status', 'start_time']),
            models.Index(fields=['exam', 'user']),
            models.Index(fields=['session_type', 'exam_type']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.session_type} - {self.start_time}"

    def is_practice_mode(self):
        """Check if this is a practice mode session."""
        return self.session_type == 'PRACTICE'

    def is_real_exam_mode(self):
        """Check if this is a real exam mode session."""
        return self.session_type == 'REAL_EXAM'

    def should_show_learning_material(self):
        """Check if learning material should be shown before exam."""
        return self.is_practice_mode() and not self.learning_material_viewed

    def get_evaluation_mode(self):
        """Get the appropriate evaluation mode based on session type."""
        if self.is_practice_mode():
            return 'REAL_TIME'
        elif self.is_real_exam_mode():
            return 'END_OF_EXAM'
        else:
            return self.evaluation_mode


class LearningMaterial(models.Model):
    """Model for storing learning materials for exams and topics."""
    MATERIAL_TYPE_CHOICES = (
        ('TEXT', 'Text Content'),
        ('VIDEO', 'Video'),
        ('PDF', 'PDF Document'),
        ('LINK', 'External Link'),
        ('INTERACTIVE', 'Interactive Content'),
    )

    exam = models.ForeignKey(Exam, on_delete=models.CASCADE, related_name='learning_materials')
    topic = models.ForeignKey('questions.Topic', on_delete=models.CASCADE, null=True, blank=True,
                            related_name='learning_materials',
                            help_text="Specific topic within the exam (optional)")
    title = models.CharField(max_length=255)
    description = models.TextField(null=True, blank=True)
    material_type = models.CharField(max_length=20, choices=MATERIAL_TYPE_CHOICES, default='TEXT')
    content = models.TextField(null=True, blank=True, 
                             help_text="Text content or HTML for display")
    file_url = models.URLField(null=True, blank=True,
                              help_text="URL for video, PDF, or external link")
    duration_minutes = models.IntegerField(null=True, blank=True,
                                         help_text="Estimated time to consume this material")
    display_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        db_table = 'assessment_learningmaterial'
        indexes = [
            models.Index(fields=['exam', 'display_order']),
            models.Index(fields=['topic', 'display_order']),
        ]
        ordering = ['display_order', 'title']

    def __str__(self):
        topic_info = f" - {self.topic.name}" if self.topic else ""
        return f"{self.exam.name}{topic_info}: {self.title}"


class ExamSessionQuestion(models.Model):
    """Through model for ExamSession and Question."""
    exam_session = models.ForeignKey(ExamSession, on_delete=models.CASCADE)
    question = models.ForeignKey(Question, on_delete=models.CASCADE)
    display_order = models.IntegerField(default=0)
    question_weight = models.FloatField(default=1.0)

    class Meta:
        db_table = 'assessment_examsession_questions'
        unique_together = ('exam_session', 'question')
        indexes = [
            models.Index(fields=['exam_session', 'display_order']),
        ]

class UserAnswer(models.Model):
    """Model for user answers to questions."""
    EVALUATION_STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('EVALUATED', 'Evaluated'),
        ('ERROR', 'Error'),
        ('MCQ_SCORED', 'MCQ Scored'),
        ('NOT_APPLICABLE', 'Not Applicable'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='answers')
    question = models.ForeignKey(Question, on_delete=models.PROTECT, related_name='user_answers')
    exam_session = models.ForeignKey(ExamSession, null=True, blank=True, on_delete=models.SET_NULL, related_name='user_answers')
    submitted_answer_text = models.TextField(null=True, blank=True)
    submitted_calculation_input = models.JSONField(null=True, blank=True)
    raw_score = models.FloatField(null=True, blank=True)
    weighted_score = models.FloatField(null=True, blank=True)
    max_possible_score = models.FloatField()
    is_correct = models.BooleanField(null=True, blank=True)
    ai_feedback = models.TextField(null=True, blank=True)
    human_feedback = models.TextField(null=True, blank=True)
    evaluation_status = models.CharField(max_length=20, choices=EVALUATION_STATUS_CHOICES, db_index=True)
    time_spent_seconds = models.IntegerField(null=True, blank=True)
    submission_time = models.DateTimeField(db_index=True)
    retry_count = models.IntegerField(default=0)
    metadata = models.JSONField(null=True, blank=True)
    mcq_choices = models.ManyToManyField(MCQChoice, through='UserAnswerMCQChoice')

    class Meta:
        db_table = 'assessment_useranswer'
        indexes = [
            models.Index(fields=['user', 'question', 'submission_time']),
            models.Index(fields=['exam_session', 'evaluation_status']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.question.text[:30]} - {self.submission_time}"

class UserAnswerMCQChoice(models.Model):
    """Through model for UserAnswer and MCQChoice for multiple choice questions."""
    user_answer = models.ForeignKey(UserAnswer, on_delete=models.CASCADE)
    mcq_choice = models.ForeignKey(MCQChoice, on_delete=models.CASCADE)

    class Meta:
        db_table = 'assessment_useranswer_mcq_choices'
        unique_together = ('user_answer', 'mcq_choice') 