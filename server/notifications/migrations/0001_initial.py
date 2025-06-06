# Generated notification system migration

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone
import uuid


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='NotificationSettings',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('friend_requests', models.BooleanField(default=True)),
                ('events', models.BooleanField(default=True)),
                ('reminders', models.BooleanField(default=True)),
                ('nearby_events', models.BooleanField(default=True)),
                ('system_notifications', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='notification_settings', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'notification_settings',
            },
        ),
        migrations.CreateModel(
            name='FCMToken',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('token', models.TextField(unique=True)),
                ('device_platform', models.CharField(default='unknown', max_length=20)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('last_used', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='fcm_tokens', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'fcm_tokens',
            },
        ),
        migrations.CreateModel(
            name='NotificationHistory',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('notification_type', models.CharField(choices=[('friend_request', 'Friend Request'), ('friend_request_accepted', 'Friend Request Accepted'), ('new_event', 'New Event'), ('still_there', 'Still There Confirmation'), ('event_update', 'Event Update'), ('event_cancelled', 'Event Cancelled'), ('nearby_event', 'Nearby Event'), ('reminder', 'Reminder'), ('system', 'System Notification')], max_length=50)),
                ('title', models.CharField(max_length=255)),
                ('body', models.TextField()),
                ('data', models.JSONField(default=dict)),
                ('sent', models.BooleanField(default=False)),
                ('delivered', models.BooleanField(default=False)),
                ('read', models.BooleanField(default=False)),
                ('processed', models.BooleanField(default=False)),
                ('sent_at', models.DateTimeField(blank=True, null=True)),
                ('delivered_at', models.DateTimeField(blank=True, null=True)),
                ('read_at', models.DateTimeField(blank=True, null=True)),
                ('processed_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='notifications', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'notification_history',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='FriendRequest',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('accepted', 'Accepted'), ('rejected', 'Rejected'), ('cancelled', 'Cancelled')], default='pending', max_length=20)),
                ('message', models.TextField(blank=True, default='')),
                ('notification_sent', models.BooleanField(default=False)),
                ('notification_id', models.UUIDField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('responded_at', models.DateTimeField(blank=True, null=True)),
                ('from_user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='sent_friend_requests', to=settings.AUTH_USER_MODEL)),
                ('to_user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='received_friend_requests', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'friend_requests',
            },
        ),
        migrations.CreateModel(
            name='EventConfirmation',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('event_id', models.CharField(max_length=255)),
                ('is_still_there', models.BooleanField()),
                ('response_message', models.TextField(blank=True, default='')),
                ('notification_id', models.UUIDField(blank=True, null=True)),
                ('confirmation_request_sent', models.BooleanField(default=False)),
                ('response_received', models.BooleanField(default=False)),
                ('requested_at', models.DateTimeField(auto_now_add=True)),
                ('responded_at', models.DateTimeField(blank=True, null=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='event_confirmations', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'event_confirmations',
            },
        ),
        migrations.CreateModel(
            name='NotificationQueue',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('notification_type', models.CharField(max_length=50)),
                ('title', models.CharField(max_length=255)),
                ('body', models.TextField()),
                ('data', models.JSONField(default=dict)),
                ('priority', models.CharField(choices=[('low', 'Low'), ('normal', 'Normal'), ('high', 'High'), ('urgent', 'Urgent')], default='normal', max_length=10)),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('processing', 'Processing'), ('sent', 'Sent'), ('failed', 'Failed'), ('cancelled', 'Cancelled')], default='pending', max_length=20)),
                ('scheduled_for', models.DateTimeField(default=django.utils.timezone.now)),
                ('max_retries', models.IntegerField(default=3)),
                ('retry_count', models.IntegerField(default=0)),
                ('processing_started_at', models.DateTimeField(blank=True, null=True)),
                ('processed_at', models.DateTimeField(blank=True, null=True)),
                ('error_message', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='queued_notifications', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'notification_queue',
                'ordering': ['priority', 'scheduled_for'],
            },
        ),
        migrations.CreateModel(
            name='NotificationTemplate',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True)),
                ('notification_type', models.CharField(max_length=50)),
                ('title_template', models.CharField(max_length=255)),
                ('body_template', models.TextField()),
                ('data_template', models.JSONField(default=dict)),
                ('available_variables', models.JSONField(default=list, help_text='List of available template variables')),
                ('description', models.TextField(blank=True)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'db_table': 'notification_templates',
            },
        ),
        migrations.AddConstraint(
            model_name='fcmtoken',
            constraint=models.UniqueConstraint(fields=('user', 'token'), name='unique_user_token'),
        ),
        migrations.AddConstraint(
            model_name='friendrequest',
            constraint=models.UniqueConstraint(fields=('from_user', 'to_user'), name='unique_friend_request'),
        ),
        migrations.AddConstraint(
            model_name='eventconfirmation',
            constraint=models.UniqueConstraint(fields=('event_id', 'user', 'requested_at'), name='unique_event_confirmation'),
        ),
    ]
