from django.db import models
from users.models import User
from questions.models import Topic

class UserPerformanceRecord(models.Model):
    """Model for tracking user performance by topic and question type."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='performance_records')
    topic = models.ForeignKey(Topic, null=True, blank=True, on_delete=models.SET_NULL, related_name='performance_records')
    question_type = models.CharField(max_length=20, null=True, blank=True, db_index=True)
    difficulty = models.CharField(max_length=10, null=True, blank=True)
    date_recorded = models.DateField(db_index=True)
    questions_answered = models.IntegerField(default=0)
    correct_answers = models.IntegerField(default=0)
    partially_correct_answers = models.IntegerField(default=0)
    total_points_earned = models.FloatField(default=0)
    total_points_possible = models.FloatField(default=0)
    total_time_spent_seconds = models.IntegerField(default=0)
    accuracy = models.FloatField(null=True, blank=True)
    average_time_per_question = models.FloatField(null=True, blank=True)

    class Meta:
        db_table = 'analytics_userperformancerecord'
        unique_together = ('user', 'topic', 'question_type', 'difficulty', 'date_recorded')

    def __str__(self):
        topic_name = self.topic.name if self.topic else "All Topics"
        return f"{self.user.username} - {topic_name} - {self.date_recorded}"

class UserProgress(models.Model):
    """Model for tracking user progress by topic."""
    PROFICIENCY_LEVELS = (
        ('BEGINNER', 'Beginner'),
        ('INTERMEDIATE', 'Intermediate'),
        ('ADVANCED', 'Advanced'),
        ('EXPERT', 'Expert'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='topic_progress')
    topic = models.ForeignKey(Topic, on_delete=models.CASCADE, related_name='user_progress')
    total_questions_in_topic = models.IntegerField()
    questions_attempted = models.IntegerField(default=0)
    questions_mastered = models.IntegerField(default=0)
    proficiency_level = models.CharField(max_length=20, choices=PROFICIENCY_LEVELS)
    last_activity_date = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'analytics_userprogress'
        unique_together = ('user', 'topic')

    def __str__(self):
        return f"{self.user.username} - {self.topic.name} - {self.proficiency_level}"

class StudySession(models.Model):
    """Model for tracking study sessions."""
    SESSION_SOURCE_CHOICES = (
        ('WEB', 'Web'),
        ('ANDROID', 'Android'),
        ('IOS', 'iOS'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='study_sessions')
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    topics_studied = models.JSONField()
    questions_answered = models.IntegerField()
    correct_answers = models.IntegerField()
    device_info = models.CharField(max_length=255, null=True, blank=True)
    session_source = models.CharField(max_length=10, choices=SESSION_SOURCE_CHOICES)

    class Meta:
        db_table = 'analytics_studysession'

    def __str__(self):
        return f"{self.user.username} - {self.start_time} to {self.end_time}" 