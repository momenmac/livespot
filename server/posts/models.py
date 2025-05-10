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
    PENDING = 'pending', _('Pending')
    PUBLISHED = 'published', _('Published')
    REJECTED = 'rejected', _('Rejected')
    ARCHIVED = 'archived', _('Archived')

class PostCoordinates(models.Model):
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.CharField(max_length=255, null=True, blank=True)

    def __str__(self):
        return f"{self.latitude}, {self.longitude}"

class Thread(models.Model):
    title = models.CharField(max_length=100)
    category = models.CharField(
        max_length=20,
        choices=PostCategory.choices,
        default=PostCategory.NEWS
    )
    location = models.ForeignKey(
        PostCoordinates, 
        on_delete=models.CASCADE,
        related_name='threads'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    tags = models.JSONField(default=list)
    honesty_score = models.IntegerField(default=100)

    def __str__(self):
        return self.title

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
        default=PostStatus.PUBLISHED
    )
    thread = models.ForeignKey(
        Thread, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='posts'
    )
    is_verified_location = models.BooleanField(default=True)
    taken_within_app = models.BooleanField(default=True)
    tags = models.JSONField(default=list)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title
    
    @property
    def vote_score(self):
        return self.upvotes - self.downvotes
    
    @property
    def has_media(self):
        return len(self.media_urls) > 0
    
    @property
    def is_in_thread(self):
        return self.thread is not None
        
    @property
    def user_vote(self):
        """Return the user's vote status for serialization.
        1 = upvoted, -1 = downvoted, 0 = no vote
        This will be used by the API when the user's vote status is needed.
        """
        # This will be set dynamically by the serializer
        return getattr(self, '_user_vote', 0)

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

class PostThread(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='threads')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='thread_posts')
    content = models.TextField()
    media_url = models.CharField(max_length=255, null=False, blank=False)  # Media is required
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    likes = models.IntegerField(default=0)
    replies = models.IntegerField(default=0)
    is_verified_location = models.BooleanField(default=False)  # Must be verified

    class Meta:
        ordering = ['-created_at']
        
    def __str__(self):
        return f"Thread by {self.author.username} on post {self.post.title}"
