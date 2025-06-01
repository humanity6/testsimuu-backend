from datetime import datetime, timedelta
from django.utils import timezone
from django.db.models import Sum, Count, Avg, F, FloatField, Q, Case, When, Value
from django.db.models.functions import Coalesce, TruncDate, TruncWeek, TruncMonth
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from django.core.cache import cache
from django.conf import settings
from .models import UserPerformanceRecord, UserProgress
from .serializers import (
    PerformanceSummarySerializer,
    PerformanceByTopicSerializer,
    PerformanceByDifficultySerializer,
    PerformanceTrendsSerializer,
    TopicProgressSerializer
)
from assessment.models import UserAnswer
from questions.models import Topic, Question
from django.contrib.auth.decorators import login_required
from django.utils.decorators import method_decorator
from decimal import Decimal, ROUND_HALF_UP
import logging

logger = logging.getLogger(__name__)


class PerformanceSummaryView(APIView):
    """
    API view to get user's overall performance summary with proper validation
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Get date range from query parameters
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')
        exam_id = request.GET.get('exam_id')
        
        # Set default date range (last 30 days) if not provided
        end_date = timezone.now().date()
        start_date = end_date - timedelta(days=30)
        
        # Parse custom date range if provided
        if start_date_str:
            try:
                start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid start_date format. Use YYYY-MM-DD'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        if end_date_str:
            try:
                end_date = datetime.strptime(end_date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid end_date format. Use YYYY-MM-DD'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Validate date range
        if start_date > end_date:
            return Response(
                {'error': 'start_date cannot be after end_date'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create cache key
        cache_key = f"performance_summary_{user.id}_{start_date}_{end_date}_{exam_id or 'all'}"
        cached_data = cache.get(cache_key)
        if cached_data:
            return Response(cached_data)
        
        # Base queryset
        queryset = UserPerformanceRecord.objects.filter(
            user=user,
            date_recorded__gte=start_date,
            date_recorded__lte=end_date
        )
        
        # Filter by exam if specified
        if exam_id:
            # Note: We would need to link UserPerformanceRecord to exam sessions
            # For now, we'll filter by topics related to the exam
            pass
        
        # Aggregate metrics with proper validation
        aggregates = queryset.aggregate(
            total_questions=Sum('questions_answered'),
            correct_answers=Sum('correct_answers'),
            partially_correct_answers=Sum('partially_correct_answers'),
            total_points_earned=Sum('total_points_earned'),
            total_points_possible=Sum('total_points_possible'),
            total_time_spent_seconds=Sum('total_time_spent_seconds')
        )
        
        # Handle case with no records
        if not aggregates['total_questions'] or aggregates['total_questions'] == 0:
            data = {
                'total_questions': 0,
                'correct_answers': 0,
                'partially_correct_answers': 0,
                'total_points_earned': 0.0,
                'total_points_possible': 0.0,
                'total_time_spent_seconds': 0,
                'accuracy': 0.0,
                'average_time_per_question': 0.0,
                # Frontend compatibility fields
                'completed_sessions': 0,
                'average_score': 0.0,
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            }
        else:
            # Calculate derived metrics with proper validation and rounding
            total_questions = aggregates['total_questions']
            correct_answers = aggregates['correct_answers'] or 0
            
            # Calculate accuracy as percentage (0-100)
            if total_questions > 0:
                accuracy_decimal = Decimal(correct_answers) / Decimal(total_questions) * 100
                accuracy = float(accuracy_decimal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))
            else:
                accuracy = 0.0
            
            # Calculate average time per question
            total_time = aggregates['total_time_spent_seconds'] or 0
            if total_questions > 0:
                avg_time_decimal = Decimal(total_time) / Decimal(total_questions)
                avg_time = float(avg_time_decimal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))
            else:
                avg_time = 0.0
            
            # Calculate average score (accuracy as decimal for frontend compatibility)
            average_score = accuracy / 100.0
            
            # Get number of completed sessions (distinct dates with records)
            completed_sessions = queryset.values('date_recorded').distinct().count()
            
            # Ensure all values are properly typed and validated
            data = {
                'total_questions': int(total_questions),
                'correct_answers': int(correct_answers),
                'partially_correct_answers': int(aggregates['partially_correct_answers'] or 0),
                'total_points_earned': float(aggregates['total_points_earned'] or 0),
                'total_points_possible': float(aggregates['total_points_possible'] or 0),
                'total_time_spent_seconds': int(total_time),
                'accuracy': round(accuracy, 2),
                'average_time_per_question': round(avg_time, 2),
                # Frontend compatibility fields
                'completed_sessions': completed_sessions,
                'average_score': round(average_score, 3),
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            }
        
        serializer = PerformanceSummarySerializer(data)
        
        # Cache the result for 1 hour (3600 seconds)
        cache.set(cache_key, serializer.data, 3600)
        
        return Response(serializer.data)


class PerformanceByTopicView(APIView):
    """
    View for retrieving a user's performance breakdown by topic.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Get date range filters
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        # Parse dates if provided
        if start_date:
            try:
                start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid start_date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            # Default to last 90 days
            start_date = (timezone.now() - timedelta(days=90)).date()
            
        if end_date:
            try:
                end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid end_date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            end_date = timezone.now().date()
        
        # Generate cache key
        cache_key = f'performance_by_topic_{user.id}_{start_date}_{end_date}'
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return Response(cached_data)
        
        try:
            # Get all topics with their parent topics for hierarchical information
            topics = Topic.objects.select_related('parent_topic').filter(is_active=True)
            
            # Get raw records and then aggregate in Python (to avoid Django ORM limitations)
            records = UserPerformanceRecord.objects.filter(
                user=user,
                date_recorded__gte=start_date,
                date_recorded__lte=end_date,
                topic__isnull=False  # Exclude records with no topic
            ).select_related('topic').values(
                'topic', 'questions_answered', 'correct_answers', 'partially_correct_answers',
                'total_points_earned', 'total_points_possible', 'total_time_spent_seconds'
            )
            
            # Aggregate by topic in Python
            topic_aggregates = {}
            for record in records:
                topic_id = record['topic']
                if topic_id not in topic_aggregates:
                    topic_aggregates[topic_id] = {
                        'topic': topic_id,
                        'questions_answered': 0,
                        'correct_answers': 0,
                        'partially_correct_answers': 0,
                        'total_points_earned': 0,
                        'total_points_possible': 0,
                        'total_time_spent_seconds': 0
                    }
                
                topic_data = topic_aggregates[topic_id]
                topic_data['questions_answered'] += record['questions_answered'] or 0
                topic_data['correct_answers'] += record['correct_answers'] or 0
                topic_data['partially_correct_answers'] += record['partially_correct_answers'] or 0
                topic_data['total_points_earned'] += record['total_points_earned'] or 0
                topic_data['total_points_possible'] += record['total_points_possible'] or 0
                topic_data['total_time_spent_seconds'] += record['total_time_spent_seconds'] or 0
            
            # Build the response data with calculated metrics
            result = []
            for topic_id, data in topic_aggregates.items():
                try:
                    topic = next(t for t in topics if t.id == topic_id)
                    
                    # Calculate derived metrics
                    questions = data['questions_answered']
                    accuracy = (data['correct_answers'] / questions * 100) if questions > 0 else 0
                    avg_time = (data['total_time_spent_seconds'] / questions) if questions > 0 else 0
                    
                    result.append({
                        'topic': topic,
                        'topic_name': topic.name,
                        'questions_answered': data['questions_answered'],
                        'correct_answers': data['correct_answers'],
                        'partially_correct_answers': data['partially_correct_answers'],
                        'total_points_earned': data['total_points_earned'],
                        'total_points_possible': data['total_points_possible'],
                        'total_time_spent_seconds': data['total_time_spent_seconds'],
                        'accuracy': round(accuracy, 2),
                        'average_time_per_question': round(avg_time, 2)
                    })
                except StopIteration:
                    # Topic not found or inactive
                    pass
            
            # Sort by questions answered
            result.sort(key=lambda x: x['questions_answered'], reverse=True)
            
            serializer = PerformanceByTopicSerializer(result, many=True)
            
            # Cache the result for 1 hour
            cache.set(cache_key, serializer.data, 3600)
            
            return Response(serializer.data)
        
        except Exception as e:
            # Log the error
            logger.error(f"Error in PerformanceByTopicView: {str(e)}")
            
            # Return empty result to prevent UI errors
            return Response([])


