import time
import json
import logging
import requests
from datetime import datetime, timedelta
from django.conf import settings
from django.utils import timezone
from django.db import transaction
from .models import (
    AIFeedbackTemplate, 
    AIEvaluationLog, 
    AIContentAlert, 
    ContentUpdateScanConfig, 
    ContentUpdateScanLog,
    ChatbotConversation,
    ChatbotMessage
)
from assessment.models import UserAnswer
from questions.models import Topic, Question
from exams.models import Exam

logger = logging.getLogger(__name__)

class AIAnswerEvaluationService:
    """
    Service for evaluating user answers using OpenAI API.
    This service is designed to be called asynchronously via Celery.
    """
    
    # Predefined prompts for different question types
    OPEN_ENDED_PROMPT = """
You are an expert evaluator for professional exams. Your task is to assess student answers against model answers.

CONTEXT:
- Exam: {exam_name}
- Topic: {topic_name}
- Question: {question_text}
- Model Answer: {model_answer_text}
- Maximum Points: {max_possible_score}

STUDENT ANSWER:
{submitted_answer_text}

EVALUATION INSTRUCTIONS:
1. Compare the student answer to the model answer
2. Assess for accuracy, completeness, and relevance
3. Provide a score between 0 and {max_possible_score} points
4. Explain your scoring rationale with specific references to content
5. Provide constructive feedback with specific improvement suggestions
6. Do not mention any evaluation criteria not reflected in the model answer

Please respond in JSON format using the following structure:
{
  "raw_score": float,
  "is_correct": boolean,
  "ai_feedback": "Your detailed feedback here, addressing strengths and areas for improvement",
  "score_explanation": "Brief explanation of why this score was given"
}
"""

    OPEN_ENDED_NO_MODEL_PROMPT = """
You are an expert evaluator for professional exams. Your task is to assess student answers.

CONTEXT:
- Exam: {exam_name}
- Topic: {topic_name}
- Question: {question_text}
- Maximum Points: {max_possible_score}

STUDENT ANSWER:
{submitted_answer_text}

EVALUATION INSTRUCTIONS (No Model Answer Provided):
1. Carefully analyze the student's answer in relation to the question asked.
2. Assess the answer for general accuracy, relevance to the question, and logical coherence based on your knowledge of the topic: {topic_name}.
3. Provide a score between 0 and {max_possible_score} points.
4. Explain your scoring rationale clearly.
5. Provide constructive feedback and highlight areas where the answer could be improved or might be missing key information generally expected for such a question.
6. Acknowledge that this evaluation is performed without a specific model answer.

Please respond in JSON format using the following structure:
{
  "raw_score": float,
  "is_correct": boolean,
  "ai_feedback": "Your detailed feedback here, addressing strengths and areas for improvement",
  "score_explanation": "Brief explanation of why this score was given"
}
"""

    CALCULATION_PROMPT = """
You are an expert calculator evaluator for professional exams. Evaluate this calculation-based response.

CONTEXT:
- Exam: {exam_name}
- Topic: {topic_name}
- Question: {question_text}
- Calculation Logic Model: {model_calculation_logic}
- Maximum Points: {max_possible_score}

STUDENT CALCULATION:
{submitted_calculation_input}

EVALUATION INSTRUCTIONS:
1. Check all calculation steps against the model calculation logic
2. Assess for correct formulas, values, and final results
3. Award partial credit for correct steps even if final answer is wrong
4. Assign a score between 0 and {max_possible_score} points
5. Explain where errors occurred (if any)
6. Provide constructive feedback with correct calculation approach

Please respond in JSON format using the following structure:
{
  "raw_score": float,
  "is_correct": boolean,
  "ai_feedback": "Your detailed feedback explaining the calculation evaluation",
  "error_locations": ["step where error occurred", "another error location"],
  "correct_approach": "Brief summary of the correct calculation approach"
}
"""
    
    @classmethod
    def get_template_for_question_type(cls, question_type):
        """Get the active template for a question type."""
        try:
            return AIFeedbackTemplate.objects.filter(
                question_type=question_type,
                is_active=True
            ).order_by('-updated_at').first()
        except AIFeedbackTemplate.DoesNotExist:
            logger.error(f"No active template found for question type: {question_type}")
            return None
    
    @classmethod
    def prepare_prompt(cls, template, user_answer):
        """Prepare the prompt using the template and user answer data."""
        # Get question type first
        question_type = user_answer.question.question_type
        
        # If a custom template is provided, use it
        if template and template.template_content.strip():
            prompt = template.template_content
        else:
            # Use default prompts based on question type
            if question_type == 'OPEN_ENDED':
                if user_answer.question.model_answer_text:
                    prompt = cls.OPEN_ENDED_PROMPT
                else:
                    prompt = cls.OPEN_ENDED_NO_MODEL_PROMPT
            elif question_type == 'CALCULATION':
                prompt = cls.CALCULATION_PROMPT
            else:
                logger.error(f"Unsupported question type: {question_type}")
                return None
        
        # Get related objects
        question = user_answer.question
        topic = question.topic
        exam = question.exam
        
        # Prepare template variables
        template_vars = {
            'exam_name': exam.name if exam else "Unknown Exam",
            'topic_name': topic.name if topic else "Unknown Topic",
            'question_text': question.text,
            'max_possible_score': user_answer.max_possible_score,
            'submitted_answer_text': user_answer.submitted_answer_text or "",
        }
        
        # Add model answer if available
        if question.model_answer_text:
            template_vars['model_answer_text'] = question.model_answer_text
        
        # Add calculation data if available
        if question_type == 'CALCULATION':
            if question.model_calculation_logic:
                template_vars['model_calculation_logic'] = json.dumps(question.model_calculation_logic, indent=2)
            
            if user_answer.submitted_calculation_input:
                template_vars['submitted_calculation_input'] = json.dumps(
                    user_answer.submitted_calculation_input, indent=2
                )
        
        # Replace variables in template
        for key, value in template_vars.items():
            placeholder = f"{{{{{key}}}}}"
            prompt = prompt.replace(placeholder, str(value))
        
        return prompt
    
    @classmethod
    def call_openai_api(cls, prompt):
        """Call OpenAI API to evaluate the answer."""
        if not prompt:
            return None, None, "No prompt available"
        
        start_time = time.time()
        
        try:
            # OpenAI API call
            headers = {
                'Authorization': f"Bearer {settings.OPENAI_API_KEY}",
                'Content-Type': 'application/json'
            }
            
            # Enhanced system message to ensure proper JSON response
            system_message = """You are an expert educational evaluator. You MUST always respond in valid JSON format.
            
CRITICAL INSTRUCTIONS:
- NEVER return error messages or explanations outside of JSON
- ALWAYS evaluate the student's answer even if it seems incomplete
- If you cannot parse the question or answer, still provide a valid JSON response with appropriate feedback
- Use the exact JSON structure requested in the prompt

If the input appears invalid or incomplete, still provide evaluation feedback within the JSON structure."""
            
            data = {
                'model': settings.OPENAI_MODEL or "gpt-4",
                'messages': [
                    {'role': 'system', 'content': system_message},
                    {'role': 'user', 'content': prompt}
                ],
                'temperature': 0.2,
                'response_format': {'type': 'json_object'}  # Ensure JSON response
            }
            
            response = requests.post(
                'https://api.openai.com/v1/chat/completions',
                headers=headers,
                json=data,
                timeout=30  # Add timeout
            )
            
            if response.status_code != 200:
                error_msg = f"OpenAI API error: {response.status_code} - {response.text}"
                logger.error(error_msg)
                return None, int((time.time() - start_time) * 1000), error_msg
            
            result = response.json()
            ai_response = result['choices'][0]['message']['content']
            processing_time = int((time.time() - start_time) * 1000)  # in ms
            
            # Validate that the response is valid JSON
            try:
                json.loads(ai_response)
            except json.JSONDecodeError:
                error_msg = f"AI returned invalid JSON: {ai_response}"
                logger.error(error_msg)
                return None, processing_time, error_msg
            
            return ai_response, processing_time, None
        
        except requests.exceptions.Timeout:
            error_msg = "OpenAI API request timed out"
            logger.exception(error_msg)
            processing_time = int((time.time() - start_time) * 1000)
            return None, processing_time, error_msg
        except Exception as e:
            error_msg = f"Error calling OpenAI API: {str(e)}"
            logger.exception(error_msg)
            processing_time = int((time.time() - start_time) * 1000)  # in ms
            return None, processing_time, error_msg
    
    @classmethod
    def parse_ai_response(cls, ai_response, question_type):
        """
        Parse the AI response to extract evaluation data based on question type.
        """
        try:
            # Try to extract JSON from the response
            response_data = json.loads(ai_response)
            
            # Handle nested response format - if response data is wrapped in a "response" key
            if 'response' in response_data and isinstance(response_data['response'], dict):
                response_data = response_data['response']
            
            # Check for the expected format first
            if 'raw_score' in response_data and 'is_correct' in response_data and 'ai_feedback' in response_data:
                raw_score = float(response_data.get('raw_score'))
                is_correct = bool(response_data.get('is_correct'))
                ai_feedback = response_data.get('ai_feedback')
                
                # Additional metadata specific to question type
                metadata = {}
                
                if question_type == 'OPEN_ENDED':
                    if 'score_explanation' in response_data:
                        metadata['score_explanation'] = response_data.get('score_explanation')
                
                elif question_type == 'CALCULATION':
                    if 'error_locations' in response_data:
                        metadata['error_locations'] = response_data.get('error_locations')
                    if 'correct_approach' in response_data:
                        metadata['correct_approach'] = response_data.get('correct_approach')
                
                return ai_feedback, raw_score, is_correct, metadata
            
            # Try to handle alternative formats
            elif 'user_answer_correctness_indicator' in response_data:
                # Handle the format with user_answer_correctness_indicator
                correctness_indicator = response_data.get('user_answer_correctness_indicator', '').lower()
                is_correct = correctness_indicator in ['correct', 'true', '1', 'yes']
                
                # Build feedback from available parts
                feedback_parts = []
                if 'specific_feedback' in response_data:
                    if isinstance(response_data['specific_feedback'], list):
                        feedback_parts.extend(response_data['specific_feedback'])
                    else:
                        feedback_parts.append(str(response_data['specific_feedback']))
                
                if 'areas_for_improvement' in response_data:
                    improvement_text = response_data['areas_for_improvement']
                    if isinstance(improvement_text, list):
                        if improvement_text:  # Only add if not empty
                            feedback_parts.append("Areas for improvement: " + ", ".join(improvement_text))
                    else:
                        feedback_parts.append("Areas for improvement: " + str(improvement_text))
                
                if 'strengths' in response_data:
                    strengths_text = response_data['strengths']
                    if isinstance(strengths_text, list):
                        if strengths_text:  # Only add if not empty
                            feedback_parts.insert(0, "Strengths: " + ", ".join(strengths_text))
                    else:
                        feedback_parts.insert(0, "Strengths: " + str(strengths_text))
                
                if 'encouragement' in response_data:
                    feedback_parts.append(response_data['encouragement'])
                
                ai_feedback = "\n\n".join(feedback_parts) if feedback_parts else "Answer reviewed."
                
                # Try to extract a score, with fallbacks
                raw_score = 0.5  # Default middle score
                if 'score' in response_data:
                    try:
                        raw_score = float(response_data['score'])
                    except (ValueError, TypeError):
                        pass
                elif is_correct:
                    raw_score = 1.0
                else:
                    raw_score = 0.0
                
                # Build metadata
                metadata = {
                    'strengths': response_data.get('strengths', []),
                    'areas_for_improvement': response_data.get('areas_for_improvement', []),
                    'question_type_detected': response_data.get('question_type', question_type),
                    'correctness_indicator': correctness_indicator
                }
                
                return ai_feedback, raw_score, is_correct, metadata
            
            # Try to handle format with 'evaluation' wrapper
            elif 'evaluation' in response_data and isinstance(response_data['evaluation'], dict):
                eval_data = response_data['evaluation']
                
                # Extract score
                raw_score = 0.5  # Default
                if 'score' in eval_data:
                    try:
                        raw_score = float(eval_data['score'])
                    except (ValueError, TypeError):
                        pass
                
                # Extract feedback
                ai_feedback = eval_data.get('feedback', 'Answer evaluated.')
                
                # Determine correctness based on score
                is_correct = raw_score >= 0.7  # 70% threshold
                
                metadata = {'evaluation_format': 'wrapped', 'original_data': eval_data}
                
                return ai_feedback, raw_score, is_correct, metadata
            
            # Try to handle other potential formats
            elif 'feedback' in response_data:
                # Handle simpler format with just feedback
                ai_feedback = response_data.get('feedback', 'Answer evaluated.')
                raw_score = response_data.get('score', 0.5)  # Default to middle score
                try:
                    raw_score = float(raw_score)
                except (ValueError, TypeError):
                    raw_score = 0.5
                
                is_correct = raw_score >= 0.7  # Consider >=70% as correct
                metadata = {'format': 'simple_feedback'}
                
                return ai_feedback, raw_score, is_correct, metadata
            
            else:
                # If we can't parse the structured response, provide defaults
                logger.warning(f"Unexpected AI response format: {ai_response}")
                
                # Fallback: use the entire response as feedback
                ai_feedback = "AI Evaluation: " + json.dumps(response_data, indent=2)
                raw_score = 0.3  # Give some partial credit for attempting the question
                is_correct = False  # Mark as incorrect since we couldn't parse properly
                metadata = {'parsing_fallback': True, 'original_response': response_data}
                
                return ai_feedback, raw_score, is_correct, metadata
            
        except (json.JSONDecodeError, ValueError) as e:
            logger.error(f"Failed to parse AI response: {str(e)} - {ai_response}")
            
            # Ultimate fallback: treat as plain text
            if ai_response and isinstance(ai_response, str):
                ai_feedback = f"AI Response: {ai_response}"
                raw_score = 0.2  # Minimal credit for getting a response
                is_correct = False
                metadata = {'parsing_error': str(e), 'text_fallback': True}
                
                return ai_feedback, raw_score, is_correct, metadata
            
            # Absolute fallback if we have nothing
            return "Unable to evaluate answer.", 0.0, False, {'error': 'complete_parsing_failure'}
    
    @classmethod
    def evaluate_user_answer(cls, user_answer_id):
        """
        Main method to evaluate a user answer.
        This method should be called by the Celery task.
        """
        try:
            try:
                user_answer = UserAnswer.objects.get(id=user_answer_id)
            except UserAnswer.DoesNotExist:
                logger.warning(f"User answer with ID {user_answer_id} does not exist - likely deleted due to duplicate submission")
                return
            
            # Only process OPEN_ENDED or CALCULATION answers that are PENDING
            if user_answer.evaluation_status != 'PENDING' or user_answer.question.question_type not in ['OPEN_ENDED', 'CALCULATION']:
                logger.info(f"Skipping evaluation for answer {user_answer_id}: Not pending or not an eligible question type")
                return
            
            # Get the appropriate template (can be None to use default prompts)
            template = cls.get_template_for_question_type(user_answer.question.question_type)
            
            # Prepare the prompt
            prompt = cls.prepare_prompt(template, user_answer)
            if not prompt:
                try:
                    cls._mark_as_error(user_answer, "Failed to prepare prompt")
                except UserAnswer.DoesNotExist:
                    logger.warning(f"Cannot mark answer {user_answer_id} as error - answer no longer exists")
                return
            
            # Call OpenAI API
            ai_response, processing_time, error = cls.call_openai_api(prompt)
            
            # Try to log the evaluation (but don't fail the evaluation if logging fails)
            try:
                evaluation_log = AIEvaluationLog(
                    user_answer=user_answer,
                    prompt_used=prompt,
                    ai_response=ai_response if ai_response else "",
                    processing_time_ms=processing_time or 0,
                    success=error is None,
                    error_message=error
                )
                evaluation_log.save()
            except Exception as log_error:
                logger.warning(f"Failed to save evaluation log for answer {user_answer_id}: {str(log_error)}")
                # Continue with evaluation even if logging fails
            
            if error:
                try:
                    cls._mark_as_error(user_answer, error)
                except UserAnswer.DoesNotExist:
                    logger.warning(f"Cannot mark answer {user_answer_id} as error - answer no longer exists")
                return
            
            # Parse the AI response
            feedback, raw_score, is_correct, metadata = cls.parse_ai_response(
                ai_response, 
                user_answer.question.question_type
            )
            
            # The parse_ai_response method now always returns valid values, so we can proceed
            
            # Update the user answer with evaluation data
            try:
                with transaction.atomic():
                    # Refresh user_answer to avoid stale data
                    try:
                        user_answer.refresh_from_db()
                    except UserAnswer.DoesNotExist:
                        logger.warning(f"User answer {user_answer_id} no longer exists during evaluation - likely replaced by newer submission")
                        return
                    
                    # Ensure raw_score is within reasonable bounds (0 to max_possible_score)
                    if raw_score > user_answer.max_possible_score:
                        # If raw_score seems to be in the 0-1 range, scale it
                        if raw_score <= 1:
                            weighted_score = raw_score * user_answer.max_possible_score
                        else:
                            # Cap at max possible score
                            weighted_score = min(raw_score, user_answer.max_possible_score)
                    else:
                        weighted_score = raw_score
                    
                    user_answer.ai_feedback = feedback
                    user_answer.raw_score = raw_score
                    user_answer.weighted_score = weighted_score
                    user_answer.is_correct = is_correct
                    user_answer.evaluation_status = 'EVALUATED'
                    
                    # Store additional metadata if provided
                    if metadata and isinstance(metadata, dict):
                        # Get existing metadata or initialize empty dict
                        existing_metadata = user_answer.metadata or {}
                        # Update with new metadata
                        existing_metadata.update({
                            'ai_evaluation_metadata': metadata,
                            'evaluation_timestamp': timezone.now().isoformat()
                        })
                        user_answer.metadata = existing_metadata
                    
                    user_answer.save()
                
                logger.info(f"Successfully evaluated answer {user_answer_id}: score={raw_score}, correct={is_correct}")
                
            except Exception as save_error:
                logger.exception(f"Error saving evaluation for answer {user_answer_id}: {str(save_error)}")
                # Don't try to mark as error if the user_answer doesn't exist anymore
                try:
                    cls._mark_as_error(user_answer, f"Error saving evaluation: {str(save_error)}")
                except UserAnswer.DoesNotExist:
                    logger.warning(f"Cannot mark answer {user_answer_id} as error - answer no longer exists")
            
        except Exception as e:
            logger.exception(f"Error evaluating user answer {user_answer_id}: {str(e)}")
            try:
                user_answer = UserAnswer.objects.get(id=user_answer_id)
                cls._mark_as_error(user_answer, str(e))
            except:
                pass
    
    @staticmethod
    def _mark_as_error(user_answer, error_message):
        """Mark a user answer as having an evaluation error."""
        user_answer.evaluation_status = 'ERROR'
        user_answer.ai_feedback = f"Evaluation error: {error_message}"
        user_answer.save()
        logger.error(f"Evaluation error for answer {user_answer.id}: {error_message}")

    @classmethod
    def evaluate_answer(cls, question, user_answer, question_type, language="en"):
        """
        Evaluate a user's answer to a question using OpenAI API.
        
        Parameters:
        - question: The Question object
        - user_answer: The user's answer text
        - question_type: Type of question (MCQ, OPEN_ENDED, CALCULATION)
        - language: Language code for the AI response (default: "en")
        
        Returns:
        - ai_response: The raw AI response
        - processing_time: Time taken for processing in ms
        - error: Error message if any
        """
        # Get the appropriate template
        template = cls.get_template_for_question_type(question_type)
        
        # Create a temporary user answer for prompt preparation
        from assessment.models import UserAnswer
        temp_user_answer = UserAnswer(
            user=None,  # Not needed for prompt generation
            question=question,
            submitted_answer_text=user_answer if question_type == 'OPEN_ENDED' else None,
            submitted_calculation_input={'user_input': user_answer} if question_type == 'CALCULATION' else None,
            max_possible_score=question.points,
            evaluation_status='PENDING'
        )
        
        # Prepare the prompt
        prompt = cls.prepare_prompt(template, temp_user_answer)
        
        if not prompt:
            return None, 0, "Failed to prepare evaluation prompt"
        
        # Add language instruction to the prompt
        language_name = cls.get_language_name(language)
        language_instruction = f"\n\nIMPORTANT: Provide your response in {language_name}. All feedback must be in {language_name}.\n"
        prompt += language_instruction
        
        # Call the OpenAI API
        return cls.call_openai_api(prompt)
        
    @classmethod
    def get_language_name(cls, language_code):
        """Convert language code to full language name for instructions"""
        language_map = {
            "en": "English",
            "de": "German",
            "nl": "Dutch",
        }
        return language_map.get(language_code, "English")


