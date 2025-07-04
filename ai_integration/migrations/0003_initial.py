# Generated by Django 5.2.1 on 2025-05-10 15:57

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('ai_integration', '0002_initial'),
        ('assessment', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='aicontentalert',
            name='reviewed_by_admin',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='reviewed_ai_alerts', to=settings.AUTH_USER_MODEL),
        ),
        migrations.AddField(
            model_name='aievaluationlog',
            name='user_answer',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='ai_evaluation_logs', to='assessment.useranswer'),
        ),
    ]
