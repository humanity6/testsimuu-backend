from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from subscriptions.models import UserSubscription, Payment
from subscriptions.services import SubscriptionManagementService
from notifications.models import Notification
import logging

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Manages subscription-related tasks'

    def add_arguments(self, parser):
        parser.add_argument(
            '--task',
            type=str,
            choices=['process-expired', 'send-reminders', 'sync-payments', 'all'],
            default='all',
            help='Specific task to run (default: all)'
        )
        parser.add_argument(
            '--days',
            type=int,
            default=7,
            help='Days before subscription expiration to send reminders (default: 7)'
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Run without making changes (preview mode)'
        )

    def handle(self, *args, **options):
        task = options['task']
        days = options['days']
        dry_run = options['dry_run']
        
        subscription_service = SubscriptionManagementService()
        
        if task in ['process-expired', 'all']:
            self.process_expired_subscriptions(subscription_service, dry_run)
            
        if task in ['send-reminders', 'all']:
            self.send_expiration_reminders(subscription_service, days, dry_run)
            
        if task in ['sync-payments', 'all']:
            self.sync_pending_payments(dry_run)
    
    def process_expired_subscriptions(self, subscription_service, dry_run=False):
        """Process subscriptions that have expired."""
        self.stdout.write("Processing expired subscriptions...")
        
        now = timezone.now()
        expired_subscriptions = UserSubscription.objects.filter(
            status='ACTIVE',
            end_date__lt=now
        )
        
        self.stdout.write(f"Found {expired_subscriptions.count()} expired subscriptions")
        
        if dry_run:
            self.stdout.write("DRY RUN - No changes will be made")
            for subscription in expired_subscriptions:
                self.stdout.write(f"  Would expire: {subscription.id} - {subscription.user.email} - {subscription.pricing_plan.name}")
            return
        
        count = subscription_service.process_expired_subscriptions()
        self.stdout.write(self.style.SUCCESS(f"Successfully processed {count} expired subscriptions"))
    
    def send_expiration_reminders(self, subscription_service, days=7, dry_run=False):
        """Send reminders for subscriptions expiring soon."""
        self.stdout.write(f"Sending reminders for subscriptions expiring in the next {days} days...")
        
        expiring_subscriptions = subscription_service.check_expiring_subscriptions(days_before=days)
        
        self.stdout.write(f"Found {expiring_subscriptions.count()} subscriptions expiring soon")
        
        if dry_run:
            self.stdout.write("DRY RUN - No reminders will be sent")
            for subscription in expiring_subscriptions:
                self.stdout.write(f"  Would notify: {subscription.user.email} - Expires: {subscription.end_date}")
            return
        
        for subscription in expiring_subscriptions:
            try:
                # Create notification
                Notification.objects.create(
                    user=subscription.user,
                    title='Subscription Expiring Soon',
                    message=f'Your subscription to {subscription.pricing_plan.name} will expire on {subscription.end_date.strftime("%Y-%m-%d")}. Please renew to maintain access.',
                    notification_type='SUBSCRIPTION',
                    is_read=False
                )
                
                # Mark as reminder sent
                subscription.renewal_reminder_sent = True
                subscription.save()
                
                self.stdout.write(f"  Reminder sent to {subscription.user.email}")
                
            except Exception as e:
                logger.error(f"Error sending reminder for subscription {subscription.id}: {str(e)}")
        
        self.stdout.write(self.style.SUCCESS(f"Successfully sent reminders for {expiring_subscriptions.count()} subscriptions"))
    
    def sync_pending_payments(self, dry_run=False):
        """Sync pending payments with payment gateway."""
        self.stdout.write("Syncing pending payments...")
        
        # Get payments that are still in pending status
        pending_payments = Payment.objects.filter(status='PENDING')
        
        self.stdout.write(f"Found {pending_payments.count()} pending payments")
        
        if dry_run:
            self.stdout.write("DRY RUN - No payments will be synced")
            for payment in pending_payments:
                self.stdout.write(f"  Would sync: {payment.id} - {payment.user.email} - {payment.amount} {payment.currency}")
            return
        
        payment_service = subscription_service = SubscriptionManagementService().payment_service
        synced_count = 0
        
        for payment in pending_payments:
            try:
                result = payment_service.verify_payment(payment.payment_gateway_transaction_id)
                
                if result.get('status') == 'success':
                    synced_count += 1
                    self.stdout.write(f"  Synced payment {payment.id} - New status: {payment.status}")
                
            except Exception as e:
                logger.error(f"Error syncing payment {payment.id}: {str(e)}")
        
        self.stdout.write(self.style.SUCCESS(f"Successfully synced {synced_count} payments")) 