class ContentUpdateService:
    """
    Service for scanning the web for content updates and creating alerts.
    This service is designed to be called asynchronously via Celery.
    """
    
    # Default prompt template for web content updates
    DEFAULT_CONTENT_UPDATE_PROMPT = """
You are an AI content monitor for a professional exam preparation platform. Your task is to identify recent changes in regulations, standards, or knowledge that would affect exam questions.

CONTEXT:
- Exam Topic: {topic_name}
- Current Questions in our Database:
{questions_data}

SEARCH RESULTS:
{web_search_results}

ANALYSIS INSTRUCTIONS:
1. Identify any new information in the search results that would affect our questions
2. For each affected question, explain what has changed and how it impacts the question/answer
3. Assign a confidence score (1-10) and priority (Low/Medium/High) based on:
   - Reliability of source
   - Significance of change
   - Certainty of impact on our content

Respond in the following JSON format:
{
  "affected_questions": [
    {
      "question_id": int,
      "change_summary": "Brief summary of what changed",
      "detailed_explanation": "Detailed explanation with sources",
      "source_urls": ["url1", "url2"],
      "ai_confidence_score": float,
      "priority": "LOW|MEDIUM|HIGH"
    }
  ],
  "unaffected_questions": [list of question_ids that don't need updates],
  "new_topic_suggestions": [
    {
      "suggested_topic": "Name of potential new topic",
      "reasoning": "Why this should be added to curriculum",
      "source_urls": ["url1", "url2"]
    }
  ]
}
"""
    
    @classmethod
    def get_due_scan_configs(cls):
        """Get scan configurations that are due to run."""
        now = timezone.now()
        
        # Get active configs where next_scheduled_run is None or in the past
        return ContentUpdateScanConfig.objects.filter(
            is_active=True
        ).filter(
            models.Q(next_scheduled_run__isnull=True) | 
            models.Q(next_scheduled_run__lte=now)
        )
    
    @classmethod
    def perform_web_search(cls, topic_name, additional_keywords=None):
        """
        Perform a web search using OpenAI Responses API with web search capabilities.
        Returns a list of search results.
        """
        try:
            from openai import OpenAI
            
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            
            search_term = topic_name
            if additional_keywords:
                search_term += f" {additional_keywords}"
                
            # Add recent time frame to focus on new content
            search_term += " recent changes updates new developments"
            
            # Use the new OpenAI responses API with web search
            response = client.responses.create(
                model="gpt-4o-mini-search-preview",
                tools=[{"type": "web_search_preview"}],
                input=f"Find recent updates, changes, or new information about: {search_term}. Focus on changes to regulations, standards, or best practices that happened in the past year. Provide specific sources and URLs.",
            )
            
            # Parse the response
            search_results = []
            if response.status == "completed" and response.output:
                for output_item in response.output:
                    if output_item.type == "message" and output_item.status == "completed":
                        for content in output_item.content:
                            if content.type == "output_text":
                                text = content.text
                                
                                # Extract URL citations if available
                                urls = []
                                if hasattr(content, 'annotations'):
                                    for annotation in content.annotations:
                                        if annotation.type == "url_citation":
                                            urls.append({
                                                'url': annotation.url,
                                                'title': getattr(annotation, 'title', ''),
                                                'start_index': annotation.start_index,
                                                'end_index': annotation.end_index
                                            })
                                
                                search_results.append({
                                    'content': text,
                                    'urls': urls,
                                    'source': 'OpenAI Web Search'
                                })
            
            if not search_results:
                # Fallback result if no web search results
                search_results = [{
                    'content': f"No recent updates found for {topic_name} through web search.",
                    'urls': [],
                    'source': 'OpenAI Web Search'
                }]
                
            return search_results
            
        except Exception as e:
            logger.error(f"Error performing web search for topic '{topic_name}': {str(e)}")
            # Return fallback results
            return [{
                'content': f"Error searching for updates on {topic_name}: {str(e)}",
                'urls': [],
                'source': 'Error'
            }]
    
    @classmethod
    def prepare_questions_data(cls, questions):
        """Prepare questions data for the AI prompt."""
        questions_data = []
        
        for question in questions:
            question_data = {
                "question_id": question.id,
                "question_text": question.text
            }
            
            # Add model answer if available
            if question.model_answer_text:
                question_data["current_answer"] = question.model_answer_text
            
            questions_data.append(question_data)
        
        return json.dumps(questions_data, indent=2)
    
    @classmethod
    def prepare_update_prompt(cls, topic, questions, search_results, template=None):
        """Prepare the prompt for content update analysis."""
        if template:
            prompt = template
        else:
            prompt = cls.DEFAULT_CONTENT_UPDATE_PROMPT
        
        # Prepare questions data
        questions_data = cls.prepare_questions_data(questions)
        
        # Format search results
        web_search_results = ""
        for i, result in enumerate(search_results, 1):
            web_search_results += f"Result {i}:\n"
            web_search_results += f"Title: {result.get('title', '')}\n"
            web_search_results += f"URL: {result.get('url', '')}\n"
            web_search_results += f"Content: {result.get('snippet', '')}\n\n"
        
        # Replace variables in template
        prompt = prompt.replace("{topic_name}", topic.name)
        prompt = prompt.replace("{questions_data}", questions_data)
        prompt = prompt.replace("{web_search_results}", web_search_results)
        
        return prompt
    
    @classmethod
    def analyze_content_updates(cls, prompt):
        """
        Use OpenAI API to analyze potential content updates.
        Returns (ai_response, error_message).
        """
        try:
            from openai import OpenAI
            
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            
            response = client.chat.completions.create(
                model=settings.OPENAI_MODEL or "gpt-4o-mini",
                messages=[
                    {'role': 'system', 'content': 'You are an expert content monitor for a professional exam platform. Always respond in valid JSON format.'},
                    {'role': 'user', 'content': prompt}
                ],
                temperature=0.2,
                response_format={'type': 'json_object'}
            )
            
            ai_response = response.choices[0].message.content
            return ai_response, None
        
        except Exception as e:
            error_msg = f"Error calling OpenAI API: {str(e)}"
            logger.exception(error_msg)
            return None, error_msg
    
    @classmethod
    def process_update_analysis(cls, ai_response, topic, questions):
        """
        Process the AI response and create alerts for affected questions.
        Returns count of alerts created.
        """
        try:
            # Parse JSON response
            analysis = json.loads(ai_response)
            
            # Check if required fields exist
            if 'affected_questions' not in analysis:
                logger.error(f"Missing 'affected_questions' in AI response: {ai_response}")
                return 0
            
            alerts_created = 0
            
            # Process affected questions
            with transaction.atomic():
                for affected in analysis.get('affected_questions', []):
                    # Extract data
                    question_id = affected.get('question_id')
                    change_summary = affected.get('change_summary', '')
                    detailed_explanation = affected.get('detailed_explanation', '')
                    source_urls = affected.get('source_urls', [])
                    ai_confidence_score = affected.get('ai_confidence_score')
                    priority = affected.get('priority', 'MEDIUM').upper()
                    
                    # Validate priority value
                    if priority not in ['LOW', 'MEDIUM', 'HIGH']:
                        priority = 'MEDIUM'
                    
                    # Find the question
                    question = None
                    for q in questions:
                        if q.id == question_id:
                            question = q
                            break
                    
                    if not question:
                        logger.warning(f"Question with ID {question_id} not found")
                        continue
                    
                    # Create alert
                    alert = AIContentAlert(
                        alert_type='QUESTION_UPDATE_SUGGESTION',
                        related_topic=topic,
                        related_question=question,
                        summary_of_potential_change=change_summary,
                        detailed_explanation=detailed_explanation,
                        source_urls=source_urls,
                        ai_confidence_score=ai_confidence_score,
                        priority=priority,
                        status='NEW'
                    )
                    alert.save()
                    alerts_created += 1
                
                # Process new topic suggestions
                for suggestion in analysis.get('new_topic_suggestions', []):
                    suggested_topic = suggestion.get('suggested_topic', '')
                    reasoning = suggestion.get('reasoning', '')
                    source_urls = suggestion.get('source_urls', [])
                    
                    # Create alert for new topic
                    alert = AIContentAlert(
                        alert_type='TOPIC_UPDATE',
                        related_topic=topic,  # Associate with the parent topic
                        summary_of_potential_change=f"New topic suggestion: {suggested_topic}",
                        detailed_explanation=reasoning,
                        source_urls=source_urls,
                        ai_confidence_score=8.0,  # Default confidence for new topics
                        priority='MEDIUM',
                        status='NEW'
                    )
                    alert.save()
                    alerts_created += 1
            
            return alerts_created
        
        except (json.JSONDecodeError, ValueError) as e:
            logger.error(f"Failed to parse AI response: {str(e)} - {ai_response}")
            return 0
        except Exception as e:
            logger.exception(f"Error processing update analysis: {str(e)}")
            return 0
    
    @classmethod
    def calculate_next_run_date(cls, frequency):
        """Calculate the next run date based on frequency."""
        now = timezone.now()
        
        if frequency == 'DAILY':
            return now + timedelta(days=1)
        elif frequency == 'WEEKLY':
            return now + timedelta(weeks=1)
        elif frequency == 'MONTHLY':
            return now + timedelta(days=30)
        elif frequency == 'QUARTERLY':
            return now + timedelta(days=90)
        else:
            return now + timedelta(weeks=1)  # Default to weekly
    
    @classmethod
    def run_content_update_scan(cls, scan_config_id):
        """
        Execute a content update scan for the given configuration.
        This is the main entry point for the Celery task.
        """
        try:
            # Get scan configuration
            scan_config = ContentUpdateScanConfig.objects.get(id=scan_config_id)
            
            # Create log entry
            scan_log = ContentUpdateScanLog(
                scan_config=scan_config,
                start_time=timezone.now(),
                status='IN_PROGRESS'
            )
            scan_log.save()
            
            # Get exams to scan
            exams = scan_config.exams.filter(is_active=True)
            if not exams:
                cls._complete_scan_log(scan_log, 'COMPLETED', error_message="No active exams found for scanning")
                return
            
            # Track topics and questions scanned
            topics_scanned = []
            total_questions_scanned = 0
            total_alerts_generated = 0
            
            # Process each exam
            for exam in exams:
                # Get active topics for this exam
                topics = Topic.objects.filter(
                    questions__exam=exam
                ).distinct()
                
                # Process each topic
                for topic in topics:
                    # Get active questions for this topic
                    questions = Question.objects.filter(
                        exam=exam,
                        topic=topic,
                        is_active=True
                    )[:scan_config.max_questions_per_scan]
                    
                    if not questions:
                        continue
                    
                    # Perform web search
                    search_results = cls.perform_web_search(topic.name, exam.name)
                    
                    if not search_results:
                        logger.warning(f"No search results found for topic '{topic.name}'")
                        continue
                    
                    # Prepare analysis prompt
                    prompt = cls.prepare_update_prompt(
                        topic, 
                        questions, 
                        search_results, 
                        template=scan_config.prompt_template
                    )
                    
                    # Analyze content updates
                    ai_response, error = cls.analyze_content_updates(prompt)
                    
                    if error or not ai_response:
                        logger.error(f"Failed to analyze content updates for topic '{topic.name}': {error}")
                        continue
                    
                    # Process analysis results
                    alerts_created = cls.process_update_analysis(ai_response, topic, questions)
                    
                    # Update stats
                    topics_scanned.append({
                        'id': topic.id,
                        'name': topic.name,
                        'alerts_created': alerts_created
                    })
                    total_questions_scanned += len(questions)
                    total_alerts_generated += alerts_created
            
            # Update scan config with last run time and next scheduled run
            scan_config.last_run = timezone.now()
            scan_config.next_scheduled_run = cls.calculate_next_run_date(scan_config.frequency)
            scan_config.save()
            
            # Update log entry
            cls._complete_scan_log(
                scan_log, 
                'COMPLETED', 
                topics_scanned=topics_scanned,
                questions_scanned=total_questions_scanned,
                alerts_generated=total_alerts_generated
            )
            
            return total_alerts_generated
            
        except ContentUpdateScanConfig.DoesNotExist:
            logger.error(f"Scan configuration with ID {scan_config_id} does not exist")
            return 0
        except Exception as e:
            logger.exception(f"Error running content update scan: {str(e)}")
            
            # Try to update log entry if it exists
            try:
                scan_log = ContentUpdateScanLog.objects.filter(
                    scan_config_id=scan_config_id,
                    status='IN_PROGRESS'
                ).order_by('-start_time').first()
                
                if scan_log:
                    cls._complete_scan_log(scan_log, 'FAILED', error_message=str(e))
            except:
                pass
            
            return 0
    
    @staticmethod
    def _complete_scan_log(scan_log, status, error_message=None, topics_scanned=None, questions_scanned=0, alerts_generated=0):
        """Complete a scan log entry with results."""
        scan_log.end_time = timezone.now()
        scan_log.status = status
        scan_log.error_message = error_message
        scan_log.topics_scanned = topics_scanned
        scan_log.questions_scanned = questions_scanned
        scan_log.alerts_generated = alerts_generated
        scan_log.save()


