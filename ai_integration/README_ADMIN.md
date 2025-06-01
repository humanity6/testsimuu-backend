# AI Integration Admin Endpoints

This document describes the admin-specific endpoints for the AI Integration module.

## Overview

The AI Integration admin endpoints provide comprehensive administrative functionality for managing AI-related features in the platform. These endpoints are only accessible to admin users and are located at `/api/v1/admin/ai/`.

## Features

### 1. Content Alert Management
- **Purpose**: Manage AI-generated alerts about content that may need updating
- **Endpoints**: Full CRUD operations for content alerts
- **Key Features**:
  - Filter by alert type, status, priority
  - Filter by related topics and questions
  - Date range filtering
  - Review and action tracking

### 2. Content Scan Configuration Management
- **Purpose**: Configure automated content scanning for updates
- **Endpoints**: Full CRUD operations plus scan triggering
- **Key Features**:
  - Configure scan frequency and parameters
  - Associate with specific exams
  - Trigger manual scans
  - Track scan execution

### 3. Content Scan Log Monitoring
- **Purpose**: Monitor and analyze content scan execution logs
- **Endpoints**: Read-only access to scan logs
- **Key Features**:
  - Filter by scan status and configuration
  - View detailed scan results
  - Track scan performance metrics

### 4. AI Feedback Template Management
- **Purpose**: Manage templates used for AI-generated feedback
- **Endpoints**: Full CRUD operations plus metrics
- **Key Features**:
  - Manage templates by question type
  - Toggle template active status
  - View template usage metrics
  - Ensure quality control of AI responses

### 5. AI Evaluation Log Analysis
- **Purpose**: Monitor and analyze AI evaluation performance
- **Endpoints**: Read-only access to evaluation logs
- **Key Features**:
  - Filter by success status, date range, user, question type
  - View detailed evaluation metrics
  - Track processing times and success rates
  - Performance analysis by question type

### 6. Chatbot Administration
- **Purpose**: Moderate and manage chatbot conversations
- **Endpoints**: Full CRUD operations for conversations and read-only for messages
- **Key Features**:
  - View all user conversations
  - Deactivate/reactivate conversations (moderation)
  - Monitor conversation metrics
  - Analyze chatbot message performance
  - Track processing times

### 7. AI Evaluation Triggers
- **Purpose**: Manually trigger AI evaluations for testing and maintenance
- **Endpoints**: Trigger individual or batch evaluations
- **Key Features**:
  - Re-evaluate specific user answers
  - Batch process pending evaluations
  - Administrative override for evaluation status

## Permission Requirements

All admin AI endpoints require:
- User authentication (`IsAuthenticated`)
- Admin privileges (`IsAdminUser`)

## Endpoint Categories

### Content Management
- Content alerts: `/api/v1/admin/ai/content-alerts/`
- Scan configurations: `/api/v1/admin/ai/content-scan-configs/`
- Scan logs: `/api/v1/admin/ai/content-scan-logs/`

### AI Configuration
- Feedback templates: `/api/v1/admin/ai/feedback-templates/`
- Evaluation logs: `/api/v1/admin/ai/evaluation-logs/`

### User Interaction Management
- Chatbot conversations: `/api/v1/admin/ai/chatbot/conversations/`
- Chatbot messages: `/api/v1/admin/ai/chatbot/messages/`

### Administrative Actions
- Manual evaluations: `/api/v1/admin/ai/evaluate/`

## Metrics and Analytics

Most endpoint categories provide dedicated metrics endpoints that offer:
- Usage statistics
- Performance metrics
- Success rates
- Date range analysis
- User behavior insights

## Filtering and Search

All list endpoints support extensive filtering options:
- **Date Filtering**: `date_from`, `date_to`, `created_after`, `created_before`
- **Status Filtering**: Various status fields per model
- **User Filtering**: `user_id` where applicable
- **Type Filtering**: Question types, alert types, etc.
- **Performance Filtering**: Processing times, success rates

## Integration with Project Features

### Alignment with Project Description
- **Daily Web Search**: Managed through content scan configurations
- **Content Quality**: Ensured through feedback template management
- **AI Evaluation**: Monitored through evaluation logs and manual triggers
- **User Support**: Enhanced through chatbot administration

### Database Schema Compliance
All endpoints operate on the models defined in the database schema:
- `ai_integration_aicontentalert`
- `ai_integration_aifeedbacktemplate`
- `ai_integration_aievaluationlog`
- `ai_integration_contentupdatescanconfig`
- `ai_integration_contentupdatescanlog`
- `ai_integration_chatbotconversation`
- `ai_integration_chatbotmessage`

### API Documentation Consistency
All endpoints are documented in the main API_ENDPOINTS.txt file under section "9A. AI INTEGRATION ADMIN ENDPOINTS".

## Usage Examples

### Creating a Content Scan Configuration
```bash
POST /api/v1/admin/ai/content-scan-configs/
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "name": "Daily Law Updates Scan",
  "exams": [1, 2, 3],
  "frequency": "DAILY",
  "max_questions_per_scan": 50,
  "is_active": true,
  "prompt_template": "Check for updates to {topic_name} based on: {questions_data}. Web results: {web_search_results}"
}
```

### Reviewing Content Alerts
```bash
GET /api/v1/admin/ai/content-alerts/?status=NEW&priority=HIGH
Authorization: Bearer {admin_token}
```

### Getting AI Performance Metrics
```bash
GET /api/v1/admin/ai/evaluation-logs/metrics/?date_from=2024-01-01&date_to=2024-01-31
Authorization: Bearer {admin_token}
```

## Security Considerations

- All endpoints require admin authentication
- Sensitive data (like evaluation prompts) is logged but protected
- Message content in chatbot logs should be reviewed for privacy compliance
- Evaluation triggers should be used judiciously to avoid system overload

## Maintenance and Monitoring

Regular monitoring should include:
- Checking evaluation success rates
- Reviewing content alert priorities
- Monitoring chatbot conversation quality
- Analyzing scan configuration effectiveness
- Ensuring feedback template relevance

## Error Handling

All endpoints follow standard DRF error handling:
- `400 Bad Request`: Invalid request data
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Insufficient privileges (non-admin)
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server-side issues

## Rate Limiting

Consider implementing rate limiting for:
- Manual evaluation triggers
- Content scan triggering
- Bulk operations

This ensures system stability and prevents abuse of administrative functions. 