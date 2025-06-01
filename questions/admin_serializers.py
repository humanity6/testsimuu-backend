from rest_framework import serializers
from .models import Topic, Question, Tag, MCQChoice, QuestionTag
from exams.models import Exam

class AdminTagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ['id', 'name', 'slug', 'description']
        read_only_fields = ['id']

class AdminTopicSerializer(serializers.ModelSerializer):
    class Meta:
        model = Topic
        fields = [
            'id', 'name', 'slug', 'description', 'parent_topic', 
            'display_order', 'is_active', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

class MCQChoiceAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = MCQChoice
        fields = ['id', 'choice_text', 'is_correct', 'display_order', 'explanation']
        read_only_fields = ['id']

class AdminQuestionSerializer(serializers.ModelSerializer):
    choices = MCQChoiceAdminSerializer(many=True, required=False)
    tags = serializers.PrimaryKeyRelatedField(
        queryset=Tag.objects.all(), 
        many=True, 
        required=False
    )
    
    class Meta:
        model = Question
        fields = [
            'id', 'exam', 'topic', 'text', 'question_type', 'difficulty',
            'estimated_time_seconds', 'points', 'model_answer_text',
            'model_calculation_logic', 'is_active', 'answer_explanation',
            'created_at', 'updated_at', 'created_by', 'last_updated_by',
            'choices', 'tags'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def validate(self, data):
        # Ensure exam is provided
        if 'exam' not in data and self.instance is None:
            raise serializers.ValidationError(
                {"exam": "An exam must be selected for the question"}
            )
            
        # Validate that MCQ questions have choices
        if data.get('question_type') == 'MCQ':
            choices = data.get('choices', [])
            if not choices and self.instance is None:  # Only for creation
                raise serializers.ValidationError(
                    {"choices": "MCQ questions must have at least one choice"}
                )
            
            # Check that at least one choice is correct
            if choices and not any(choice.get('is_correct', False) for choice in choices):
                raise serializers.ValidationError(
                    {"choices": "At least one choice must be marked as correct"}
                )
        
        return data
    
    def create(self, validated_data):
        choices_data = validated_data.pop('choices', [])
        tags_data = validated_data.pop('tags', [])
        
        # Set the created_by field to the current user
        request = self.context.get('request')
        if request and not validated_data.get('created_by'):
            validated_data['created_by'] = request.user
            validated_data['last_updated_by'] = request.user
        
        # Create the question
        question = Question.objects.create(**validated_data)
        
        # Create choices for MCQ
        for choice_data in choices_data:
            MCQChoice.objects.create(question=question, **choice_data)
        
        # Add tags
        for tag in tags_data:
            QuestionTag.objects.create(question=question, tag=tag)
        
        return question
    
    def update(self, instance, validated_data):
        choices_data = validated_data.pop('choices', None)
        tags_data = validated_data.pop('tags', None)
        
        # Update the last_updated_by field
        request = self.context.get('request')
        if request:
            validated_data['last_updated_by'] = request.user
        
        # Update the question fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update choices if provided
        if choices_data is not None:
            # Remove existing choices
            MCQChoice.objects.filter(question=instance).delete()
            
            # Create new choices
            for choice_data in choices_data:
                MCQChoice.objects.create(question=instance, **choice_data)
        
        # Update tags if provided
        if tags_data is not None:
            # Remove existing tags
            QuestionTag.objects.filter(question=instance).delete()
            
            # Add new tags
            for tag in tags_data:
                QuestionTag.objects.create(question=instance, tag=tag)
        
        return instance

class QuestionTagAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionTag
        fields = ['question', 'tag'] 