class ChatbotService:
    """
    Service for handling AI chatbot conversations.
    This service provides methods for creating, retrieving, and interacting with chatbot conversations.
    """
    
    # Enhanced system prompt for the support chatbot
    DEFAULT_CHATBOT_PROMPT = """
You are a helpful and knowledgeable support assistant for Testsimu, a professional exam preparation platform. Your goal is to provide excellent customer support and help users with their questions about our platform, exam preparation, and services.

PLATFORM DETAILS:
- Available Exams: {list_of_exams}
- Question Types: Multiple choice, open-ended, and calculation-based questions
- Subscription Plans: {subscription_details}
- Key Features: Exam simulations, performance analytics, AI-evaluated practice, progress tracking

SUPPORT CAPABILITIES:
- Account and subscription management
- Technical troubleshooting
- Exam preparation guidance
- Performance analytics explanation
- Billing and payment support
- Feature explanations

INSTRUCTIONS:
1. Always be friendly, professional, and helpful
2. Provide clear, step-by-step solutions when possible
3. For account-specific issues (billing, subscriptions), provide general guidance but suggest contacting support for detailed help
4. For technical issues, offer troubleshooting steps and workarounds
5. When discussing exam content, provide study tips and guidance without giving away actual answers
6. If you don't have enough information, be honest and direct users to appropriate resources
7. Always end with asking if there's anything else you can help with
8. Use a conversational, supportive tone

CURRENT USER QUESTION:
{user_query}

RELEVANT FAQ INFORMATION:
{relevant_faq_items}

RESPONSE GUIDELINES:
- Keep responses concise but comprehensive
- Use bullet points or numbered lists for complex instructions
- Include relevant links or contact information when helpful
- Maintain a positive, encouraging tone
- Focus on solving the user's immediate problem
"""
    
    @classmethod
    def get_available_exams(cls):
        """Retrieve list of available exams in the system."""
        try:
            return list(Exam.objects.filter(is_active=True).values_list('name', flat=True))
        except Exception as e:
            logger.error(f"Error retrieving exams: {str(e)}")
            return []
    
    @classmethod
    def get_subscription_details(cls):
        """
        Retrieve subscription plan details.
        This is a placeholder - in a real implementation, this would fetch actual subscription plans from the database.
        """
        # This would typically come from a subscription plans table or model
        return [
            {"name": "Basic Plan", "price": "$19.99/month", "features": ["Access to 2 exam simulations", "Basic performance analytics"]},
            {"name": "Pro Plan", "price": "$39.99/month", "features": ["Access to all exam simulations", "Advanced analytics", "AI-evaluated practice"]},
            {"name": "Premium Plan", "price": "$59.99/month", "features": ["Everything in Pro", "1-on-1 tutoring sessions", "Priority support"]}
        ]
    
    @classmethod
    def get_relevant_faq_items(cls, user_query):
        """
        Find FAQ items relevant to the user's query.
        Enhanced with more comprehensive support topics.
        """
        # Comprehensive FAQ database for better support
        all_faqs = [
            # Account & Authentication
            {"question": "How do I reset my password?", "answer": "Go to the login page and click 'Forgot Password'. Follow the instructions sent to your email.", "category": "account"},
            {"question": "How do I change my email address?", "answer": "Go to your Profile settings and update your email. You'll need to verify the new email address.", "category": "account"},
            {"question": "Why can't I log in to my account?", "answer": "Check your email and password. If forgotten, use 'Forgot Password'. Ensure your account isn't suspended.", "category": "account"},
            
            # Subscriptions & Billing
            {"question": "How can I upgrade my subscription?", "answer": "Log in to your account, go to 'Subscription' tab, and select 'Upgrade' next to your desired plan.", "category": "subscription"},
            {"question": "Can I get a refund?", "answer": "We offer a 7-day refund policy. Contact support@testsimu.com with your request and order details.", "category": "billing"},
            {"question": "How do I cancel my subscription?", "answer": "Go to your Account Settings > Subscription and click 'Cancel Subscription'. Your access continues until the end of the billing period.", "category": "subscription"},
            {"question": "What payment methods do you accept?", "answer": "We accept major credit cards, debit cards, and PayPal. All payments are processed securely.", "category": "billing"},
            
            # Exams & Practice
            {"question": "Are the practice exams similar to real exams?", "answer": "Yes, our exams are designed by industry experts to closely match the format, difficulty, and content of actual certification exams.", "category": "exams"},
            {"question": "How is my practice exam score calculated?", "answer": "Scores are calculated based on correct answers. For multiple-choice, each correct answer earns points. For open-ended questions, our AI evaluates your response against model answers.", "category": "scoring"},
            {"question": "Can I retake practice exams?", "answer": "Yes, you can retake practice exams as many times as you want during your subscription period.", "category": "exams"},
            {"question": "How do I view my exam results?", "answer": "After completing an exam, go to 'My Exams' > 'Results' to see detailed performance analytics and feedback.", "category": "results"},
            
            # Technical Issues
            {"question": "The app is running slowly, what should I do?", "answer": "Try closing and reopening the app, check your internet connection, and ensure you have the latest version installed.", "category": "technical"},
            {"question": "I'm having trouble loading questions", "answer": "Check your internet connection, try refreshing the page, or restart the app. If problems persist, contact support.", "category": "technical"},
            {"question": "How do I update the app?", "answer": "Go to your device's app store (Google Play or App Store) and check for updates to Testsimu.", "category": "technical"},
            
            # Features & Usage
            {"question": "How do I track my progress?", "answer": "Use the Analytics section to view detailed progress reports, performance trends, and topic-wise analysis.", "category": "features"},
            {"question": "What is AI evaluation?", "answer": "Our AI system automatically evaluates your open-ended answers and provides detailed feedback to help you improve.", "category": "features"},
            {"question": "How do I study effectively?", "answer": "Use practice exams regularly, review detailed explanations for wrong answers, and focus on weak topics identified in your analytics.", "category": "study"}
        ]
        
        # Enhanced keyword matching with category weighting
        relevant_faqs = []
        query_lower = user_query.lower()
        query_terms = query_lower.split()
        
        # Define category keywords for better matching
        category_keywords = {
            "account": ["login", "password", "email", "account", "profile", "sign", "register"],
            "subscription": ["subscription", "plan", "upgrade", "premium", "cancel", "renew"],
            "billing": ["payment", "refund", "billing", "charge", "money", "cost", "price"],
            "exams": ["exam", "test", "practice", "question", "quiz", "simulation"],
            "scoring": ["score", "points", "grade", "result", "evaluation"],
            "technical": ["slow", "loading", "error", "bug", "crash", "problem", "issue"],
            "features": ["analytics", "progress", "ai", "tracking", "dashboard"],
            "study": ["study", "learn", "prepare", "tips", "help", "improve"]
        }
        
        for faq in all_faqs:
            relevance_score = 0
            question_text = faq["question"].lower()
            answer_text = faq["answer"].lower()
            category = faq.get("category", "")
            
            # Direct keyword matching
            for term in query_terms:
                if term in question_text:
                    relevance_score += 3
                elif term in answer_text:
                    relevance_score += 2
            
            # Category-based matching
            if category in category_keywords:
                for keyword in category_keywords[category]:
                    if keyword in query_lower:
                        relevance_score += 1
            
            # Add FAQ if it has any relevance
            if relevance_score > 0:
                relevant_faqs.append((faq, relevance_score))
        
        # Sort by relevance score and return top 3
        relevant_faqs.sort(key=lambda x: x[1], reverse=True)
        return [faq[0] for faq in relevant_faqs[:3]]
    
    @classmethod
    def _generate_fallback_response(cls, user_message):
        """
        Generate a fallback response when OpenAI API is not available.
        This provides helpful responses based on FAQ matching.
        """
        # Get relevant FAQs for the user's message
        relevant_faqs = cls.get_relevant_faq_items(user_message)
        
        if relevant_faqs:
            # Create a response based on relevant FAQs
            response = "I found some information that might help:\n\n"
            for i, faq in enumerate(relevant_faqs, 1):
                response += f"{i}. **{faq['question']}**\n"
                response += f"   {faq['answer']}\n\n"
            
            response += "If you need further assistance, please contact our support team at support@testsimu.com."
        else:
            # Generic fallback response
            response = """Thank you for your message! I'm currently unable to provide a detailed response, but I'm here to help with:

• Account and login issues
• Subscription and billing questions
• Exam preparation guidance
• Technical troubleshooting
• Performance analytics

For immediate assistance, please contact our support team at support@testsimu.com, or try rephrasing your question using specific keywords like "password", "subscription", "exam", etc.

Is there anything specific I can help you with?"""
        
        return response

    @classmethod
    def get_active_conversation(cls, user):
        """
        Get or create an active conversation for the user.
        Returns the active conversation or creates a new one if none exists.
        """
        try:
            # First, try to get an existing active conversation
            conversation = ChatbotConversation.objects.filter(
                user=user,
                is_active=True
            ).first()
            
            if conversation:
                return conversation
            
            # If no active conversation exists, create a new one
            conversation = ChatbotConversation.objects.create(
                user=user,
                title="New Conversation",
                is_active=True
            )
            
            # Add system message to the conversation
            cls._add_system_message(conversation)
            
            return conversation
            
        except Exception as e:
            logger.error(f"Error getting/creating active conversation for user {user.id}: {str(e)}")
            return None

    @classmethod
    def create_conversation(cls, user, title=None):
        """
        Create a new conversation for a user.
        """
        try:
            # Deactivate any existing active conversation
            ChatbotConversation.objects.filter(
                user=user,
                is_active=True
            ).update(is_active=False)
            
            # Create new conversation
            conversation = ChatbotConversation.objects.create(
                user=user,
                title=title or "New Conversation",
                is_active=True
            )
            
            # Add system message to the conversation
            cls._add_system_message(conversation)
            
            return conversation
            
        except Exception as e:
            logger.error(f"Error creating conversation for user {user.id}: {str(e)}")
            return None

    @classmethod
    def _add_system_message(cls, conversation):
        """Add initial system message to a conversation."""
        try:
            from .models import ChatbotMessage
            
            # Get platform information
            available_exams = cls.get_available_exams()
            subscription_details = cls.get_subscription_details()
            
            # Format system prompt
            system_prompt = cls.DEFAULT_CHATBOT_PROMPT.format(
                list_of_exams=", ".join(available_exams) if available_exams else "Various certification exams",
                subscription_details=", ".join([f"{plan['name']}: {plan['price']}" for plan in subscription_details]),
                user_query="",
                relevant_faq_items=""
            )
            
            # Create system message
            ChatbotMessage.objects.create(
                conversation=conversation,
                role='SYSTEM',
                content=system_prompt
            )
            
        except Exception as e:
            logger.error(f"Error adding system message to conversation {conversation.id}: {str(e)}")

    @classmethod
    def send_message(cls, user, message, language='en'):
        """
        Send a message to the chatbot and get a response.
        """
        try:
            from .models import ChatbotMessage
            
            # Get or create active conversation
            conversation = cls.get_active_conversation(user)
            if not conversation:
                return {"error": "Could not create conversation"}
            
            # Add user message to conversation
            user_message = ChatbotMessage.objects.create(
                conversation=conversation,
                role='USER',
                content=message
            )
            
            # Prepare conversation history for AI
            messages = cls.prepare_conversation_history(conversation)
            
            start_time = time.time()
            
            try:
                # Try to use OpenAI API
                ai_response = cls._get_openai_response(messages, user_message.content, language)
            except Exception as e:
                logger.warning(f"OpenAI API failed, using fallback response: {str(e)}")
                ai_response = cls._generate_fallback_response(message)
            
            processing_time = int((time.time() - start_time) * 1000)
            
            # Save AI response
            ai_message = ChatbotMessage.objects.create(
                conversation=conversation,
                role='ASSISTANT',
                content=ai_response,
                processing_time_ms=processing_time
            )
            
            # Update conversation timestamp
            conversation.updated_at = timezone.now()
            conversation.save(update_fields=['updated_at'])
            
            return {
                "message_id": ai_message.id,
                "content": ai_response,
                "processing_time_ms": processing_time,
                "conversation_id": conversation.id
            }
            
        except Exception as e:
            logger.error(f"Error sending message for user {user.id}: {str(e)}")
            return {"error": f"Failed to send message: {str(e)}"}

    @classmethod
    def _get_openai_response(cls, messages, user_query, language='en'):
        """
        Get response from OpenAI API.
        """
        # Check if OpenAI is configured
        if not hasattr(settings, 'OPENAI_API_KEY') or not settings.OPENAI_API_KEY:
            raise Exception("OpenAI API not configured")
        
        try:
            from openai import OpenAI
            
            # Initialize OpenAI client
            client = OpenAI(api_key=settings.OPENAI_API_KEY)
            
            # Prepare the final message with relevant FAQs
            relevant_faqs = cls.get_relevant_faq_items(user_query)
            faq_text = ""
            if relevant_faqs:
                faq_text = "\n".join([f"Q: {faq['question']}\nA: {faq['answer']}" for faq in relevant_faqs])
            
            # Update the last system message with current context
            if messages and messages[0]['role'] == 'system':
                messages[0]['content'] = cls.DEFAULT_CHATBOT_PROMPT.format(
                    list_of_exams=", ".join(cls.get_available_exams()),
                    subscription_details=", ".join([f"{plan['name']}: {plan['price']}" for plan in cls.get_subscription_details()]),
                    user_query=user_query,
                    relevant_faq_items=faq_text
                )
            
            # Make API request
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=messages,
                max_tokens=500,
                temperature=0.7
            )
            
            return response.choices[0].message.content.strip()
            
        except ImportError:
            raise Exception("OpenAI library not installed")
        except Exception as e:
            raise Exception(f"OpenAI API error: {str(e)}")

    @classmethod
    def prepare_conversation_history(cls, conversation):
        """
        Prepare conversation history for OpenAI API.
        """
        try:
            from .models import ChatbotMessage
            
            messages = []
            
            # Get all messages in chronological order
            conversation_messages = ChatbotMessage.objects.filter(
                conversation=conversation
            ).order_by('created_at')
            
            for msg in conversation_messages:
                if msg.role == 'SYSTEM':
                    messages.append({
                        'role': 'system',
                        'content': msg.content
                    })
                elif msg.role == 'USER':
                    messages.append({
                        'role': 'user',
                        'content': msg.content
                    })
                elif msg.role == 'ASSISTANT':
                    messages.append({
                        'role': 'assistant',
                        'content': msg.content
                    })
            
            # Limit history to last 20 messages to stay within token limits
            if len(messages) > 20:
                # Keep system message and last 19 messages
                system_messages = [msg for msg in messages if msg['role'] == 'system']
                other_messages = [msg for msg in messages if msg['role'] != 'system']
                messages = system_messages + other_messages[-19:]
            
            return messages
            
        except Exception as e:
            logger.error(f"Error preparing conversation history: {str(e)}")
            return []

    @classmethod
    def list_user_conversations(cls, user):
        """
        Get a list of conversations for a user.
        """
        try:
            conversations = ChatbotConversation.objects.filter(
                user=user
            ).order_by('-updated_at')
            
            result = []
            for conv in conversations:
                result.append({
                    'id': conv.id,
                    'title': conv.title or f"Conversation {conv.id}",
                    'created_at': conv.created_at.isoformat(),
                    'updated_at': conv.updated_at.isoformat(),
                    'is_active': conv.is_active,
                    'message_count': conv.messages.count()
                })
            
            return result
            
        except Exception as e:
            logger.error(f"Error listing conversations for user {user.id}: {str(e)}")
            return {"error": f"Failed to retrieve conversations: {str(e)}"}

    @classmethod
    def get_conversation_history(cls, user, conversation_id):
        """
        Get the message history for a specific conversation.
        """
        try:
            conversation = ChatbotConversation.objects.filter(
                id=conversation_id,
                user=user
            ).first()
            
            if not conversation:
                return {"error": "Conversation not found"}
            
            from .models import ChatbotMessage
            messages = ChatbotMessage.objects.filter(
                conversation=conversation
            ).exclude(role='SYSTEM').order_by('created_at')
            
            result = {
                'conversation_id': conversation.id,
                'title': conversation.title,
                'messages': []
            }
            
            for msg in messages:
                result['messages'].append({
                    'id': msg.id,
                    'role': msg.role,
                    'content': msg.content,
                    'created_at': msg.created_at.isoformat(),
                    'processing_time_ms': msg.processing_time_ms
                })
            
            return result
            
        except Exception as e:
            logger.error(f"Error getting conversation history for user {user.id}, conversation {conversation_id}: {str(e)}")
            return {"error": f"Failed to retrieve conversation history: {str(e)}"}

    @classmethod
    def end_conversation(cls, user, conversation_id):
        """
        End (deactivate) a conversation.
        """
        try:
            conversation = ChatbotConversation.objects.filter(
                id=conversation_id,
                user=user
            ).first()
            
            if not conversation:
                return {"error": "Conversation not found"}
            
            conversation.is_active = False
            conversation.save(update_fields=['is_active'])
            
            return {"message": f"Conversation {conversation_id} ended successfully"}
            
        except Exception as e:
            logger.error(f"Error ending conversation {conversation_id} for user {user.id}: {str(e)}")
            return {"error": f"Failed to end conversation: {str(e)}"}

    @classmethod
    def add_user_message(cls, conversation, message):
        """
        Add a user message to a conversation.
        """
        try:
            from .models import ChatbotMessage
            
            user_message = ChatbotMessage.objects.create(
                conversation=conversation,
                role='USER',
                content=message
            )
            
            # Update conversation timestamp
            conversation.updated_at = timezone.now()
            conversation.save(update_fields=['updated_at'])
            
            return user_message
            
        except Exception as e:
            logger.error(f"Error adding user message to conversation {conversation.id}: {str(e)}")
            return None