from rest_framework import serializers
from .models import Exam


class AdminExamSerializer(serializers.ModelSerializer):
    parent_exam_name = serializers.CharField(source='parent_exam.name', read_only=True)
    sub_exams_count = serializers.SerializerMethodField()
    questions_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Exam
        fields = [
            'id', 'name', 'slug', 'description', 'parent_exam', 'parent_exam_name',
            'is_active', 'display_order', 'created_at', 'updated_at',
            'sub_exams_count', 'questions_count'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_sub_exams_count(self, obj):
        """Get count of sub-exams."""
        return obj.sub_exams.count()
    
    def get_questions_count(self, obj):
        """Get count of questions in this exam."""
        return obj.questions.count()
    
    def validate_name(self, value):
        """Validate exam name is unique."""
        if self.instance:
            # For updates, exclude current instance from uniqueness check
            if Exam.objects.exclude(pk=self.instance.pk).filter(name=value).exists():
                raise serializers.ValidationError("An exam with this name already exists.")
        else:
            # For creation, check if name already exists
            if Exam.objects.filter(name=value).exists():
                raise serializers.ValidationError("An exam with this name already exists.")
        return value
    
    def validate_slug(self, value):
        """Validate exam slug is unique."""
        if self.instance:
            # For updates, exclude current instance from uniqueness check
            if Exam.objects.exclude(pk=self.instance.pk).filter(slug=value).exists():
                raise serializers.ValidationError("An exam with this slug already exists.")
        else:
            # For creation, check if slug already exists
            if Exam.objects.filter(slug=value).exists():
                raise serializers.ValidationError("An exam with this slug already exists.")
        return value
    
    def validate_parent_exam(self, value):
        """Validate parent exam to prevent circular references."""
        if value and self.instance:
            # Check if setting this parent would create a circular reference
            current_exam = self.instance
            parent = value
            
            # Traverse up the parent chain to check for circular reference
            while parent:
                if parent == current_exam:
                    raise serializers.ValidationError("Cannot set parent exam: this would create a circular reference.")
                parent = parent.parent_exam
        
        return value 