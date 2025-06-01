from rest_framework import serializers
from django.db.models import Sum, Count, Avg, F, FloatField
from django.db.models.functions import Coalesce
from .models import UserPerformanceRecord, UserProgress


class PerformanceSummarySerializer(serializers.Serializer):
    """Serializer for aggregated user performance metrics."""
    total_questions = serializers.IntegerField()
    correct_answers = serializers.IntegerField()
    partially_correct_answers = serializers.IntegerField()
    total_points_earned = serializers.FloatField()
    total_points_possible = serializers.FloatField()
    total_time_spent_seconds = serializers.IntegerField()
    accuracy = serializers.FloatField()
    average_time_per_question = serializers.FloatField()
    # Frontend compatibility fields
    completed_sessions = serializers.IntegerField()
    average_score = serializers.FloatField()
    start_date = serializers.DateField(read_only=True)
    end_date = serializers.DateField(read_only=True)


class TopicSerializer(serializers.Serializer):
    """Serializer for topic information in performance breakdowns."""
    id = serializers.IntegerField()
    name = serializers.CharField()
    slug = serializers.CharField()
    parent_topic_id = serializers.IntegerField(source='parent_topic.id', allow_null=True)
    parent_topic_name = serializers.CharField(source='parent_topic.name', allow_null=True)


class PerformanceByTopicSerializer(serializers.Serializer):
    """Serializer for performance metrics grouped by topic."""
    topic = TopicSerializer()
    topic_name = serializers.CharField(source='topic.name', read_only=True)
    questions_answered = serializers.IntegerField()
    correct_answers = serializers.IntegerField()
    partially_correct_answers = serializers.IntegerField()
    total_points_earned = serializers.FloatField()
    total_points_possible = serializers.FloatField()
    total_time_spent_seconds = serializers.IntegerField()
    accuracy = serializers.FloatField()
    average_time_per_question = serializers.FloatField()


class PerformanceByDifficultySerializer(serializers.Serializer):
    """Serializer for performance metrics grouped by difficulty level."""
    difficulty = serializers.CharField()
    questions_answered = serializers.IntegerField()
    correct_answers = serializers.IntegerField()
    partially_correct_answers = serializers.IntegerField()
    total_points_earned = serializers.FloatField()
    total_points_possible = serializers.FloatField()
    total_time_spent_seconds = serializers.IntegerField()
    accuracy = serializers.FloatField()
    average_time_per_question = serializers.FloatField()


class PerformanceTrendPointSerializer(serializers.Serializer):
    """Serializer for a single data point in performance trends."""
    date = serializers.DateField()
    questions_answered = serializers.IntegerField()
    correct_answers = serializers.IntegerField()
    accuracy = serializers.FloatField()
    points_earned = serializers.FloatField()


class PerformanceTrendsSerializer(serializers.Serializer):
    """Serializer for performance trends over time."""
    time_unit = serializers.CharField()
    data_points = PerformanceTrendPointSerializer(many=True)


class TopicProgressSerializer(serializers.Serializer):
    """Serializer for user progress in a topic."""
    topic_id = serializers.IntegerField()
    topic_name = serializers.CharField()
    topic_slug = serializers.CharField()
    parent_topic_id = serializers.IntegerField(allow_null=True)
    parent_topic_name = serializers.CharField(allow_null=True)
    total_questions_in_topic = serializers.IntegerField()
    questions_attempted = serializers.IntegerField()
    questions_mastered = serializers.IntegerField()
    proficiency_level = serializers.CharField()
    completion_percentage = serializers.FloatField()
    last_activity_date = serializers.DateTimeField() 