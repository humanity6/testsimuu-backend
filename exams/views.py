from django.shortcuts import render
from rest_framework import generics, filters, status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from .models import Exam, ExamTranslation
from .serializers import ExamSerializer, ExamDetailSerializer, ExamTranslationSerializer
from .services import ExamTranslationService

# Create your views here.

class ExamListView(generics.ListAPIView):
    serializer_class = ExamSerializer
    permission_classes = [AllowAny]  # Allow anonymous access for browsing exams
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['parent_exam_id']
    
    def get_queryset(self):
        return Exam.objects.filter(is_active=True).order_by('display_order')
    
    def list(self, request, *args, **kwargs):
        """Override list method to ensure proper response format"""
        queryset = self.filter_queryset(self.get_queryset())
        
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = self.get_serializer(queryset, many=True)
        return Response({
            'count': len(serializer.data),
            'next': None,
            'previous': None,
            'results': serializer.data
        })


class ExamDetailView(generics.RetrieveAPIView):
    queryset = Exam.objects.filter(is_active=True)
    serializer_class = ExamDetailSerializer
    permission_classes = [AllowAny]
    lookup_field = 'slug'


class ExamTranslationView(APIView):
    """
    API endpoint for managing exam translations.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request, exam_id):
        """
        Trigger translation for a specific exam to a target language.
        """
        try:
            exam = Exam.objects.get(id=exam_id, is_active=True)
        except Exam.DoesNotExist:
            return Response(
                {'error': 'Exam not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        language_code = request.data.get('language_code')
        if not language_code:
            return Response(
                {'error': 'language_code is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        language_code = language_code.lower()
        
        if language_code not in ExamTranslationService.LANGUAGE_NAMES:
            return Response(
                {'error': f'Unsupported language: {language_code}'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if exam has description to translate
        if not exam.description or not exam.description.strip():
            return Response(
                {'error': 'Exam has no description to translate'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Trigger translation
        translation = ExamTranslationService.translate_exam_description(exam, language_code)
        
        if not translation:
            return Response(
                {'error': 'Failed to create translation'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        serializer = ExamTranslationSerializer(translation)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    def get(self, request, exam_id):
        """
        Get translation status for a specific exam.
        """
        try:
            exam = Exam.objects.get(id=exam_id, is_active=True)
        except Exam.DoesNotExist:
            return Response(
                {'error': 'Exam not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        language_code = request.query_params.get('language_code')
        
        if language_code:
            # Get specific translation
            try:
                translation = ExamTranslation.objects.get(
                    exam=exam, 
                    language_code=language_code.lower()
                )
                serializer = ExamTranslationSerializer(translation)
                return Response(serializer.data)
            except ExamTranslation.DoesNotExist:
                return Response(
                    {'error': 'Translation not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
        else:
            # Get all translations for the exam
            translations = ExamTranslation.objects.filter(exam=exam)
            serializer = ExamTranslationSerializer(translations, many=True)
            return Response({
                'exam_id': exam.id,
                'exam_name': exam.name,
                'original_description': exam.description,
                'translations': serializer.data
            })


class BatchTranslationView(APIView):
    """
    API endpoint for batch translation of multiple exams.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """
        Trigger batch translation for multiple exams.
        """
        exam_ids = request.data.get('exam_ids', [])
        language_codes = request.data.get('language_codes', [])
        
        if not exam_ids:
            return Response(
                {'error': 'exam_ids is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not language_codes:
            return Response(
                {'error': 'language_codes is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validate language codes
        invalid_languages = [
            lang for lang in language_codes 
            if lang.lower() not in ExamTranslationService.LANGUAGE_NAMES
        ]
        if invalid_languages:
            return Response(
                {'error': f'Unsupported languages: {invalid_languages}'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Process batch translation
        results = ExamTranslationService.translate_multiple_exams(
            exam_ids, 
            [lang.lower() for lang in language_codes]
        )
        
        return Response({
            'message': 'Batch translation initiated',
            'results': results
        }, status=status.HTTP_202_ACCEPTED)


@api_view(['GET'])
@permission_classes([AllowAny])
def supported_languages(request):
    """
    Get list of supported languages for translation.
    """
    languages = ExamTranslationService.get_supported_languages()
    return Response({
        'supported_languages': languages,
        'count': len(languages)
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def exam_with_translation(request, exam_slug):
    """
    Get exam details with translation in specified language.
    """
    try:
        exam = Exam.objects.get(slug=exam_slug, is_active=True)
    except Exam.DoesNotExist:
        return Response(
            {'error': 'Exam not found'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    
    language_code = request.query_params.get('lang', 'en').lower()
    
    # Get exam data with translation context
    serializer = ExamDetailSerializer(exam, context={'request': request})
    exam_data = serializer.data
    
    # Add specific translation info if requested
    if language_code != 'en':
        try:
            translation = ExamTranslation.objects.get(
                exam=exam, 
                language_code=language_code
            )
            exam_data['translation_info'] = {
                'language_code': translation.language_code,
                'language_name': ExamTranslationService.LANGUAGE_NAMES.get(
                    translation.language_code, translation.language_code
                ),
                'translation_status': translation.translation_status,
                'translated_at': translation.translated_at,
                'translation_method': translation.translation_method
            }
        except ExamTranslation.DoesNotExist:
            exam_data['translation_info'] = {
                'language_code': language_code,
                'language_name': ExamTranslationService.LANGUAGE_NAMES.get(
                    language_code, language_code
                ),
                'translation_status': 'NOT_AVAILABLE',
                'translated_at': None,
                'translation_method': None
            }
    
    return Response(exam_data)
