import logging
from django.utils.deprecation import MiddlewareMixin
from .models import AffiliateLink, Affiliate
from .services import AffiliateTrackingService

logger = logging.getLogger(__name__)

class AffiliateTrackingMiddleware(MiddlewareMixin):
    """
    Middleware to track affiliate referrals and store them in the session.
    
    This middleware checks for affiliate tracking parameters in the URL
    and stores them in the session for later use during conversions.
    """
    
    def process_request(self, request):
        # Only process GET requests
        if request.method != 'GET':
            return None
            
        # Check for tracking parameters in URL
        ref = request.GET.get('ref')
        aff_id = request.GET.get('aff_id')
        
        if not (ref or aff_id):
            return None
            
        # Initialize the session if not already done
        if not request.session.session_key:
            request.session.save()
            
        # Store affiliate info in session
        if ref:
            try:
                # Try to find the affiliate by tracking code
                affiliate = Affiliate.objects.get(tracking_code=ref, is_active=True)
                request.session['affiliate_ref'] = ref
                request.session['affiliate_id'] = affiliate.id
                request.session.modified = True
                
                logger.info(f"Storing affiliate ref in session: {ref}")
            except Affiliate.DoesNotExist:
                logger.warning(f"Invalid affiliate ref: {ref}")
                
        if aff_id:
            try:
                # Try to find the affiliate link by tracking ID
                link = AffiliateLink.objects.get(tracking_id=aff_id, is_active=True)
                
                request.session['affiliate_link_id'] = aff_id
                request.session['affiliate_id'] = link.affiliate.id
                request.session.modified = True
                
                # Track click if this is a new session or a different link
                if not request.session.get('tracked_link_id') or request.session.get('tracked_link_id') != aff_id:
                    tracking_service = AffiliateTrackingService()
                    click = tracking_service.track_click(
                        affiliate_link=link,
                        request=request,
                        user=request.user if hasattr(request, 'user') and request.user.is_authenticated else None,
                        session_id=request.session.session_key
                    )
                    
                    # Mark this link as tracked in this session
                    request.session['tracked_link_id'] = aff_id
                    request.session.modified = True
                    
                    logger.info(f"Tracked click for affiliate link: {aff_id}")
            except AffiliateLink.DoesNotExist:
                logger.warning(f"Invalid affiliate link ID: {aff_id}")
                
        return None 