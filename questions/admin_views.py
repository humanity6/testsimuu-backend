from rest_framework import viewsets, permissions, status, generics
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.views import APIView
from django.db.models import ProtectedError, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import timedelta
from .models import Topic, Question, Tag, QuestionTag
from .admin_serializers import (
    AdminTopicSerializer, AdminQuestionSerializer, 
    AdminTagSerializer, QuestionTagAdminSerializer
)
from .serializers import QuestionSerializer, TopicSerializer

class IsAdminUser(permissions.BasePermission):
    """
    Custom permission to only allow admin users to access the view.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            print(f"❌ Questions Admin permission denied: User not authenticated")
            return False
            
        # Force a fresh database lookup to ensure we have latest is_staff status
        try:
            from users.models import User
            fresh_user = User.objects.get(id=request.user.id)
            has_permission = fresh_user.is_staff
            print(f"🔍 Questions Admin permission check: user={fresh_user.email}, is_staff={fresh_user.is_staff}, result={has_permission}")
            return has_permission
        except User.DoesNotExist:
            print(f"❌ Questions Admin permission denied: User not found in database")
            return False


class AdminTopicViewSet(viewsets.ModelViewSet):
    queryset = Topic.objects.all()
    serializer_class = AdminTopicSerializer
    permission_classes = [IsAdminUser]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter topics by exam if specified
        exam_id = self.request.query_params.get('exam_id')
        if exam_id:
            # Get topics that have questions in the specified exam
            queryset = queryset.filter(questions__exam_id=exam_id).distinct()
        
        return queryset.order_by('display_order', 'name')
    
    def destroy(self, request, *args, **kwargs):
        try:
            return super().destroy(request, *args, **kwargs)
        except ProtectedError:
            return Response(
                {"error": "Cannot delete topic because it is referenced by questions or child topics."},
                status=status.HTTP_400_BAD_REQUEST
            )


class AdminQuestionViewSet(viewsets.ModelViewSet):
    queryset = Question.objects.all().order_by('-created_at')
    serializer_class = AdminQuestionSerializer
    permission_classes = [IsAdminUser]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filter by exam if specified
        exam_id = self.request.query_params.get('exam_id')
        if exam_id:
            queryset = queryset.filter(exam_id=exam_id)
        
        # Filter by topic if specified
        topic_id = self.request.query_params.get('topic_id')
        if topic_id:
            queryset = queryset.filter(topic_id=topic_id)
        
        # Filter by question type if specified
        question_type = self.request.query_params.get('question_type')
        if question_type:
            queryset = queryset.filter(question_type=question_type)
        
        # Filter by difficulty if specified
        difficulty = self.request.query_params.get('difficulty')
        if difficulty:
            queryset = queryset.filter(difficulty=difficulty)
        
        # Filter by tag if specified
        tag_id = self.request.query_params.get('tag_id')
        if tag_id:
            queryset = queryset.filter(tags__id=tag_id)
        
        # Filter by active status if specified
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            is_active_bool = is_active.lower() == 'true'
            queryset = queryset.filter(is_active=is_active_bool)
        
        return queryset

    def perform_create(self, serializer):
        # Set created_by and last_updated_by to current user
        serializer.save(created_by=self.request.user, last_updated_by=self.request.user)

    def perform_update(self, serializer):
        # Set last_updated_by to current user on update
        serializer.save(last_updated_by=self.request.user)

    def destroy(self, request, *args, **kwargs):
        """Override destroy to handle relationships properly."""
        try:
            instance = self.get_object()
            # Check if question has user answers (protected relationship)
            if hasattr(instance, 'user_answers') and instance.user_answers.exists():
                return Response(
                    {"error": "Cannot delete question with existing user answers. Deactivate it instead."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Proceed with deletion
            self.perform_destroy(instance)
            return Response(status=status.HTTP_204_NO_CONTENT)
        except ProtectedError as e:
            return Response(
                {"error": f"Cannot delete question: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {"error": f"Error deleting question: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['get'])
    def metrics(self, request):
        """Get question metrics."""
        print(f"🔍 QuestionMetricsAction: Authenticated user: {request.user.email}")
        print(f"🔍 QuestionMetricsAction: User is_staff: {request.user.is_staff}")
        
        now = timezone.now()
        seven_days_ago = now - timedelta(days=7)

        # Get question metrics - Updated to match API documentation
        total_questions = Question.objects.count()
        active_questions = Question.objects.filter(is_active=True).count()
        
        # Questions by type
        questions_by_type = {}
        for question_type in ['MCQ', 'OPEN_ENDED', 'CALCULATION']:
            count = Question.objects.filter(question_type=question_type).count()
            if count > 0:
                questions_by_type[question_type] = count
        
        # Questions by difficulty
        questions_by_difficulty = {}
        for difficulty in ['EASY', 'MEDIUM', 'HARD']:
            count = Question.objects.filter(difficulty=difficulty).count()
            if count > 0:
                questions_by_difficulty[difficulty] = count

        metrics = {
            'total_questions': total_questions,
            'active_questions': active_questions,
            'questions_by_type': questions_by_type,
            'questions_by_difficulty': questions_by_difficulty,
        }
        
        print(f"✅ QuestionMetricsAction: Returning metrics: {metrics}")
        return Response(metrics)
    
    @action(detail=True, methods=['post'])
    def add_tag(self, request, pk=None):
        question = self.get_object()
        tag_id = request.data.get('tag_id')
        
        if not tag_id:
            return Response(
                {"error": "tag_id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            tag = Tag.objects.get(pk=tag_id)
        except Tag.DoesNotExist:
            return Response(
                {"error": f"Tag with id {tag_id} does not exist"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if the question already has this tag
        if QuestionTag.objects.filter(question=question, tag=tag).exists():
            return Response(
                {"error": f"Question already has tag with id {tag_id}"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Add the tag to the question
        QuestionTag.objects.create(question=question, tag=tag)
        
        return Response(
            {"message": f"Tag with id {tag_id} added to question with id {pk}"},
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=True, methods=['post'])
    def remove_tag(self, request, pk=None):
        question = self.get_object()
        tag_id = request.data.get('tag_id')
        
        if not tag_id:
            return Response(
                {"error": "tag_id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Try to find and delete the question-tag relationship
        try:
            question_tag = QuestionTag.objects.get(question=question, tag_id=tag_id)
            question_tag.delete()
            return Response(
                {"message": f"Tag with id {tag_id} removed from question with id {pk}"},
                status=status.HTTP_200_OK
            )
        except QuestionTag.DoesNotExist:
            return Response(
                {"error": f"Question does not have tag with id {tag_id}"},
                status=status.HTTP_404_NOT_FOUND
            )


class AdminTagViewSet(viewsets.ModelViewSet):
    queryset = Tag.objects.all().order_by('name')
    serializer_class = AdminTagSerializer
    permission_classes = [IsAdminUser]
    
    def destroy(self, request, *args, **kwargs):
        try:
            return super().destroy(request, *args, **kwargs)
        except ProtectedError:
            return Response(
                {"error": "Cannot delete tag because it is referenced by questions."},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['get'])
    def questions(self, request, pk=None):
        """Get all questions with this tag."""
        tag = self.get_object()
        questions = Question.objects.filter(tags=tag)
        
        # Use the main question serializer, not the admin one which can be too verbose
        serializer = QuestionSerializer(questions, many=True)
        
        return Response(serializer.data)


class QuestionTagViewSet(viewsets.ModelViewSet):
    queryset = QuestionTag.objects.all()
    serializer_class = QuestionTagAdminSerializer
    permission_classes = [IsAdminUser] 


class QuestionMetricsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]

    def get(self, request):
        print(f"🔍 QuestionMetricsView: Authenticated user: {request.user.email}")
        print(f"🔍 QuestionMetricsView: User is_staff: {request.user.is_staff}")
        
        now = timezone.now()
        seven_days_ago = now - timedelta(days=7)

        # Get question metrics - Updated to match API documentation
        total_questions = Question.objects.count()
        active_questions = Question.objects.filter(is_active=True).count()
        
        # Questions by type
        questions_by_type = {}
        for question_type in ['MCQ', 'OPEN_ENDED', 'CALCULATION']:
            count = Question.objects.filter(question_type=question_type).count()
            if count > 0:
                questions_by_type[question_type] = count
        
        # Questions by difficulty
        questions_by_difficulty = {}
        for difficulty in ['EASY', 'MEDIUM', 'HARD']:
            count = Question.objects.filter(difficulty=difficulty).count()
            if count > 0:
                questions_by_difficulty[difficulty] = count

        metrics = {
            'total_questions': total_questions,
            'active_questions': active_questions,
            'questions_by_type': questions_by_type,
            'questions_by_difficulty': questions_by_difficulty,
        }
        
        print(f"✅ QuestionMetricsView: Returning metrics: {metrics}")
        return Response(metrics)


class QuestionListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = Question.objects.all()
    serializer_class = QuestionSerializer


class QuestionDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = Question.objects.all()
    serializer_class = QuestionSerializer


class TopicListView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = Topic.objects.all()
    serializer_class = TopicSerializer


class TopicDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminUser]
    queryset = Topic.objects.all()
    serializer_class = TopicSerializer 