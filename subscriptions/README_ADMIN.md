# Subscription Management System

This document provides instructions for administrators on how to manage the subscription system, including pricing plans, user subscriptions, and SumUp payment integration.

## Overview

The subscription management system allows administrators to:

- Create and manage pricing plans with different pricing tiers (monthly, yearly, bundle-based)
- Associate pricing plans with specific exams
- Monitor user subscriptions and payments
- Manually activate, deactivate, and extend subscriptions
- Sync subscription statuses with SumUp payment gateway

## Admin Interface

### Django Admin Panel

The system provides a comprehensive Django admin interface at `/admin/subscriptions/`:

- **Pricing Plans**: Manage all subscription pricing tiers
- **User Subscriptions**: View and manage user subscriptions
- **Payments**: View payment history and details

Key features in the admin panel:

- **Duplicate Plans**: Easily create copies of existing plans
- **Activate/Deactivate Plans**: Control plan availability
- **Extend Subscriptions**: Add days to existing subscriptions
- **Payment Sync**: Sync payment status with SumUp

### Admin API

The system also provides a RESTful API for administrative tasks at `/api/subscriptions/admin/`:

#### Pricing Plans API

- **List/Create Plans**: `GET/POST /api/subscriptions/admin/pricing-plans/`
- **Retrieve/Update/Delete Plan**: `GET/PUT/PATCH/DELETE /api/subscriptions/admin/pricing-plans/{id}/`
- **Duplicate Plan**: `POST /api/subscriptions/admin/pricing-plans/{id}/duplicate/`
- **Plans by Exam**: `GET /api/subscriptions/admin/pricing-plans/by_exam/`
- **Activate Plan**: `POST /api/subscriptions/admin/pricing-plans/{id}/activate/`
- **Deactivate Plan**: `POST /api/subscriptions/admin/pricing-plans/{id}/deactivate/`

#### Subscriptions API

- **List/Create Subscriptions**: `GET/POST /api/subscriptions/admin/subscriptions/`
- **Retrieve/Update Subscription**: `GET/PUT/PATCH /api/subscriptions/admin/subscriptions/{id}/`
- **Cancel Subscription**: `POST /api/subscriptions/admin/subscriptions/{id}/cancel/`
- **Activate Subscription**: `POST /api/subscriptions/admin/subscriptions/{id}/activate/`
- **Extend Subscription**: `POST /api/subscriptions/admin/subscriptions/{id}/extend/`
- **Sync Payment Status**: `POST /api/subscriptions/admin/subscriptions/{id}/sync_payment_status/`
- **Process Expired Subscriptions**: `POST /api/subscriptions/admin/subscriptions/process_expired/`
- **Expiring Soon Subscriptions**: `GET /api/subscriptions/admin/subscriptions/expiring_soon/`

#### Payments API

- **List Payments**: `GET /api/subscriptions/admin/payments/`
- **Retrieve Payment**: `GET /api/subscriptions/admin/payments/{id}/`
- **Mark as Successful**: `POST /api/subscriptions/admin/payments/{id}/mark_as_successful/`
- **Mark as Failed**: `POST /api/subscriptions/admin/payments/{id}/mark_as_failed/`
- **Sync with SumUp**: `POST /api/subscriptions/admin/payments/{id}/sync_with_sumup/`

## Creating Pricing Plans

To create a new pricing plan:

1. Navigate to the admin panel or use the admin API
2. Provide the following information:
   - Name: Clear descriptive name
   - Exam: The exam this plan provides access to
   - Price: The cost of the subscription
   - Currency: 3-letter currency code (e.g., USD, EUR)
   - Billing Cycle: Monthly, Quarterly, Yearly, or One-Time
   - Features List: List of features included in the plan
   - Trial Days: Number of free trial days (if applicable)
   - Display Order: Order in which plans appear to users
   - Active Status: Whether the plan is available for purchase

## SumUp Integration

The system integrates with SumUp for payment processing:

### SumUp Configuration

Ensure the following environment variables are set:

```
SUMUP_API_KEY=your_api_key
SUMUP_MERCHANT_ID=your_merchant_id
SUMUP_MERCHANT_EMAIL=your_merchant_email
SUMUP_WEBHOOK_SECRET=your_webhook_secret
```

### Payment Flow

1. User selects a subscription plan
2. System creates a checkout with SumUp
3. User completes payment on SumUp's platform
4. SumUp sends webhook notification of payment status
5. System activates/deactivates subscription based on payment status

### Manual Payment Verification

You can manually verify payment status using:

- The admin API: `POST /api/subscriptions/admin/subscriptions/{id}/sync_payment_status/`
- The Django admin panel: Select payments and use the "Sync with SumUp" action

## Scheduled Tasks

The system includes a management command to handle subscription-related tasks:

```bash
# Process all subscription tasks
python manage.py manage_subscriptions

# Process only expired subscriptions
python manage.py manage_subscriptions --task=process-expired

# Send reminders for subscriptions expiring in 14 days
python manage.py manage_subscriptions --task=send-reminders --days=14

# Sync pending payments with SumUp
python manage.py manage_subscriptions --task=sync-payments

# Dry run (preview changes without making them)
python manage.py manage_subscriptions --dry-run
```

It's recommended to set up a scheduled task (cron job) to run this command daily:

```
0 0 * * * cd /path/to/project && python manage.py manage_subscriptions >> /var/log/subscription_management.log 2>&1
```

## Troubleshooting

### Common Issues

- **Webhook Issues**: Ensure the webhook URL is correctly configured in your SumUp account
- **Payment Sync Issues**: Check that the SumUp API credentials are valid
- **Subscription Status Issues**: Manually sync the subscription with SumUp using the admin API

### Logs

Check the application logs for detailed error messages related to SumUp integration and subscription management.

## Reporting

For detailed reporting on subscriptions and payments, use the Django admin panel or the admin API to export data for further analysis. 