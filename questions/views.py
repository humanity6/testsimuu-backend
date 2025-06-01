from rest_framework import generics, filters, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from .models import Topic, Question, MCQChoice
from .serializers import (
    TopicSerializer, 
    TopicDetailSerializer,
    QuestionSerializer, 
    QuestionDetailSerializer,
    MCQChoiceSerializer
)
from subscriptions.permissions import HasActiveExamSubscription

class TopicListView(generics.ListAPIView):
    serializer_class = TopicSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['parent_topic_id']
    
    def get_queryset(self):
        return Topic.objects.filter(is_active=True).order_by('display_order')

class TopicDetailView(generics.RetrieveAPIView):
    serializer_class = TopicDetailSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = 'slug'
    
    def get_queryset(self):
        return Topic.objects.filter(is_active=True)
    
    def get_object(self):
        lookup_value = self.kwargs[self.lookup_field]
        
        # Try to retrieve by slug first
        queryset = self.get_queryset()
        
        # If the lookup value is numeric, try finding by ID
        if lookup_value.isdigit():
            try:
                return queryset.get(id=lookup_value)
            except Topic.DoesNotExist:
                pass
                
        # Otherwise, find by slug
        return queryset.get(slug=lookup_value)

class QuestionListView(generics.ListAPIView):
    serializer_class = QuestionSerializer
    permission_classes = [IsAuthenticated, HasActiveExamSubscription]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['exam_id', 'topic_id', 'question_type', 'difficulty']
    search_fields = ['text']
    
    def get_queryset(self):
        queryset = Question.objects.filter(is_active=True)
        
        # Allow filtering by topic_slug
        topic_slug = self.request.query_params.get('topic_slug')
        if topic_slug:
            queryset = queryset.filter(topic__slug=topic_slug)
        
        # Allow filtering by exam_slug
        exam_slug = self.request.query_params.get('exam_slug')
        if exam_slug:
            queryset = queryset.filter(exam__slug=exam_slug)
            
        return queryset

class QuestionDetailView(generics.RetrieveAPIView):
    serializer_class = QuestionDetailSerializer
    permission_classes = [IsAuthenticated, HasActiveExamSubscription]
    queryset = Question.objects.filter(is_active=True)
    lookup_field = 'id'

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def debug_mcq_choices(request, question_id):
    """Debug endpoint to directly fetch MCQ choices for a specific question"""
    try:
        question = Question.objects.get(id=question_id)
        if question.question_type != 'MCQ':
            return Response(
                {"error": "Not an MCQ question"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Try multiple ways to fetch choices
        choices_direct = MCQChoice.objects.filter(question=question)
        choices_via_related = question.mcqchoice_set.all()
        
        # Debug info
        result = {
            'question_id': question.id,
            'question_text': question.text,
            'question_type': question.question_type,
            'choices_direct_count': choices_direct.count(),
            'choices_via_related_count': choices_via_related.count(),
            'choices_direct': MCQChoiceSerializer(choices_direct, many=True).data,
            'choices_via_related': MCQChoiceSerializer(choices_via_related, many=True).data,
        }
        
        return Response(result, status=status.HTTP_200_OK)
    except Question.DoesNotExist:
        return Response(
            {"error": "Question not found"},
            status=status.HTTP_404_NOT_FOUND
        )

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def debug_mcq_choice(request, choice_id):
    """Debug endpoint to directly fetch a specific MCQ choice by ID"""
    try:
        choice = MCQChoice.objects.get(id=choice_id)
        return Response(
            {
                "id": choice.id,
                "choice_text": choice.choice_text,
                "is_correct": choice.is_correct
            },
            status=status.HTTP_200_OK
        )
    except MCQChoice.DoesNotExist:
        return Response(
            {"error": "Choice not found"},
            status=status.HTTP_404_NOT_FOUND
        ) 