class PerformanceByDifficultyView(APIView):
    """
    View for retrieving a user's performance breakdown by difficulty level.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Get date range filters
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        # Parse dates if provided
        if start_date:
            try:
                start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid start_date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            # Default to last 90 days
            start_date = (timezone.now() - timedelta(days=90)).date()
            
        if end_date:
            try:
                end_date = datetime.strptime(end_date, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid end_date format. Use YYYY-MM-DD.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        else:
            end_date = timezone.now().date()
        
        # Generate cache key
        cache_key = f'performance_by_difficulty_{user.id}_{start_date}_{end_date}'
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return Response(cached_data)
        
        try:
            # Get raw records and then aggregate in Python (to avoid Django ORM limitations)
            records = UserPerformanceRecord.objects.filter(
                user=user,
                date_recorded__gte=start_date,
                date_recorded__lte=end_date,
                difficulty__isnull=False  # Exclude records with no difficulty
            ).values(
                'difficulty', 'questions_answered', 'correct_answers', 'partially_correct_answers',
                'total_points_earned', 'total_points_possible', 'total_time_spent_seconds'
            )
            
            # Aggregate by difficulty in Python
            difficulty_aggregates = {}
            for record in records:
                difficulty = record['difficulty']
                if difficulty not in difficulty_aggregates:
                    difficulty_aggregates[difficulty] = {
                        'difficulty': difficulty,
                        'questions_answered': 0,
                        'correct_answers': 0,
                        'partially_correct_answers': 0,
                        'total_points_earned': 0,
                        'total_points_possible': 0,
                        'total_time_spent_seconds': 0
                    }
                
                difficulty_data = difficulty_aggregates[difficulty]
                difficulty_data['questions_answered'] += record['questions_answered'] or 0
                difficulty_data['correct_answers'] += record['correct_answers'] or 0
                difficulty_data['partially_correct_answers'] += record['partially_correct_answers'] or 0
                difficulty_data['total_points_earned'] += record['total_points_earned'] or 0
                difficulty_data['total_points_possible'] += record['total_points_possible'] or 0
                difficulty_data['total_time_spent_seconds'] += record['total_time_spent_seconds'] or 0
            
            # Convert to list and calculate derived metrics
            difficulty_records = []
            for difficulty, data in difficulty_aggregates.items():
                questions = data['questions_answered']
                accuracy = (data['correct_answers'] / questions * 100) if questions > 0 else 0
                avg_time = (data['total_time_spent_seconds'] / questions) if questions > 0 else 0
                
                difficulty_records.append({
                    'difficulty': difficulty,
                    'questions_answered': data['questions_answered'],
                    'correct_answers': data['correct_answers'],
                    'partially_correct_answers': data['partially_correct_answers'],
                    'total_points_earned': data['total_points_earned'],
                    'total_points_possible': data['total_points_possible'],
                    'total_time_spent_seconds': data['total_time_spent_seconds'],
                    'accuracy': round(accuracy, 2),
                    'average_time_per_question': round(avg_time, 2)
                })
                
        except Exception as e:
            # If there's a database error, return empty data
            logger.error(f"Error querying difficulty performance: {str(e)}")
            difficulty_records = []
        
        # For any missing difficulty levels, add empty records
        difficulty_dict = {record['difficulty']: record for record in difficulty_records}
        
        for level in ['EASY', 'MEDIUM', 'HARD']:
            if level not in difficulty_dict:
                difficulty_dict[level] = {
                    'difficulty': level,
                    'questions_answered': 0,
                    'correct_answers': 0,
                    'partially_correct_answers': 0,
                    'total_points_earned': 0,
                    'total_points_possible': 0,
                    'total_time_spent_seconds': 0,
                    'accuracy': 0,
                    'average_time_per_question': 0
                }
        
        # Create ordered result (sort by difficulty level)
        difficulty_order = {'EASY': 1, 'MEDIUM': 2, 'HARD': 3}
        result = sorted(
            [difficulty_dict[level] for level in difficulty_dict.keys()], 
            key=lambda x: difficulty_order.get(x['difficulty'], 999)
        )
        
        serializer = PerformanceByDifficultySerializer(result, many=True)
        
        # Cache the result for 1 hour
        cache.set(cache_key, serializer.data, 3600)
        
        return Response(serializer.data)


class PerformanceTrendsView(APIView):
    """
    API view to get user's performance trends over time with accurate calculations
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Get date range from query parameters
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')
        exam_id = request.GET.get('exam_id')
        
        # Set default date range (last 30 days) if not provided
        end_date = timezone.now().date()
        start_date = end_date - timedelta(days=30)
        
        # Parse custom date range if provided
        if start_date_str:
            try:
                start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid start_date format. Use YYYY-MM-DD'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        if end_date_str:
            try:
                end_date = datetime.strptime(end_date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Invalid end_date format. Use YYYY-MM-DD'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Create cache key
        cache_key = f"performance_trends_{user.id}_{start_date}_{end_date}_{exam_id or 'all'}"
        cached_data = cache.get(cache_key)
        if cached_data:
            return Response(cached_data)
        
        try:
            # Get records grouped by date
            records = UserPerformanceRecord.objects.filter(
                user=user,
                date_recorded__gte=start_date,
                date_recorded__lte=end_date
            ).values('date_recorded').annotate(
                total_questions=Sum('questions_answered'),
                total_correct=Sum('correct_answers'),
                total_time=Sum('total_time_spent_seconds')
            ).order_by('date_recorded')
            
            # Calculate trends with proper validation
            result = []
            for record in records:
                date_recorded = record['date_recorded']
                total_questions = record['total_questions'] or 0
                total_correct = record['total_correct'] or 0
                total_time = record['total_time'] or 0
                
                if total_questions > 0:
                    # Calculate accuracy as percentage
                    accuracy_decimal = Decimal(total_correct) / Decimal(total_questions) * 100
                    accuracy = float(accuracy_decimal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))
                    
                    # Calculate average time
                    avg_time_decimal = Decimal(total_time) / Decimal(total_questions)
                    avg_time = float(avg_time_decimal.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))
                else:
                    accuracy = 0.0
                    avg_time = 0.0
                
                result.append({
                    'date': date_recorded.isoformat(),
                    'questions_answered': total_questions,
                    'correct_answers': total_correct,
                    'accuracy': round(accuracy, 2),
                    'average_time_per_question': round(avg_time, 2),
                    'total_time_spent_seconds': total_time
                })
            
            # Cache the result for 1 hour
            cache.set(cache_key, result, 3600)
            
            return Response({'data_points': result})
            
        except Exception as e:
            logger.error(f"Error in PerformanceTrendsView: {e}")
            return Response(
                {'error': 'Failed to fetch performance trends data'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ProgressByTopicView(APIView):
    """
    View for retrieving a user's progress within each topic.
    Only returns topics where user has actual progress or activity.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Add pagination support
        limit = int(request.query_params.get('limit', 100))  # Default to 100 topics max
        offset = int(request.query_params.get('offset', 0))
        
        # Add filter for only topics with progress
        only_with_progress = request.query_params.get('only_with_progress', 'true').lower() == 'true'
        
        # Generate cache key
        cache_key = f'progress_by_topic_{user.id}_{limit}_{offset}_{only_with_progress}'
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return Response(cached_data)
        
        # Get user progress records first to limit scope
        progress_records = UserProgress.objects.filter(
            user=user
        ).select_related('topic__parent_topic')
        
        if only_with_progress:
            # Only return topics where user has actual progress
            result = []
            
            for progress in progress_records:
                topic = progress.topic
                completion_percentage = (progress.questions_mastered / progress.total_questions_in_topic * 100) if progress.total_questions_in_topic > 0 else 0
                
                result.append({
                    'topic_id': topic.id,
                    'topic_name': topic.name,
                    'topic_slug': topic.slug,
                    'parent_topic_id': topic.parent_topic_id,
                    'parent_topic_name': topic.parent_topic.name if topic.parent_topic else None,
                    'total_questions_in_topic': progress.total_questions_in_topic,
                    'questions_attempted': progress.questions_attempted,
                    'questions_mastered': progress.questions_mastered,
                    'proficiency_level': progress.proficiency_level,
                    'completion_percentage': round(completion_percentage, 2),
                    'last_activity_date': progress.last_activity_date
                })
        else:
            # Get topics with hierarchical information (legacy behavior for all topics)
            topics = Topic.objects.select_related('parent_topic').filter(is_active=True)[offset:offset+limit]
            
            # Create a dictionary for quick lookup
            progress_dict = {record.topic_id: record for record in progress_records}
            
            # Query total question counts for topics where user has no progress record
            topics_without_progress = [t.id for t in topics if t.id not in progress_dict]
            
            # Count questions per topic
            topic_question_counts = {}
            if topics_without_progress:
                question_counts = Question.objects.filter(
                    topic_id__in=topics_without_progress,
                    is_active=True
                ).values('topic_id').annotate(
                    count=Count('id')
                )
                
                topic_question_counts = {item['topic_id']: item['count'] for item in question_counts}
            
            # Build the response data
            result = []
            
            for topic in topics:
                if topic.id in progress_dict:
                    # User has a progress record for this topic
                    progress = progress_dict[topic.id]
                    
                    completion_percentage = (progress.questions_mastered / progress.total_questions_in_topic * 100) if progress.total_questions_in_topic > 0 else 0
                    
                    result.append({
                        'topic_id': topic.id,
                        'topic_name': topic.name,
                        'topic_slug': topic.slug,
                        'parent_topic_id': topic.parent_topic_id,
                        'parent_topic_name': topic.parent_topic.name if topic.parent_topic else None,
                        'total_questions_in_topic': progress.total_questions_in_topic,
                        'questions_attempted': progress.questions_attempted,
                        'questions_mastered': progress.questions_mastered,
                        'proficiency_level': progress.proficiency_level,
                        'completion_percentage': round(completion_percentage, 2),
                        'last_activity_date': progress.last_activity_date
                    })
                elif topic.id in topic_question_counts:
                    # Topic has questions but no progress record
                    result.append({
                        'topic_id': topic.id,
                        'topic_name': topic.name,
                        'topic_slug': topic.slug,
                        'parent_topic_id': topic.parent_topic_id,
                        'parent_topic_name': topic.parent_topic.name if topic.parent_topic else None,
                        'total_questions_in_topic': topic_question_counts[topic.id],
                        'questions_attempted': 0,
                        'questions_mastered': 0,
                        'proficiency_level': 'BEGINNER',
                        'completion_percentage': 0,
                        'last_activity_date': None
                    })
        
        # Sort by completion percentage (highest first) for topics with progress
        if only_with_progress:
            result.sort(key=lambda x: (x['completion_percentage'], x['questions_attempted']), reverse=True)
        else:
            # Sort by parent topic and then by name
            result.sort(key=lambda x: (x['parent_topic_name'] or '', x['topic_name']))
        
        # Add metadata for frontend
        response_data = {
            'count': len(result),
            'showing_only_with_progress': only_with_progress,
            'results': result
        }
        
        serializer = TopicProgressSerializer(result, many=True)
        
        # Cache the result for 30 minutes (shorter cache for progress data)
        cache.set(cache_key, serializer.data, 1800)
        
        return Response(serializer.data) 