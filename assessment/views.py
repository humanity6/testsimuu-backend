import json
import logging
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.db import transaction
from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import ExamSession, ExamSessionQuestion, UserAnswer, UserAnswerMCQChoice, LearningMaterial
from .serializers import (
    ExamSessionCreateSerializer, ExamSessionDetailSerializer, ExamSessionSummarySerializer,
    UserAnswerCreateSerializer, UserAnswerDetailSerializer, LearningMaterialSerializer
)
from questions.models import Question, MCQChoice, Topic
from exams.models import Exam
from subscriptions.permissions import HasActiveExamSubscription
from django.db.models import Q, Count, Avg, Sum, F
import random
from collections import defaultdict

logger = logging.getLogger(__name__)


class ExamSessionViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated, HasActiveExamSubscription]
    
    def list(self, request):
        """List user's exam sessions."""
        queryset = ExamSession.objects.filter(user=request.user).order_by('-start_time')
        
        # Filter by session type if provided
        session_type = request.query_params.get('session_type')
        if session_type:
            queryset = queryset.filter(session_type=session_type)
        
        # Filter by exam type if provided
        exam_type = request.query_params.get('exam_type')
        if exam_type:
            queryset = queryset.filter(exam_type=exam_type)
        
        # Filter by exam if provided
        exam_id = request.query_params.get('exam_id')
        if exam_id:
            queryset = queryset.filter(exam_id=exam_id)
        
        # Filter by status if provided
        status_filter = request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        serializer = ExamSessionSummarySerializer(queryset, many=True)
        return Response(serializer.data)
    
    def create(self, request):
        """Start a new exam session with mode-specific configuration."""
        serializer = ExamSessionCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            # Set additional required fields before creating
            time_limit = serializer.validated_data.get('time_limit_seconds', 3600)  # Default 1 hour
            start_time = timezone.now()
            exam_id = serializer.validated_data.get('exam_id')
            session_type = serializer.validated_data.get('session_type')
            exam_type = serializer.validated_data.get('exam_type', 'FULL')
            is_timed = serializer.validated_data.get('is_timed', True)
            
            # For Practice Mode, set time limit to a very large value since it's untimed
            if session_type == 'PRACTICE':
                time_limit = 86400  # 24 hours
                is_timed = False
            
            # Create exam session with user and time data
            exam_session = ExamSession.objects.create(
                user=request.user,
                exam_id=exam_id,
                start_time=start_time,
                end_time_expected=start_time + timezone.timedelta(seconds=time_limit),
                status='IN_PROGRESS',
                session_type=session_type,
                exam_type=exam_type,
                evaluation_mode=serializer.validated_data.get('evaluation_mode', 'REAL_TIME'),
                is_timed=is_timed,
                time_limit_seconds=time_limit,
                title=serializer.validated_data.get('title'),
                topic_ids=serializer.validated_data.get('topic_ids'),
                total_possible_score=0,  # Will be updated after adding questions
                pass_threshold=0.7,  # Default threshold, can be customized
            )
            
            # Get questions based on provided criteria
            questions = []
            question_ids = serializer.validated_data.get('question_ids', [])
            topic_ids = serializer.validated_data.get('topic_ids', [])
            num_questions = serializer.validated_data.get('num_questions')
            
            if question_ids:
                # Use specific questions if IDs provided
                questions = Question.objects.filter(id__in=question_ids, is_active=True, exam_id=exam_id)
            elif exam_type == 'TOPIC_BASED' and topic_ids and num_questions:
                # Select questions from specific topics
                questions = Question.objects.filter(
                    topic_id__in=topic_ids,
                    exam_id=exam_id, 
                    is_active=True
                ).order_by('?')[:num_questions]
            elif exam_type == 'FULL' and num_questions:
                # Select questions from entire exam
                questions = Question.objects.filter(
                    exam_id=exam_id, 
                    is_active=True
                ).order_by('?')[:num_questions]
            elif exam_type == 'FULL':
                # Get all questions from exam if no specific count requested
                questions = Question.objects.filter(
                    exam_id=exam_id, 
                    is_active=True
                ).order_by('?')
            else:
                return Response(
                    {"error": "Invalid question selection criteria. Provide either question_ids, or specify exam_type with appropriate parameters."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Add questions to exam session
            total_points = 0
            for i, question in enumerate(questions):
                ExamSessionQuestion.objects.create(
                    exam_session=exam_session,
                    question=question,
                    display_order=i,
                    question_weight=1.0  # Default weight, can be customized
                )
                total_points += question.points
            
            # Update total possible score
            exam_session.total_possible_score = total_points
            exam_session.save()
            
            # Return session details
            return Response(
                ExamSessionDetailSerializer(exam_session).data,
                status=status.HTTP_201_CREATED
            )
    
    def retrieve(self, request, pk=None):
        """Get specific exam session details."""
        exam_session = get_object_or_404(ExamSession, pk=pk, user=request.user)
        serializer = ExamSessionDetailSerializer(exam_session)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def learning_materials(self, request, pk=None):
        """Get learning materials for an exam session."""
        exam_session = get_object_or_404(ExamSession, pk=pk, user=request.user)
        
        if not exam_session.should_show_learning_material():
            return Response({"detail": "Learning materials not available for this session type."}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        materials = LearningMaterial.objects.filter(
            exam=exam_session.exam,
            is_active=True
        ).order_by('display_order')
        
        # Filter by topics if this is a topic-based exam
        if exam_session.exam_type == 'TOPIC_BASED' and exam_session.topic_ids:
            materials = materials.filter(
                Q(topic__isnull=True) |  # General exam materials
                Q(topic__id__in=exam_session.topic_ids)  # Topic-specific materials
            )
        
        serializer = LearningMaterialSerializer(materials, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def mark_learning_material_viewed(self, request, pk=None):
        """Mark that user has viewed learning materials."""
        exam_session = get_object_or_404(ExamSession, pk=pk, user=request.user)
        
        if exam_session.status != 'IN_PROGRESS':
            return Response({"error": "Cannot update learning material status for non-active sessions."},
                          status=status.HTTP_400_BAD_REQUEST)
        
        exam_session.learning_material_viewed = True
        exam_session.save()
        
        return Response({"detail": "Learning material marked as viewed."})

    @action(detail=True, methods=['get'])
    def topics(self, request, pk=None):
        """Get available topics for an exam session."""
        exam_session = get_object_or_404(ExamSession, pk=pk, user=request.user)
        
        topics = Topic.objects.filter(
            questions__exam=exam_session.exam,
            is_active=True
        ).distinct().annotate(
            question_count=Count('questions', filter=Q(questions__is_active=True))
        ).order_by('display_order', 'name')
        
        topics_data = []
        for topic in topics:
            topics_data.append({
                'id': topic.id,
                'name': topic.name,
                'slug': topic.slug,
                'description': topic.description,
                'question_count': topic.question_count,
            })
        
        return Response(topics_data)

    @action(detail=True, methods=['post'])
    def submit_answer(self, request, pk=None):
        """Submit an answer for a question in the exam session."""
        exam_session = get_object_or_404(ExamSession, pk=pk, user=request.user)
        
        if exam_session.status != 'IN_PROGRESS':
            return Response({"error": "Cannot submit answers for non-active sessions."},
                          status=status.HTTP_400_BAD_REQUEST)
        
        serializer = UserAnswerCreateSerializer(data=request.data)
        if serializer.is_valid():
            # Get the question to determine max_possible_score
            question = get_object_or_404(Question, id=request.data.get('question_id'))
            
            # Set initial evaluation status based on question type
            if question.question_type == 'MCQ':
                evaluation_status = 'MCQ_SCORED'
            elif question.question_type in ['OPEN_ENDED', 'CALCULATION']:
                evaluation_status = 'PENDING'
            else:
                evaluation_status = 'NOT_APPLICABLE'
            
            # Create the answer with evaluation based on mode
            user_answer = serializer.save(
                user=request.user,
                exam_session=exam_session,
                question=question,
                max_possible_score=question.points,  # Set from question
                evaluation_status=evaluation_status,
                submission_time=timezone.now()
            )
            
            # Handle MCQ scoring first
            if question.question_type == 'MCQ':
                submitted_mcq_choice_ids = serializer.validated_data.get('submitted_mcq_choice_ids', [])
                
                if submitted_mcq_choice_ids:
                    # Create UserAnswerMCQChoice entries
                    mcq_choices = MCQChoice.objects.filter(
                        id__in=submitted_mcq_choice_ids,
                        question=question
                    )
                    
                    for choice in mcq_choices:
                        UserAnswerMCQChoice.objects.create(
                            user_answer=user_answer,
                            mcq_choice=choice
                        )
                    
                    # Auto-score MCQs
                    correct_choices = set(MCQChoice.objects.filter(
                        question=question, is_correct=True
                    ).values_list('id', flat=True))
                    
                    submitted_choices = set(submitted_mcq_choice_ids)
                    
                    # Check if selected choices match correct choices exactly
                    if submitted_choices == correct_choices:
                        is_correct = True
                        raw_score = question.points
                    else:
                        is_correct = False
                        raw_score = 0
                    
                    # Update score
                    user_answer.is_correct = is_correct
                    user_answer.raw_score = raw_score
                    user_answer.weighted_score = raw_score  # No question weight here since we don't have exam_session_question
                    user_answer.save()
                else:
                    # No choices selected - mark as incorrect
                    user_answer.is_correct = False
                    user_answer.raw_score = 0
                    user_answer.weighted_score = 0
                    user_answer.save()
            
            # Check if this is practice mode for real-time evaluation
            elif exam_session.is_practice_mode() or exam_session.get_evaluation_mode() == 'REAL_TIME':
                # Implement immediate AI evaluation and feedback for eligible questions
                if user_answer.question.question_type in ['OPEN_ENDED', 'CALCULATION']:
                    try:
                        # Import here to avoid circular import
                        from ai_integration.services import AIAnswerEvaluationService
                        
                        # For real-time evaluation, we'll call the service directly
                        # instead of using Celery to provide immediate feedback
                        ai_response, processing_time, error = AIAnswerEvaluationService.evaluate_answer(
                            user_answer.question,
                            user_answer.submitted_answer_text or 
                            (user_answer.submitted_calculation_input.get('user_input', '') 
                             if user_answer.submitted_calculation_input else ''),
                            user_answer.question.question_type
                        )
                        
                        if not error and ai_response:
                            # Parse the AI response
                            feedback, raw_score, is_correct, metadata = AIAnswerEvaluationService.parse_ai_response(
                                ai_response, user_answer.question.question_type
                            )
                            
                            if feedback is not None:
                                # Update the user answer with AI feedback
                                user_answer.ai_feedback = feedback
                                user_answer.raw_score = raw_score
                                user_answer.is_correct = is_correct
                                user_answer.evaluation_status = 'EVALUATED'
                                
                                # Calculate weighted score
                                if user_answer.max_possible_score > 0:
                                    if raw_score and raw_score > 1:
                                        normalized_score = raw_score / user_answer.max_possible_score
                                    else:
                                        normalized_score = raw_score or 0
                                    user_answer.weighted_score = normalized_score * user_answer.max_possible_score
                                else:
                                    user_answer.weighted_score = raw_score or 0
                                
                                # Store metadata
                                if metadata:
                                    existing_metadata = user_answer.metadata or {}
                                    existing_metadata.update({
                                        'ai_evaluation_metadata': metadata,
                                        'evaluation_timestamp': timezone.now().isoformat(),
                                        'processing_time_ms': processing_time
                                    })
                                    user_answer.metadata = existing_metadata
                                
                                user_answer.save()
                            else:
                                # Failed to parse AI response
                                user_answer.evaluation_status = 'ERROR'
                                user_answer.ai_feedback = 'Failed to process AI evaluation'
                                user_answer.save()
                        else:
                            # AI evaluation failed
                            user_answer.evaluation_status = 'ERROR'
                            user_answer.ai_feedback = f'AI evaluation error: {error}' if error else 'AI evaluation failed'
                            user_answer.save()
                    
                    except Exception as e:
                        # Handle any errors gracefully
                        user_answer.evaluation_status = 'ERROR'
                        user_answer.ai_feedback = f'Evaluation error: {str(e)}'
                        user_answer.save()
                        # Log the error but don't fail the entire request
                        logger.error(f"Real-time AI evaluation error for answer {user_answer.id}: {e}")
            
            return Response(UserAnswerDetailSerializer(user_answer).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Complete an exam session."""
        exam_session = get_object_or_404(ExamSession, pk=pk, user=request.user)
        
        if exam_session.status != 'IN_PROGRESS':
            return Response({"error": "Session is not in progress."},
                          status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            # Clean up duplicate answers first - keep only the latest answer for each question
            from django.db.models import Max
            
            # Get all answers for this session
            all_answers = UserAnswer.objects.filter(
                user=request.user,
                exam_session=exam_session
            ).order_by('question_id', '-submission_time')
            
            # Group by question_id and keep track of which answers to keep
            answers_by_question = defaultdict(list)
            for answer in all_answers:
                answers_by_question[answer.question_id].append(answer)
            
            # For each question, keep the latest answer and delete the rest
            answers_to_delete = []
            for question_id, answers in answers_by_question.items():
                if len(answers) > 1:
                    # Keep the first (latest) answer, mark others for deletion
                    answers_to_delete.extend(answers[1:])
            
            # Delete duplicate answers
            if answers_to_delete:
                duplicate_ids = [answer.id for answer in answers_to_delete]
                UserAnswer.objects.filter(id__in=duplicate_ids).delete()
                logger.info(f"Removed {len(duplicate_ids)} duplicate answers for exam session {exam_session.id}")
            
            # Set completion time
            exam_session.actual_end_time = timezone.now()
            exam_session.status = 'COMPLETED'
            
            # For Real Exam Mode, perform AI evaluation now
            if exam_session.is_real_exam_mode() or exam_session.get_evaluation_mode() == 'END_OF_EXAM':
                self._perform_final_evaluation(exam_session)
            
            # Ensure all answers have proper scores and correctness status
            self._finalize_answer_scores(exam_session)
            
            # Calculate final score and pass status
            total_score = UserAnswer.objects.filter(
                user=request.user,
                exam_session=exam_session
            ).aggregate(total=Sum('raw_score'))['total'] or 0
            
            exam_session.total_score_achieved = total_score
            exam_session.passed = total_score >= (exam_session.total_possible_score * exam_session.pass_threshold)
            exam_session.save()
            
            # Create analytics performance records from this session
            try:
                from analytics.services import AnalyticsService
                records_created = AnalyticsService.create_performance_records_from_session(exam_session)
                logger.info(f"Created {records_created} analytics records for session {exam_session.id}")
            except Exception as e:
                # Don't fail the exam completion if analytics creation fails
                logger.error(f"Error creating analytics records for session {exam_session.id}: {e}")
        
        return Response(ExamSessionDetailSerializer(exam_session).data)

    def _finalize_answer_scores(self, exam_session):
        """Ensure all answers have proper scores and correctness status."""
        answers = UserAnswer.objects.filter(
            user=exam_session.user,
            exam_session=exam_session
        )
        
        for answer in answers:
            needs_update = False
            
            # If the answer has no raw_score, assign a default based on question type and evaluation status
            if answer.raw_score is None:
                if answer.question.question_type == 'MCQ':
                    # MCQ should already be scored, but if not, mark as incorrect
                    answer.raw_score = 0
                    answer.is_correct = False
                    needs_update = True
                elif answer.evaluation_status in ['PENDING', 'ERROR']:
                    # For AI-evaluated questions that failed, assign partial credit
                    if answer.submitted_answer_text or answer.submitted_calculation_input:
                        # Give some credit for attempting the question
                        answer.raw_score = answer.max_possible_score * 0.1  # 10% for effort
                        answer.is_correct = False
                    else:
                        # No answer provided
                        answer.raw_score = 0
                        answer.is_correct = False
                    needs_update = True
                else:
                    # Other cases, use zero score
                    answer.raw_score = 0
                    answer.is_correct = False
                    needs_update = True
            
            # If is_correct is None, determine it based on score
            if answer.is_correct is None:
                if answer.question.question_type == 'MCQ':
                    answer.is_correct = answer.raw_score > 0
                else:
                    # For open-ended and calculation questions, consider >70% as correct
                    threshold = answer.max_possible_score * 0.7
                    answer.is_correct = answer.raw_score >= threshold
                needs_update = True
            
            # Ensure weighted_score is set
            if answer.weighted_score is None and answer.raw_score is not None:
                session_question = ExamSessionQuestion.objects.filter(
                    exam_session=exam_session,
                    question=answer.question
                ).first()
                
                if session_question:
                    answer.weighted_score = answer.raw_score * session_question.question_weight
                else:
                    answer.weighted_score = answer.raw_score
                needs_update = True
            
            if needs_update:
                answer.save()
                logger.info(f"Finalized scores for answer {answer.id}: raw_score={answer.raw_score}, is_correct={answer.is_correct}")

    def _perform_final_evaluation(self, exam_session):
        """Perform AI evaluation for all answers in a real exam session."""
        # Import here to avoid circular import
        try:
            from ai_integration.services import AIAnswerEvaluationService
            
            # Get all answers that need AI evaluation (open-ended and calculation)
            answers_needing_evaluation = UserAnswer.objects.filter(
                user=exam_session.user,
                exam_session=exam_session,
                question__question_type__in=['OPEN_ENDED', 'CALCULATION'],
                evaluation_status='PENDING'
            )
            
            logger.info(f"Starting AI evaluation for {answers_needing_evaluation.count()} answers in session {exam_session.id}")
            
            for answer in answers_needing_evaluation:
                try:
                    # Use the existing evaluate_user_answer method which is more robust
                    AIAnswerEvaluationService.evaluate_user_answer(answer.id)
                    
                except Exception as e:
                    # Log error but continue with other answers
                    logger.error(f"Error evaluating answer {answer.id}: {e}")
                    # Mark as error but don't fail the entire evaluation
                    try:
                        answer.refresh_from_db()
                        answer.evaluation_status = 'ERROR'
                        answer.ai_feedback = f'Evaluation error: {str(e)}'
                        # Assign partial credit for attempted answers
                        if answer.submitted_answer_text or answer.submitted_calculation_input:
                            answer.raw_score = answer.max_possible_score * 0.3  # 30% for effort
                            answer.is_correct = False
                        else:
                            answer.raw_score = 0
                            answer.is_correct = False
                        answer.save()
                    except Exception as save_error:
                        logger.error(f"Failed to save error status for answer {answer.id}: {save_error}")
                        
        except ImportError:
            # AI service not available, skip evaluation
            logger.warning("AI integration service not available for final evaluation")
        except Exception as e:
            logger.error(f"Error in final evaluation: {e}")
            # Don't fail the exam completion if AI evaluation fails


class UserAnswerViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]
    
    @action(detail=False, methods=['post'], url_path='exam-sessions/(?P<session_id>[^/.]+)/questions/(?P<question_id>[^/.]+)/answer')
    def submit_answer(self, request, session_id=None, question_id=None):
        """Submit an answer for a question within a given exam session."""
        # Validate session and question
        exam_session = get_object_or_404(
            ExamSession, pk=session_id, user=request.user, status='IN_PROGRESS'
        )
        
        # Ensure the question is part of this exam session
        exam_session_question = get_object_or_404(
            ExamSessionQuestion, 
            exam_session=exam_session,
            question_id=question_id
        )
        
        question = exam_session_question.question
        
        # Validate input data
        serializer = UserAnswerCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            # Check if an answer already exists and remove it if so
            UserAnswer.objects.filter(
                user=request.user,
                exam_session=exam_session,
                question=question
            ).delete()
            
            # Create user answer
            evaluation_status = 'PENDING'
            max_possible_score = question.points * exam_session_question.question_weight
            
            # Handle MCQ scoring
            if question.question_type == 'MCQ':
                evaluation_status = 'MCQ_SCORED'
            
            user_answer = UserAnswer.objects.create(
                user=request.user,
                question=question,
                exam_session=exam_session,
                submitted_answer_text=serializer.validated_data.get('submitted_answer_text'),
                submitted_calculation_input=serializer.validated_data.get('submitted_calculation_input'),
                time_spent_seconds=serializer.validated_data.get('time_spent_seconds'),
                max_possible_score=max_possible_score,
                evaluation_status=evaluation_status,
                submission_time=timezone.now()
            )
            
            # Handle MCQ choices if provided
            submitted_mcq_choice_ids = serializer.validated_data.get('submitted_mcq_choice_ids', [])
            if question.question_type == 'MCQ' and submitted_mcq_choice_ids:
                # Create UserAnswerMCQChoice entries
                mcq_choices = MCQChoice.objects.filter(
                    id__in=submitted_mcq_choice_ids,
                    question=question
                )
                
                for choice in mcq_choices:
                    UserAnswerMCQChoice.objects.create(
                        user_answer=user_answer,
                        mcq_choice=choice
                    )
                
                # Auto-score MCQs
                correct_choices = set(MCQChoice.objects.filter(
                    question=question, is_correct=True
                ).values_list('id', flat=True))
                
                submitted_choices = set(submitted_mcq_choice_ids)
                
                # Check if selected choices match correct choices exactly
                if submitted_choices == correct_choices:
                    is_correct = True
                    raw_score = question.points
                else:
                    is_correct = False
                    raw_score = 0
                
                # Update score
                user_answer.is_correct = is_correct
                user_answer.raw_score = raw_score
                user_answer.weighted_score = raw_score * exam_session_question.question_weight
                user_answer.save()
            
            return Response(
                UserAnswerDetailSerializer(user_answer).data,
                status=status.HTTP_201_CREATED
            ) 