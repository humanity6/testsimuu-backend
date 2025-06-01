from rest_framework import serializers
from questions.serializers import QuestionSerializer, MCQChoiceSerializer
from questions.models import MCQChoice, Topic
from exams.models import Exam
from .models import ExamSession, ExamSessionQuestion, UserAnswer, UserAnswerMCQChoice, LearningMaterial
from django.db import models
import logging

class LearningMaterialSerializer(serializers.ModelSerializer):
    """Serializer for learning materials."""
    
    class Meta:
        model = LearningMaterial
        fields = [
            'id', 'exam', 'topic', 'title', 'description', 'material_type',
            'content', 'file_url', 'duration_minutes', 'display_order', 'is_active'
        ]
        read_only_fields = ['id']

class ExamSessionSummarySerializer(serializers.ModelSerializer):
    """Lightweight serializer for exam sessions used in analytics/reports"""
    exam_name = serializers.CharField(source='exam.name', read_only=True)
    exam_slug = serializers.CharField(source='exam.slug', read_only=True)
    
    class Meta:
        model = ExamSession
        fields = [
            'id', 'user', 'exam', 'exam_name', 'exam_slug', 'title', 'session_type', 'exam_type',
            'evaluation_mode', 'start_time', 'end_time_expected', 'actual_end_time', 'status',
            'total_score_achieved', 'total_possible_score', 'pass_threshold',
            'passed', 'time_limit_seconds', 'is_timed', 'learning_material_viewed', 'created_at'
        ]
        read_only_fields = ['id', 'user', 'exam', 'start_time', 'total_score_achieved', 
                          'total_possible_score', 'passed', 'created_at']

class ExamSessionQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExamSessionQuestion
        fields = ['id', 'question', 'display_order', 'question_weight']
        read_only_fields = ['id']

class ExamSessionCreateSerializer(serializers.ModelSerializer):
    question_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        write_only=True
    )
    topic_id = serializers.IntegerField(required=False, write_only=True)
    topic_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        write_only=True,
        help_text="List of topic IDs for topic-based exams"
    )
    exam_id = serializers.IntegerField(required=True, write_only=True)
    num_questions = serializers.IntegerField(required=False, write_only=True, min_value=1)
    
    class Meta:
        model = ExamSession
        fields = [
            'id', 'session_type', 'exam_type', 'evaluation_mode', 'time_limit_seconds', 'is_timed', 'title',
            'question_ids', 'topic_id', 'topic_ids', 'exam_id', 'num_questions'
        ]
        read_only_fields = ['id']
    
    def validate_exam_id(self, value):
        try:
            # Validate that the exam exists and is active
            exam = Exam.objects.get(id=value, is_active=True)
            return value
        except Exam.DoesNotExist:
            raise serializers.ValidationError("Selected exam does not exist or is not active.")
    
    def validate_session_type(self, value):
        """Validate session type and set appropriate defaults."""
        valid_types = ['PRACTICE', 'REAL_EXAM', 'TIMED_EXAM', 'ASSESSMENT']
        if value not in valid_types:
            raise serializers.ValidationError(f"Invalid session type. Must be one of: {valid_types}")
        return value
    
    def validate(self, data):
        """Cross-field validation."""
        session_type = data.get('session_type')
        is_timed = data.get('is_timed', True)
        evaluation_mode = data.get('evaluation_mode')
        
        # Set defaults based on session type
        if session_type == 'PRACTICE':
            data['is_timed'] = False  # Practice mode is always untimed
            data['evaluation_mode'] = 'REAL_TIME'
        elif session_type == 'REAL_EXAM':
            data['is_timed'] = True  # Real exam is always timed
            data['evaluation_mode'] = 'END_OF_EXAM'
        
        return data
    
    def create(self, validated_data):
        # Extract non-model fields
        question_ids = validated_data.pop('question_ids', [])
        topic_id = validated_data.pop('topic_id', None)
        topic_ids = validated_data.pop('topic_ids', [])
        exam_id = validated_data.pop('exam_id', None)
        num_questions = validated_data.pop('num_questions', None)
        
        # Handle legacy topic_id by adding it to topic_ids list
        if topic_id and topic_id not in topic_ids:
            topic_ids.append(topic_id)
        
        # Add topic_ids to validated_data for model creation
        if topic_ids:
            validated_data['topic_ids'] = topic_ids
        
        # Add exam_id back into validated_data for model creation
        if exam_id:
            validated_data['exam_id'] = exam_id
        
        # Create ExamSession instance
        exam_session = ExamSession.objects.create(**validated_data)
        
        # Handle question population logic in the view
        return exam_session

