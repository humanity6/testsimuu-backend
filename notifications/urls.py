from django.urls import path
from .views import (
    NotificationListView,
    MarkNotificationAsReadView,
    MarkAllNotificationsAsReadView
)

urlpatterns = [
    path('users/me/notifications/', NotificationListView.as_view(), name='notification-list'),
    path('users/me/notifications/<int:notification_id>/mark-as-read/', 
         MarkNotificationAsReadView.as_view(), name='mark-notification-read'),
    path('users/me/notifications/mark-all-as-read/', 
         MarkAllNotificationsAsReadView.as_view(), name='mark-all-notifications-read'),
] 