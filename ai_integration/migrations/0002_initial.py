# Generated by Django 5.2.1 on 2025-05-10 15:57

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('ai_integration', '0001_initial'),
        ('questions', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='aicontentalert',
            name='related_question',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='ai_alerts', to='questions.question'),
        ),
        migrations.AddField(
            model_name='aicontentalert',
            name='related_topic',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='ai_alerts', to='questions.topic'),
        ),
    ]
