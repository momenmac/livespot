from django.db import models
from django.contrib.auth import get_user_model
from django.utils.translation import gettext_lazy as _

User = get_user_model()

class PostCategory(models.TextChoices):
    NEWS = 'news', _('News')
    EVENT = 'event', _('Event')
    ALERT = 'alert', _('Alert')
    MILITARY = 'military', _('Military')
    CASUALTIES = 'casualties', _('Casualties')
    EXPLOSION = 'explosion', _('Explosion')
    POLITICS = 'politics', _('Politics')
    SPORTS = 'sports', _('Sports')
    HEALTH = 'health', _('Health')
    TRAFFIC = 'traffic', _('Traffic')
    WEATHER = 'weather', _('Weather')
    CRIME = 'crime', _('Crime')
    COMMUNITY = 'community', _('Community')
    DISASTER = 'disaster', _('Disaster')
    ENVIRONMENT = 'environment', _('Environment')
    EDUCATION = 'education', _('Education')
    FIRE = 'fire', _('Fire')
    OTHER = 'other', _('Other')

class PostStatus(models.TextChoices):
    HAPPENING = 'happening', _('Happening')
    ENDED = 'ended', _('Ended')

class PostCoordinates(models.Model):
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.CharField(max_length=255, null=True, blank=True)

    def __str__(self):
        return f"{self.latitude}, {self.longitude}"

class Post(models.Model):
    title = models.CharField(max_length=100)
    content = models.TextField()
    media_urls = models.JSONField(default=list)
    category = models.CharField(
        max_length=20,
        choices=PostCategory.choices,
        default=PostCategory.NEWS
    )
    location = models.ForeignKey(
        PostCoordinates, 
        on_delete=models.CASCADE,
        related_name='posts'
    )
    author = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name='posts'
    )
    is_anonymous = models.BooleanField(default=False)  # New field to mark post as anonymous
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True)
    upvotes = models.IntegerField(default=0)
    downvotes = models.IntegerField(default=0)
    honesty_score = models.IntegerField(default=100)
    status = models.CharField(
        max_length=20, 
        choices=PostStatus.choices,
        default=PostStatus.HAPPENING
    )
    is_verified_location = models.BooleanField(default=True)
    taken_within_app = models.BooleanField(default=True)
    tags = models.JSONField(default=list)
    related_post = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='related_posts'
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        # Ensure proper Unicode handling for Arabic text
        try:
            return self.title
        except UnicodeEncodeError:
            return self.title.encode('utf-8', errors='ignore').decode('utf-8')

    @property
    def vote_score(self):
        return self.upvotes - self.downvotes
    
    @property
    def has_media(self):
        return len(self.media_urls) > 0
        
    @property
    def user_vote(self):
        """Return the user's vote status for serialization.
        1 = upvoted, -1 = downvoted, 0 = no vote
        This will be used by the API when the user's vote status is needed.
        """
        # This will be set dynamically by the serializer
        return getattr(self, '_user_vote', 0)
    
    @property
    def is_main_post(self):
        """Return True if this post is a main post (not related to any other post)"""
        return self.related_post is None
    
    @property
    def related_posts_count(self):
        """Return the number of posts related to this one"""
        if hasattr(self, '_related_posts_count'):
            return self._related_posts_count
        
        # If this is a main post, count posts that reference it
        if self.related_post is None:
            return Post.objects.filter(related_post=self).count()
        else:
            # If this is a related post, count all posts related to the same main post
            return Post.objects.filter(related_post=self.related_post).count()
    
    @property
    def has_related_posts(self):
        """Return True if this post has related posts"""
        return self.related_posts_count > 0
    
    @property
    def is_happening(self):
        """Return True if the event is currently happening"""
        return self.status == PostStatus.HAPPENING
    
    @property
    def is_ended(self):
        """Return True if the event has ended"""
        return self.status == PostStatus.ENDED
    
    def get_ended_votes_count(self):
        """Get count of users who voted that this event has ended"""
        return self.status_votes.filter(voted_ended=True).count()
    
    def get_happening_votes_count(self):
        """Get count of users who voted that this event is still happening"""
        return self.status_votes.filter(voted_ended=False).count()
    
    def should_mark_as_ended(self, threshold=3):
        """Check if event should be marked as ended based on user votes"""
        # If we have the cached vote counts, use them
        if hasattr(self, '_ended_votes_count') and hasattr(self, '_happening_votes_count'):
            ended_votes = self._ended_votes_count
            total_votes = self._ended_votes_count + self._happening_votes_count
        else:
            # Otherwise, query the database
            ended_votes = self.get_ended_votes_count()
            total_votes = self.status_votes.count()
        
        # If we have at least threshold votes and majority says ended
        if total_votes >= threshold:
            return ended_votes > (total_votes / 2)
        
        # If we have overwhelming ended votes (e.g., 5+ people say ended)
        return ended_votes >= 5

    def check_and_update_status(self):
        """Check if post should be marked as ended based on time (auto-updates)"""
        from datetime import timedelta
        from django.utils import timezone
        
        # Only check posts that are still happening
        if self.status != PostStatus.HAPPENING:
            return False
            
        # Set time threshold for auto-ending (24 hours by default)
        time_threshold = timezone.now() - timedelta(hours=24)
        
        # If post is older than threshold, mark as ended
        if self.created_at < time_threshold:
            self.status = PostStatus.ENDED
            self.save(update_fields=['status'])
            return True
            
        return False
    
class PostVote(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='votes')
    is_upvote = models.BooleanField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'post')
        
    def __str__(self):
        vote_type = "Upvote" if self.is_upvote else "Downvote"
        return f"{vote_type} by {self.user.username} on {self.post.title}"

class EventStatusVote(models.Model):
    """Track user votes for event status (happening/ended)"""
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='status_votes')
    voted_ended = models.BooleanField(default=True, help_text="True if user thinks event ended")
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ('user', 'post')
        
    def __str__(self):
        status = "ended" if self.voted_ended else "still happening"
        return f"{self.user.username} voted {self.post.title} as {status}"

class CategoryInteraction(models.Model):
    """Track user interactions with post categories for analytics - with aggregated counters"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='category_interactions')
    category = models.CharField(
        max_length=20,
        choices=PostCategory.choices,
        help_text="Category that was interacted with"
    )
    interaction_type = models.CharField(
        max_length=20,
        choices=[
            ('filter', 'Filter'),
            ('view', 'View'),
            ('click', 'Click'),
        ],
        default='filter',
        help_text="Type of interaction with the category"
    )
    count = models.PositiveIntegerField(
        default=1,
        help_text="Number of times this interaction has occurred"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    last_updated = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-last_updated']
        unique_together = ('user', 'category', 'interaction_type')
        
    def __str__(self):
        username = getattr(self.user, 'username', self.user.email)
        return f"{username} {self.interaction_type} {self.category} category ({self.count}x)"
    
    @classmethod
    def increment_interaction(cls, user, category, interaction_type='filter'):
        """
        Increment the count for a specific user-category-interaction_type combination.
        Creates a new record if it doesn't exist.
        """
        try:
            interaction, created = cls.objects.get_or_create(
                user=user,
                category=category,
                interaction_type=interaction_type,
                defaults={'count': 1}
            )
            
            if not created:
                # Record exists, increment the count
                interaction.count += 1
                interaction.save(update_fields=['count', 'last_updated'])
                
            return interaction
        except Exception as e:
            print(f"⚠️ Error incrementing category interaction: {e}")
            return None


