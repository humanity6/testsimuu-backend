from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, UserPreference

class UserPreferenceInline(admin.StackedInline):
    model = UserPreference
    can_delete = False
    verbose_name_plural = 'Preferences'

class UserAdmin(BaseUserAdmin):
    inlines = (UserPreferenceInline,)
    list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'email_verified', 'last_active')
    list_filter = ('is_staff', 'is_superuser', 'is_active', 'email_verified')
    search_fields = ('username', 'email', 'first_name', 'last_name')
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Additional Info', {'fields': ('email_verified', 'profile_picture_url', 'date_of_birth', 
                                       'gdpr_consent_date', 'referral_code', 'last_active', 'time_zone')}),
    )

admin.site.register(User, UserAdmin) 