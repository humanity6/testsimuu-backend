# SumUp Integration

This module provides integration with SumUp payment gateway for handling subscription payments in the exam prep platform.

## Setup

### 1. Environment Variables

Set up the following environment variables for SumUp integration:

```
SUMUP_API_KEY=your_api_key
SUMUP_MERCHANT_ID=your_merchant_id
SUMUP_MERCHANT_EMAIL=your_merchant_email
SUMUP_WEBHOOK_SECRET=your_webhook_secret
```

You can obtain these credentials from your SumUp merchant dashboard.

### 2. Webhook Configuration

Configure your SumUp account to send webhooks to:

```
https://your-domain.com/api/subscriptions/webhooks/sumup/
```

Make sure to set up the webhook secret in both SumUp dashboard and your environment variables.

## API Endpoints

### Single Subscription

- **Create a subscription with payment**:
  - `POST /api/subscriptions/users/me/subscriptions/`
  - Body: `{ "pricing_plan_id": 1 }`
  - This creates a subscription and returns a payment URL

### Bundle Subscriptions

- **Create multiple subscriptions as a bundle**:
  - `POST /api/subscriptions/users/me/bundles/`
  - Body: `{ "pricing_plan_ids": [1, 2, 3] }`
  - This creates multiple subscriptions and returns a single payment URL

### Payment Verification

- **Verify payment status**:
  - `POST /api/subscriptions/payments/verify/`
  - Body: `{ "transaction_id": "transaction-id-from-sumup" }`
  - Use this to check if a payment was successful

### Payment Methods

- **Get available payment methods**:
  - `GET /api/subscriptions/payments/methods/`
  - Returns the payment methods supported by your SumUp account

### Webhooks

- **SumUp webhook handler**:
  - `POST /api/subscriptions/webhooks/sumup/`
  - This endpoint is called by SumUp when payment status changes
  - It automatically updates subscription status based on payment status

## Integration Flow

1. User selects a subscription plan or bundle
2. Backend creates subscription(s) in "PENDING_PAYMENT" status
3. User is redirected to SumUp checkout URL
4. User completes payment on SumUp's platform
5. SumUp sends webhook with payment status
6. System updates subscription status based on payment result
7. User is redirected to thank you page

## Testing

For testing the integration, you can use SumUp's sandbox environment. Set `SUMUP_API_BASE_URL` to the sandbox URL in your development environment.

## Supported Subscription Types

- Monthly
- Quarterly
- Yearly
- One-time (perpetual access)
- Bundles (multiple exams/products in a single purchase)

## Troubleshooting

Check the application logs for detailed error messages. Common issues include:

- Missing or incorrect API credentials
- Webhook signature verification failures
- Network connectivity issues with SumUp API

For more information, refer to the [SumUp API documentation](https://developer.sumup.com/api). 