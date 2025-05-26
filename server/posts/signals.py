"""
Signal handlers for post-related models.
"""

from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import EventStatusVote, Post, PostStatus

@receiver(post_save, sender=EventStatusVote)
def check_event_status_after_vote(sender, instance, created, **kwargs):
    """
    Check if a post should be marked as ended after a new vote is registered.
    """
    if created:  # Only process for new votes
        post = instance.post
        
        # Only check for posts that are still happening
        if post.status == PostStatus.HAPPENING:
            # Check if the post should be ended based on votes
            if post.should_mark_as_ended():
                post.status = PostStatus.ENDED
                post.event_status = PostStatus.ENDED  # Update both status fields
                post.save(update_fields=['status', 'event_status'])
                print(f"Post '{post.title}' (ID: {post.id}) marked as ENDED based on votes.")
