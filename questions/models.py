from django.db import models
from users.models import User
from exams.models import Exam

class Topic(models.Model):
    """Topic model for organizing questions."""
    name = models.CharField(max_length=255, unique=True, db_index=True)
    slug = models.SlugField(max_length=255, unique=True, db_index=True)
    description = models.TextField(null=True, blank=True)
    parent_topic = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='child_topics')
    display_order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'questions_topic'
        indexes = [
            models.Index(fields=['parent_topic', 'display_order']),
        ]

    def __str__(self):
        return self.name

class Tag(models.Model):
    """Tag model for categorizing questions."""
    name = models.CharField(max_length=100, unique=True, db_index=True)
    slug = models.SlugField(max_length=100, unique=True, db_index=True)
    description = models.TextField(null=True, blank=True)

    class Meta:
        db_table = 'questions_tag'

    def __str__(self):
        return self.name

class Question(models.Model):
    """Question model for storing various types of questions."""
    QUESTION_TYPES = (
        ('MCQ', 'Multiple Choice Question'),
        ('OPEN_ENDED', 'Open Ended Question'),
        ('CALCULATION', 'Calculation Question'),
    )
    DIFFICULTY_LEVELS = (
        ('EASY', 'Easy'),
        ('MEDIUM', 'Medium'),
        ('HARD', 'Hard'),
    )

    exam = models.ForeignKey(Exam, on_delete=models.PROTECT, related_name='questions', db_index=True,
                            help_text="The most specific exam/category/subject this question belongs to.")
    topic = models.ForeignKey(Topic, on_delete=models.SET_NULL, null=True, blank=True, related_name='questions',
                            help_text="Optional secondary categorization within an exam.")
    text = models.TextField()
    question_type = models.CharField(max_length=20, choices=QUESTION_TYPES, db_index=True)
    difficulty = models.CharField(max_length=10, choices=DIFFICULTY_LEVELS, db_index=True)
    estimated_time_seconds = models.IntegerField(default=60)
    points = models.IntegerField(default=1)
    model_answer_text = models.TextField(null=True, blank=True)
    model_calculation_logic = models.JSONField(null=True, blank=True)
    is_active = models.BooleanField(default=True, db_index=True)
    answer_explanation = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_questions')
    last_updated_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='updated_questions')
    tags = models.ManyToManyField(Tag, related_name='questions', through='QuestionTag')

    class Meta:
        db_table = 'questions_question'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['exam', 'topic', 'question_type', 'difficulty', 'is_active']),
        ]

    def __str__(self):
        return f"{self.text[:50]}..."

class MCQChoice(models.Model):
    """Multiple choice options for MCQ questions."""
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name='mcqchoice_set')
    choice_text = models.TextField()
    is_correct = models.BooleanField(default=False)
    display_order = models.IntegerField(default=0)
    explanation = models.TextField(null=True, blank=True)

    class Meta:
        db_table = 'questions_mcqchoice'
        indexes = [
            models.Index(fields=['question', 'display_order']),
        ]

    def __str__(self):
        return self.choice_text[:50]

class QuestionTag(models.Model):
    """Many-to-many relationship between Question and Tag."""
    question = models.ForeignKey(Question, on_delete=models.CASCADE)
    tag = models.ForeignKey(Tag, on_delete=models.CASCADE)

    class Meta:
        db_table = 'questions_question_tags'
        unique_together = ('question', 'tag') 