from rest_framework import serializers
from .models import Topic, Question, MCQChoice, Tag
from exams.models import Exam

class MCQChoiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = MCQChoice
        fields = ['id', 'choice_text', 'display_order']
        # Exclude is_correct to prevent exposing answers

class TopicSerializer(serializers.ModelSerializer):
    class Meta:
        model = Topic
        fields = ['id', 'name', 'slug', 'description', 'parent_topic_id', 'display_order']

class TopicDetailSerializer(serializers.ModelSerializer):
    parent_topic = TopicSerializer(read_only=True)
    
    class Meta:
        model = Topic
        fields = ['id', 'name', 'slug', 'description', 'parent_topic', 'parent_topic_id',
                 'display_order', 'is_active', 'created_at', 'updated_at']

class ExamSerializer(serializers.ModelSerializer):
    class Meta:
        model = Exam
        fields = ['id', 'name', 'slug', 'description', 'parent_exam_id', 'display_order']

class QuestionSerializer(serializers.ModelSerializer):
    topic_name = serializers.StringRelatedField(source='topic.name', read_only=True)
    topic_slug = serializers.SlugRelatedField(source='topic', slug_field='slug', read_only=True)
    exam_name = serializers.StringRelatedField(source='exam.name', read_only=True)
    exam_slug = serializers.SlugRelatedField(source='exam', slug_field='slug', read_only=True)
    mcq_choices = MCQChoiceSerializer(source='mcqchoice_set', many=True, read_only=True)
    choices = serializers.SerializerMethodField()
    
    class Meta:
        model = Question
        fields = ['id', 'text', 'question_type', 'difficulty', 'estimated_time_seconds', 
                 'points', 'exam_id', 'exam_name', 'exam_slug', 'topic_id', 'topic_name', 
                 'topic_slug', 'mcq_choices', 'choices']

    def get_choices(self, obj):
        """Return choices with the same data as mcq_choices for compatibility"""
        if obj.question_type != 'MCQ':
            return []
            
        # First try the related name
        choices = list(obj.mcqchoice_set.all())
        
        # If that fails, try direct query
        if not choices:
            choices = list(MCQChoice.objects.filter(question=obj))
            
        # Return serialized data
        return MCQChoiceSerializer(choices, many=True).data

class QuestionDetailSerializer(serializers.ModelSerializer):
    topic = TopicSerializer(read_only=True)
    exam = ExamSerializer(read_only=True)
    mcq_choices = MCQChoiceSerializer(source='mcqchoice_set', many=True, read_only=True)
    tags = serializers.StringRelatedField(many=True, read_only=True)
    
    class Meta:
        model = Question
        fields = ['id', 'text', 'question_type', 'difficulty', 'estimated_time_seconds', 
                 'points', 'exam', 'topic', 'mcq_choices', 'answer_explanation', 
                 'tags', 'created_at', 'updated_at'] 