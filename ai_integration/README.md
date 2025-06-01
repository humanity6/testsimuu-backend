# AI Integration

This Django app implements AI-based features for the exam platform, including automatic evaluation of user answers and content updates alerts.

## Features

### 1. Automatic Answer Evaluation

The system automatically evaluates user answers for:
- **Open-ended questions** - Using OpenAI to compare against model answers
- **Calculation-based questions** - Evaluating calculations against predefined logic

### 2. Content Update Alerts

AI scans the web daily for updates related to exam topics (e.g., changes in laws or regulations) and notifies admins to keep content fresh.

## Setup

### Prerequisites

- OpenAI API key configured in Django settings
- Working Celery setup for asynchronous processing

### Configuration

In your Django settings, add:

```python
OPENAI_API_KEY = 'your-api-key'
OPENAI_MODEL = 'gpt-4' # or the model you prefer
```

### Installing Templates and Default Configurations

Run the management commands to create default feedback templates and scan configurations:

```bash
python manage.py create_feedback_templates
python manage.py create_scan_config --frequency WEEKLY
```

## Usage

### Automatic Answer Evaluation

When a user submits an open-ended or calculation-based answer:

1. Set the `evaluation_status` to `PENDING`
2. The system will automatically queue the evaluation via Celery
3. Results appear in the user's answer with feedback and scoring

### Manual Evaluation Triggering (Admin Only)

#### Via API:

- Single answer: `POST /api/ai/evaluate/answer/` with `{"user_answer_id": 123}`
- Batch processing: `POST /api/ai/evaluate/batch/` to process up to 100 pending answers

### Web Content Update Scanning

The system periodically scans the web for updates related to exam topics and creates alerts when potential changes are detected.

#### Configuration via Admin Interface:

1. Go to the Django admin interface
2. Navigate to AI Integration > Content Update Scan Configurations
3. Create or edit scan configurations, selecting:
   - Exams to monitor
   - Scan frequency (daily, weekly, monthly, quarterly)
   - Maximum questions to check per scan

#### Manual Triggering via API:

- `POST /api/ai/scan-configs/{id}/run_scan/` to trigger a scan for a specific configuration

#### Scheduled Execution:

For automatic scanning, add the Celery Beat scheduler task:

```python
# In your Celery Beat schedule settings
CELERY_BEAT_SCHEDULE = {
    'check-content-update-scans': {
        'task': 'ai_integration.tasks.check_and_schedule_content_update_scans',
        'schedule': crontab(minute=0, hour='*/6'),  # Run every 6 hours
    },
}
```

## Customizing Templates

Templates can be customized through the Django admin. Each template includes:

- Context variables (question, topic, model answer)
- Instructions for the AI evaluator
- JSON response format expectations

## Technical Details

### Response Format for Answer Evaluation

The AI evaluation produces a structured response:

#### For Open-Ended Questions:
```json
{
  "raw_score": 0.85,
  "is_correct": true,
  "ai_feedback": "Detailed feedback...",
  "score_explanation": "Explanation of scoring..."
}
```

#### For Calculation Questions:
```json
{
  "raw_score": 0.7,
  "is_correct": false,
  "ai_feedback": "Detailed feedback...",
  "error_locations": ["Step 2", "Final calculation"],
  "correct_approach": "Brief summary of correct method..."
}
```

### Response Format for Content Updates

The content update analysis produces a structured response:

```json
{
  "affected_questions": [
    {
      "question_id": 123,
      "change_summary": "Brief summary of what changed",
      "detailed_explanation": "Detailed explanation with sources",
      "source_urls": ["url1", "url2"],
      "ai_confidence_score": 8.5,
      "priority": "MEDIUM"
    }
  ],
  "unaffected_questions": [124, 125, 126],
  "new_topic_suggestions": [
    {
      "suggested_topic": "Name of potential new topic",
      "reasoning": "Why this should be added to curriculum",
      "source_urls": ["url1", "url2"]
    }
  ]
}
```

## Logging

All evaluations and content scans are logged in their respective models:
- `AIEvaluationLog` for answer evaluations
- `ContentUpdateScanLog` for content update scans

This allows for monitoring, debugging, and improving the processes over time. 