class ExamSessionDetailSerializer(serializers.ModelSerializer):
    questions = serializers.SerializerMethodField()
    exam_name = serializers.CharField(source='exam.name', read_only=True)
    exam_slug = serializers.CharField(source='exam.slug', read_only=True)
    learning_materials = serializers.SerializerMethodField()
    
    class Meta:
        model = ExamSession
        fields = [
            'id', 'user', 'exam', 'exam_name', 'exam_slug', 'title', 'session_type', 'exam_type',
            'evaluation_mode', 'topic_ids', 'start_time', 'end_time_expected', 'actual_end_time', 
            'status', 'total_score_achieved', 'total_possible_score', 'pass_threshold',
            'passed', 'time_limit_seconds', 'is_timed', 'learning_material_viewed', 
            'metadata', 'created_at', 'questions', 'learning_materials'
        ]
        read_only_fields = ['id', 'user', 'exam', 'start_time', 'total_score_achieved', 
                          'total_possible_score', 'passed', 'created_at']

    def get_questions(self, obj):
        """Get questions with their answers for this session."""
        session_questions = obj.examsessionquestion_set.all().order_by('display_order')
        questions_data = []
        
        for session_question in session_questions:
            question_data = QuestionSerializer(session_question.question).data
            question_data['session_question_id'] = session_question.id
            question_data['display_order'] = session_question.display_order
            question_data['question_weight'] = session_question.question_weight
            
            # For MCQ questions, add the correct answer information
            if session_question.question.question_type == 'MCQ':
                try:
                    correct_choice = MCQChoice.objects.filter(
                        question=session_question.question,
                        is_correct=True
                    ).first()
                    if correct_choice:
                        question_data['correct_answer'] = str(correct_choice.id)
                    else:
                        question_data['correct_answer'] = None
                except Exception:
                    question_data['correct_answer'] = None
            else:
                question_data['correct_answer'] = None
            
            # Add user's answer if available
            try:
                user_answer = UserAnswer.objects.filter(
                    user=obj.user,
                    question=session_question.question,
                    exam_session=obj
                ).order_by('-submission_time').first()
                
                if user_answer:
                    # Get MCQ choices for this answer
                    mcq_choice_ids = []
                    if session_question.question.question_type == 'MCQ':
                        mcq_choice_ids = list(
                            UserAnswerMCQChoice.objects.filter(
                                user_answer=user_answer
                            ).values_list('mcq_choice_id', flat=True)
                        )
                    
                    question_data['user_answer'] = {
                        'id': user_answer.id,
                        'answer_text': user_answer.submitted_answer_text,
                        'calculation_input': user_answer.submitted_calculation_input,
                        'mcq_choices': mcq_choice_ids,
                        'is_correct': user_answer.is_correct,
                        'raw_score': user_answer.raw_score,
                        'weighted_score': user_answer.weighted_score,
                        'ai_feedback': user_answer.ai_feedback,
                        'evaluation_status': user_answer.evaluation_status,
                        'submitted_at': user_answer.submission_time,
                    }
                else:
                    question_data['user_answer'] = None
            except Exception as e:
                # Log the error but don't fail the serialization
                logging.error(f"Error getting user answer for question {session_question.question.id}: {e}")
                question_data['user_answer'] = None
                
            questions_data.append(question_data)
        
        return questions_data

    def get_learning_materials(self, obj):
        """Get learning materials for this exam session."""
        if not obj.should_show_learning_material():
            return []
        
        materials = LearningMaterial.objects.filter(
            exam=obj.exam,
            is_active=True
        )
        
        # Filter by topics if this is a topic-based exam
        if obj.exam_type == 'TOPIC_BASED' and obj.topic_ids:
            materials = materials.filter(
                models.Q(topic__isnull=True) |  # General exam materials
                models.Q(topic__id__in=obj.topic_ids)  # Topic-specific materials
            )
        
        return LearningMaterialSerializer(materials, many=True).data

class UserAnswerMCQChoiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserAnswerMCQChoice
        fields = ['mcq_choice']

class UserAnswerCreateSerializer(serializers.ModelSerializer):
    submitted_mcq_choice_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        write_only=True
    )
    
    class Meta:
        model = UserAnswer
        fields = [
            'id', 'submitted_answer_text', 'submitted_calculation_input',
            'time_spent_seconds', 'submitted_mcq_choice_ids'
        ]
        read_only_fields = ['id']
    
    def create(self, validated_data):
        # Extract MCQ choices
        mcq_choice_ids = validated_data.pop('submitted_mcq_choice_ids', [])
        
        # Create UserAnswer instance
        user_answer = UserAnswer.objects.create(**validated_data)
        
        # Add MCQ choices if provided
        if mcq_choice_ids:
            for choice_id in mcq_choice_ids:
                UserAnswerMCQChoice.objects.create(
                    user_answer=user_answer,
                    mcq_choice_id=choice_id
                )
        
        return user_answer

class UserAnswerDetailSerializer(serializers.ModelSerializer):
    mcq_choices = MCQChoiceSerializer(many=True, read_only=True)
    
    class Meta:
        model = UserAnswer
        fields = [
            'id', 'user', 'question', 'exam_session', 'submitted_answer_text',
            'submitted_calculation_input', 'raw_score', 'weighted_score',
            'max_possible_score', 'is_correct', 'ai_feedback', 'human_feedback',
            'evaluation_status', 'time_spent_seconds', 'submission_time',
            'retry_count', 'mcq_choices'
        ]
        read_only_fields = [
            'id', 'user', 'question', 'exam_session', 'raw_score', 'weighted_score',
            'max_possible_score', 'is_correct', 'ai_feedback', 'human_feedback',
            'evaluation_status', 'submission_time', 'retry_count'
        ] 