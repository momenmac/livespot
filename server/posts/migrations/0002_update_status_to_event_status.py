# Generated migration to update status field from publication status to event status

from django.db import migrations, models
from django.conf import settings

def update_status_to_event_status(apps, schema_editor):
    """Convert existing status values to event status values"""
    Post = apps.get_model('posts', 'Post')
    
    # Update all existing posts to 'happening' status
    # Since we're changing the meaning of status field
    Post.objects.all().update(status='happening')

def reverse_status_update(apps, schema_editor):
    """Reverse the status update (set back to published)"""
    Post = apps.get_model('posts', 'Post')
    
    # Set all posts back to published (original default)
    Post.objects.all().update(status='published')

class Migration(migrations.Migration):

    dependencies = [
        ('posts', '0001_initial'),  # Replace with your latest migration
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # Add the new EventStatusVote model
        migrations.CreateModel(
            name='EventStatusVote',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('voted_ended', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('post', models.ForeignKey(on_delete=models.CASCADE, related_name='status_votes', to='posts.post')),
                ('user', models.ForeignKey(on_delete=models.CASCADE, to=settings.AUTH_USER_MODEL)),  # Use settings reference
            ],
            options={
                'unique_together': {('user', 'post')},
            },
        ),
        
        # Run the data migration to update existing status values
        migrations.RunPython(
            update_status_to_event_status,
            reverse_status_update
        ),
    ]
